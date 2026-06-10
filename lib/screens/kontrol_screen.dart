// lib/screens/kontrol_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/connection_service.dart';
import '../services/grbl_service.dart';
import '../widgets/canvas_painter.dart';
import '../theme.dart';

class KontrolScreen extends StatefulWidget {
  final ConnectionService conn;
  final GrblService grbl;
  const KontrolScreen({super.key, required this.conn, required this.grbl});

  @override
  State<KontrolScreen> createState() => _KontrolScreenState();
}

class _KontrolScreenState extends State<KontrolScreen> {
  final List<ToolPathPoint> _path = [];
  double _viewOX = 150, _viewOY = 100, _viewScale = 0.8;
  double _lastPanX = 0, _lastPanY = 0;
  double _lastPinchDist = 0;
  bool _isPinching = false;

  final _gcodeCtrl = TextEditingController(text:
      '; G-code di sini\nG21 G90\nG0 X0 Y0 Z5\nM3 S12000\n'
      'G1 Z-3 F200\nG1 X50 F1000\nG1 Y50\nG1 X0 Y0\nG0 Z5\nM5\nM30');

  double _step = 1.0;
  double _jogFeed = 1000;

  @override
  void initState() {
    super.initState();
    widget.conn.addListener(_onStateChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initViewScale());
  }

  void _initViewScale() {
    final w = MediaQuery.of(context).size.width - 20;
    final h = (w * 0.65).clamp(0, 250.0);
    _viewOX = w / 2;
    _viewOY = h / 2;
    _viewScale = (w < h ? w : h) /
        (widget.conn.state.bedX > widget.conn.state.bedY
            ? widget.conn.state.bedX
            : widget.conn.state.bedY) * 0.8;
    if (mounted) setState(() {});
  }

  void _onStateChange() {
    if (!mounted) return;
    setState(() {
      final s = widget.conn.state;
      _path.add(ToolPathPoint(
          _path.isNotEmpty ? _path.last.x2 : 0,
          _path.isNotEmpty ? _path.last.y2 : 0,
          s.posX, s.posY,
          rapid: s.status != MachineStatus.run));
      if (_path.length > 2000) _path.removeAt(0);
    });
  }

  @override
  void dispose() {
    widget.conn.removeListener(_onStateChange);
    _gcodeCtrl.dispose();
    super.dispose();
  }

  void _jog(String axis, double dir) {
    widget.grbl.jog(axis, dir);
    setState(() {});
  }

