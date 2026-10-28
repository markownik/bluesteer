// channel-probe: cross-language conformance check for SecureChannel.
//
// Listens on TCP (loopback) as a BlueSteer host with a known pairing PSK,
// completes the Noise handshake with whatever connects, then answers every
// Ping envelope with a Pong and exits after the first Pong. The Dart side is
// packages/bluesteer_protocol_dart/tool/probe_remote.dart.
//
//   channel-probe <port> <psk-hex>     pair with a PSK (Noise_XXpsk3)
//   channel-probe <port> code          pair by code: accept any remote, print the pairing code

import BlueSteerProtocol
import Foundation
import Network

let args = CommandLine.arguments
guard args.count == 3, let port = UInt16(args[1]) else {
    print("usage: channel-probe <port> <psk-hex|code>"); exit(64)
}
let byCode = args[2] == "code"
let psk: Data? = byCode ? nil : Data(stride(from: 0, to: args[2].count, by: 2).map { i -> UInt8 in
    let s = args[2].index(args[2].startIndex, offsetBy: i)
    return UInt8(args[2][s..<args[2].index(s, offsetBy: 2)], radix: 16)!
})
setvbuf(stdout, nil, _IOLBF, 0)

let hostKey = NoiseKeyPair()
let channel = try SecureChannel(role: .host(pairedKeys: [], pairingPSK: psk, acceptUnknownRemote: byCode), staticKey: hostKey)
print("host static key: \(hostKey.publicKey.base64EncodedString())")

let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
listener.newConnectionHandler = { conn in
    conn.start(queue: .main)
    func pump() {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, done, error in
            if let error { print("receive error: \(error)"); exit(1) }
            if let data {
                do {
                    for event in try channel.receive(data) {
                        switch event {
                        case .send(let bytes):
                            conn.send(content: bytes, completion: .contentProcessed { _ in })
                        case .established(let key):
                            print("established with remote key \(key.base64EncodedString())")
                            if byCode { print("pairing code \(SecureChannel.pairingCode(handshakeHash: channel.handshakeHash!))") }
                        case .message(let plaintext):
                            let envelope = try BSEnvelope(serializedBytes: plaintext)
                            guard case .ping(let ping)? = envelope.body else { print("unexpected message"); exit(1) }
                            print("ping nonce \(ping.nonce)")
                            var reply = BSEnvelope()
                            reply.pong = BSPong.with { $0.nonce = ping.nonce }
                            let bytes = try channel.encrypt(try reply.serializedData())
                            conn.send(content: bytes, completion: .contentProcessed { _ in
                                print("pong sent; done")
                                exit(0)
                            })
                        }
                    }
                } catch {
                    print("protocol error: \(error)"); exit(1)
                }
            }
            if done { print("peer closed"); exit(1) }
            pump()
        }
    }
    pump()
}
listener.start(queue: .main)
print("listening on \(port)")
dispatchMain()
