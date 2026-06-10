// lib/widgets/connection_dialog.dart
import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import '../services/connection_service.dart';
import '../theme.dart';

class ConnectionDialog extends StatefulWidget {
  final ConnectionService conn;
  const ConnectionDialog({super.key, required this.conn});

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<UsbDevice> _usbDevices = [];
  bool _scanning = false;
  String _wifiHost = '';
  String _wifiPort = '23';
  String _status = '';
  bool _connecting = false;

  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '23');

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _hostCtrl.text = widget.conn.state.wifiHost;
    _portCtrl.text = widget.conn.state.wifiPort.toString();
    _scanUsb();
  }

  Future<void> _scanUsb() async {
    setState(() => _scanning = true);
    final devices = await UsbSerial.listDevices();
    setState(() {
      _usbDevices = devices;
      _scanning = false;
      _status = devices.isEmpty
          ? 'Tidak ada USB device. Pastikan kabel OTG terpasang.'
          : '${devices.length} device ditemukan';
    });
  }

  Future<void> _connectUsb(UsbDevice device) async {
    setState(() { _connecting = true; _status = 'Menghubungkan...'; });
    final ok = await widget.conn.connectUsb(device, widget.conn.state.baudRate);
    setState(() {
      _connecting = false;
      _status = ok ? '✅ Terhubung!' : '❌ Gagal konek';
    });
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _connectWifi() async {
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text) ?? 23;
    if (host.isEmpty) {
      setState(() => _status = '❌ Masukkan IP address');
      return;
    }
    setState(() { _connecting = true; _status = 'Menghubungkan ke $host:$port...'; });
    final ok = await widget.conn.connectWifi(host, port);
    setState(() {
      _connecting = false;
      _status = ok ? '✅ Terhubung!' : '❌ Gagal. Cek IP/port.';
    });
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _tab.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF111111),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: kNeon)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(children: [
              const Icon(Icons.cable, color: kNeon, size: 20),
              const SizedBox(width: 8),
              Text('KONEKSI SERIAL',
                  style: neonText(size: 14, weight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close, color: kDim, size: 18),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints()),
            ]),
            const SizedBox(height: 12),

            // Tabs
            Container(
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder),
              ),
              child: TabBar(
                controller: _tab,
                tabs: const [
                  Tab(text: '🔌  USB OTG'),
                  Tab(text: '📶  WiFi TCP'),
                ],
                labelStyle: const TextStyle(
                    fontSize: 11, fontFamily: kFontMono, fontWeight: FontWeight.bold),
                indicator: BoxDecoration(
                  color: kNeon.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: kNeon.withOpacity(0.5)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 220,
              child: TabBarView(
                controller: _tab,
                children: [
                  // ── USB TAB ──
                  _buildUsbTab(),
                  // ── WiFi TAB ──
                  _buildWifiTab(),
                ],
              ),
            ),

            // Status bar
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: kBorder)),
                child: Text(_status,
                    style: const TextStyle(
                        color: kDim, fontSize: 11, fontFamily: kFontMono)),
              ),
            ],

            const SizedBox(height: 12),

            // Simulator button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  widget.conn.state.simMode = true;
                  widget.conn.state.connectionType = ConnectionType.none;
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.science_outlined, size: 16, color: kDim),
                label: const Text('GUNAKAN SIMULATOR',
                    style: TextStyle(fontSize: 10, fontFamily: kFontMono, color: kDim)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kDim),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsbTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Device Terdeteksi:', style: dimText()),
          const Spacer(),
          IconButton(
            icon: _scanning
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(color: kNeon, strokeWidth: 2))
                : const Icon(Icons.refresh, color: kNeon, size: 18),
            onPressed: _scanning ? null : _scanUsb,
            tooltip: 'Scan ulang',
          ),
        ]),
        const SizedBox(height: 6),
        Expanded(
          child: _usbDevices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.usb_off, color: kDim, size: 36),
                      const SizedBox(height: 8),
                      Text('Tidak ada device\nHubungkan via USB OTG',
                          textAlign: TextAlign.center, style: dimText()),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _usbDevices.length,
                  itemBuilder: (_, i) {
                    final d = _usbDevices[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kBorder)),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.usb, color: kNeon, size: 20),
                        title: Text(
                            d.manufacturerName ?? 'USB Device',
                            style: neonText(size: 12)),
                        subtitle: Text(
                            'VID:${d.vid?.toRadixString(16).toUpperCase()} '
                            'PID:${d.pid?.toRadixString(16).toUpperCase()}',
                            style: dimText(size: 10)),
                        trailing: _connecting
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: kNeon, strokeWidth: 2))
                            : ElevatedButton(
                                onPressed: () => _connectUsb(d),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: kNeon.withOpacity(0.15),
                                    foregroundColor: kNeon,
                                    side: const BorderSide(color: kNeon),
                                    minimumSize: const Size(70, 32),
                                    padding: const EdgeInsets.symmetric(horizontal: 10)),
                                child: const Text('KONEK',
                                    style: TextStyle(fontSize: 10, fontFamily: kFontMono))),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWifiTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: kNeon.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kNeon.withOpacity(0.15))),
          child: Text(
              '💡 WiFi Serial Bridge:\n'
              'ESP32/ESP8266 dengan firmware AT atau\n'
              'program TCP-Serial bridge.\n'
              'Default port: 23 (Telnet) atau 80/8080',
              style: dimText(size: 10)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _hostCtrl,
          style: neonText(size: 14),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'IP Address',
            prefixIcon: Icon(Icons.wifi, color: kNeon, size: 18),
            hintText: '192.168.1.100',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _portCtrl,
          style: neonText(size: 14),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Port',
            prefixIcon: Icon(Icons.numbers, color: kBlue, size: 18),
            hintText: '23',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _connecting ? null : _connectWifi,
            icon: _connecting
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(color: kNeon, strokeWidth: 2))
                : const Icon(Icons.wifi_tethering, size: 16),
            label: Text(_connecting ? 'MENGHUBUNGKAN...' : 'CONNECT WIFI',
                style: const TextStyle(fontSize: 11, fontFamily: kFontMono)),
            style: ElevatedButton.styleFrom(
                backgroundColor: kBlue.withOpacity(0.15),
                foregroundColor: kBlue,
                side: const BorderSide(color: kBlue),
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
      ],
    );
  }
}
