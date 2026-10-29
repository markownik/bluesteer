import CoreBluetooth
import Foundation

/// CoreBluetooth peripheral for the BlueSteer GATT service (SPEC.md §1).
/// Exposes one ordered byte stream per subscribed central ("link").
public final class BLEPeripheralService: NSObject {
    public typealias LinkID = UUID

    public static let serviceUUID = CBUUID(string: "7B5E5A6E-0001-4B1E-9C0E-5A2D2E1F0001")
    public static let txUUID = CBUUID(string: "7B5E5A6E-0002-4B1E-9C0E-5A2D2E1F0001")
    public static let rxUUID = CBUUID(string: "7B5E5A6E-0003-4B1E-9C0E-5A2D2E1F0001")
    public static let infoUUID = CBUUID(string: "7B5E5A6E-0004-4B1E-9C0E-5A2D2E1F0001")
    public static let statusUUID = CBUUID(string: "7B5E5A6E-0005-4B1E-9C0E-5A2D2E1F0001")

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
    private var pairingOpen = false
    private var accepting = true
    /// Time for a goodbye already queued to reach the centrals before the service goes away.
    static let goodbyeGrace: TimeInterval = 0.5
    private var queues: [LinkID: SendQueue] = [:]
    private let queue = DispatchQueue(label: "dev.bluesteer.ble")

    /// Bytes waiting for a central, consumed from the front without re-copying the rest.
    private struct SendQueue {
        var data = Data()
        var offset = 0
        var count: Int { data.count - offset }
        var isEmpty: Bool { offset >= data.count }
        mutating func append(_ more: Data) { data.append(more) }
        func peek(_ max: Int) -> Data { data[offset..<min(offset + max, data.count)] }
        mutating func drop(_ n: Int) {
            offset += n
            if isEmpty { data.removeAll(keepingCapacity: true); offset = 0 }
            else if offset > 1 << 16 { data.removeSubrange(0..<offset); offset = 0 }
        }
    }

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
            queues[link, default: SendQueue()].append(data)
            pump()
        }
    }

    /// Bytes queued for a link that have not been handed to CoreBluetooth yet.
    public func pendingBytes(for link: LinkID) -> Int {
        queue.sync { queues[link]?.count ?? 0 }
    }

    /// Bit 0 of the STATUS characteristic (SPEC.md §1.1): the pairing window is open.
    public func setPairingOpen(_ open: Bool) {
        queue.async { [self] in pairingOpen = open }
    }

    /// Whether remotes may connect. `false` ("Disconnect all") stops advertising,
    /// withdraws the service and closes every link after `goodbyeGrace`, so a
    /// goodbye queued just before still goes out; CoreBluetooth has no
    /// peripheral-side disconnect, but a central whose service vanished fails on
    /// its next write and drops the link itself. `true` publishes the service again.
    public func setAccepting(_ accepting: Bool) {
        queue.async { [self] in
            self.accepting = accepting
            guard manager.state == .poweredOn else { return }
            if accepting {
                publish()
                return
            }
            pump()
            queue.asyncAfter(deadline: .now() + Self.goodbyeGrace) { [self] in
                guard !self.accepting else { return }
                manager.stopAdvertising()
                manager.removeAllServices()
                isAdvertising = false
                closeAllLinks()
            }
        }
    }

    /// (Re)creates the GATT service and starts advertising once it is added.
    private func publish() {
        tx = CBMutableCharacteristic(type: Self.txUUID, properties: [.notify], value: nil, permissions: [.readable])
        let rx = CBMutableCharacteristic(type: Self.rxUUID, properties: [.writeWithoutResponse, .write], value: nil, permissions: [.writeable])
        let info = CBMutableCharacteristic(type: Self.infoUUID, properties: [.read], value: infoValue, permissions: [.readable])
        let status = CBMutableCharacteristic(type: Self.statusUUID, properties: [.read], value: nil, permissions: [.readable])
        let service = CBMutableService(type: Self.serviceUUID, primary: true)
        service.characteristics = [tx, rx, info, status]
        manager.removeAllServices()
        manager.add(service)
    }

    private func pump() {
        for (id, central) in centrals {
            guard var pending = queues[id], !pending.isEmpty else { continue }
            while !pending.isEmpty {
                let chunk = pending.peek(central.maximumUpdateValueLength)
                guard manager.updateValue(chunk, for: tx, onSubscribedCentrals: [central]) else { break }
                pending.drop(chunk.count)
            }
            queues[id] = pending
        }
    }

    /// Bluetooth went away under the links: every central is gone with it.
    private func closeAllLinks() {
        let ids = Array(centrals.keys)
        centrals.removeAll()
        queues.removeAll()
        for id in ids { onLinkClosed?(id) }
    }
}

extension BLEPeripheralService: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ p: CBPeripheralManager) {
        onStateChange?(p.state)
        guard p.state == .poweredOn else {
            isAdvertising = false
            closeAllLinks()
            return
        }
        if accepting { publish() }
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
        queues[central.identifier] = SendQueue()
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
                    queues[r.central.identifier] = SendQueue()
                    onLinkOpened?(r.central.identifier)
                }
                onBytes?(r.central.identifier, v)
            }
        }
        // One response covers the whole batch (CoreBluetooth's contract: answer the first request).
        if let first = requests.first, first.characteristic.properties.contains(.write) {
            p.respond(to: first, withResult: .success)
        }
    }

    public func peripheralManager(_ p: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard request.characteristic.uuid == Self.statusUUID else { p.respond(to: request, withResult: .attributeNotFound); return }
        request.value = Data([pairingOpen ? 1 : 0])
        p.respond(to: request, withResult: .success)
    }

    public func peripheralManagerIsReady(toUpdateSubscribers p: CBPeripheralManager) { pump() }
}
