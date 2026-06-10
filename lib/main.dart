// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/connection_service.dart';
import 'services/grbl_service.dart';
import 'screens/kontrol_screen.dart';
import 'screens/spindle_screen.dart';
import 'screens/terminal_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/connection_dialog.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: kDark,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const KlCncApp());
}

class KlCncApp extends StatelessWidget {
  const KlCncApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KL CNC Controller',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late ConnectionService _conn;
  late GrblService _grbl;
  OverlayEntry? _notifOverlay;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _conn = ConnectionService();
    _grbl = GrblService(_conn);

    _conn.onNotify = (msg, isErr) => _showNotif(msg, isErr);
    _conn.onConnectionChanged = () => setState(() {});
    _conn.startUsbListener();

    // Load saved prefs
    SettingsScreen.loadPrefs(_conn).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _showNotif(String msg, bool isErr) {
    _notifOverlay?.remove();
    _notifOverlay = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 60,
        left: 20, right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                color: isErr ? kRed.withOpacity(0.9) : const Color(0xFF0A1A0A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isErr ? kRed : kNeon),
                boxShadow: [BoxShadow(
                    color: (isErr ? kRed : kNeon).withOpacity(0.3),
                    blurRadius: 12)]),
            child: Text(msg,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: isErr ? Colors.white : kNeon,
                    fontSize: 12, fontFamily: kFontMono)),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_notifOverlay!);
    Future.delayed(const Duration(seconds: 3), () {
      _notifOverlay?.remove();
      _notifOverlay = null;
    });
  }

  void _showConnDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => ConnectionDialog(conn: _conn),
    ).then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    _conn.dispose();
    _grbl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _conn.state;
    final isConnected = s.isConnected;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(children: [

          // ── HEADER ──
          Container(
            decoration: const BoxDecoration(
              color: kDark,
              border: Border(bottom: BorderSide(color: kNeon, width: 2)),
              boxShadow: [BoxShadow(color: Color(0x50AAFF00), blurRadius: 10)],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              // Logo
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: kNeon.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kNeon.withOpacity(0.5))),
                alignment: Alignment.center,
                child: const Text('KL', style: TextStyle(
                    color: kNeon, fontSize: 13,
                    fontFamily: kFontMono, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),

              // Title + status
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.cncTypeLabel,
                      style: neonText(size: 13, weight: FontWeight.bold)),
                  Row(children: [
                    Container(
                      width: 7, height: 7,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConnected ? kNeon : s.simMode ? kWarn : kRed,
                          boxShadow: [BoxShadow(
                              color: (isConnected ? kNeon : s.simMode ? kWarn : kRed)
                                  .withOpacity(0.6),
                              blurRadius: 6)]),
                    ),
                    Text(
                        isConnected
                            ? (s.connectionType == ConnectionType.usb
                            ? 'USB OTG · ${s.baudRate}'
                            : 'WiFi · ${s.wifiHost}')
                            : s.simMode ? 'SIMULATOR' : 'OFFLINE',
                        style: dimText(size: 10)),
                  ]),
                ]),
              ),

              // Connect button
              GestureDetector(
                onTap: isConnected ? () {
                  _conn.disconnect();
                  setState(() {});
                } : _showConnDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: (isConnected ? kRed : kNeon).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isConnected ? kRed : kNeon)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        isConnected ? Icons.link_off : Icons.link,
                        size: 14,
                        color: isConnected ? kRed : kNeon),
                    const SizedBox(width: 5),
                    Text(
                        isConnected ? 'PUTUS' : 'KONEK',
                        style: TextStyle(
                            color: isConnected ? kRed : kNeon,
                            fontSize: 10, fontFamily: kFontMono,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ]),
          ),

          // ── TABS ──
          Container(
            color: kDark,
            child: TabBar(
              controller: _tab,
              labelStyle: const TextStyle(
                  fontSize: 9, fontFamily: kFontMono, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(
                  fontSize: 9, fontFamily: kFontMono),
              indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(color: kNeon, width: 2)),
              tabs: const [
                Tab(icon: Icon(Icons.gamepad_outlined, size: 18), text: 'KONTROL'),
                Tab(icon: Icon(Icons.settings_input_component, size: 18), text: 'SPINDLE'),
                Tab(icon: Icon(Icons.terminal, size: 18), text: 'TERMINAL'),
                Tab(icon: Icon(Icons.tune, size: 18), text: 'SETING'),
              ],
            ),
          ),

          // ── CONTENT ──
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                KontrolScreen(conn: _conn, grbl: _grbl),
                SpindleScreen(conn: _conn, grbl: _grbl),
                TerminalScreen(conn: _conn),
                SettingsScreen(conn: _conn),
              ],
            ),
          ),
        ]),
      ),

      // ── E-STOP BUTTON ──
      floatingActionButton: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF110000),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: kRed, width: 2)),
              title: const Text('⛔ EMERGENCY STOP',
                  style: TextStyle(color: kRed, fontFamily: kFontMono,
                      fontWeight: FontWeight.bold, fontSize: 15),
                  textAlign: TextAlign.center),
              content: const Text(
                  'Hentikan semua gerakan mesin sekarang?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontFamily: kFontMono)),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('BATAL',
                      style: TextStyle(color: Colors.white54, fontFamily: kFontMono)),
                ),
                ElevatedButton(
                  onPressed: () {
                    _grbl.emergencyStop();
                    Navigator.pop(context);
                    _showNotif('🛑 EMERGENCY STOP!', true);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                  child: const Text('STOP SEKARANG',
                      style: TextStyle(fontFamily: kFontMono, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
        child: Container(
          width: 68, height: 68,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(colors: [Color(0xFFFF0000), Color(0xFF990000)]),
              border: Border.all(color: const Color(0xFFFF4444), width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0x80FF0000), blurRadius: 16),
                BoxShadow(color: Color(0x40FF0000), blurRadius: 30),
              ]),
          alignment: Alignment.center,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('⛔', style: TextStyle(fontSize: 20)),
              Text('E-STOP', style: TextStyle(
                  color: Colors.white, fontSize: 9,
                  fontFamily: kFontMono, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
