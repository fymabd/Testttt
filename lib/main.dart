import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const SelfbotApp());
}

class SelfbotApp extends StatelessWidget {
  const SelfbotApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Selfbot Manager',
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
  final _serverUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _userIdController = TextEditingController();

  String _selectedType = 'STREAMING';
  final _titleController = TextEditingController();
  final _detailsController = TextEditingController();
  final _stateController = TextEditingController();
  final _streamUrlController = TextEditingController();
  final _largeImgController = TextEditingController();
  final _smallImgController = TextEditingController();
  final _btn1LabelController = TextEditingController();
  final _btn1UrlController = TextEditingController();

  final _clearChannelController = TextEditingController();
  final _clearCountController = TextEditingController(text: '10');

  Future<void> _sendApiRequest(String endpoint, Map<String, dynamic> bodyData) async {
    final baseUrl = _serverUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (baseUrl.isEmpty || apiKey.isEmpty) {
      _showSnackBar('يرجى كتابة رابط سيرفر Replit ومفتاح الـ API أولاً', isError: true);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
        },
        body: jsonEncode(bodyData),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _showSnackBar(data['message'] ?? 'تم تنفيذ الأمر بنجاح 🎉');
      } else {
        _showSnackBar(data['error'] ?? 'حدث خطأ في التنفيذ', isError: true);
      }
    } catch (e) {
      _showSnackBar('فشل الاتصال بالسيرفر، تأكد من رابط Replit', isError: true);
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
        title: const Text('لوحة تحكم السيلف بوت'),
        centerTitle: true,
        backgroundColor: const Color(0xFF181825),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildCard(
              title: '⚙️ ربط السيرفر والحساب',
              child: Column(
                children: [
                  _buildTextField(_serverUrlController, 'رابط سيرفر Replit (مثل https://app.replit.dev)'),
                  const SizedBox(height: 10),
                  _buildTextField(_apiKeyController, 'مفتاح الأمان (API Key)', obscureText: true),
                  const SizedBox(height: 10),
                  _buildTextField(_userIdController, 'User ID (آيدي حسابك بالديسكورد)'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildCard(
              title: '🎭 التحكم بالحالة والـ RPC',
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    dropdownColor: const Color(0xFF313244),
                    decoration: const InputDecoration(labelText: 'نوع النشاط', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'STREAMING', child: Text('بث مباشر (Streaming)')),
                      DropdownMenuItem(value: 'WATCHING', child: Text('يشاهد (Watching)')),
                      DropdownMenuItem(value: 'PLAYING', child: Text('يلعب (Playing)')),
                      DropdownMenuItem(value: 'LISTENING', child: Text('يستمع (Listening)')),
                    ],
                    onChanged: (val) => setState(() => _selectedType = val!),
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(_titleController, 'العنوان الرئيسي (Title)'),
                  const SizedBox(height: 10),
                  _buildTextField(_detailsController, 'التفاصيل (Details) - السطر الأول'),
                  const SizedBox(height: 10),
                  _buildTextField(_stateController, 'الحالة (State) - السطر الثاني'),
                  const SizedBox(height: 10),
                  if (_selectedType == 'STREAMING') ...[
                    _buildTextField(_streamUrlController, 'رابط الستريم (Twitch/YouTube)'),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_largeImgController, 'الصورة الكبيرة (URL)')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField(_smallImgController, 'الصورة الصغيرة (URL)')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_btn1LabelController, 'اسم الزر')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField(_btn1UrlController, 'رابط الزر')),
                    ],
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF89B4FA),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: () {
                      _sendApiRequest('/api/app/presence', {
                        'userId': _userIdController.text.trim(),
                        'type': _selectedType,
                        'title': _titleController.text,
                        'details': _detailsController.text,
                        'state': _stateController.text,
                        'url': _streamUrlController.text,
                        'largeImage': _largeImgController.text,
                        'smallImage': _smallImgController.text,
                        'button1Label': _btn1LabelController.text,
                        'button1Url': _btn1UrlController.text,
                      });
                    },
                    child: const Text('تحديث الحالة والـ RPC', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildCard(
              title: '🧹 مسح الرسائل (Clear)',
              child: Column(
                children: [
                  _buildTextField(_clearChannelController, 'ID الروم (Channel ID)'),
                  const SizedBox(height: 10),
                  _buildTextField(_clearCountController, 'عدد الرسائل', isNumber: true),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: () {
                      _sendApiRequest('/api/app/clear', {
                        'userId': _userIdController.text.trim(),
                        'channelId': _clearChannelController.text.trim(),
                        'count': int.tryParse(_clearCountController.text) ?? 10,
                      });
                    },
                    child: const Text('مسح الرسائل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildTextField(TextEditingController controller, String label, {bool obscureText = false, bool isNumber = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
