class WeatherModel {
  final String condition;
  final String iconCode;
  final double temp;
  final double feelsLike;
  final double humidity;
  final double windSpeed;
  final double pressure;
  final double visibility;
  final double chanceOfRain;

  WeatherModel({
    required this.condition,
    required this.iconCode,
    required this.temp,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.pressure,
    required this.visibility,
    required this.chanceOfRain,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    final list = json['list'][0];
    final main = list['main'];
    final weather = list['weather'][0];
    final wind = list['wind'];

    return WeatherModel(
      condition: weather['main'],
      iconCode: weather['icon'],
      temp: (main['temp'] as num).toDouble(),
      feelsLike: (main['feels_like'] as num).toDouble(),
      humidity: (main['humidity'] as num).toDouble(),
      windSpeed: (wind['speed'] as num).toDouble(),
      pressure: (main['pressure'] as num).toDouble(),
      visibility: (list['visibility'] as num).toDouble(),
      chanceOfRain: ((list['pop'] as num?)?.toDouble() ?? 0.0) * 100,
    );
  }

  String getTempString(bool isCelsius) {
    double value = isCelsius ? temp : (temp * 9 / 5) + 32;
    return value.toStringAsFixed(0);
  }

  String getFeelsLikeString(bool isCelsius) {
    double value = isCelsius ? feelsLike : (feelsLike * 9 / 5) + 32;
    return value.toStringAsFixed(0);
  }

  String getWindString(bool isKmh) {
    if (isKmh) {
      return "${(windSpeed * 3.6).toStringAsFixed(1)} km/h";
    }
    return "${windSpeed.toStringAsFixed(1)} m/s";
  }

  String getPressureString(bool isMmHg) {
    if (isMmHg) {
      return "${(pressure * 0.750062).toStringAsFixed(0)} mmHg";
    }
    return "${pressure.toStringAsFixed(0)} hPa";
  }

  String getVisibilityString(bool isCelsius) {
    if (isCelsius) {
      return "${(visibility / 1000).toStringAsFixed(1)} km";
    } else {
      return "${(visibility / 1609.34).toStringAsFixed(1)} mi";
    }
  }
}