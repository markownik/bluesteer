import CoreBluetooth
import Foundation

/// CoreBluetooth peripheral for the BlueSteer GATT service (SPEC.md §1).
/// Exposes one ordered byte stream per subscribed central ("link").
public final class BLEPeripheralService: NSObject {
    public typealias LinkID = UUID

    public static let serviceUUID = CBUUID(string: "7B5E5A6E-0001-4B1E-9C0E-5A2D2E1F0001")
    static let txUUID = CBUUID(string: "7B5E5A6E-0002-4B1E-9C0E-5A2D2E1F0001")
    static let rxUUID = CBUUID(string: "7B5E5A6E-0003-4B1E-9C0E-5A2D2E1F0001")
    static let infoUUID = CBUUID(string: "7B5E5A6E-0004-4B1E-9C0E-5A2D2E1F0001")

    public var onStateChange: ((CBManagerState) -> Void)?
    public var onLinkOpened: ((LinkID) -> Void)?
    public var onLinkClosed: ((LinkID) -> Void)?
    public var onBytes: ((LinkID, Data) -> Void)?

    public private(set) var isAdvertising = false
    public var state: CBManagerState { manager.state }

    private var manager: CBPeripheralManager!
    private var tx: CBMutableCharacteristic!
    private let infoValue: Data
    private let localName: String
    private var centrals: [LinkID: CBCentral] = [:]
    private var queues: [LinkID: Data] = [:]
    private let queue = DispatchQueue(label: "dev.bluesteer.ble")

    /// - Parameters:
    ///   - instanceID: 16 bytes identifying this host install.
    ///   - displayName: shown in the remote's host list.
    public init(protocolVersion: UInt32, instanceID: Data, displayName: String) {
        var info = Data([UInt8(protocolVersion)])
        info.append(instanceID.prefix(16))
        info.append(displayName.data(using: .utf8)!.prefix(40))
        infoValue = info
        localName = "BlueSteer \(displayName)".prefix(28).description
        super.init()
        manager = CBPeripheralManager(delegate: self, queue: queue)
    }

    /// Queues bytes for one link. They are chunked and sent as the central allows.
    public func send(_ data: Data, to link: LinkID) {
        queue.async { [self] in
            queues[link, default: Data()].append(data)
            pump()
        }
    }

    public func disconnectAll() {
        queue.async { [self] in
            // CoreBluetooth has no peripheral-side disconnect; dropping the queues and
            // restarting advertising is the closest thing. Centrals time out on their own.
            queues.removeAll()
        }
    }

    private func pump() {
        for (id, central) in centrals {
            guard var pending = queues[id], !pending.isEmpty else { continue }
            while !pending.isEmpty {
                let chunk = pending.prefix(central.maximumUpdateValueLength)
                guard manager.updateValue(chunk, for: tx, onSubscribedCentrals: [central]) else { break }
                pending.removeFirst(chunk.count)
            }
            queues[id] = pending
        }
    }
}

extension BLEPeripheralService: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ p: CBPeripheralManager) {
        onStateChange?(p.state)
        guard p.state == .poweredOn else { isAdvertising = false; return }
        tx = CBMutableCharacteristic(type: Self.txUUID, properties: [.notify], value: nil, permissions: [.readable])
        let rx = CBMutableCharacteristic(type: Self.rxUUID, properties: [.writeWithoutResponse, .write], value: nil, permissions: [.writeable])
        let info = CBMutableCharacteristic(type: Self.infoUUID, properties: [.read], value: infoValue, permissions: [.readable])
        let service = CBMutableService(type: Self.serviceUUID, primary: true)
        service.characteristics = [tx, rx, info]
        p.removeAllServices()
        p.add(service)
    }

    public func peripheralManager(_ p: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard error == nil else { return }
        p.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
                            CBAdvertisementDataLocalNameKey: localName])
    }

    public func peripheralManagerDidStartAdvertising(_ p: CBPeripheralManager, error: Error?) {
        isAdvertising = error == nil
    }

    public func peripheralManager(_ p: CBPeripheralManager, central: CBCentral, didSubscribeTo c: CBCharacteristic) {
        centrals[central.identifier] = central
        queues[central.identifier] = Data()
        onLinkOpened?(central.identifier)
    }

    public func peripheralManager(_ p: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom c: CBCharacteristic) {
        centrals[central.identifier] = nil
        queues[central.identifier] = nil
        onLinkClosed?(central.identifier)
    }

    public func peripheralManager(_ p: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for r in requests {
            if let v = r.value, r.characteristic.uuid == Self.rxUUID {
                // A write can arrive before the central subscribes to TX; treat that as link open.
                if centrals[r.central.identifier] == nil {
                    centrals[r.central.identifier] = r.central
                    queues[r.central.identifier] = Data()
                    onLinkOpened?(r.central.identifier)
                }
                onBytes?(r.central.identifier, v)
            }
            if r.characteristic.properties.contains(.write) { p.respond(to: r, withResult: .success) }
        }
    }

    public func peripheralManagerIsReady(toUpdateSubscribers p: CBPeripheralManager) { pump() }
}
