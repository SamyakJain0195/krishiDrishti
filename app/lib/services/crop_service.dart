import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../secrets.dart';

class CropService {

  static Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied.',
      );
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  static Future<Map<String, dynamic>> predictCrop({
    required Map<String, dynamic> payload,
    bool useDeviceLocationIfMissing = true,
  }) async {

    final Map<String, dynamic> body = Map<String, dynamic>.from(payload);

    if (useDeviceLocationIfMissing &&
        (body['latitude'] == null || body['longitude'] == null)) {
      final Position pos = await _determinePosition();
      body['latitude'] = pos.latitude;
      body['longitude'] = pos.longitude;
    }

    final response = await http.post(
      Uri.parse("${Secrets.backendBaseUrl}/predict"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }

    throw Exception("Error ${response.statusCode}: ${response.body}");
  }
}
