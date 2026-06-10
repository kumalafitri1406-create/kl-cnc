// lib/services/grbl_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/grbl_state.dart';
import 'connection_service.dart';

class GrblService extends ChangeNotifier {
  final ConnectionService conn;
  Timer? _runTimer;
  List<String> _gcodeLines = [];

  GrblService(this.conn);

  GrblState get state => conn.state;

  // ---------------------------------------------------------------
  // JOG
  // ---------------------------------------------------------------
  void jog(String axis, double dir) {
    final dist = state.step * dir;
    if (state.isConnected) {
      final cmd = '\$J=G91G21$axis${dist.toStringAsFixed(3)}F${state.jogFeed.toInt()}';
      conn.sendCommand(cmd);
    } else {
      // Simulator
      if (axis == 'X') state.posX += dist;
      if (axis == 'Y') state.posY += dist;
      if (axis == 'Z') state.posZ += dist;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------
  // MACHINE COMMANDS
  // ---------------------------------------------------------------
  void homeAll() {
    conn.sendCommand('\$H');
    conn.logManual('🏠 Homing...', 'sys');
    if (!state.isConnected) {
      state.posX = 0; state.posY = 0; state.posZ = 0;
      notifyListeners();
    }
  }

  void softReset() {
    conn.sendRaw(0x18); // Ctrl+X
    conn.logManual('🔄 Soft Reset', 'sys');
  }

  void emergencyStop() {
    conn.sendRaw(0x18);
    state.running = false;
    state.status = MachineStatus.alarm;
    stopRun();
    conn.logManual('🛑 EMERGENCY STOP', 'err');
    notifyListeners();
  }

  void hold() => conn.sendRaw(0x21); // '!'
  void resume() => conn.sendRaw(0x7E); // '~'
  void unlock() => conn.sendCommand('\$X');
  void checkMode() => conn.sendCommand('\$C');
  void probeZ() => conn.sendCommand('G38.2 Z-30 F50');

  void setZero(String axis) {
    final cmds = {
      'X': 'G92 X0', 'Y': 'G92 Y0',
      'Z': 'G92 Z0', 'ALL': 'G92 X0 Y0 Z0'
    };
    conn.sendCommand(cmds[axis]!);
    if (axis == 'X' || axis == 'ALL') state.wposX = state.posX;
    if (axis == 'Y' || axis == 'ALL') state.wposY = state.posY;
    if (axis == 'Z' || axis == 'ALL') state.wposZ = state.posZ;
    notifyListeners();
  }

  void goToZero() {
    conn.sendCommand('G90 G0 X0 Y0');
    if (!state.isConnected) {
      state.posX = 0; state.posY = 0;
      notifyListeners();
    }
  }

  void spindleOn() => conn.sendCommand('M3 S${state.spindleRPM.toInt()}');
  void spindleOff() => conn.sendCommand('M5');
  void spindleCCW() => conn.sendCommand('M4 S${state.spindleRPM.toInt()}');
  void coolantOn() => conn.sendCommand('M8');
  void coolantOff() => conn.sendCommand('M9');

  void setUnit(String unit) {
    state.unit = unit;
    conn.sendCommand(unit == 'mm' ? 'G21' : 'G20');
    notifyListeners();
  }

  // ---------------------------------------------------------------
  // G-CODE RUN
  // ---------------------------------------------------------------
  void startRun(String gcode) {
    _gcodeLines = gcode
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (_gcodeLines.isEmpty) return;

    state.gcodeTotal = _gcodeLines.length;
    state.gcodeIndex = 0;
    state.running = true;
    state.paused = false;
    state.status = MachineStatus.run;
    notifyListeners();

    _runTimer?.cancel();
    _runTimer = Timer.periodic(const Duration(milliseconds: 120), (_) => _runNextLine());
  }

  void _runNextLine() {
    if (!state.running || state.paused) return;
    if (state.gcodeIndex >= _gcodeLines.length) {
      _runTimer?.cancel();
      state.running = false;
      state.status = MachineStatus.idle;
      conn.logManual('✅ Program selesai!', 'sys');
      notifyListeners();
      return;
    }
    final line = _gcodeLines[state.gcodeIndex];
    final clean = line.split(';').first.trim().toUpperCase();
    state.currentLine = line;

    // Parse position for simulator
    final xm = RegExp(r'X(-?[\d.]+)').firstMatch(clean);
    final ym = RegExp(r'Y(-?[\d.]+)').firstMatch(clean);
    if (xm != null) state.posX = double.parse(xm.group(1)!);
    if (ym != null) state.posY = double.parse(ym.group(1)!);

    if (state.isConnected) {
      conn.sendCommand(clean);
    } else {
      conn.logManual(clean, 'send');
    }
    state.gcodeIndex++;
    notifyListeners();
  }

  void pauseRun() {
    state.paused = !state.paused;
    if (state.paused) {
      hold();
      state.status = MachineStatus.hold;
    } else {
      resume();
      state.status = MachineStatus.run;
    }
    notifyListeners();
  }

  void stopRun() {
    _runTimer?.cancel();
    state.running = false;
    state.paused = false;
    if (state.isConnected) conn.sendRaw(0x18);
    state.status = MachineStatus.idle;
    notifyListeners();
  }

  void dryRun(String gcode) {
    final prevSim = state.simMode;
    state.simMode = true;
    startRun(gcode);
    state.simMode = prevSim;
  }

  @override
  void dispose() {
    _runTimer?.cancel();
    super.dispose();
  }
}

// Extension tambahan untuk state
extension GrblStateExt on GrblState {
  double get step => _stepValue;
  set step(double v) => _stepValue = v;
  double get jogFeed => _jogFeedValue;
  set jogFeed(double v) => _jogFeedValue = v;
}

double _stepValue = 1.0;
double _jogFeedValue = 1000.0;
