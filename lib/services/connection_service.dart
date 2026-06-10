// lib/services/connection_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';
import '../models/grbl_state.dart';

class ConnectionService extends ChangeNotifier {
  // USB
  UsbPort? _usbPort;
  StreamSubscription? _usbDataSub;
  StreamSubscription? _usbDevicesSub;

  // WiFi TCP
  Socket? _socket;
  StreamSubscription? _wifiDataSub;

  // State
  final GrblState state = GrblState();
  final List<String> terminalLog = [];
  String _lineBuffer = '';

  // Callbacks
  Function(String line)? onResponse;
  Function(String msg, bool isError)? onNotify;
  Function()? onConnectionChanged;

  // ---------------------------------------------------------------
  // USB AUTO-DETECT
  // ---------------------------------------------------------------
  void startUsbListener() {
    _usbDevicesSub = UsbSerial.usbEventStream?.listen((UsbEvent event) {
      if (event.event == UsbEvent.ACTION_USB_ATTACHED) {
        _log('🔌 USB device terhubung', 'sys');
        onNotify?.call('🔌 USB device terdeteksi!', false);
        autoConnectUsb();
      } else if (event.event == UsbEvent.ACTION_USB_DETACHED) {
        _log('⚠️ USB device dicabut', 'sys');
        onNotify?.call('⚠️ USB dicabut', true);
        disconnect();
      }
    });
  }

  Future<List<UsbDevice>> getUsbDevices() async {
    return await UsbSerial.listDevices();
  }

  Future<bool> autoConnectUsb() async {
    final devices = await getUsbDevices();
    if (devices.isEmpty) {
      _log('Tidak ada USB device ditemukan', 'err');
      return false;
    }
    return connectUsb(devices.first, state.baudRate);
  }

