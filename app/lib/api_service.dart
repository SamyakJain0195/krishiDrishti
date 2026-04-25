import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secrets.dart';

const String baseUrl = "http://192.168.137.129:8000";

class ApiService {
  // ---------------- Yield Prediction ----------------
  Future<Map<String, dynamic>> predictYield(Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse("$baseUrl/predict_yield"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Yield Prediction Failed: ${response.body}");
    }
  }

  // ---------------- Irrigation Prediction ----------------
  Future<Map<String, dynamic>> predictIrrigation(
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/predict_irrigation"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Irrigation Prediction Failed: ${response.body}");
    }
  }

  // ---------------- Chatbot ----------------
  Future<String> sendChatMessage({
    required String userId,
    required String message,
    required String language,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/chat"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_id": userId,
        "message": message,
        "language": language,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["response"] ??
          data["reply"] ??
          "No reply key found in backend";
    } else {
      throw Exception("Chat Error: ${response.body}");
    }
  }

  // =====================================================
  //                 OPENWEATHER API
  // =====================================================

  static const String _openWeatherBaseUrl =
      "https://192.168.137.129/weather/current";

  /// Get current weather by latitude & longitude
  /// Example usage:
  ///   final data = await api.getCurrentWeather(23.45, 85.32);
  ///   final temp = data["main"]["temp"];
  Future<Map<String, dynamic>> getCurrentWeather(double lat, double lon) async {
    final uri = Uri.parse(
      "$_openWeatherBaseUrl/weather"
      "?lat=$lat&lon=$lon"
      "&appid=${Secrets.openWeatherApiKey}"
      "&units=metric",
    );

    final res = await http.get(uri);

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else {
      throw Exception("Weather API error: ${res.statusCode} - ${res.body}");
    }
  }

  // =====================================================
  //           CROP RECOMMENDATION 
  // =====================================================

  /// Calls backend: POST /crops/predict_top3
  /// `payload` should contain N, P, K, pH, etc as our backend expects.
  Future<List<dynamic>> getTop3Crops(Map<String, dynamic> payload) async {
    final uri = Uri.parse("${Secrets.backendBaseUrl}/crops/predict_top3");

    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      //  backend returns a list like ["Wheat", "Rice", "Maize"]
      if (data is List) return data;
      if (data is Map && data["crops"] is List) {
        return data["crops"] as List;
      }
      throw Exception("Unexpected crop prediction response format: $data");
    } else {
      throw Exception("Crop prediction error: ${res.statusCode} - ${res.body}");
    }
  }

  // =====================================================
  //                 BHASHINI TRANSLATION
  // =====================================================

  /// Frontend -> our backend -> Bhashini
  /// Example:
  ///   final out = await api.translateText(
  ///       text: "नमस्ते", sourceLang: "hi", targetLang: "en");
  Future<String> translateText({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final uri = Uri.parse("${Secrets.backendBaseUrl}/nlp/translate");

    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "text": text,
        "source": sourceLang,
        "target": targetLang,
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data["translated_text"] ?? data["output"] ?? text).toString();
    } else {
      throw Exception(
        "Bhashini translate error: ${res.statusCode} - ${res.body}",
      );
    }
  }
}
