import 'dart:convert';

class TokenParser {
  static String? extractToken(String message) {
    try {
      print('🔍 Parsing message: $message');

      // Check if message contains break/close keywords
      // final lowerMessage = message.toLowerCase();
      // if (lowerMessage.contains('break') || lowerMessage.contains('close')) {
      //   print('🛑 Break/Close detected, returning 0000');
      //   return '0000';
      // }

      final Map<String, dynamic> result = jsonDecode(message);

      if (result['isSuccess'] == true) {
        final Map<String, dynamic> dataDic =
            Map<String, dynamic>.from(result['dataBundle']);
        final Map<String, dynamic> mainTokenDetailDic =
            Map<String, dynamic>.from(dataDic['mainTokenDetailDic']);

        final token = mainTokenDetailDic['tokenNumber']?.toString();
        print('✅ Extracted token: $token');
        return token;
      } else {
        print('❌ isSuccess is false');
      }
    } catch (e) {
      print("⚠️ JSON parsing error: $e");
    }
    return null;
  }
}
