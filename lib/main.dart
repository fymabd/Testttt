import 'dartd:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const SelfbotAppWrapper());
}

class SelfbotAppWrapper extends StatelessWidget {
  const SelfbotAppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SelfbotControlApp(),
    );
  }
}

class SelfbotControlApp extends StatefulWidget {
  const SelfbotControlApp({super.key});

  @override
  State<SelfbotControlApp> createState() => _SelfbotControlAppState();
}

class _SelfbotControlAppState extends State<SelfbotControlApp> {
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _channelIdController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _spamCountController = TextEditingController(text: '5');
  final TextEditingController _clearCountController = TextEditingController(text: '10');

  final TextEditingController _rpcNameController = TextEditingController(text: 'Flutter Engine');
  final TextEditingController _rpcDetailsController = TextEditingController(text: 'تحكم كامل من التطبيق');
  final TextEditingController _rpcStateController = TextEditingController(text: 'Online');
  final TextEditingController _buttonLabelController = TextEditingController(text: 'My Website');
  final TextEditingController _buttonUrlController = TextEditingController(text: 'https://google.com');

  WebSocketChannel? _wsChannel;
  Timer? _heartbeatTimer;
  bool _isConnected = false;
  String _statusMessage = 'غير متصل';
  String _myUserId = '';

  // ----------------------------------------------------
  // 1. الاتصال بـ Discord Gateway v10 المعدل
  // ----------------------------------------------------
  void _connectToDiscord() {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      _showSnackBar('الرجاء إدخال التوكين أولاً!');
      return;
    }

    _wsChannel?.sink.close();
    _heartbeatTimer?.cancel();

    setState(() {
      _statusMessage = 'جاري محاولة الاتصال بـ Gateway v10...';
    });

