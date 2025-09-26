
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

void main() {
  runApp(const DarbSaeedApp());
}

class DarbSaeedApp extends StatelessWidget {
  const DarbSaeedApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'درب خانه سعید',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      home: const ControlPage(),
    );
  }
}

class ControlPage extends StatefulWidget {
  const ControlPage({Key? key}) : super(key: key);
  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> with SingleTickerProviderStateMixin {
  String serverIp = '192.168.4.1';
  String path = 'door';
  bool busy = false;
  String message = '';
  late AnimationController _animController;
  late Animation<double> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _offsetAnimation = Tween(begin: 0.0, end: 8.0).chain(CurveTween(curve: Curves.elasticIn)).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      serverIp = prefs.getString('serverIP') ?? serverIp;
    });
  }

  Future<void> _saveIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('serverIP', ip);
    setState(() { serverIp = ip; });
  }

  String _baseUrl() {
    return 'http://$serverIp/$path';
  }

  Future<void> _sendOpen() async {
    setState(() { busy = true; message = ''; });
    // start shake
    _animController.forward().then((_) => _animController.reverse());
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 50);
    }
    try {
      final url = Uri.parse(_baseUrl());
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        _showTempMessage('درب باز شد ✅');
      } else {
        _showTempMessage('ارتباط برقرار نشد ❌');
      }
    } catch (e) {
      _showTempMessage('ارتباط برقرار نشد ❌');
    } finally {
      setState(() { busy = false; });
    }
  }

  void _showTempMessage(String text) {
    setState(() { message = text; });
    Future.delayed(const Duration(seconds:3), () {
      setState(() { message = ''; });
    });
  }

  Future<void> _testConnection() async {
    final testUrl = Uri.parse('http://$serverIp/test');
    setState(() { busy = true; message = ''; });
    try {
      final res = await http.get(testUrl).timeout(const Duration(seconds:5));
      if (res.statusCode == 200) _showTempMessage('اتصال برقرار است ✅');
      else _showTempMessage('ارتباط برقرار نشد ❌');
    } catch (e) {
      _showTempMessage('ارتباط برقرار نشد ❌');
    } finally {
      setState(() { busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/door_icon.png', width: 100, height: 100),
                      const SizedBox(height: 16),
                      AnimatedBuilder(
                        animation: _offsetAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(_offsetAnimation.value, 0),
                            child: child,
                          );
                        },
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              textStyle: const TextStyle(fontSize: 22),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: busy ? null : _sendOpen,
                            child: const Text('باز کردن درب', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.settings),
                        label: const Text('تنظیمات'),
                        onPressed: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage(onSave: _saveIp, currentIp: serverIp)));
                          await _loadSettings();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (message.isNotEmpty)
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.only(top: 30),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                    child: Text(message, style: const TextStyle(color: Colors.white)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final Function(String) onSave;
  final String currentIp;
  const SettingsPage({Key? key, required this.onSave, required this.currentIp}) : super(key: key);
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _ipController;
  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: widget.currentIp);
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: Padding(padding: const EdgeInsets.all(12.0), child: Column(children: [
        TextField(controller: _ipController, decoration: const InputDecoration(labelText: 'IP یا دامنه ماژول')),
        const SizedBox(height: 8),
        Row(children: [
          ElevatedButton(onPressed: () { widget.onSave(_ipController.text.trim()); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ذخیره شد'))); }, child: const Text('ذخیره')),
          const SizedBox(width: 12),
          ElevatedButton(onPressed: () { FocusScope.of(context).unfocus(); _testNow(); }, child: const Text('تست اتصال')),
        ])
      ])),
    ));
  }

  void _testNow() {
    final parent = context.findAncestorStateOfType<_ControlPageState>();
    parent?._saveIp(_ipController.text.trim());
    parent?._testConnection();
  }
}