  Future<void> _loadFile() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['nc', 'gcode', 'tap', 'cnc', 'txt']);
    if (result != null && result.files.single.bytes != null) {
      final content = String.fromCharCodes(result.files.single.bytes!);
      setState(() => _gcodeCtrl.text = content);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.conn.state;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(children: [

        // ── STATUS ROW ──
        _buildStatusRow(s),
        const SizedBox(height: 8),

        // ── VISUALIZER ──
        _buildVisualizer(s),
        const SizedBox(height: 8),

        // ── JOG CONTROL ──
        _buildJogCard(s),
        const SizedBox(height: 8),

        // ── ZERO POINT ──
        _buildZeroCard(s),
        const SizedBox(height: 8),

        // ── MACHINE CONTROLS ──
        _buildMachineControls(),
        const SizedBox(height: 8),

        // ── G-CODE RUN ──
        _buildGcodeCard(s),
        const SizedBox(height: 80), // space for E-STOP
      ]),
    );
  }

  // ──────────────────────────────────────────────
  // STATUS ROW
  // ──────────────────────────────────────────────
  Widget _buildStatusRow(s) {
    final items = [
      {'label': 'STATUS', 'val': s.statusText, 'color': _statusColor(s.status)},
      {'label': 'FEED', 'val': s.feedRate.toInt().toString(), 'color': Colors.white},
      {'label': 'SPINDLE', 'val': s.spindleRPM.toInt().toString(), 'color': kWarn},
      {'label': 'MODE', 'val': s.simMode ? 'SIM' : (s.connectionType == ConnectionType.usb ? 'USB' : 'WiFi'), 'color': kNeon},
    ];
    return Row(
      children: items.map((item) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder)),
          child: Column(children: [
            Text(item['label'] as String, style: dimText(size: 9)),
            const SizedBox(height: 2),
            Text(item['val'] as String,
                style: TextStyle(
                    color: item['color'] as Color,
                    fontSize: 13,
                    fontFamily: kFontMono,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
      )).toList(),
    );
  }

  Color _statusColor(MachineStatus s) {
    switch (s) {
      case MachineStatus.run: return kWarn;
      case MachineStatus.alarm: return kRed;
      case MachineStatus.hold: return Colors.amber;
      default: return kNeon;
    }
  }

  // ──────────────────────────────────────────────
  // VISUALIZER
  // ──────────────────────────────────────────────
  Widget _buildVisualizer(s) {
    return Container(
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: _cardTitle('📺 VISUALISASI'),
        ),

        // XYZ Position
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(children: [
            _posBox('X', s.posX, kNeon),
            const SizedBox(width: 6),
            _posBox('Y', s.posY, kNeon),
            const SizedBox(width: 6),
            _posBox('Z', s.posZ, kBlue),
          ]),
        ),
        const SizedBox(height: 8),

        // Canvas
        GestureDetector(
          onScaleStart: (d) {
            _lastPanX = d.focalPoint.dx;
            _lastPanY = d.focalPoint.dy;
            _lastPinchDist = 0;
            _isPinching = d.pointerCount > 1;
          },
          onScaleUpdate: (d) {
            setState(() {
              if (d.pointerCount > 1) {
                _isPinching = true;
                final newScale = (_viewScale * d.scale).clamp(0.1, 20.0);
                _viewScale = newScale;
              } else if (!_isPinching) {
                _viewOX += d.focalPoint.dx - _lastPanX;
                _viewOY += d.focalPoint.dy - _lastPanY;
              }
              _lastPanX = d.focalPoint.dx;
              _lastPanY = d.focalPoint.dy;
            });
          },
          onScaleEnd: (_) => _isPinching = false,
          child: LayoutBuilder(builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            final h = (w * 0.65).clamp(0, 280.0);
            return SizedBox(
              width: w, height: h,
              child: CustomPaint(
                painter: CanvasPainter(
                  path: _path,
                  toolX: s.posX, toolY: s.posY,
                  bedX: s.bedX, bedY: s.bedY,
                  viewOX: _viewOX, viewOY: _viewOY,
                  viewScale: _viewScale,
                  showGrid: true,
                ),
              ),
            );
          }),
        ),

        // Controls
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            _smallBtn('CLEAR', kNeon, () => setState(() => _path.clear())),
            const SizedBox(width: 6),
            _smallBtn('CENTER', kBlue, () {
              _initViewScale();
            }),
            const SizedBox(width: 6),
            _smallBtn('RESET', kRed, () {
              setState(() {
                _path.clear();
                widget.conn.state.posX = 0;
                widget.conn.state.posY = 0;
              });
            }),
            const Spacer(),
            Text('X:${s.posX.toStringAsFixed(2)} Y:${s.posY.toStringAsFixed(2)}',
                style: dimText(size: 9)),
          ]),
        ),
      ]),
    );
  }

  Widget _posBox(String axis, double val, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder)),
      child: Column(children: [
        Text(axis, style: TextStyle(color: color, fontSize: 11,
            fontFamily: kFontMono, fontWeight: FontWeight.bold)),
        Text(val.toStringAsFixed(3),
            style: const TextStyle(color: Colors.white,
                fontSize: 18, fontFamily: kFontMono)),
        Text('mm', style: dimText(size: 9)),
      ]),
    ),
  );

  // ──────────────────────────────────────────────
  // JOG CONTROL
  // ──────────────────────────────────────────────
  Widget _buildJogCard(s) {
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        _cardTitle('🕹️ JOG CONTROL'),
        const SizedBox(height: 10),

        // Step size
        Row(children: [
          Text('STEP:', style: dimText(size: 10)),
          const SizedBox(width: 8),
          for (final v in [0.01, 0.1, 1.0, 5.0, 10.0, 50.0])
            Expanded(child: GestureDetector(
              onTap: () => setState(() => _step = v),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                    color: _step == v ? kNeon.withOpacity(0.15) : Colors.black45,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: _step == v ? kNeon : kBorder)),
                child: Text(
                    v < 1 ? v.toString() : v.toInt().toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _step == v ? kNeon : kDim,
                        fontSize: 11, fontFamily: kFontMono)),
              ),
            )),
        ]),
        const SizedBox(height: 10),

        // Feed rate
        Row(children: [
          Text('FEED:', style: dimText(size: 10)),
          Expanded(child: Slider(
            value: _jogFeed,
            min: 100, max: 5000,
            onChanged: (v) => setState(() => _jogFeed = v),
          )),
          Text('${_jogFeed.toInt()}', style: neonText(size: 11)),
        ]),
        const SizedBox(height: 10),

        // XY + Z Jog pads
        Row(children: [
          // XY pad
          Expanded(flex: 2, child: Column(children: [
            Text('X · Y AXIS', style: dimText(size: 9)),
            const SizedBox(height: 4),
            _buildXYPad(),
          ])),
          const SizedBox(width: 12),
          // Z pad
          SizedBox(width: 60, child: Column(children: [
            Text('Z AXIS', style: TextStyle(color: kBlue, fontSize: 9, fontFamily: kFontMono)),
            const SizedBox(height: 4),
            _buildZPad(),
          ])),
        ]),
      ]),
    );
  }

  Widget _buildXYPad() {
    return AspectRatio(
      aspectRatio: 1,
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 5, crossAxisSpacing: 5,
        children: [
          _emptyCell(),
          _jogCell('▲', () => _jog('Y', 1)),
          _homeCell(),
          _jogCell('◀', () => _jog('X', -1)),
          _zeroCell(),
          _jogCell('▶', () => _jog('X', 1)),
          _emptyCell(),
          _jogCell('▼', () => _jog('Y', -1)),
          _emptyCell(),
        ],
      ),
    );
  }

  Widget _buildZPad() {
    return SizedBox(
      height: 160,
      child: Column(children: [
        Expanded(child: _jogCell('▲', () => _jog('Z', 1), color: kBlue)),
        const SizedBox(height: 5),
        Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder)),
          child: Text('Z', style: TextStyle(color: kDim, fontSize: 10, fontFamily: kFontMono)),
        ),
        const SizedBox(height: 5),
        Expanded(child: _jogCell('▼', () => _jog('Z', -1), color: kBlue)),
      ]),
    );
  }

  Widget _jogCell(String label, VoidCallback onTap, {Color? color}) =>
      GestureDetector(
        onTap: onTap,
        onLongPressStart: (_) {
          onTap();
          _startRepeat(onTap);
        },
        onLongPressEnd: (_) => _stopRepeat(),
        child: Container(
          decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color ?? kBorder)),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(color: color ?? kNeon, fontSize: 22)),
        ),
      );

  Timer? _repeatTimer;
  void _startRepeat(VoidCallback fn) {
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 150), (_) => fn());
  }
  void _stopRepeat() => _repeatTimer?.cancel();

  Widget _emptyCell() => const SizedBox();
  Widget _homeCell() => GestureDetector(
        onTap: widget.grbl.homeAll,
        child: Container(
          decoration: BoxDecoration(
              color: kNeon.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder)),
          alignment: Alignment.center,
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('🏠', style: TextStyle(fontSize: 16)),
            Text('HOME', style: TextStyle(color: Colors.white, fontSize: 8, fontFamily: kFontMono)),
          ]),
        ),
      );

  Widget _zeroCell() => GestureDetector(
        onTap: widget.grbl.goToZero,
        child: Container(
          decoration: BoxDecoration(
              color: kNeon.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder)),
          alignment: Alignment.center,
          child: Text('⊙', style: TextStyle(color: kNeon, fontSize: 20)),
        ),
      );

  // ──────────────────────────────────────────────
  // ZERO CARD
  // ──────────────────────────────────────────────
  Widget _buildZeroCard(s) {
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardTitle('🎯 SET TITIK NOL'),
        const SizedBox(height: 10),
        Row(children: [
          for (final ax in ['X', 'Y', 'Z', 'ALL'])
            Expanded(child: GestureDetector(
              onTap: () { widget.grbl.setZero(ax); setState(() {}); },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.3))),
                alignment: Alignment.center,
                child: Text(ax == 'ALL' ? 'ALL=0' : 'SET $ax=0',
                    style: const TextStyle(color: Colors.amber,
                        fontSize: 9, fontFamily: kFontMono, fontWeight: FontWeight.bold)),
              ),
            )),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _actionBtn('🎯 GO ZERO', Colors.amber, widget.grbl.goToZero)),
          const SizedBox(width: 8),
          Expanded(child: _actionBtn('📏 PROBE Z', kBlue, widget.grbl.probeZ)),
        ]),
      ]),
    );
  }

  // ──────────────────────────────────────────────
  // MACHINE CONTROLS
  // ──────────────────────────────────────────────
  Widget _buildMachineControls() {
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardTitle('⚡ KONTROL MESIN'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 6, mainAxisSpacing: 6,
          childAspectRatio: 2.2,
          children: [
            _ctrlBtn('🏠 HOMING', kNeon, widget.grbl.homeAll),
            _ctrlBtn('⏸ HOLD', Colors.amber, widget.grbl.hold),
            _ctrlBtn('▶ RESUME', kBlue, widget.grbl.resume),
            _ctrlBtn('🔄 RESET', kWarn, widget.grbl.softReset),
            _ctrlBtn('🔓 UNLOCK', kPurple, widget.grbl.unlock),
            _ctrlBtn('✅ CHECK', kNeon, widget.grbl.checkMode),
          ],
        ),
      ]),
    );
  }

  // ──────────────────────────────────────────────
  // G-CODE RUN
  // ──────────────────────────────────────────────
  Widget _buildGcodeCard(s) {
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardTitle('▶️ RUN G-CODE'),
        const SizedBox(height: 8),

        // Editor
        TextField(
          controller: _gcodeCtrl,
          maxLines: 8,
          style: neonText(size: 12),
          decoration: InputDecoration(
            hintText: '; Masukkan G-code di sini',
            contentPadding: const EdgeInsets.all(10),
            filled: true, fillColor: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),

        // File buttons
        Row(children: [
          Expanded(child: _smallBtn('📂 LOAD', kNeon, _loadFile)),
          const SizedBox(width: 6),
          Expanded(child: _smallBtn('🗑 CLEAR', kRed, () => setState(() => _gcodeCtrl.clear()))),
        ]),
        const SizedBox(height: 8),

        // Run buttons
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: s.running ? null : () => widget.grbl.startRun(_gcodeCtrl.text),
            icon: const Icon(Icons.play_arrow, size: 20),
            label: const Text('▶  START PROGRAM',
                style: TextStyle(fontSize: 13, fontFamily: kFontMono, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
                backgroundColor: kNeon.withOpacity(0.15),
                foregroundColor: kNeon,
                side: const BorderSide(color: kNeon)),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _ctrlBtn('⏸ PAUSE', Colors.amber, widget.grbl.pauseRun)),
          const SizedBox(width: 6),
          Expanded(child: _ctrlBtn('⏹ STOP', kRed, widget.grbl.stopRun)),
          const SizedBox(width: 6),
          Expanded(child: _ctrlBtn('🧪 DRY RUN', kBlue, () => widget.grbl.dryRun(_gcodeCtrl.text))),
        ]),
        const SizedBox(height: 10),

        // Progress
        LinearProgressIndicator(
          value: s.progressPct,
          backgroundColor: Colors.black54,
          color: kNeon,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${s.gcodeIndex} / ${s.gcodeTotal} lines', style: dimText(size: 10)),
            Text('${(s.progressPct * 100).toInt()}%',
                style: neonText(size: 11, weight: FontWeight.bold)),
          ],
        ),
        if (s.currentLine.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.black54,
                borderRadius: BorderRadius.circular(6)),
            child: Text(s.currentLine,
                style: neonText(size: 11), overflow: TextOverflow.ellipsis),
          ),
        ],
      ]),
    );
  }

  // ──────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────
  Widget _cardTitle(String t) => Row(children: [
        Container(width: 3, height: 14,
            decoration: BoxDecoration(color: kNeon, borderRadius: BorderRadius.circular(2),
                boxShadow: [BoxShadow(color: kNeon.withOpacity(0.5), blurRadius: 6)])),
        const SizedBox(width: 6),
        Text(t, style: neonText(size: 10, weight: FontWeight.bold)),
      ]);

  Widget _ctrlBtn(String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.6))),
          alignment: Alignment.center,
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 9,
                  fontFamily: kFontMono, fontWeight: FontWeight.bold)),
        ),
      );

  Widget _actionBtn(String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.5))),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(color: color, fontSize: 10,
                  fontFamily: kFontMono, fontWeight: FontWeight.bold)),
        ),
      );

  Widget _smallBtn(String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.5))),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(color: color, fontSize: 10,
                  fontFamily: kFontMono, fontWeight: FontWeight.bold)),
        ),
      );
}
