import 'package:shared_preferences/shared_preferences.dart';

class TursoConfig {
  // Default values. User can replace these or configure them dynamically in the app.
  static const String defaultDatabaseUrl = 'libsql://aromaa-whitedevil.aws-ap-south-1.turso.io';
  static const String defaultAuthToken = 'eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJhIjoicnciLCJpYXQiOjE3ODc3MzkwMTUsImlkIjoiMDFhMDNkOGItZGQwMS03NTZhLWI5OWEtMDUzZjc0MTYxYjllIiwia2lkIjoiRDVDcEE3dHFRQWR1WlpoblZqWW5HckFYT2ItdW53T3E0eWpmc0VLazBfbyIsInJpZCI6IjAwMzAzNzg3LWFlODQtNDU0Ni1iNGUzLTIzNTEyMzYxOTc5MCJ9.QRhscjfSQBKGwGF2dxy8jP7AaS8v0f5o4ZxanRrUzoswpYoHLm0bpQ4ozyhhVEbikktP-8Lt3agO4g8g73JbAg';

  static const String _keyUrl = 'turso_db_url';
  static const String _keyToken = 'turso_auth_token';

  static Future<String> getDatabaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_keyUrl);
    if (url == null || url.trim().isEmpty) {
      return defaultDatabaseUrl;
    }
    return url.trim();
  }

  static Future<String> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    if (token == null || token.trim().isEmpty) {
      return defaultAuthToken;
    }
    return token.trim();
  }

  static Future<void> saveConfig(String url, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUrl, url.trim());
    await prefs.setString(_keyToken, token.trim());
  }
}
