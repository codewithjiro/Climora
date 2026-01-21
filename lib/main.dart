import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
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
  Color activeColor = CupertinoColors.systemTeal;
  int autoRefreshInterval = 0;
  bool isKmh = false;
  bool isMmHg = false;

  // --- DATA ---
  List<String> recentSearches = [];
  String city = "Angeles City";

  WeatherModel? _weather;
  String weatherCondition = "Loading...";
  String lastFetchTime = "--";
  bool isFetching = false;
  bool isLoading = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // --- LOGIC ---
  Future<void> _loadPreferences() async {
    final minSplashTime = Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      city = prefs.getString('city') ?? "Angeles City";
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
    await getWeatherData(targetCity: city, saveToHistory: false);
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
        getWeatherData(targetCity: city);
      });
    }
  }

  void _showResultDialog(String title, String message, {bool isError = false}) {
    if (navigatorKey.currentContext == null) return;

    showCupertinoDialog(
      context: navigatorKey.currentContext!,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title,
            style: TextStyle(
                fontFamily: 'SFPro',
                color: isError ? CupertinoColors.destructiveRed : activeColor
            )
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(message, style: const TextStyle(fontFamily: 'SFPro')),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("OK", style: TextStyle(fontFamily: 'SFPro')),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  Future<void> getWeatherData({required String targetCity, bool saveToHistory = false}) async {
    if (targetCity.trim().isEmpty) return;

    if (_weather == null) setState(() => isLoading = true);
    setState(() => isFetching = true);

    try {
      final weatherData = await _weatherService.fetchWeather(targetCity);

      if (!mounted) return;

      setState(() {
        _weather = weatherData;
        city = targetCity;

        if (weatherData.iconCode.startsWith("02")) {
          weatherCondition = "Partly Cloudy";
        } else {
          weatherCondition = weatherData.condition;
        }

        lastFetchTime = DateFormat('h:mm a').format(DateTime.now());
        isLoading = false;
      });

      if (saveToHistory) {
        await _addToRecentSearches(targetCity);
        await _savePreferences();
      }

    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        if (_weather == null) {
          weatherCondition = e.toString().toLowerCase().contains("not found")
              ? "City Not Found"
              : "Connection Error";
        }
      });

      String errorMsg = e.toString().toLowerCase();
      await Future.delayed(const Duration(milliseconds: 500));

      if (errorMsg.contains("city not found") || errorMsg.contains("404")) {
        _showResultDialog("Invalid City", "We couldn't find \"$targetCity\". Please check your spelling.", isError: true);
      } else {
        _showResultDialog("Error", "Could not load weather. Please check your connection.", isError: true);
      }
    } finally {
      if (mounted) setState(() => isFetching = false);
    }
  }

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

  String _getWeatherImagePath(String? iconCode) {
    if (iconCode == null) return "assets/icons/sun.png";

    String code = iconCode.substring(0, 2);
    bool isDay = iconCode.endsWith('d');

    switch (code) {
      case '01': // Clear Sky
        return isDay ? "assets/icons/sun.png" : "assets/icons/moon.png";
      case '02': // Few Clouds
      case '03': // Scattered Clouds
      case '04': // Broken Clouds
        return "assets/icons/wind.png"; // Using wind/cloud substitute
      case '09': // Shower Rain
      case '10': // Rain
        return isDay ? "assets/icons/sunRaint.png" : "assets/icons/nightRain.png";
      case '11': // Thunderstorm
        return isDay ? "assets/icons/thunder.png" : "assets/icons/nightThunder.png";
      case '13': // Snow
        return "assets/icons/heavyRain.png"; // Fallback
      case '50': // Mist
        return "assets/icons/wind.png";
      default:
        return isDay ? "assets/icons/sun.png" : "assets/icons/moon.png";
    }
  }

  void _showColorPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Choose App Theme', style: TextStyle(fontFamily: 'SFPro')),
        actions: [
          _buildColorAction(context, 'Teal', CupertinoColors.systemTeal),
          _buildColorAction(context, 'Blue', CupertinoColors.activeBlue),
          _buildColorAction(context, 'Green', CupertinoColors.activeGreen),
          _buildColorAction(context, 'Orange', CupertinoColors.activeOrange),
          _buildColorAction(context, 'Red', CupertinoColors.systemRed),
          _buildColorAction(context, 'Purple', CupertinoColors.systemPurple),
        ],
        cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'SFPro'))
        ),
      ),
    );
  }

  CupertinoActionSheetAction _buildColorAction(BuildContext context, String name, Color color) {
    return CupertinoActionSheetAction(
      onPressed: () {
        setState(() => activeColor = color);
        _savePreferences();
        Navigator.pop(context);
      },
      child: Text(name, style: TextStyle(color: color, fontFamily: 'SFPro')),
    );
  }

  void _showAutoRefreshPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Auto Refresh Interval', style: TextStyle(fontFamily: 'SFPro')),
        actions: [
          CupertinoActionSheetAction(onPressed: () { Navigator.pop(context); _updateAutoRefresh(0); }, child: const Text('Off', style: TextStyle(fontFamily: 'SFPro'))),
          CupertinoActionSheetAction(onPressed: () { Navigator.pop(context); _updateAutoRefresh(15); }, child: const Text('15 Minutes', style: TextStyle(fontFamily: 'SFPro'))),
          CupertinoActionSheetAction(onPressed: () { Navigator.pop(context); _updateAutoRefresh(30); }, child: const Text('30 Minutes', style: TextStyle(fontFamily: 'SFPro'))),
          CupertinoActionSheetAction(onPressed: () { Navigator.pop(context); _updateAutoRefresh(60); }, child: const Text('1 Hour', style: TextStyle(fontFamily: 'SFPro'))),
        ],
        cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'SFPro'))
        ),
      ),
    );
  }

  Widget _buildGridInfoCard(String title, String value, IconData icon) {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.9), size: 22),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7), fontFamily: 'SFPro')),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'SFPro')),
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
      theme: CupertinoThemeData(
          brightness: isDarkMode ? Brightness.dark : Brightness.light,
          primaryColor: activeColor,
          textTheme: CupertinoTextThemeData(
            textStyle: TextStyle(
              fontFamily: 'SFPro',
              color: isDarkMode ? CupertinoColors.white : CupertinoColors.black,
            ),
          )
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
              // Splash Icon
              const Icon(CupertinoIcons.cloud_sun_fill, size: 80, color: CupertinoColors.white),
              const SizedBox(height: 20),
              const Text("Climora", style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.white,
                  letterSpacing: 2.0,
                  fontFamily: 'SFPro',
                  decoration: TextDecoration.none
              )),
              const SizedBox(height: 60),
              const CupertinoActivityIndicator(radius: 12, color: CupertinoColors.white),
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
        activeColor: activeColor,
        border: Border(top: BorderSide(color: isDarkMode ? Colors.white12 : Colors.black12, width: 0.5)),
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E).withOpacity(0.9) : const Color(0xFFF9F9F9).withOpacity(0.9),
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.house_alt), activeIcon: Icon(CupertinoIcons.house_alt_fill), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.settings), activeIcon: Icon(CupertinoIcons.settings_solid), label: 'Settings'),
        ],
      ),
      tabBuilder: (context, index) {
        if (index == 0) {
          return _buildWeatherHome();
        } else {
          return _buildSettingsPage(context);
        }
      },
    );
  }

  Widget _buildWeatherHome() {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black, // Fallback color
      child: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: Image.asset(
                _getBackgroundImage(_weather?.iconCode),
                key: ValueKey(_weather?.iconCode),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: () async { await getWeatherData(targetCity: city); },
                  builder: (context, refreshState, pulledExtent, refreshTriggerPullDistance, refreshIndicatorExtent) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Center(child: CupertinoActivityIndicator(color: Colors.white.withOpacity(0.7))),
                    );
                  },
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // --- HEADER ---
                        const SizedBox(height: 10),
                        Text(
                          "Climora",
                          style: TextStyle(
                            fontFamily: 'SFPro',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: Colors.white.withOpacity(0.9),
                            shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                        ),

                        // --- CITY NAME ---
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () {
                             // Shortcut to search if needed
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.location_solid, color: activeColor, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                  city,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 28,
                                      color: Colors.white,
                                      fontFamily: 'SFPro',
                                      shadows: [Shadow(blurRadius: 10, color: Colors.black45, offset: Offset(2, 2))]
                                  )
                              ),
                            ],
                          ),
                        ),
                        Text(
                            isFetching ? "Updating..." : "Updated $lastFetchTime",
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6), fontFamily: 'SFPro')
                        ),

                        // --- MAIN TEMP & ICON (NOW USING PNG) ---
                        const Spacer(),
                        _weather == null
                            ? Icon(CupertinoIcons.cloud, size: 100, color: Colors.white.withOpacity(0.5))
                            : Column(
                          children: [
                            // MODERN IMAGE
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.15),
                                    blurRadius: 30,
                                    spreadRadius: -10,
                                  )
                                ],
                              ),
                              child: Image.asset(
                                _getWeatherImagePath(_weather!.iconCode),
                                width: 180,
                                height: 180,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                                weatherCondition,
                                style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 22,
                                    color: Colors.white.withOpacity(0.9),
                                    fontFamily: 'SFPro',
                                    letterSpacing: 0.5
                                )
                            ),
                            Text(
                                "${_weather!.getTempString(isCelsius)}°",
                                style: const TextStyle(
                                  fontSize: 100,
                                  fontWeight: FontWeight.w200,
                                  color: Colors.white,
                                  letterSpacing: -4,
                                  fontFamily: 'SFPro',
                                  height: 1.0,
                                )
                            ),
                          ],
                        ),
                        const Spacer(),

                        // --- GLASS DETAILS GRID ---
                        Container(
                          margin: const EdgeInsets.only(bottom: 30),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      )
                                    ]
                                ),
                                child: Column(
                                  children: [
                                    // Row 1
                                    Row(
                                      children: [
                                        Expanded(child: _buildGridInfoCard("Feels Like", _weather == null ? "--" : "${_weather!.getFeelsLikeString(isCelsius)}°", CupertinoIcons.thermometer)),
                                        const SizedBox(width: 12),
                                        Expanded(child: _buildGridInfoCard("Humidity", _weather == null ? "--" : "${_weather!.humidity.toStringAsFixed(0)}%", CupertinoIcons.drop)),
                                        const SizedBox(width: 12),
                                        Expanded(child: _buildGridInfoCard("Rain", _weather == null ? "--" : "${_weather!.chanceOfRain.toStringAsFixed(0)}%", CupertinoIcons.cloud_rain)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Row 2
                                    Row(
                                      children: [
                                        Expanded(child: _buildGridInfoCard("Wind", _weather == null ? "--" : _weather!.getWindString(isKmh), CupertinoIcons.wind)),
                                        const SizedBox(width: 12),
                                        Expanded(child: _buildGridInfoCard("Pressure", _weather == null ? "--" : _weather!.getPressureString(isMmHg), CupertinoIcons.gauge)),
                                        const SizedBox(width: 12),
                                        Expanded(child: _buildGridInfoCard("Visibility", _weather == null ? "--" : _weather!.getVisibilityString(isCelsius), CupertinoIcons.eye)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPage(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text("Settings", style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        border: null,
      ),
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 10),
            CupertinoListSection.insetGrouped(
              header: const Text('APPEARANCE'),
              children: [
                CupertinoListTile(leading: Container(padding:const EdgeInsets.all(4), decoration: BoxDecoration(color: CupertinoColors.systemGrey, borderRadius: BorderRadius.circular(6)), child: const Icon(CupertinoIcons.moon_fill, color: Colors.white, size: 18)), title: const Text('Dark Mode'), trailing: CupertinoSwitch(value: isDarkMode, activeColor: activeColor, onChanged: (value) { setState(() => isDarkMode = value); _savePreferences(); })),
                CupertinoListTile(
                    leading: Container(padding:const EdgeInsets.all(4), decoration: BoxDecoration(color: activeColor, borderRadius: BorderRadius.circular(6)), child: const Icon(CupertinoIcons.paintbrush_fill, color: Colors.white, size: 18)),
                    title: const Text('Theme Color'),
                    trailing: const Icon(CupertinoIcons.chevron_right, color: CupertinoColors.systemGrey3, size: 16),
                    onTap: () => _showColorPicker(context)
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('UNITS & PREFERENCES'),
              children: [
                CupertinoListTile(leading: const Icon(CupertinoIcons.thermometer, color: CupertinoColors.systemGrey), title: const Text('Temperature'), trailing: CupertinoSlidingSegmentedControl<bool>(thumbColor: activeColor, groupValue: isCelsius, children: {true: Text('°C', style: TextStyle(color: isCelsius ? CupertinoColors.white : CupertinoColors.black)), false: Text('°F', style: TextStyle(color: !isCelsius ? CupertinoColors.white : CupertinoColors.black))}, onValueChanged: (value) { if (value != null) { setState(() { isCelsius = value; }); _savePreferences(); } })),
                CupertinoListTile(leading: const Icon(CupertinoIcons.wind, color: CupertinoColors.systemGrey), title: const Text('Wind Speed'), trailing: CupertinoSlidingSegmentedControl<bool>(thumbColor: activeColor, groupValue: isKmh, children: {false: Text('m/s', style: TextStyle(fontSize: 13, color: !isKmh ? CupertinoColors.white : CupertinoColors.black)), true: Text('km/h', style: TextStyle(fontSize: 13, color: isKmh ? CupertinoColors.white : CupertinoColors.black))}, onValueChanged: (value) { if (value != null) { setState(() { isKmh = value; }); _savePreferences(); } })),
                CupertinoListTile(leading: const Icon(CupertinoIcons.gauge, color: CupertinoColors.systemGrey), title: const Text('Pressure'), trailing: CupertinoSlidingSegmentedControl<bool>(thumbColor: activeColor, groupValue: isMmHg, children: {false: Text('hPa', style: TextStyle(fontSize: 13, color: !isMmHg ? CupertinoColors.white : CupertinoColors.black)), true: Text('mmHg', style: TextStyle(fontSize: 13, color: isMmHg ? CupertinoColors.white : CupertinoColors.black))}, onValueChanged: (value) { if (value != null) { setState(() { isMmHg = value; }); _savePreferences(); } })),
                CupertinoListTile(
                    leading: const Icon(CupertinoIcons.time, color: CupertinoColors.systemGrey),
                    title: const Text('Auto Refresh'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text(autoRefreshInterval == 0 ? "Off" : "${autoRefreshInterval} min", style: const TextStyle(color: CupertinoColors.systemGrey)), const SizedBox(width: 6), const Icon(CupertinoIcons.chevron_right, color: CupertinoColors.systemGrey3, size: 16)]),
                    onTap: () => _showAutoRefreshPicker(context)
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('LOCATION'),
              children: [
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.location_solid, color: CupertinoColors.systemGrey),
                  title: const Text('Current City'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text(city, style: TextStyle(color: activeColor, fontWeight: FontWeight.w500)), const SizedBox(width: 6), const Icon(CupertinoIcons.chevron_right, color: CupertinoColors.systemGrey3, size: 16)]),
                  onTap: () {
                    Navigator.of(context).push(CupertinoPageRoute(builder: (context) => CitySearchPage(
                        recentSearches: recentSearches,
                        popularCities: popularCities,
                        onCitySelected: (selectedCity) async {
                          await getWeatherData(targetCity: selectedCity, saveToHistory: true);
                        }
                    )));
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(child: Text("Climora v1.0.0", style: TextStyle(color: CupertinoColors.systemGrey.withOpacity(0.5), fontSize: 12))),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}