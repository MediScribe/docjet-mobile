class ApiConfig {
  static const String baseUrl = 'https://api.docjet.com/api/v1';
  static const String apiKey =
      'YOUR_API_KEY'; // Replace with your actual API key

  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'X-API-Key': apiKey,
  };
}
