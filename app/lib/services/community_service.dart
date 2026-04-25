import 'dart:convert';
import 'package:http/http.dart' as http;
import '../secrets.dart';

class CommunityService {

  static Future<List<dynamic>> getPosts() async {
    final response = await http.get(
      Uri.parse("${Secrets.communityBackendUrl}/posts"),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception("Failed to load posts");
  }

  static Future<void> createPost(String content) async {
    await http.post(
      Uri.parse("${Secrets.communityBackendUrl}/posts"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"content": content}),
    );
  }
}