  Future<bool> connectUsb(UsbDevice device, int baud) async {
    try {
      _usbPort = await device.create();
      if (_usbPort == null) {
        _log('Gagal buat port', 'err');
        return false;
      }

      bool opened = await _usbPort!.open();
      if (!opened) {
        _log('Gagal buka port', 'err');
        return false;
      }

      await _usbPort!.setDTR(true);
      await _usbPort!.setRTS(true);
      await _usbPort!.setPortParameters(
        baud,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      _usbDataSub = _usbPort!.inputStream?.listen(_onDataReceived);

      state.connectionType = ConnectionType.usb;
      state.simMode = false;
      _log('✅ USB terhubung: ${device.manufacturerName ?? "Unknown"} @ ${baud}bps', 'sys');
      onNotify?.call('✅ USB terhubung!', false);
      onConnectionChanged?.call();
      notifyListeners();

      // Send initial queries
      await Future.delayed(const Duration(milliseconds: 500));
      sendCommand('\r\n'); // wake GRBL
      sendCommand('\$I');

      // Start status polling
      _startPolling();
      return true;
    } catch (e) {
      _log('❌ USB Error: $e', 'err');
      onNotify?.call('❌ USB Gagal: $e', true);
      return false;
    }
  }

  // ---------------------------------------------------------------
  // WIFI TCP CONNECT
  // ---------------------------------------------------------------
  Future<bool> connectWifi(String host, int port) async {
    try {
      _log('🌐 Menghubungkan ke $host:$port...', 'sys');
      _socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 5));

      _wifiDataSub = _socket!.listen(
        _onDataReceived,
        onError: (e) {
          _log('❌ WiFi Error: $e', 'err');
          onNotify?.call('❌ WiFi Error', true);
          disconnect();
        },
        onDone: () {
          _log('WiFi terputus', 'sys');
          disconnect();
        },
      );

      state.connectionType = ConnectionType.wifi;
      state.simMode = false;
      state.wifiHost = host;
      state.wifiPort = port;
      _log('✅ WiFi terhubung: $host:$port', 'sys');
      onNotify?.call('✅ WiFi terhubung!', false);
      onConnectionChanged?.call();
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 500));
      sendCommand('\r\n');
      sendCommand('\$I');
      _startPolling();
      return true;
    } catch (e) {
      _log('❌ WiFi Gagal: $e', 'err');
      onNotify?.call('❌ WiFi Gagal: $e', true);
      return false;
    }
  }

  // ---------------------------------------------------------------
  // SEND COMMAND
  // ---------------------------------------------------------------
  void sendCommand(String cmd) {
    final data = utf8.encode('$cmd\n');
    if (state.connectionType == ConnectionType.usb && _usbPort != null) {
      _usbPort!.write(Uint8List.fromList(data));
    } else if (state.connectionType == ConnectionType.wifi && _socket != null) {
      _socket!.add(data);
    }
    if (cmd.trim().isNotEmpty && cmd != '?') {
      _log(cmd.trim(), 'send');
    }
  }

  void sendRaw(int byte) {
    final data = Uint8List.fromList([byte]);
    if (state.connectionType == ConnectionType.usb && _usbPort != null) {
      _usbPort!.write(data);
    } else if (state.connectionType == ConnectionType.wifi && _socket != null) {
      _socket!.add(data);
    }
  }

  // ---------------------------------------------------------------
  // DATA RECEIVED
  // ---------------------------------------------------------------
  void _onDataReceived(dynamic data) {
    String received;
    if (data is Uint8List) {
      received = utf8.decode(data, allowMalformed: true);
    } else {
      received = data.toString();
    }

    _lineBuffer += received;
    final lines = _lineBuffer.split('\n');
    _lineBuffer = lines.removeLast();

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      _parseGrblResponse(trimmed);
    }
  }

  void _parseGrblResponse(String line) {
    _log(line, 'recv');
    onResponse?.call(line);

    // Status report: <Idle|WPos:0.000,0.000,0.000|...>
    if (line.startsWith('<')) {
      final statusMatch = RegExp(r'<([^|>]+)').firstMatch(line);
      if (statusMatch != null) {
        final s = statusMatch.group(1)!;
        switch (s.toLowerCase()) {
          case 'idle': state.status = MachineStatus.idle; break;
          case 'run': state.status = MachineStatus.run; break;
          case 'hold':
          case 'hold:0':
          case 'hold:1': state.status = MachineStatus.hold; break;
          case 'alarm': state.status = MachineStatus.alarm; break;
          case 'door':
          case 'door:0':
          case 'door:1':
          case 'door:2':
          case 'door:3': state.status = MachineStatus.door; break;
          case 'check': state.status = MachineStatus.check; break;
          case 'sleep': state.status = MachineStatus.sleep; break;
          default: state.status = MachineStatus.unknown;
        }
      }

      // WPos
      final wposMatch = RegExp(
          r'WPos:(-?[\d.]+),(-?[\d.]+),(-?[\d.]+)')
          .firstMatch(line);
      if (wposMatch != null) {
        state.posX = double.parse(wposMatch.group(1)!);
        state.posY = double.parse(wposMatch.group(2)!);
        state.posZ = double.parse(wposMatch.group(3)!);
      }

      // MPos fallback
      final mposMatch = RegExp(
          r'MPos:(-?[\d.]+),(-?[\d.]+),(-?[\d.]+)')
          .firstMatch(line);
      if (mposMatch != null && wposMatch == null) {
        state.posX = double.parse(mposMatch.group(1)!);
        state.posY = double.parse(mposMatch.group(2)!);
        state.posZ = double.parse(mposMatch.group(3)!);
      }

      // Feed and speed: FS:1000,12000
      final fsMatch = RegExp(r'FS:(\d+),(\d+)').firstMatch(line);
      if (fsMatch != null) {
        state.feedRate = double.parse(fsMatch.group(1)!);
        state.spindleRPM = double.parse(fsMatch.group(2)!);
      }

      notifyListeners();
    }
  }

  // ---------------------------------------------------------------
  // STATUS POLLING
  // ---------------------------------------------------------------
  Timer? _pollTimer;
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.connectionType != ConnectionType.none && !state.simMode) {
        sendRaw(0x3F); // '?' status query (single byte, no newline)
      }
    });
  }

  // ---------------------------------------------------------------
  // DISCONNECT
  // ---------------------------------------------------------------
  Future<void> disconnect() async {
    _pollTimer?.cancel();
    _usbDataSub?.cancel();
    _wifiDataSub?.cancel();
    await _usbPort?.close();
    _socket?.destroy();
    _usbPort = null;
    _socket = null;
    state.connectionType = ConnectionType.none;
    state.simMode = true;
    onConnectionChanged?.call();
    notifyListeners();
    _log('Koneksi terputus', 'sys');
  }

  // ---------------------------------------------------------------
  // TERMINAL LOG
  // ---------------------------------------------------------------
  void _log(String msg, String type) {
    final prefix = {'send': '→ ', 'recv': '← ', 'sys': '  ', 'err': '! ', 'ok': '✓ '}[type] ?? '';
    terminalLog.add('[$type] $prefix$msg');
    if (terminalLog.length > 300) terminalLog.removeAt(0);
    notifyListeners();
  }

  void logManual(String msg, String type) => _log(msg, type);

  @override
  void dispose() {
    _usbDevicesSub?.cancel();
    _pollTimer?.cancel();
    disconnect();
    super.dispose();
  }
}
