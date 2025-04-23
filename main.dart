import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';



void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const WeatherScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  List<WeatherData> _weatherDataList = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getLocationAndWeather();
  }
  Future<void> _openAppSettings() async {
    await openAppSettings();
  }

  Future<void> _getLocationAndWeather() async {
    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Location services are disabled. Please enable them.';
        });
        return;
      }

      // Check location permission status
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Request permission if not granted
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Location permissions are denied';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Location permissions are permanently denied. Please enable them in app settings.';
        });
        // Open app settings so user can enable permissions
        await openAppSettings();
        return;
      }

      // If we get here, permissions are granted
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      await _fetchWeather(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error getting location or weather data: ${e.toString()}';
      });
    }
  }

  Future<void> _fetchWeather(double lat, double lon) async {
    const apiKey = '22e9b944f843e1a22b9c53eb7e38e117';
    final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _weatherDataList.add(WeatherData(
            city: data['name'],
            temperature: data['main']['temp'],
            description: data['weather'][0]['description'],
            humidity: data['main']['humidity'],
            windSpeed: data['wind']['speed'],
            weatherIcon: _getWeatherIcon(data['weather'][0]['main']),
            lat: lat,
            lon: lon,
          ));
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to fetch weather data (HTTP ${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to fetch weather data: ${e.toString()}';
      });
    }
  }

  Future<void> _searchLocation(String locationName) async {
    if (locationName.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      const apiKey = '22e9b944f843e1a22b9c53eb7e38e117';
      final geoUrl = Uri.parse(
          'https://api.openweathermap.org/geo/1.0/direct?q=$locationName&limit=1&appid=$apiKey');
      
      final geoResponse = await http.get(geoUrl);
      if (geoResponse.statusCode == 200) {
        final geoData = json.decode(geoResponse.body);
        if (geoData.isNotEmpty) {
          final lat = geoData[0]['lat'];
          final lon = geoData[0]['lon'];
          await _fetchWeather(lat, lon);
          _searchController.clear();
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Location not found';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to search location (HTTP ${geoResponse.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to search location: ${e.toString()}';
      });
    }
  }

  String _getWeatherIcon(String weatherCondition) {
    switch (weatherCondition.toLowerCase()) {
      case 'clear':
        return '☀️';
      case 'clouds':
        return '☁️';
      case 'rain':
        return '🌧️';
      case 'snow':
        return '❄️';
      case 'thunderstorm':
        return '⛈️';
      case 'drizzle':
        return '🌦️';
      case 'mist':
      case 'smoke':
      case 'haze':
      case 'fog':
        return '🌫️';
      default:
        return '🌈';
    }
  }

  List<Color> _getBackgroundGradient(WeatherData? weatherData) {
    if (weatherData == null) return [Colors.blue.shade300, Colors.blue.shade600];
    
    final temp = weatherData.temperature;
    if (temp > 30) return [Colors.orange.shade600, Colors.red.shade400];
    if (temp > 20) return [Colors.yellow.shade600, Colors.orange.shade400];
    if (temp > 10) return [Colors.lightBlue.shade400, Colors.blue.shade600];
    return [Colors.blue.shade800, Colors.indigo.shade600];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _weatherDataList.isEmpty
                ? [Colors.blue.shade300, Colors.blue.shade600]
                : _getBackgroundGradient(_weatherDataList.last),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search city or county...',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.my_location, color: Colors.white),
                          onPressed: _getLocationAndWeather,
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: () => _searchLocation(_searchController.text),
                        ),
                      ],
                    ),
                    hintStyle: const TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: _searchLocation,
                ),
              ),
              
              // Content Area
              Expanded(
                child: _isLoading && _weatherDataList.isEmpty
                    ? const Center(
                        child: SpinKitFadingCircle(
                          color: Colors.white,
                          size: 50.0,
                        ),
                      )
                    : // In your build method, modify the error display:
                _errorMessage.isNotEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (_errorMessage.contains('permanently denied'))
                        ElevatedButton(
                          onPressed: openAppSettings,
                          child: const Text('Open Settings'),
                        ),
                    ],
                  ),
                )
                        : _weatherDataList.isEmpty
                            ? const Center(
                                child: Text(
                                  'No locations added',
                                  style: TextStyle(color: Colors.white),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _weatherDataList.length,
                                itemBuilder: (context, index) {
                                  final weatherData = _weatherDataList[index];
                                  return _buildWeatherCard(weatherData);
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherCard(WeatherData weatherData) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white.withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  weatherData.city,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _weatherDataList.remove(weatherData);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              weatherData.weatherIcon,
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(height: 10),
            Text(
              '${weatherData.temperature.toStringAsFixed(1)}°C',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w200,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              weatherData.description.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWeatherDetail('Humidity', '${weatherData.humidity}%', Icons.water_drop),
                _buildWeatherDetail('Wind', '${weatherData.windSpeed.toStringAsFixed(1)} m/s', Icons.air),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherDetail(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 30),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
  final String weatherIcon;
  final double lat;
  final double lon;

  WeatherData({
    required this.city,
    required this.temperature,
    required this.description,
    required this.humidity,
    required this.windSpeed,
    required this.weatherIcon,
    required this.lat,
    required this.lon,
  });
}
