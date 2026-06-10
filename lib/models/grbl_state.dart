// lib/models/grbl_state.dart

enum ConnectionType { none, usb, wifi }
enum MachineStatus { idle, run, hold, alarm, door, check, sleep, unknown }
enum CncType { router, laser, fiber, plasma, mill, printer }

class GrblState {
  MachineStatus status;
  ConnectionType connectionType;
  CncType cncType;

  double posX, posY, posZ;
  double wposX, wposY, wposZ;
  double feedRate;
  double spindleRPM;
  bool simMode;
  bool running;
  bool paused;
  String unit; // 'mm' or 'inch'
  double bedX, bedY;
  int gcodeTotal;
  int gcodeIndex;
  String currentLine;

  // WiFi settings
  String wifiHost;
  int wifiPort;

  // USB baud
  int baudRate;

  GrblState({
    this.status = MachineStatus.idle,
    this.connectionType = ConnectionType.none,
    this.cncType = CncType.router,
    this.posX = 0,
    this.posY = 0,
    this.posZ = 0,
    this.wposX = 0,
    this.wposY = 0,
    this.wposZ = 0,
    this.feedRate = 1000,
    this.spindleRPM = 0,
    this.simMode = true,
    this.running = false,
    this.paused = false,
    this.unit = 'mm',
    this.bedX = 300,
    this.bedY = 200,
    this.gcodeTotal = 0,
    this.gcodeIndex = 0,
    this.currentLine = '',
    this.wifiHost = '192.168.1.100',
    this.wifiPort = 23,
    this.baudRate = 115200,
  });

  bool get isConnected => connectionType != ConnectionType.none && !simMode;

  String get statusText {
    switch (status) {
      case MachineStatus.idle: return 'IDLE';
      case MachineStatus.run: return 'RUN';
      case MachineStatus.hold: return 'HOLD';
      case MachineStatus.alarm: return 'ALARM';
      case MachineStatus.door: return 'DOOR';
      case MachineStatus.check: return 'CHECK';
      case MachineStatus.sleep: return 'SLEEP';
      default: return 'UNKNOWN';
    }
  }

  String get cncTypeLabel {
    switch (cncType) {
      case CncType.router: return 'CNC ROUTER';
      case CncType.laser: return 'CNC LASER';
      case CncType.fiber: return 'CNC FIBER';
      case CncType.plasma: return 'CNC PLASMA';
      case CncType.mill: return 'CNC MILL';
      case CncType.printer: return '3D PRINTER';
    }
  }

  double get progressPct => gcodeTotal > 0 ? gcodeIndex / gcodeTotal : 0;
}