    try {
      // التحديث لـ Gateway v10
      _wsChannel = IOWebSocketChannel.connect(
        Uri.parse('wss://gateway.discord.gg/?v=10&encoding=json'),
      );

      _wsChannel!.stream.listen(
        (data) {
          final payload = jsonDecode(data);
          final op = payload['op'];
          final t = payload['t'];
          final d = payload['d'];

          // OP 10: Hello -> إرسال Heartbeat وتصريح الدخول
          if (op == 10) {
            int heartbeatInterval = d['heartbeat_interval'];
            _startHeartbeat(heartbeatInterval);
            _sendIdentify(token);
          }

          // تم الاتصال وحفظ بيانات المستخدم
          if (t == 'READY') {
            setState(() {
              _isConnected = true;
              _myUserId = d['user']['id'];
              _statusMessage = 'تم الاتصال: ${d['user']['username']}';
            });
            _showSnackBar('تم الاتصال بنجاح!');
          }
        },
        onError: (err) {
          setState(() {
            _isConnected = false;
            _statusMessage = 'خطأ في شبكة الاتصال: $err';
          });
        },
        onDone: () {
          setState(() {
            _isConnected = false;
            _statusMessage = 'تم إغلاق الاتصال من ديسكورد (تأكد من صحة التوكين والشبكة)';
          });
        },
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'فشل الاتصال: $e';
      });
    }
  }

  void _startHeartbeat(int interval) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(milliseconds: interval), (timer) {
      _wsChannel?.sink.add(jsonEncode({'op': 1, 'd': null}));
    });
  }

  // محاكاة خصائص متصفح إلكترون الاصلي لمنع الرفض الحسابي
  void _sendIdentify(String token) {
    final payload = {
      'op': 2,
      'd': {
        'token': token,
        'capabilities': 8189,
        'properties': {
          'os': 'Windows',
          'browser': 'Chrome',
          'device': '',
          'system_locale': 'en-US',
          'browser_user_agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'browser_version': '120.0.0.0',
          'os_version': '10',
          'referrer': '',
          'referring_domain': '',
          'search_engine': 'google',
          'client_build_number': 260000,
        },
        'presence': {
          'status': 'online',
          'since': 0,
          'activities': [],
          'afk': false
        },
        'compress': false,
        'client_state': {
          'guild_versions': {},
          'highest_last_message_id': '0',
          'read_state_version': 0,
          'user_guild_settings_version': -1,
          'user_settings_version': -1,
        }
      }
    };
    _wsChannel?.sink.add(jsonEncode(payload));
  }

  // ----------------------------------------------------
  // 2. أوامر التحكم بالرسائل و RPC
  // ----------------------------------------------------
  Future<void> _sendMessage() async {
    final channelId = _channelIdController.text.trim();
    final msg = _messageController.text.trim();
    if (channelId.isEmpty || msg.isEmpty) return;

    final res = await http.post(
      Uri.parse('https://discord.com/api/v10/channels/$channelId/messages'),
      headers: {
        'authorization': _tokenController.text.trim(),
        'content-type': 'application/json',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
      },
      body: jsonEncode({'content': msg}),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      _messageController.clear();
      _showSnackBar('تم إرسال الرسالة!');
    } else {
      _showSnackBar('فشل الإرسال: كود ${res.statusCode}');
    }
  }

  Future<void> _sendSpam() async {
    final channelId = _channelIdController.text.trim();
    final msg = _messageController.text.trim();
    int count = int.tryParse(_spamCountController.text) ?? 5;

    if (channelId.isEmpty || msg.isEmpty) return;

    for (int i = 0; i < count; i++) {
      await http.post(
        Uri.parse('https://discord.com/api/v10/channels/$channelId/messages'),
        headers: {
          'authorization': _tokenController.text.trim(),
          'content-type': 'application/json',
          'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
        },
        body: jsonEncode({'content': msg}),
      );
      await Future.delayed(const Duration(milliseconds: 400));
    }
    _showSnackBar('تم الانتهاء من الـ Spam!');
  }

  Future<void> _clearMessages() async {
    final channelId = _channelIdController.text.trim();
    int target = int.tryParse(_clearCountController.text) ?? 10;
    if (channelId.isEmpty) return;

    _showSnackBar('جاري مسح الرسائل...');
    int deleted = 0;

    final res = await http.get(
      Uri.parse('https://discord.com/api/v10/channels/$channelId/messages?limit=100'),
      headers: {
        'authorization': _tokenController.text.trim(),
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
      },
    );

    if (res.statusCode == 200) {
      List messages = jsonDecode(res.body);
      for (var m in messages) {
        if (m['author']['id'] == _myUserId) {
          String msgId = m['id'];
          await http.delete(
            Uri.parse('https://discord.com/api/v10/channels/$channelId/messages/$msgId'),
            headers: {
              'authorization': _tokenController.text.trim(),
              'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
            },
          );
          deleted++;
          await Future.delayed(const Duration(milliseconds: 400));
          if (deleted >= target) break;
        }
      }
      _showSnackBar('تم مسح $deleted رسالة!');
    }
  }

  void _updateRpc() {
    if (!_isConnected) return;

    final activity = {
      'name': _rpcNameController.text,
      'type': 0,
      'details': _rpcDetailsController.text,
      'state': _rpcStateController.text,
      'timestamps': {'start': DateTime.now().millisecondsSinceEpoch},
    };

    if (_buttonLabelController.text.isNotEmpty && _buttonUrlController.text.isNotEmpty) {
      activity['buttons'] = [_buttonLabelController.text];
      activity['metadata'] = {
        'button_urls': [_buttonUrlController.text]
      };
    }

    final payload = {
      'op': 3,
      'd': {
        'since': null,
        'activities': [activity],
        'status': 'online',
        'afk': false,
      }
    };

    _wsChannel?.sink.add(jsonEncode(payload));
    _showSnackBar('تم تحديث البروفايل (RPC)!');
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ----------------------------------------------------
  // 3. بناء الواجهات
  // ----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم السيلف بوت'),
        backgroundColor: Colors.indigo.shade900,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                _isConnected ? '🟢 متصل' : '🔴 غير متصل',
                style: TextStyle(
                  color: _isConnected ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCard('1. إعداد الحساب', [
              TextField(
                controller: _tokenController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'التوكين (Discord Token)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _connectToDiscord,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                child: Text(_isConnected ? 'إعادة الاتصال' : 'تشغيل الربط'),
              ),
              const SizedBox(height: 5),
              Text('الحالة: $_statusMessage', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
            const SizedBox(height: 15),
            if (_isConnected) ...[
              _buildCard('2. التحكم بالرسائل والقنوات', [
                TextField(
                  controller: _channelIdController,
                  decoration: const InputDecoration(
                    labelText: 'آيدي الروم (Channel ID)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'محتوى الرسالة',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _sendMessage,
                        child: const Text('إرسال رسالة'),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _spamCountController,
                        decoration: const InputDecoration(labelText: 'عدد التكرار (Spam)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _sendSpam,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
                      child: const Text('بدء الـ Spam'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _clearCountController,
                        decoration: const InputDecoration(labelText: 'عدد الرسائل المراد مسحها'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _clearMessages,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
                      child: const Text('مسح رسائلي (Clear)'),
                    ),
                  ],
                ),
              ]),
              const SizedBox(height: 15),
              _buildCard('3. إعدادات Rich Presence (الحالة والبروفايل)', [
                TextField(controller: _rpcNameController, decoration: const InputDecoration(labelText: 'اسم النشاط (Name)')),
                const SizedBox(height: 5),
                TextField(controller: _rpcDetailsController, decoration: const InputDecoration(labelText: 'التفاصيل (Details)')),
                const SizedBox(height: 5),
                TextField(controller: _rpcStateController, decoration: const InputDecoration(labelText: 'الحالة (State)')),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _buttonLabelController, decoration: const InputDecoration(labelText: 'اسم الزر'))),
                    const SizedBox(width: 5),
                    Expanded(child: TextField(controller: _buttonUrlController, decoration: const InputDecoration(labelText: 'رابط الزر'))),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _updateRpc,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800),
                  child: const Text('تطبيق الـ Rich Presence'),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, List<Widget> children) {
    return Card(
      elevation: 4,
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigoAccent),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}
