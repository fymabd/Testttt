import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const DiscordDirectApp());
}

class DiscordDirectApp extends StatelessWidget {
  const DiscordDirectApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Discord Direct Controller',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E2E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF89B4FA),
          surface: Color(0xFF181825),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // الاتصال المباشر عبر التوكن
  final _tokenController = TextEditingController();

  // إعدادات الـ RPC والحالة
  String _selectedStatus = 'online';
  final _customStatusController = TextEditingController();
  final _clearChannelController = TextEditingController();
  final _clearCountController = TextEditingController(text: '10');

  // إرسال طلب مباشرة لـ Discord API
  Future<void> _sendDiscordRequest(String endpoint, Map<String, dynamic> bodyData, {String method = 'PATCH'}) async {
    final token = _tokenController.text.trim();

    if (token.isEmpty) {
      _showSnackBar('يرجى إدخال Discord Token أولاً', isError: true);
      return;
    }

    final url = Uri.parse('https://discord.com/api/v9$endpoint');
    final headers = {
      'Authorization': token,
      'Content-Type': 'application/json',
    };

    try {
      http.Response response;
      if (method == 'PATCH') {
        response = await http.patch(url, headers: headers, body: jsonEncode(bodyData));
      } else {
        response = await http.post(url, headers: headers, body: jsonEncode(bodyData));
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSnackBar('تم تحديث الحساب بنجاح 🎉');
      } else {
        final err = jsonDecode(response.body);
        _showSnackBar('خطأ من الديسكورد: ${err['message'] ?? response.statusCode}', isError: true);
      }
    } catch (e) {
      _showSnackBar('فشل الاتصال بالشبكة، تأكد من اتصالك بالإنترنت', isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التحكم المباشر بالديسكورد'),
        centerTitle: true,
        backgroundColor: const Color(0xFF181825),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. تسجيل الدخول بالتوكن
            _buildCard(
              title: '🔑 التوكن الخاص بك',
              child: Column(
                children: [
                  _buildTextField(_tokenController, 'Discord User Token', obscureText: true),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. التحكم بالحالة العامة
            _buildCard(
              title: '🎭 تغيير الحالة (Status)',
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    dropdownColor: const Color(0xFF313244),
                    decoration: const InputDecoration(labelText: 'نوع الحالة', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'online', child: Text('متصل (Online)')),
                      DropdownMenuItem(value: 'idle', child: Text('خامل (Idle)')),
                      DropdownMenuItem(value: 'dnd', child: Text('عدم الإزعاج (DND)')),
                      DropdownMenuItem(value: 'invisible', child: Text('مخفي (Invisible)')),
                    ],
                    onChanged: (val) => setState(() => _selectedStatus = val!),
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(_customStatusController, 'النص المخصص (Custom Status)'),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF89B4FA),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: () {
                      _sendDiscordRequest('/users/@me/settings', {
                        'status': _selectedStatus,
                        'custom_status': {
                          'text': _customStatusController.text,
                        }
                      });
                    },
                    child: const Text('تطبيق الحالة فوراً', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Card(
      color: const Color(0xFF181825),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF89B4FA))),
            const Divider(color: Color(0xFF313244)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool obscureText = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
