// lib/screens/spindle_screen.dart
import 'package:flutter/material.dart';
import '../services/connection_service.dart';
import '../services/grbl_service.dart';
import '../theme.dart';

class SpindleScreen extends StatefulWidget {
  final ConnectionService conn;
  final GrblService grbl;
  const SpindleScreen({super.key, required this.conn, required this.grbl});

  @override
  State<SpindleScreen> createState() => _SpindleScreenState();
}

class _SpindleScreenState extends State<SpindleScreen> {
  double _rpm = 0;
  double _feedOvr = 100;
  double _spindleOvr = 100;

  void _setRpm(double v) {
    setState(() => _rpm = v);
    widget.conn.state.spindleRPM = v;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(children: [

        // Spindle control
        Container(
          decoration: cardDecoration(),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _cardTitle('⚙️ KONTROL SPINDLE / LASER'),
            const SizedBox(height: 14),

            Row(children: [
              Text('RPM / Power:', style: dimText()),
              Expanded(child: Slider(
                value: _rpm,
                min: 0, max: 24000,
                divisions: 240,
                onChanged: _setRpm,
                activeColor: kWarn,
                thumbColor: kWarn,
              )),
              SizedBox(
                width: 70,
                child: Text('${_rpm.toInt()}',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: kWarn, fontSize: 13, fontFamily: kFontMono)),
              ),
            ]),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(child: _btn('🔧 SPINDLE ON\n(M3)', kNeon, widget.grbl.spindleOn)),
              const SizedBox(width: 8),
              Expanded(child: _btn('🛑 SPINDLE OFF\n(M5)', kRed, widget.grbl.spindleOff)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _btn('🔄 CCW (M4)', kWarn, widget.grbl.spindleCCW)),
              const SizedBox(width: 8),
              Expanded(child: _btn('💧 COOLANT ON\n(M8)', kBlue, widget.grbl.coolantOn)),
              const SizedBox(width: 8),
              Expanded(child: _btn('🚫 COOLANT OFF\n(M9)', Colors.amber, widget.grbl.coolantOff)),
            ]),
          ]),
        ),
        const SizedBox(height: 8),

        // Preset RPM
        Container(
          decoration: cardDecoration(),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _cardTitle('PRESET RPM'),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8, mainAxisSpacing: 8,
              childAspectRatio: 3,
              children: [
                _presetBtn('🔵 6000 RPM', () => _setRpm(6000)),
                _presetBtn('🟡 10000 RPM', () => _setRpm(10000)),
                _presetBtn('🟠 15000 RPM', () => _setRpm(15000)),
                _presetBtn('🔴 20000 RPM', () => _setRpm(20000)),
                _presetBtn('⚡ MAX 24000', () => _setRpm(24000)),
                _presetBtn('⬛ STOP', () { _setRpm(0); widget.grbl.spindleOff(); }),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 8),

        // Override
        Container(
          decoration: cardDecoration(),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _cardTitle('FEED OVERRIDE'),
            const SizedBox(height: 12),
            _overrideRow('FEED %:', _feedOvr, kNeon, (v) => setState(() => _feedOvr = v)),
            const SizedBox(height: 8),
            _overrideRow('SPINDLE %:', _spindleOvr, kWarn, (v) => setState(() => _spindleOvr = v)),
          ]),
        ),
      ]),
    );
  }

  Widget _overrideRow(String label, double val, Color color, Function(double) onChanged) =>
      Row(children: [
        SizedBox(width: 80, child: Text(label, style: dimText(size: 11))),
        Expanded(child: Slider(
          value: val, min: 10, max: 200,
          onChanged: onChanged,
          activeColor: color, thumbColor: color,
        )),
        SizedBox(width: 50,
            child: Text('${val.toInt()}%',
                textAlign: TextAlign.right,
                style: TextStyle(color: color, fontSize: 12, fontFamily: kFontMono))),
      ]);

  Widget _cardTitle(String t) => Row(children: [
        Container(width: 3, height: 14,
            decoration: BoxDecoration(color: kNeon, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(t, style: neonText(size: 10, weight: FontWeight.bold)),
      ]);

  Widget _btn(String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.6))),
          alignment: Alignment.center,
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 11,
                  fontFamily: kFontMono, fontWeight: FontWeight.bold)),
        ),
      );

  Widget _presetBtn(String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder)),
          alignment: Alignment.center,
          child: Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12,
                  fontFamily: kFontMono)),
        ),
      );
}
