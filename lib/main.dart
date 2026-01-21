import 'dart:async';
import 'dart:ui'; // Required for Blur
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // Needed for Colors
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// Siguraduhin na ang mga files na ito ay nasa lib folder mo
import 'constants.dart';
import 'weather_model.dart';
import 'weather_service.dart';
import 'city_search_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final WeatherService _weatherService = WeatherService();

  // --- SPLASH STATE ---
  bool _showSplash = true;

  // --- PREFERENCES ---
  bool isDarkMode = false;
  bool isCelsius = true;
  Color activeColor = CupertinoColors.activeBlue; // Ito ang magdadala ng kulay sa Home at Settings
  int autoRefreshInterval = 0;
  bool isKmh = false;
  bool isMmHg = false;

  // --- DATA ---
  List<String> recentSearches = [];
  String city = "Arayat";

  WeatherModel? _weather;
  String weatherCondition = "Loading...";
  String lastFetchTime = "--";
  bool isFetching = false;
  bool isLoading = false;
  Timer? _refreshTimer;

  // --- TOAST VARIABLES ---
  bool _showToast = false;
  String _toastMessage = "";
  Color _toastColor = CupertinoColors.activeBlue;
  IconData _toastIcon = CupertinoIcons.location_fill;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  // --- LOGIC ---

  Future<void> _loadPreferences() async {
    final minSplashTime = Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      city = prefs.getString('city') ?? "Doha";
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
      isCelsius = prefs.getBool('isCelsius') ?? true;
      autoRefreshInterval = prefs.getInt('autoRefreshInterval') ?? 0;
      isKmh = prefs.getBool('isKmh') ?? false;
      isMmHg = prefs.getBool('isMmHg') ?? false;
      recentSearches = prefs.getStringList('recentSearches') ?? [];

      int? colorValue = prefs.getInt('activeColor');
      if (colorValue != null) {
        activeColor = Color(colorValue);
      }
    });

    _updateAutoRefresh(autoRefreshInterval, save: false);
    // Initial load: Don't show toast, don't re-save to history
    await getWeatherData(targetCity: city, showToast: false, saveToHistory: false);
    await minSplashTime;

    if (mounted) {
      setState(() {
        _showSplash = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('city', city);
    await prefs.setBool('isDarkMode', isDarkMode);
    await prefs.setBool('isCelsius', isCelsius);
    await prefs.setBool('isKmh', isKmh);
    await prefs.setBool('isMmHg', isMmHg);
    await prefs.setInt('activeColor', activeColor.value);
    await prefs.setInt('autoRefreshInterval', autoRefreshInterval);
  }

  Future<void> _addToRecentSearches(String newCity) async {
    if (newCity.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      recentSearches.removeWhere((item) => item.toLowerCase() == newCity.toLowerCase());
      recentSearches.insert(0, newCity);
      if (recentSearches.length > 10) {
        recentSearches.removeLast();
      }
    });
    await prefs.setStringList('recentSearches', recentSearches);
  }

  void _updateAutoRefresh(int minutes, {bool save = true}) {
    _refreshTimer?.cancel();
    setState(() {
      autoRefreshInterval = minutes;
    });
    if (save) _savePreferences();
    if (minutes > 0) {
      _refreshTimer = Timer.periodic(Duration(minutes: minutes), (timer) {
        getWeatherData(targetCity: city, showToast: false);
      });
    }
  }

  // --- CORE WEATHER LOGIC ---
  // targetCity: The city we want to fetch.
  // saveToHistory: Only set to TRUE if this comes from a User Search action.
  Future<void> getWeatherData({required String targetCity, bool showToast = true, bool saveToHistory = false}) async {
    if (targetCity.trim().isEmpty) return;

    // Only show full loading screen if we have no data yet
    if (_weather == null) setState(() => isLoading = true);
    setState(() => isFetching = true);

    try {
      // 1. Fetch Data
      final weatherData = await _weatherService.fetchWeather(targetCity);

      if (!mounted) return;

      // 2. Success! Update UI
      setState(() {
        _weather = weatherData;
        city = targetCity; // Confirm the change of city only on success

        if (weatherData.iconCode.startsWith("02")) {
          weatherCondition = "Partly Cloudy";
        } else {
          weatherCondition = weatherData.condition;
        }

        lastFetchTime = DateFormat('h:mm a').format(DateTime.now());
        isLoading = false;
      });

      // 3. Save Logic (Only if validated)
      if (saveToHistory) {
        await _addToRecentSearches(targetCity);
        await _savePreferences(); // Save as new default
      }

      // 4. Show Success Toast
      if (showToast) {
        _showStatusToast(city: targetCity, iconCode: weatherData.iconCode, isError: false);
      }

    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        // Don't update 'city' variable to the broken one. Keep the old valid one if possible.
        // But if we have no weather at all yet:
        if (_weather == null) {
           weatherCondition = e.toString().contains("City") ? "City Not Found" : "Connection Error";
        }
      });

      // 5. Error Handling
      if (e.toString().contains("City not found")) {
        // --- INVALID CITY LOGIC ---
        // Show Dialog, Do NOT save, Do NOT show toast
        _showErrorDialog("Invalid City", "We couldn't find \"$targetCity\". Please check your spelling.");
      } else {
         // Other errors (e.g. No Internet)
         if (showToast) {
            _showStatusToast(city: "Error", isError: true, customMessage: "Check your connection.");
         }
      }
    } finally {
      if (mounted) setState(() => isFetching = false);
    }
  }

  // --- TOAST LOGIC ---
  void _showStatusToast({required String city, String? iconCode, bool isError = false, String? customMessage}) {
    String message = "";
    Color bgColor;
    IconData icon;

    if (isError) {
      message = customMessage ?? "Something went wrong.";
      bgColor = CupertinoColors.systemRed;
      icon = CupertinoIcons.exclamationmark_circle_fill;
    } else {
      // SUCCESS: Use the current 'activeColor' for the toast background
      bgColor = activeColor;
      icon = CupertinoIcons.location_fill;

      String code = (iconCode ?? "01").substring(0, 2);
      String advice = "";
      switch(code) {
        case '01': advice = "It's a beautiful sunny day!"; break;
        case '02': advice = "Enjoy the nice weather."; break;
        case '03':
        case '04': advice = "It's a bit cloudy today."; break;
        case '09':
        case '10': advice = "Don't forget your umbrella!"; break;
        case '11': advice = "Stay safe, storm approaching."; break;
        case '13': advice = "Wrap up warm, it's snowing!"; break;
        case '50': advice = "Drive carefully, visibility is low."; break;
        default: advice = "Have a great day!";
      }
      message = "📍 $city\n$advice";
    }

    setState(() {
      _toastMessage = message;
      _toastColor = bgColor;
      _toastIcon = icon;
      _showToast = true;
    });

    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showToast = false;
        });
      }
    });
  }

  void _showErrorDialog(String title, String message) {
    if (navigatorKey.currentContext == null) return;
    showCupertinoDialog(
      context: navigatorKey.currentContext!,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  // --- HELPERS ---
  String _getBackgroundImage(String? iconCode) {
    if (iconCode == null) return "assets/images/cloudy.jpg";
    switch (iconCode.substring(0, 2)) {
      case '01':
      case '02': return iconCode.endsWith('d') ? "assets/images/sunny.jpg" : "assets/images/night.jpg";
      case '03':
      case '04':
      case '50': return "assets/images/cloudy.jpg";
      case '09':
      case '10': return "assets/images/rain.jpg";
      case '11': return "assets/images/thunder.jpg";
      case '13': return "assets/images/snow.jpg";
      default: return "assets/images/sunny.jpg";
    }
  }

  IconData _getWeatherIcon(String? iconCode) {
    if (iconCode == null) return CupertinoIcons.cloud;
    String code = iconCode.substring(0, 2);
    bool isDay = iconCode.endsWith('d');
    switch (code) {
      case '01': return isDay ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill;
      case '02': return isDay ? CupertinoIcons.cloud_sun_fill : CupertinoIcons.cloud_moon_fill;
      case '03': case '04': return CupertinoIcons.cloud_fill;
      case '09': return CupertinoIcons.cloud_drizzle_fill;
      case '10': return CupertinoIcons.cloud_rain_fill;
      case '11': return CupertinoIcons.cloud_bolt_fill;
      case '13': return CupertinoIcons.snow;
      case '50': return CupertinoIcons.cloud_fog_fill;
      default: return CupertinoIcons.cloud_fill;
    }
  }

  // --- UI BUILDER ---

  void _showColorPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Choose App Theme'),
        actions: [
          _buildColorAction(context, 'Teal', CupertinoColors.systemTeal),
          _buildColorAction(context, 'Blue', CupertinoColors.activeBlue),
          _buildColorAction(context, 'Green', CupertinoColors.activeGreen),
          _buildColorAction(context, 'Orange', CupertinoColors.activeOrange),
          _buildColorAction(context, 'Red', CupertinoColors.systemRed),
          _buildColorAction(context, 'Purple', CupertinoColors.systemPurple),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ),
    );
  }

  CupertinoActionSheetAction _buildColorAction(BuildContext context, String name, Color color) {
    return CupertinoActionSheetAction(
      onPressed: () {
        // Kapag nagpalit ng kulay, magse-setState ito
        // Dahil ang activeColor variable ay nasa root ng MyAppState,
        // magrerebuild ang buong UI kasama ang Tabs at Toast
        setState(() => activeColor = color);
        _savePreferences();
        Navigator.pop(context);
      },
      child: Text(name, style: TextStyle(color: color)),
    );
  }

  void _showAutoRefreshPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Auto Refresh Interval'),
        actions: [
          CupertinoActionSheetAction(onPressed: () { Navigator.pop(context); _updateAutoRefresh(0); }, child: const Text('Off')),
          CupertinoActionSheetAction(onPressed: () { Navigator.pop(context); _updateAutoRefresh(15); }, child: const Text('15 Minutes')),
          CupertinoActionSheetAction(onPressed: () { Navigator.pop(context); _updateAutoRefresh(30); }, child: const Text('30 Minutes')),
          CupertinoActionSheetAction(onPressed: () { Navigator.pop(context); _updateAutoRefresh(60); }, child: const Text('1 Hour')),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: "Climora",
      // Dito ina-apply ang activeColor sa buong theme
      theme: CupertinoThemeData(
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        primaryColor: activeColor
      ),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 800),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _showSplash ? _buildSplashScreen() : _buildMainApp(),
      ),
    );
  }

  Widget _buildSplashScreen() {
    return CupertinoPageScaffold(
      key: const ValueKey("SplashScreen"),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [activeColor.withOpacity(0.8), activeColor, CupertinoColors.black.withOpacity(0.8)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.cloud_sun_fill, size: 100, color: CupertinoColors.white),
              const SizedBox(height: 20),
              const Text("Climora", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: CupertinoColors.white, letterSpacing: 1.5, fontFamily: 'System', decoration: TextDecoration.none)),
              const SizedBox(height: 60),
              const CupertinoActivityIndicator(radius: 15, color: CupertinoColors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainApp() {
    return CupertinoTabScaffold(
      key: const ValueKey("MainApp"),
      tabBar: CupertinoTabBar(
        // IMPORTANT: Ginagamit nito ang activeColor variable para mag-change kulay din ang tabs
        activeColor: activeColor,
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : const Color(0xFFF9F9F9),
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.house), activeIcon: Icon(CupertinoIcons.house_fill), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.gear), activeIcon: Icon(CupertinoIcons.gear_solid), label: 'Settings'),
        ],
      ),
      tabBuilder: (context, index) {
        if (index == 0) {
          // --- HOME TAB ---
          return CupertinoPageScaffold(
            backgroundColor: Colors.transparent,
            child: Stack(
              children: [
                // 1. Background Image
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(_getBackgroundImage(_weather?.iconCode)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // 2. Dark Overlay
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.6)],
                    ),
                  ),
                ),
                // 3. Scrollable Content
                SafeArea(
                  child: CustomScrollView(
                    slivers: [
                      CupertinoSliverRefreshControl(
                        onRefresh: () async { await getWeatherData(targetCity: city, showToast: true); },
                        builder: (context, refreshState, pulledExtent, refreshTriggerPullDistance, refreshIndicatorExtent) {
                          return const Center(child: CupertinoActivityIndicator(color: Colors.white));
                        },
                      ),
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            Text(city, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 32, color: Colors.white, shadows: [Shadow(blurRadius: 10, color: Colors.black45, offset: Offset(2, 2))])),
                            const SizedBox(height: 5),
                            Text(weatherCondition, style: const TextStyle(fontWeight: FontWeight.w300, fontSize: 20, color: Colors.white70)),
                            const SizedBox(height: 8),
                            Text(isFetching ? "Fetching..." : "Updated $lastFetchTime", style: const TextStyle(fontSize: 12, color: Colors.white54)),

                            const SizedBox(height: 30),
                            SizedBox(
                              width: 150, height: 150,
                              child: _weather == null
                                ? const Icon(CupertinoIcons.cloud, size: 100, color: Colors.white)
                                : Icon(_getWeatherIcon(_weather!.iconCode), size: 110, color: Colors.white),
                            ),
                            Text(_weather == null ? "--" : "${_weather!.getTempString(isCelsius)}°", style: const TextStyle(fontSize: 90, fontWeight: FontWeight.w200, color: Colors.white, letterSpacing: -5)),
                            const Spacer(),
                            Container(
                              margin: const EdgeInsets.all(20),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(25),
                                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                          _buildInfoCard("Feels Like", _weather == null ? "--" : "${_weather!.getFeelsLikeString(isCelsius)}°", CupertinoIcons.thermometer),
                                          _buildInfoCard("Humidity", _weather == null ? "--" : "${_weather!.humidity.toStringAsFixed(0)}%", CupertinoIcons.drop),
                                          _buildInfoCard("Rain Chance", _weather == null ? "--" : "${_weather!.chanceOfRain.toStringAsFixed(0)}%", CupertinoIcons.cloud_rain)
                                        ]),
                                        const SizedBox(height: 25),
                                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                          _buildInfoCard("Wind", _weather == null ? "--" : _weather!.getWindString(isKmh), CupertinoIcons.wind),
                                          _buildInfoCard("Pressure", _weather == null ? "--" : _weather!.getPressureString(isMmHg), CupertinoIcons.gauge),
                                          _buildInfoCard("Visibility", _weather == null ? "--" : _weather!.getVisibilityString(isCelsius), CupertinoIcons.eye)
                                        ]),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // --- TOAST WIDGET ---
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  top: _showToast ? 60 : -150,
                  left: 20,
                  right: 20,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        decoration: BoxDecoration(
                          // Ensure toast uses the current active theme color (or red for error)
                          color: _toastColor.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
                          ],
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_toastIcon, color: Colors.white, size: 28),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                _toastMessage,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          // --- SETTINGS TAB ---
          return CupertinoPageScaffold(
            navigationBar: const CupertinoNavigationBar(middle: Text("Settings")),
            backgroundColor: CupertinoColors.systemGroupedBackground,
            child: SafeArea(
              child: ListView(
                children: [
                  CupertinoListSection.insetGrouped(
                    header: const Text('Appearance'),
                    children: [
                      CupertinoListTile(leading: const Icon(CupertinoIcons.moon_fill, color: CupertinoColors.systemGrey), title: const Text('Dark Mode'), trailing: CupertinoSwitch(value: isDarkMode, activeColor: activeColor, onChanged: (value) { setState(() => isDarkMode = value); _savePreferences(); })),
                      CupertinoListTile(leading: Icon(CupertinoIcons.paintbrush_fill, color: activeColor), title: const Text('Theme Color'), trailing: Icon(CupertinoIcons.circle_fill, color: activeColor), onTap: () => _showColorPicker(context)),
                    ],
                  ),
                  CupertinoListSection.insetGrouped(
                    header: const Text('Preferences'),
                    children: [
                      CupertinoListTile(leading: Icon(CupertinoIcons.thermometer, color: activeColor), title: const Text('Temperature Unit'), trailing: CupertinoSlidingSegmentedControl<bool>(thumbColor: activeColor, groupValue: isCelsius, children: {true: Text('°C', style: TextStyle(color: isCelsius ? CupertinoColors.white : CupertinoColors.black)), false: Text('°F', style: TextStyle(color: !isCelsius ? CupertinoColors.white : CupertinoColors.black))}, onValueChanged: (value) { if (value != null) { setState(() { isCelsius = value; }); _savePreferences(); } })),
                      CupertinoListTile(leading: Icon(CupertinoIcons.wind, color: activeColor), title: const Text('Wind Unit'), trailing: CupertinoSlidingSegmentedControl<bool>(thumbColor: activeColor, groupValue: isKmh, children: {false: Text('m/s', style: TextStyle(fontSize: 14, color: !isKmh ? CupertinoColors.white : CupertinoColors.black)), true: Text('km/h', style: TextStyle(fontSize: 14, color: isKmh ? CupertinoColors.white : CupertinoColors.black))}, onValueChanged: (value) { if (value != null) { setState(() { isKmh = value; }); _savePreferences(); } })),
                      CupertinoListTile(leading: Icon(CupertinoIcons.gauge, color: activeColor), title: const Text('Pressure Unit'), trailing: CupertinoSlidingSegmentedControl<bool>(thumbColor: activeColor, groupValue: isMmHg, children: {false: Text('hPa', style: TextStyle(fontSize: 14, color: !isMmHg ? CupertinoColors.white : CupertinoColors.black)), true: Text('mmHg', style: TextStyle(fontSize: 14, color: isMmHg ? CupertinoColors.white : CupertinoColors.black))}, onValueChanged: (value) { if (value != null) { setState(() { isMmHg = value; }); _savePreferences(); } })),
                      CupertinoListTile(leading: Icon(CupertinoIcons.time, color: activeColor), title: const Text('Auto Refresh'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text(autoRefreshInterval == 0 ? "Off" : "${autoRefreshInterval}m", style: const TextStyle(color: CupertinoColors.systemGrey)), const SizedBox(width: 5), const Icon(CupertinoIcons.chevron_right, color: CupertinoColors.systemGrey3)]), onTap: () => _showAutoRefreshPicker(context)),
                    ],
                  ),
                  CupertinoListSection.insetGrouped(
                    header: const Text('Location'),
                    children: [
                      CupertinoListTile(
                        leading: Icon(CupertinoIcons.location_solid, color: activeColor),
                        title: const Text('City'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text(city, style: const TextStyle(color: CupertinoColors.systemGrey)), const SizedBox(width: 5), const Icon(CupertinoIcons.chevron_right, color: CupertinoColors.systemGrey3)]),
                        onTap: () {
                          Navigator.of(context).push(CupertinoPageRoute(builder: (context) => CitySearchPage(recentSearches: recentSearches, popularCities: popularCities, onCitySelected: (selectedCity) async {
                            // Try to fetch new city data.
                            // saveToHistory: true makes sure we only add it if valid.
                            await getWeatherData(targetCity: selectedCity, showToast: true, saveToHistory: true);
                          })));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}