## 1.0.0

- Initial version.
- `SecureChannel` runs `start`, `receive` and `encrypt` in call order, so BLE chunks that arrive in a burst cannot interleave nonce use.
