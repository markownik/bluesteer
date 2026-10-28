// ble-bench-peripheral: advertises the BlueSteer GATT service from this Mac and
// measures BLE throughput against the ble-bench-central Flutter app.
//
// Control bytes written by the central to RX:
//   0x01 <payload>  ping: echoed back on TX unchanged (RTT measurement)
//   0x02            start downlink flood (TX notifications as fast as possible)
//   0x03            stop downlink flood
//   anything else   counted as uplink flood data
//
// Prints per-second TX and RX byte counts. Needs Bluetooth permission for the
// terminal app that runs it (System Settings → Privacy & Security → Bluetooth).

import CoreBluetooth
import Foundation

let serviceUUID = CBUUID(string: "7B5E5A6E-0001-4B1E-9C0E-5A2D2E1F0001")
let txUUID = CBUUID(string: "7B5E5A6E-0002-4B1E-9C0E-5A2D2E1F0001")
let rxUUID = CBUUID(string: "7B5E5A6E-0003-4B1E-9C0E-5A2D2E1F0001")
let infoUUID = CBUUID(string: "7B5E5A6E-0004-4B1E-9C0E-5A2D2E1F0001")

final class Bench: NSObject, CBPeripheralManagerDelegate {
    private var manager: CBPeripheralManager!
    private var tx: CBMutableCharacteristic!
    private var flooding = false
    private var seq: UInt32 = 0
    private var txBytes = 0, rxBytes = 0, txPackets = 0
    private var subscribers: [CBCentral] = []
    private var chunkSize = 20

    override init() {
        super.init()
        manager = CBPeripheralManager(delegate: self, queue: nil)
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [self] _ in
            if txBytes > 0 || rxBytes > 0 {
                print(String(format: "tx %7.1f KB/s (%4d pkts, chunk %d)   rx %7.1f KB/s", Double(txBytes) / 1024, txPackets, chunkSize, Double(rxBytes) / 1024))
            }
            txBytes = 0; rxBytes = 0; txPackets = 0
        }
    }

    func peripheralManagerDidUpdateState(_ p: CBPeripheralManager) {
        print("bluetooth state: \(p.state.rawValue)")
        guard p.state == .poweredOn else { return }
        tx = CBMutableCharacteristic(type: txUUID, properties: [.notify], value: nil, permissions: [.readable])
        let rx = CBMutableCharacteristic(type: rxUUID, properties: [.writeWithoutResponse, .write], value: nil, permissions: [.writeable])
        var info = Data([1])
        info.append(contentsOf: [UInt8](repeating: 0xAB, count: 16))
        info.append(("bench-" + ProcessInfo.processInfo.hostName).data(using: .utf8)!)
        let infoChar = CBMutableCharacteristic(type: infoUUID, properties: [.read], value: info, permissions: [.readable])
        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [tx, rx, infoChar]
        p.add(service)
    }

    func peripheralManager(_ p: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error { print("add service failed: \(error)"); exit(1) }
        p.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [serviceUUID], CBAdvertisementDataLocalNameKey: "BlueSteer bench"])
        print("advertising BlueSteer bench; waiting for a central…")
    }

    func peripheralManager(_ p: CBPeripheralManager, central: CBCentral, didSubscribeTo c: CBCharacteristic) {
        subscribers.append(central)
        chunkSize = central.maximumUpdateValueLength
        print("central subscribed, maximumUpdateValueLength = \(chunkSize)")
    }

    func peripheralManager(_ p: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom c: CBCharacteristic) {
        subscribers.removeAll { $0.identifier == central.identifier }
        flooding = false
        print("central unsubscribed")
    }

    func peripheralManager(_ p: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for r in requests {
            guard let v = r.value, !v.isEmpty else { continue }
            switch v[0] {
            case 0x01:
                _ = p.updateValue(v, for: tx, onSubscribedCentrals: nil)
            case 0x02:
                print("downlink flood: start"); flooding = true; pump()
            case 0x03:
                print("downlink flood: stop"); flooding = false
            default:
                rxBytes += v.count
            }
            if r.characteristic.properties.contains(.write) { p.respond(to: r, withResult: .success) }
        }
    }

    func peripheralManagerIsReady(toUpdateSubscribers p: CBPeripheralManager) { pump() }

    /// Sends chunks until the transmit queue is full; resumes from the ready callback.
    private func pump() {
        while flooding {
            var chunk = Data(capacity: chunkSize)
            var s = seq.bigEndian
            withUnsafeBytes(of: &s) { chunk.append(contentsOf: $0) }
            chunk.append(contentsOf: [UInt8](repeating: UInt8(truncatingIfNeeded: seq), count: max(0, chunkSize - 4)))
            if manager.updateValue(chunk, for: tx, onSubscribedCentrals: nil) {
                seq &+= 1; txBytes += chunk.count; txPackets += 1
            } else {
                return
            }
        }
    }
}

let bench = Bench()
RunLoop.main.run()
