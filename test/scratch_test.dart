import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  test('Scratch test to inspect F-Droid API', () async {
    final response = await http.get(Uri.parse('https://f-droid.org/api/v1/packages/org.schabi.newpipe'));
    print('F-Droid API Status Code: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('F-Droid API Keys: ${data.keys.toList()}');
      print('F-Droid API packageName: ${data['packageName']}');
      print('F-Droid API suggestedVersionCode: ${data['suggestedVersionCode']}');
      if (data['packages'] != null && data['packages'] is List) {
        print('F-Droid API first package: ${data['packages'].first}');
      }
      // Print the whole response up to 1000 characters
      print('F-Droid API full response: ${response.body.substring(0, response.body.length > 1000 ? 1000 : response.body.length)}');
    }
  });
}
