// lib/screens/terminal_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/connection_service.dart';
import '../theme.dart';

class TerminalScreen extends StatefulWidget {
  final ConnectionService conn;
  const TerminalScreen({super.key, required this.conn});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final _cmdCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _autoScroll = true;
  final List<String> _history = [];
  int _histIdx = -1;

  final _quickCmds = [
    '\$?', '\$\$', '\$I', '\$G', '\$#', '\$H',
    '\$X', '\$C', '\$N0=', '\$N1=', '?', '~', '!',
  ];

  @override
  void initState() {
    super.initState();
    widget.conn.addListener(_onLog);
  }

  void _onLog() {
    if (!mounted) return;
    setState(() {});
    if (_autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut);
        }
      });
    }
  }

  void _send() {
    final cmd = _cmdCtrl.text.trim();
    if (cmd.isEmpty) return;
    widget.conn.sendCommand(cmd);
    _history.insert(0, cmd);
    if (_history.length > 50) _history.removeLast();
    _histIdx = -1;
    _cmdCtrl.clear();
  }

  void _histUp() {
    if (_history.isEmpty) return;
    setState(() {
      _histIdx = (_histIdx + 1).clamp(0, _history.length - 1);
      _cmdCtrl.text = _history[_histIdx];
      _cmdCtrl.selection = TextSelection.collapsed(offset: _cmdCtrl.text.length);
    });
  }

  void _histDown() {
    setState(() {
      if (_histIdx <= 0) {
        _histIdx = -1;
        _cmdCtrl.clear();
      } else {
        _histIdx--;
        _cmdCtrl.text = _history[_histIdx];
        _cmdCtrl.selection = TextSelection.collapsed(offset: _cmdCtrl.text.length);
      }
    });
  }

  Color _lineColor(String line) {
    if (line.startsWith('[send]')) return kNeon;
    if (line.startsWith('[err]')) return kRed;
    if (line.startsWith('[sys]')) return kBlue;
    if (line.startsWith('[recv]')) {
      if (line.contains('ok')) return Colors.greenAccent;
      if (line.contains('error') || line.contains('ALARM')) return kRed;
      if (line.startsWith('[recv] <')) return Colors.amber;
      return Colors.white70;
    }
    return kDim;
  }

  String _formatLine(String line) {
    return line
        .replaceFirst('[send]  → ', '→ ')
        .replaceFirst('[recv]  ← ', '← ')
        .replaceFirst('[sys]   ', '  ')
        .replaceFirst('[err] ! ', '! ')
        .replaceFirst('[ok] ✓ ', '✓ ');
  }

  @override
  void dispose() {
    widget.conn.removeListener(_onLog);
    _cmdCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logs = widget.conn.terminalLog;
    return Column(children: [
      // Quick command chips
      Container(
        height: 44,
        color: Colors.black54,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          itemCount: _quickCmds.length,
          itemBuilder: (_, i) {
            final cmd = _quickCmds[i];
            return GestureDetector(
              onTap: () => widget.conn.sendCommand(cmd),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: kNeon.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kNeon.withOpacity(0.4))),
                alignment: Alignment.center,
                child: Text(cmd,
                    style: const TextStyle(
                        color: kNeon, fontSize: 11, fontFamily: kFontMono)),
              ),
            );
          },
        ),
      ),

      // Terminal log
      Expanded(
        child: Container(
          color: const Color(0xFF050F05),
          child: logs.isEmpty
              ? Center(child: Text('Terminal kosong\nKirim perintah di bawah',
                  textAlign: TextAlign.center, style: dimText()))
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(8),
                  itemCount: logs.length,
                  itemBuilder: (_, i) {
                    final line = logs[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        _formatLine(line),
                        style: TextStyle(
                            color: _lineColor(line),
                            fontSize: 12,
                            fontFamily: kFontMono,
                            height: 1.4),
                      ),
                    );
                  },
                ),
        ),
      ),

      // Bottom bar
      Container(
        color: const Color(0xFF0A0A0A),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(children: [
          // Auto-scroll + clear
          Row(children: [
            GestureDetector(
              onTap: () => setState(() => _autoScroll = !_autoScroll),
              child: Row(children: [
                Icon(
                    _autoScroll ? Icons.arrow_downward : Icons.pause,
                    color: _autoScroll ? kNeon : kDim, size: 14),
                const SizedBox(width: 4),
                Text('AUTO', style: TextStyle(
                    color: _autoScroll ? kNeon : kDim,
                    fontSize: 10, fontFamily: kFontMono)),
              ]),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                widget.conn.terminalLog.clear();
                setState(() {});
              },
              child: Row(children: [
                const Icon(Icons.delete_outline, color: kDim, size: 14),
                const SizedBox(width: 4),
                Text('CLEAR', style: dimText(size: 10)),
              ]),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                final all = widget.conn.terminalLog.join('\n');
                Clipboard.setData(ClipboardData(text: all));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Log disalin ke clipboard'),
                        duration: Duration(seconds: 1)));
              },
              child: Row(children: [
                const Icon(Icons.copy, color: kDim, size: 14),
                const SizedBox(width: 4),
                Text('COPY', style: dimText(size: 10)),
              ]),
            ),
            const Spacer(),
            Text('${logs.length} lines', style: dimText(size: 10)),
          ]),
          const SizedBox(height: 6),

          // Input row
          Row(children: [
            // History buttons
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, color: kDim, size: 18),
              onPressed: _histUp,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, color: kDim, size: 18),
              onPressed: _histDown,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _cmdCtrl,
                style: neonText(size: 14),
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Ketik G-code / GRBL command...',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: Colors.black87,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: kNeon, size: 18),
                    onPressed: _send,
                  ),
                ),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }
}
