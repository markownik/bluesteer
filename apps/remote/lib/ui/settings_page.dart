import 'package:flutter/material.dart';

import '../core/identity.dart';

/// The few things worth setting: this device's name as the Mac shows it.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.identity});
  final Identity identity;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _name = TextEditingController(text: widget.identity.deviceName);

  @override
  void dispose() {
    widget.identity.setDeviceName(_name.text);
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'This device\'s name', helperText: 'Shown in the BlueSteer menu on your Mac'),
          textInputAction: TextInputAction.done,
          onSubmitted: widget.identity.setDeviceName,
        ),
        const SizedBox(height: 24),
        Text('BlueSteer Remote $appVersion', style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
