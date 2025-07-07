import 'package:http/http.dart' as http;
import 'dart:convert';

/// 《代码文档》翻译服务类
///
/// 该类负责处理翻译API调用，提供统一的翻译接口
/// 可以被多个组件复用
class TranslationService {
  static const String _apiUrl = 'https://cerebras-proxy.brain.loocaa.com:1443/v1/chat/completions';
  static const String _apiKey = 'DlJYSkMVj1x4zoe8jZnjvxfHG6z5yGxK';
  static const String _model = 'llama-3.3-70b';

  /// 翻译文本内容
  ///
  /// [text] 要翻译的文本内容
  /// 返回翻译后的文本
  /// 如果翻译失败，会抛出异常
  static Future<String> translateText(String text) async {
    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: json.encode({
              "model": _model,
              "messages": [
                {
                  "role": "system",
                  "content": "你是一个资深的中英文翻译官，你非常擅长把英文内容翻译为优雅的中文表达。\n现在，你需要根据用户发送的内容，进行翻译，只翻译用户发的内容，不要增加任何额外的文字",
                },
                {"role": "user", "content": text},
              ],
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        throw Exception('翻译失败：HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Connection failed')) {
        throw Exception('网络连接失败，请检查网络设置');
      } else if (e.toString().contains('TimeoutException')) {
        throw Exception('请求超时，请稍后重试');
      } else {
        throw Exception('翻译失败：$e');
      }
    }
  }
}
