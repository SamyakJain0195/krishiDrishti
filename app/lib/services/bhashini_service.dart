import 'dart:convert';
import 'package:http/http.dart' as http;
import '../secrets.dart';

class BhashiniService {
  static Future<String> translateText({
    required String text,
    required String targetLangCode,
  }) async {
    final url =
        "https://inference.api.bhashini.gov.in/inference/text/translation/v2";

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer ${Secrets.inferenceKey}",
    };

    final body = {
      "processingLanguage": "en",
      "input": [
        {"source": text},
      ],
      "config": {
        "translation": {
          "sourceLanguage": "en",
          "targetLanguage": targetLangCode,
        },
      },
    };

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["output"] != null &&
              json["output"] is List &&
              json["output"].isNotEmpty
          ? (json["output"][0]["target"] ?? text)
          : text;
    } else {
      return text; // fallback if API fails
    }
  }
}
