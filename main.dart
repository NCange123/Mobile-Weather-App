import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(WeatherApp());
}

class WeatherApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: WeatherScreen(),
    );
  }
}

class WeatherScreen extends StatefulWidget {
  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  late WeatherData _weatherData;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _getLocationAndWeather();
  }

  Future<void> _getLocationAndWeather() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low);
      await _fetchWeather(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error getting location or weather data';
      });
    }
  }

  Future<void> _fetchWeather(double lat, double lon) async {
    const apiKey = 'YOUR_API_KEY'; // Get from openweathermap.org
    final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _weatherData = WeatherData(
            city: data['name'],
            temperature: data['main']['temp'],
            description: data['weather'][0]['description'],
            humidity: data['main']['humidity'],
            windSpeed: data['wind']['speed'],
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to fetch weather data';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Weather App'),
      ),
      body: _isLoading
          ? Center(
              child: SpinKitDoubleBounce(
                color: Colors.blue,
                size: 100.0,
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_weatherData.city}',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 20),
                      Text(
                        '${_weatherData.temperature.toStringAsFixed(1)}°C',
                        style: TextStyle(fontSize: 48),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '${_weatherData.description}',
                        style: TextStyle(fontSize: 20),
                      ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildWeatherInfo('Humidity', '${_weatherData.humidity}%'),
                          _buildWeatherInfo('Wind', '${_weatherData.windSpeed.toStringAsFixed(1)} m/s'),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildWeatherInfo(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(fontSize: 20),
        ),
      ],
    );
  }
}

class WeatherData {
  final String city;
  final double temperature;
  final String description;
  final int humidity;
  final double windSpeed;

  WeatherData({
    required this.city,
    required this.temperature,
    required this.description,
    required this.humidity,
    required this.windSpeed,
  });
}