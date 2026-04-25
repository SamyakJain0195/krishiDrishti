import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'secrets.dart';

class CropService {
  /// Ensures location permission and returns current Position.
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
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Sends the provided payload to [url]. If latitude/longitude are missing
  /// they will be filled from device geolocation.
  /// Returns decoded JSON response on success.
  static Future<Map<String, dynamic>> predictCrop({
    required Map<String, dynamic> payload,
    required String url,
    bool useDeviceLocationIfMissing = true,
  }) async {
    final Map<String, dynamic> body = Map<String, dynamic>.from(payload);

    if (useDeviceLocationIfMissing &&
        (body['latitude'] == null || body['longitude'] == null)) {
      final Position pos = await _determinePosition();
      body['latitude'] = pos.latitude;
      body['longitude'] = pos.longitude;
    }

    final resp = await http.post(
      Uri.parse("${Secrets.backendBaseUrl}/predict"),

      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      try {
        return Map<String, dynamic>.from(jsonDecode(resp.body));
      } catch (e) {
        return {'raw': resp.body};
      }
    }

    throw Exception('Server returned ${resp.statusCode}: ${resp.body}');
  }
}
