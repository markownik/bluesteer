import CoreBluetooth
import Foundation
import HostCore

/// A BlueSteer host seen while scanning.
public struct DiscoveredHost {
    public let peripheral: CBPeripheral
    /// From the advertised local name `BlueSteer <name>`.
    public let name: String
}

/// What a connected host says about itself before the handshake.
public struct ConnectedHostInfo {
    public let id: String
    public let name: String
    public let protocolVersion: Int
    public let pairingOpen: Bool
}

/// CoreBluetooth central for the BlueSteer service (SPEC.md §1): scan, connect,
/// read INFO/STATUS, then an ordered byte stream each way. All callbacks run on
/// the queue passed in; call the methods from that queue too.
public final class CentralLink: NSObject, RemoteTransport {
    public enum Error: Swift.Error, LocalizedError {
        case bluetoothOff, unauthorized, unsupported, noService, disconnected(String?)
        public var errorDescription: String? {
            switch self {
            case .bluetoothOff: "Bluetooth is off"
            case .unauthorized: "this program is not allowed to use Bluetooth (run it from a terminal app with Bluetooth access in System Settings > Privacy & Security > Bluetooth; an ssh session has none)"
            case .unsupported: "this Mac has no Bluetooth LE"
            case .noService: "the device has no BlueSteer service"
            case .disconnected(let why): "disconnected" + (why.map { ": \($0)" } ?? "")
            }
        }
    }

    public var onData: ((Data) -> Void)?
    public var onClosed: (() -> Void)?
    public var onDiscovered: ((DiscoveredHost) -> Void)?

    public let queue: DispatchQueue
    private var manager: CBCentralManager!
    private var ready: ((Swift.Error?) -> Void)?
    private var peripheral: CBPeripheral?
    private var tx: CBCharacteristic?, rx: CBCharacteristic?, info: CBCharacteristic?, status: CBCharacteristic?
    private var infoValue: Data?, statusValue: Data?
    private var connectCompletion: ((Result<ConnectedHostInfo, Swift.Error>) -> Void)?
    private var pendingWrites = Data()
    private var chunkSize = 20
    private var open = false

    public init(queue: DispatchQueue) {
        self.queue = queue
        super.init()
        manager = CBCentralManager(delegate: self, queue: queue)
    }

    /// Waits for Bluetooth to be powered on.
    public func waitForPower(_ completion: @escaping (Swift.Error?) -> Void) {
        if manager.state == .poweredOn { completion(nil) } else { ready = completion }
    }

    public func startScan() {
        manager.scanForPeripherals(withServices: [BLEPeripheralService.serviceUUID],
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    public func stopScan() { manager.stopScan() }

    /// Connects, discovers the service, reads INFO and STATUS, subscribes to TX.
    public func connect(_ peripheral: CBPeripheral, completion: @escaping (Result<ConnectedHostInfo, Swift.Error>) -> Void) {
        self.peripheral = peripheral
        connectCompletion = completion
        peripheral.delegate = self
        manager.connect(peripheral)
    }

    public func write(_ data: Data) {
        pendingWrites.append(data)
        pump()
    }

    public func close() {
        if let p = peripheral { manager.cancelPeripheralConnection(p) }
    }

    private func pump() {
        guard let p = peripheral, let rx, open else { return }
        while !pendingWrites.isEmpty, p.canSendWriteWithoutResponse {
            let chunk = pendingWrites.prefix(chunkSize)
            p.writeValue(chunk, for: rx, type: .withoutResponse)
            pendingWrites.removeFirst(chunk.count)
        }
    }

    private func fail(_ error: Swift.Error) {
        if let c = connectCompletion { connectCompletion = nil; c(.failure(error)) }
    }
}

extension CentralLink: CBCentralManagerDelegate, CBPeripheralDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard let ready else { return }
        switch central.state {
        case .poweredOn: self.ready = nil; ready(nil)
        case .poweredOff: self.ready = nil; ready(Error.bluetoothOff)
        case .unauthorized: self.ready = nil; ready(Error.unauthorized)
        case .unsupported: self.ready = nil; ready(Error.unsupported)
        default: break
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let local = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? peripheral.identifier.uuidString
        let name = local.hasPrefix("BlueSteer ") ? String(local.dropFirst(10)) : local
        onDiscovered?(DiscoveredHost(peripheral: peripheral, name: name))
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([BLEPeripheralService.serviceUUID])
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Swift.Error?) {
        fail(error ?? Error.disconnected(nil))
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Swift.Error?) {
        let wasOpen = open
        open = false
        fail(Error.disconnected(error?.localizedDescription))
        if wasOpen { onClosed?() }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Swift.Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == BLEPeripheralService.serviceUUID }) else {
            fail(error ?? Error.noService); close(); return
        }
        peripheral.discoverCharacteristics(nil, for: service)
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Swift.Error?) {
        for c in service.characteristics ?? [] {
            switch c.uuid {
            case BLEPeripheralService.txUUID: tx = c
            case BLEPeripheralService.rxUUID: rx = c
            case BLEPeripheralService.infoUUID: info = c
            case BLEPeripheralService.statusUUID: status = c
            default: break
            }
        }
        guard let tx, rx != nil, let info else { fail(Error.noService); close(); return }
        chunkSize = max(20, min(peripheral.maximumWriteValueLength(for: .withoutResponse), 512))
        peripheral.readValue(for: info)
        if let status { peripheral.readValue(for: status) }
        peripheral.setNotifyValue(true, for: tx)
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Swift.Error?) {
        guard let value = characteristic.value else { return }
        switch characteristic.uuid {
        case BLEPeripheralService.infoUUID: infoValue = value; finishConnectIfReady()
        case BLEPeripheralService.statusUUID: statusValue = value; finishConnectIfReady()
        case BLEPeripheralService.txUUID: onData?(value)
        default: break
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Swift.Error?) {
        guard characteristic.uuid == BLEPeripheralService.txUUID else { return }
        if let error { fail(error); close(); return }
        open = characteristic.isNotifying
        finishConnectIfReady()
        pump()
    }

    public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) { pump() }

    private func finishConnectIfReady() {
        guard open, let infoValue, infoValue.count >= 17, (status == nil || statusValue != nil), let c = connectCompletion else { return }
        connectCompletion = nil
        let id = infoValue[1..<17].base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        let name = String(decoding: infoValue.dropFirst(17), as: UTF8.self)
        let pairingOpen = (statusValue?.first ?? 0) & 1 == 1
        c(.success(ConnectedHostInfo(id: id, name: name, protocolVersion: Int(infoValue[0]), pairingOpen: pairingOpen)))
    }
}
