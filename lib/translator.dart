import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;

const String salt = 'openie';
String appid = '';
String secret = '';

Future<void> loadSetting(filepath) async {
  String keyString = await rootBundle.loadString('assets/data/baidufanyi.key');
  appid = keyString.split('\n')[0];
  secret = keyString.split('\n')[1];
}

String getSign(String query, String appid, String secret, String salt) {
  String input = appid + query + salt + secret;

  return md5.convert(utf8.encode(input)).toString();
}

Future<String> translate(
    String sentence, String appid, String secret, String salt) async {
  var url = Uri.https('fanyi-api.baidu.com', '/api/trans/vip/translate', {
    'q': sentence,
    'from': 'en',
    'to': 'zh',
    'appid': appid,
    'salt': salt,
    'sign': getSign(
      sentence,
      appid,
      secret,
      salt,
    ),
  });

  var data = await http.get(url);

  Map<String, dynamic> jsonData = jsonDecode(data.body);
  if (jsonData.containsKey('error_code')) {
    return 'error_code${jsonData['error_code']}-${jsonData['error_msg']}';
  }

  return jsonData['trans_result'][0]['dst'];
}
