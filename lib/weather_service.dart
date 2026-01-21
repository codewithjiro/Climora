import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'weather_model.dart';

class WeatherService {
  Future<WeatherModel> fetchWeather(String city) async {
    // We always request metric to standardize our data model
    final cleanCity = Uri.encodeComponent(city.trim());
    final uri = "https://api.openweathermap.org/data/2.5/forecast?q=$cleanCity&units=metric&appid=$apiKey";

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return WeatherModel.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 404) {
        throw Exception("City not found");
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      throw Exception("Connection Failed");
    }
  }
}