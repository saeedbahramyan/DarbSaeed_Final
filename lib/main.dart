
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

void main() {
  runApp(const DarbKApp());
}

class DarbKApp extends StatelessWidget {
  const DarbKApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'درب خانه سعید',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  String serverIp = '192.168.4.1';
  bool busy = false;
  String message = '';
  late AnimationController _animController;
  late Animation<double> _offsetAnimation;
  String lampTimer = '60';
  List<String> uids = [];

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
      lampTimer = prefs.getString('lampTimer') ?? lampTimer;
    });
  }

  Future<void> _saveIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('serverIP', ip);
    setState(() { serverIp = ip; });
  }

  String _url(String path) => 'http://$serverIp/$path';

  Future<void> _send(String path) async {
    setState(() { busy = true; message = ''; });
    _animController.forward().then((_) => _animController.reverse());
    if (await Vibration.hasVibrator() ?? false) Vibration.vibrate(duration: 40);
    try {
      final res = await http.get(Uri.parse(_url(path))).timeout(const Duration(seconds:5));
      if (res.statusCode == 200) {
        if (path == 'uids') {
          final body = res.body.trim();
          setState(() { uids = body.isEmpty ? [] : body.split(RegExp(r'\r?\n')); });
          _showTempMessage('کارت‌ها به‌روز شدند ✅');
        } else if (path.startsWith('light')) {
          _showTempMessage('چراغ کنترل شد ✅');
        } else {
          _showTempMessage('درب باز شد ✅');
        }
      } else {
        _showTempMessage('ارتباط برقرار نشد ❌');
      }
    } catch (e) {
      _showTempMessage('ارتباط برقرار نشد ❌');
    } finally {
      setState(() { busy = false; });
    }
  }

  Future<void> _sendLight() async {
    await _send('light?time=$lampTimer');
  }

  void _showTempMessage(String txt) {
    setState(() { message = txt; });
    Future.delayed(const Duration(seconds:3), () { setState(() { message = ''; }); });
  }

  Future<void> _testConnection() async {
    setState(() { busy = true; message = ''; });
    try {
      final res = await http.get(Uri.parse(_url('test'))).timeout(const Duration(seconds:5));
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
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(children: [
          Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Image.asset('assets/door_icon.png', width: 100, height: 100),
            const SizedBox(height: 12),
            AnimatedBuilder(animation: _offsetAnimation, builder: (context, child) {
              return Transform.translate(offset: Offset(_offsetAnimation.value, 0), child: child);
            }, child: Column(children: [
              Row(children: [
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical:18), textStyle: const TextStyle(fontSize:18)),
                  onPressed: busy ? null : () => _send('door1'),
                  child: const Text('باز کردن درب ۱', style: TextStyle(color: Colors.white)),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical:18), textStyle: const TextStyle(fontSize:18)),
                  onPressed: busy ? null : () => _send('door2'),
                  child: const Text('باز کردن درب ۲', style: TextStyle(color: Colors.white)),
                )),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(
                  decoration: InputDecoration(labelText: 'تایمر چراغ (ثانیه)', hintText: '60'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) { lampTimer = v; },
                )),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical:16), textStyle: const TextStyle(fontSize:16)),
                  onPressed: busy ? null : _sendLight,
                  child: const Text('لامپ', style: TextStyle(color: Colors.white)),
                )
              ]),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: busy ? null : () => _send('uids'), child: const Text('دریافت کارت‌ها')),
              const SizedBox(height: 12),
              ElevatedButton.icon(icon: const Icon(Icons.settings), label: const Text('تنظیمات'), onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage(onSave: _saveIp, currentIp: serverIp, onSaveTimer: (t) async { final prefs = await SharedPreferences.getInstance(); await prefs.setString('lampTimer', t); })) );
                await _loadSettings();
              }),
            ])),
            const SizedBox(height: 20),
            if (uids.isNotEmpty) Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey[100]),
              child: Column(children: uids.map((u) => Text(u)).toList()),
            ),
          ])),
          ),
          if (message.isNotEmpty) Align(alignment: Alignment.topCenter, child: Container(margin: const EdgeInsets.only(top:30), padding: const EdgeInsets.symmetric(horizontal:16, vertical:10), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)), child: Text(message, style: const TextStyle(color: Colors.white)))),
        ]),
      ),
    ));
  }
}

class SettingsPage extends StatefulWidget {
  final Function(String) onSave;
  final String currentIp;
  final Function(String)? onSaveTimer;
  const SettingsPage({Key? key, required this.onSave, required this.currentIp, this.onSaveTimer}) : super(key: key);
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _ipController;
  late TextEditingController _timerController;
  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: widget.currentIp);
    _timerController = TextEditingController();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _timerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(appBar: AppBar(title: const Text('تنظیمات')), body: Padding(padding: const EdgeInsets.all(12.0), child: Column(children: [
      TextField(controller: _ipController, decoration: const InputDecoration(labelText: 'IP یا دامنه ماژول')),
      const SizedBox(height:8),
      TextField(controller: _timerController, decoration: const InputDecoration(labelText: 'تایمر پیش‌فرض چراغ (ثانیه)'), keyboardType: TextInputType.number),
      const SizedBox(height:12),
      Row(children: [
        ElevatedButton(onPressed: () { widget.onSave(_ipController.text.trim()); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ذخیره شد'))); }, child: const Text('ذخیره')),
        const SizedBox(width:12),
        ElevatedButton(onPressed: () { FocusScope.of(context).unfocus(); _testNow(); }, child: const Text('تست اتصال')),
      ])
    ])));
  }

  void _testNow() {
    final parent = context.findAncestorStateOfType<_HomePageState>();
    if (_timerController.text.trim().isNotEmpty && widget.onSaveTimer != null) widget.onSaveTimer!(_timerController.text.trim());
    parent?._saveIp(_ipController.text.trim());
    parent?._testConnection();
  }
}
