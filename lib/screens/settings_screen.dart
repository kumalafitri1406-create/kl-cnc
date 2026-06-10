// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/grbl_state.dart';
import '../services/connection_service.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  final ConnectionService conn;
  const SettingsScreen({super.key, required this.conn});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _bedXCtrl;
  late TextEditingController _bedYCtrl;

  @override
  void initState() {
    super.initState();
    final s = widget.conn.state;
    _hostCtrl = TextEditingController(text: s.wifiHost);
    _portCtrl = TextEditingController(text: s.wifiPort.toString());
    _bedXCtrl = TextEditingController(text: s.bedX.toInt().toString());
    _bedYCtrl = TextEditingController(text: s.bedY.toInt().toString());
  }

  @override
  void dispose() {
    _hostCtrl.dispose(); _portCtrl.dispose();
    _bedXCtrl.dispose(); _bedYCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final s = widget.conn.state;
    s.wifiHost = _hostCtrl.text.trim();
    s.wifiPort = int.tryParse(_portCtrl.text) ?? 23;
    s.bedX = double.tryParse(_bedXCtrl.text) ?? 300;
    s.bedY = double.tryParse(_bedYCtrl.text) ?? 200;
    await prefs.setString('wifi_host', s.wifiHost);
    await prefs.setInt('wifi_port', s.wifiPort);
    await prefs.setDouble('bed_x', s.bedX);
    await prefs.setDouble('bed_y', s.bedY);
    await prefs.setInt('baud_rate', s.baudRate);
    await prefs.setString('cnc_type', s.cncType.name);
    await prefs.setString('unit', s.unit);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Pengaturan disimpan'),
          backgroundColor: Color(0xFF1A2E1A),
          duration: Duration(seconds: 1)));
    }
    widget.conn.notifyListeners();
  }

  static Future<void> loadPrefs(ConnectionService conn) async {
    final prefs = await SharedPreferences.getInstance();
    final s = conn.state;
    s.wifiHost = prefs.getString('wifi_host') ?? '192.168.1.100';
    s.wifiPort = prefs.getInt('wifi_port') ?? 23;
    s.bedX = prefs.getDouble('bed_x') ?? 300;
    s.bedY = prefs.getDouble('bed_y') ?? 200;
    s.baudRate = prefs.getInt('baud_rate') ?? 115200;
    final ct = prefs.getString('cnc_type');
    if (ct != null) {
      s.cncType = CncType.values.firstWhere(
          (e) => e.name == ct, orElse: () => CncType.router);
    }
    s.unit = prefs.getString('unit') ?? 'mm';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.conn.state;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(children: [

        // CNC Type
        _section('🏭 JENIS MESIN', [
          GridView.count(
            crossAxisCount: 3, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8, mainAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: CncType.values.map((t) {
              final selected = s.cncType == t;
              return GestureDetector(
                onTap: () { setState(() => s.cncType = t); },
                child: Container(
                  decoration: BoxDecoration(
                      color: selected ? kNeon.withOpacity(0.15) : Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: selected ? kNeon : kBorder)),
                  alignment: Alignment.center,
                  child: Text(t.cncTypeLabel.replaceFirst('CNC ', '').replaceFirst('3D ', ''),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: selected ? kNeon : kDim,
                          fontSize: 10, fontFamily: kFontMono,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                ),
              );
            }).toList(),
          ),
        ]),
        const SizedBox(height: 8),

        // Bed size
        _section('📐 UKURAN BED', [
          Row(children: [
            _labeledField('Lebar X (mm)', _bedXCtrl),
            const SizedBox(width: 10),
            _labeledField('Panjang Y (mm)', _bedYCtrl),
          ]),
        ]),
        const SizedBox(height: 8),

        // Baud rate
        _section('🔌 USB BAUD RATE', [
          Row(children: [
            for (final b in [9600, 38400, 115200, 250000])
              Expanded(child: GestureDetector(
                onTap: () => setState(() => s.baudRate = b),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                      color: s.baudRate == b ? kNeon.withOpacity(0.15) : Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: s.baudRate == b ? kNeon : kBorder)),
                  alignment: Alignment.center,
                  child: Text(
                      b >= 1000 ? '${b ~/ 1000}k' : '$b',
                      style: TextStyle(
                          color: s.baudRate == b ? kNeon : kDim,
                          fontSize: 11, fontFamily: kFontMono)),
                ),
              )),
          ]),
        ]),
        const SizedBox(height: 8),

        // WiFi settings
        _section('📶 WiFi SERIAL BRIDGE', [
          _labeledField('IP Address', _hostCtrl,
              hint: '192.168.1.100',
              keyboard: TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 8),
          _labeledField('Port', _portCtrl,
              hint: '23',
              keyboard: TextInputType.number),
        ]),
        const SizedBox(height: 8),

        // Unit
        _section('📏 UNIT', [
          Row(children: [
            for (final u in ['mm', 'inch'])
              Expanded(child: GestureDetector(
                onTap: () { setState(() => s.unit = u); },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: s.unit == u ? kBlue.withOpacity(0.15) : Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: s.unit == u ? kBlue : kBorder)),
                  alignment: Alignment.center,
                  child: Text(u.toUpperCase(),
                      style: TextStyle(
                          color: s.unit == u ? kBlue : kDim,
                          fontSize: 13, fontFamily: kFontMono,
                          fontWeight: FontWeight.bold)),
                ),
              )),
          ]),
        ]),
        const SizedBox(height: 16),

        // Save button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_alt, size: 18),
            label: const Text('SIMPAN PENGATURAN',
                style: TextStyle(fontSize: 13, fontFamily: kFontMono,
                    fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
                backgroundColor: kNeon.withOpacity(0.15),
                foregroundColor: kNeon,
                side: const BorderSide(color: kNeon)),
          ),
        ),
        const SizedBox(height: 16),

        // Info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ℹ️  KL CNC Controller v2.0', style: neonText(size: 11)),
            const SizedBox(height: 6),
            Text('• Support GRBL 1.1 dan GRBL-HAL\n'
                '• USB OTG: CH340, CP210x, FTDI, Arduino\n'
                '• WiFi: ESP32/ESP8266 TCP-Serial bridge\n'
                '• Pinch zoom visualizer\n'
                '• Load file .nc / .gcode dari storage',
                style: dimText(size: 11)),
          ]),
        ),
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) =>
      Container(
        decoration: cardDecoration(),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 3, height: 14,
                decoration: BoxDecoration(color: kNeon, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text(title, style: neonText(size: 10, weight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          ...children,
        ]),
      );

  Widget _labeledField(String label, TextEditingController ctrl,
      {String? hint, TextInputType? keyboard}) =>
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: dimText(size: 10)),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            style: neonText(size: 14),
            keyboardType: keyboard ?? TextInputType.text,
            decoration: InputDecoration(
              hintText: hint,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
        ]),
      );
}

// Extension helper
extension CncTypeHelperExt on CncType {
  String get cncTypeLabel {
    switch (this) {
      case CncType.router: return 'CNC ROUTER';
      case CncType.laser: return 'CNC LASER';
      case CncType.fiber: return 'CNC FIBER';
      case CncType.plasma: return 'CNC PLASMA';
      case CncType.mill: return 'CNC MILL';
      case CncType.printer: return '3D PRINTER';
    }
  }
}
