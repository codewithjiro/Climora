import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'variables.dart'; // Ensure your apiKey is here

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

  // --- SPLASH STATE ---
  bool _showSplash = true;

  // --- PREFERENCES ---
  bool isDarkMode = false;
  bool isCelsius = true;
  Color activeColor = CupertinoColors.activeBlue;
  int autoRefreshInterval = 0;

  // NEW PREFERENCES
  bool isKmh = false; // false = m/s, true = km/h
  bool isMmHg = false; // false = hPa, true = mmHg

  // --- SEARCH DATA ---
  List<String> recentSearches = [];
  final List<String> popularCities = [
    // Pampanga
    "Angeles City", "City of San Fernando", "Mabalacat City", "Bacolor",
    "Guagua", "Lubao", "Porac", "Magalang", "Mexico", "Arayat",
    "Apalit", "Candaba", "Santa Ana", "San Simon",
    // Major PH Cities
    "Manila", "Quezon City", "Makati", "Taguig", "Pasig",
    "Cebu City", "Davao City", "Baguio City", "Iloilo City",
    "Bacolod City", "Cagayan de Oro", "Zamboanga City",
    "General Santos City", "Puerto Princesa City", "Vigan City",
    "Tagaytay City", "Dumaguete City",
  ];

  // --- WEATHER DATA ---
  String city = "Arayat";
  String weatherCondition = "Loading...";
  String temperature = "0";
  String iconCode = "10d";

  String feelsLike = "0";
  String humidity = "0";
  String windSpeed = "0";
  String windUnitLabel = "m/s";
  String pressure = "0";
  String pressureUnitLabel = "hPa";
  String visibility = "0";
  String chanceOfRain = "0";

  // STATUS VARIABLES
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
    await getWeatherData();
    await minSplashTime;

    setState(() {
      _showSplash = false;
    });
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
        getWeatherData();
      });
    }
  }

  Future<void> getWeatherData() async {
    if (city.trim().isEmpty) return;
    if (weatherCondition == "Loading...") setState(() => isLoading = true);
    setState(() => isFetching = true);

    try {
      String unitType = isCelsius ? "metric" : "imperial";
      String cleanCity = Uri.encodeComponent(city.trim());
      final uri = "https://api.openweathermap.org/data/2.5/forecast?q=$cleanCity&units=$unitType&appid=$apiKey";
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        var weatherData = jsonDecode(response.body);
        DateTime now = DateTime.now();
        String period = now.hour >= 12 ? "PM" : "AM";
        int hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
        String minute = now.minute.toString().padLeft(2, '0');
        String newTime = "$hour:$minute $period";

        setState(() {
          var currentItem = weatherData["list"][0];
          var main = currentItem["main"];
          var weather = currentItem["weather"][0];
          var wind = currentItem["wind"];

          weatherCondition = weather["main"];
          iconCode = weather["icon"];
          temperature = main["temp"].toStringAsFixed(0);
          feelsLike = main["feels_like"].toStringAsFixed(0);
          humidity = main["humidity"].toString();
          double pop = (currentItem["pop"] ?? 0).toDouble();
          chanceOfRain = (pop * 100).toStringAsFixed(0);

          double rawPressure = (main["pressure"] ?? 0).toDouble();
          if (isMmHg) {
            pressure = (rawPressure * 0.750062).toStringAsFixed(0);
            pressureUnitLabel = "mmHg";
          } else {
            pressure = rawPressure.toStringAsFixed(0);
            pressureUnitLabel = "hPa";
          }

          double rawWind = (wind["speed"] ?? 0).toDouble();
          double windInMs = isCelsius ? rawWind : (rawWind * 0.44704);
          if (isKmh) {
            windSpeed = (windInMs * 3.6).toStringAsFixed(1);
            windUnitLabel = "km/h";
          } else {
            windSpeed = windInMs.toStringAsFixed(1);
            windUnitLabel = "m/s";
          }

          double visMeters = (currentItem["visibility"] ?? 0).toDouble();
          if (isCelsius) {
            visibility = (visMeters / 1000).toStringAsFixed(1) + " km";
          } else {
            visibility = (visMeters / 1609.34).toStringAsFixed(1) + " mi";
          }

          lastFetchTime = newTime;
          isLoading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          weatherCondition = "Not Found";
          isLoading = false;
          _resetValues();
        });
        if (!_showSplash) _showErrorDialog("City Not Found", "We couldn't find '$city'.");
      } else {
        setState(() {
          weatherCondition = "Server Error";
          isLoading = false;
          _resetValues();
        });
      }
    } catch (e) {
      print("Error fetching data: $e");
      setState(() {
        weatherCondition = "No Internet";
        isLoading = false;
        _resetValues();
      });
    } finally {
      setState(() => isFetching = false);
    }
  }

  void _resetValues() {
    temperature = "--";
    feelsLike = "--";
    humidity = "0";
    windSpeed = "0";
    pressure = "0";
    visibility = "0";
    chanceOfRain = "0";
    iconCode = "10d";
    lastFetchTime = "--";
  }

  void _showErrorDialog(String title, String message) {
    if (navigatorKey.currentContext == null) return;
    showCupertinoDialog(
      context: navigatorKey.currentContext!,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [CupertinoDialogAction(child: const Text("OK"), onPressed: () => Navigator.pop(context))],
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Choose App Theme'),
        actions: [
          _buildColorAction(context, 'Blue', CupertinoColors.activeBlue),
          _buildColorAction(context, 'Green', CupertinoColors.activeGreen),
          _buildColorAction(context, 'Orange', CupertinoColors.activeOrange),
          _buildColorAction(context, 'Red', CupertinoColors.systemRed),
          _buildColorAction(context, 'Purple', CupertinoColors.systemPurple),
          _buildColorAction(context, 'Teal', CupertinoColors.systemTeal),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
          Icon(icon, color: activeColor, size: 24),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 12, color: isDarkMode ? CupertinoColors.systemGrey2 : CupertinoColors.systemGrey)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDarkMode ? CupertinoColors.white : CupertinoColors.black)),
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
      theme: CupertinoThemeData(brightness: isDarkMode ? Brightness.dark : Brightness.light, primaryColor: activeColor),
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
              const SizedBox(height: 10),
              const Text("Weather Simplified", style: TextStyle(fontSize: 16, color: CupertinoColors.systemGrey5, decoration: TextDecoration.none)),
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
        activeColor: activeColor,
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.house), activeIcon: Icon(CupertinoIcons.house_fill), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.gear), activeIcon: Icon(CupertinoIcons.gear_solid), label: 'Settings'),
        ],
      ),
      tabBuilder: (context, index) {
        if (index == 0) {
          return CupertinoPageScaffold(
            navigationBar: const CupertinoNavigationBar(middle: Text("Climora"), backgroundColor: CupertinoColors.transparent, border: null),
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: () async { await getWeatherData(); }),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      children: [
                        const Spacer(),
                        Text(city, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 32, color: activeColor)),
                        const SizedBox(height: 5),
                        Text(weatherCondition, style: TextStyle(fontWeight: FontWeight.w300, fontSize: 18, color: activeColor)),
                        const SizedBox(height: 8),
                        Text(isFetching ? "Fetching..." : "Last Updated: $lastFetchTime", style: TextStyle(fontSize: 12, color: isDarkMode ? CupertinoColors.systemGrey : CupertinoColors.systemGrey)),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: 150, height: 150,
                          child: Image.network("https://openweathermap.org/img/wn/$iconCode@4x.png", fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => Icon(CupertinoIcons.cloud, size: 100, color: activeColor)),
                        ),
                        Text('$temperature°', style: TextStyle(fontSize: 70, fontWeight: FontWeight.bold, color: activeColor)),
                        const Spacer(),
                        Container(
                          margin: const EdgeInsets.all(20), padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 10),
                          decoration: BoxDecoration(color: isDarkMode ? CupertinoColors.systemGrey6.darkColor : CupertinoColors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: CupertinoColors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
                          child: Column(
                            children: [
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildInfoCard("Feels Like", "$feelsLike°", CupertinoIcons.thermometer), _buildInfoCard("Humidity", "$humidity%", CupertinoIcons.drop), _buildInfoCard("Chance Rain", "$chanceOfRain%", CupertinoIcons.cloud_rain)]),
                              const SizedBox(height: 25),
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildInfoCard("Wind", "$windSpeed $windUnitLabel", CupertinoIcons.wind), _buildInfoCard("Pressure", "$pressure $pressureUnitLabel", CupertinoIcons.gauge), _buildInfoCard("Visibility", visibility, CupertinoIcons.eye)]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
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
                      CupertinoListTile(leading: Icon(CupertinoIcons.thermometer, color: activeColor), title: const Text('Temperature Unit'), trailing: CupertinoSlidingSegmentedControl<bool>(thumbColor: activeColor, groupValue: isCelsius, children: {true: Text('°C', style: TextStyle(color: isCelsius ? CupertinoColors.white : CupertinoColors.black)), false: Text('°F', style: TextStyle(color: !isCelsius ? CupertinoColors.white : CupertinoColors.black))}, onValueChanged: (value) { if (value != null) { setState(() { isCelsius = value; }); _savePreferences(); getWeatherData(); } })),
                      CupertinoListTile(leading: Icon(CupertinoIcons.wind, color: activeColor), title: const Text('Wind Unit'), trailing: CupertinoSlidingSegmentedControl<bool>(thumbColor: activeColor, groupValue: isKmh, children: {false: Text('m/s', style: TextStyle(fontSize: 14, color: !isKmh ? CupertinoColors.white : CupertinoColors.black)), true: Text('km/h', style: TextStyle(fontSize: 14, color: isKmh ? CupertinoColors.white : CupertinoColors.black))}, onValueChanged: (value) { if (value != null) { setState(() { isKmh = value; }); _savePreferences(); getWeatherData(); } })),
                      CupertinoListTile(leading: Icon(CupertinoIcons.gauge, color: activeColor), title: const Text('Pressure Unit'), trailing: CupertinoSlidingSegmentedControl<bool>(thumbColor: activeColor, groupValue: isMmHg, children: {false: Text('hPa', style: TextStyle(fontSize: 14, color: !isMmHg ? CupertinoColors.white : CupertinoColors.black)), true: Text('mmHg', style: TextStyle(fontSize: 14, color: isMmHg ? CupertinoColors.white : CupertinoColors.black))}, onValueChanged: (value) { if (value != null) { setState(() { isMmHg = value; }); _savePreferences(); getWeatherData(); } })),
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
                          Navigator.of(context).push(CupertinoPageRoute(builder: (context) => CitySearchPage(recentSearches: recentSearches, popularCities: popularCities, onCitySelected: (selectedCity) async { setState(() { city = selectedCity; }); _savePreferences(); await _addToRecentSearches(selectedCity); getWeatherData(); })));
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

// --- UPDATED CITY SEARCH PAGE (BEGINNER FRIENDLY) ---
class CitySearchPage extends StatefulWidget {
  final List<String> recentSearches;
  final List<String> popularCities;
  final Function(String) onCitySelected;

  const CitySearchPage({
    super.key,
    required this.recentSearches,
    required this.popularCities,
    required this.onCitySelected,
  });

  @override
  State<CitySearchPage> createState() => _CitySearchPageState();
}

class _CitySearchPageState extends State<CitySearchPage> {
  final TextEditingController _textController = TextEditingController();
  String _searchText = "";

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() {
        _searchText = _textController.text;
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text("Select City"),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: CupertinoSearchTextField(
                controller: _textController,
                placeholder: "Search or enter city...",
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    widget.onCitySelected(value.trim());
                    Navigator.pop(context);
                  }
                },
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  // --- 1. NEW "ADD" BUTTON (Appears when typing) ---
                  if (_searchText.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        widget.onCitySelected(_searchText);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: CupertinoColors.systemGrey5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.add_circled_solid, color: CupertinoColors.activeGreen, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Add \"$_searchText\"",
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: CupertinoColors.activeBlue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // --- 2. RECENT SEARCHES ---
                  if (widget.recentSearches.isNotEmpty && _searchText.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text("Recent Searches",
                        style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 14, fontWeight: FontWeight.bold)
                      ),
                    ),
                    for (String city in widget.recentSearches)
                      _buildCityTile(city, isRecent: true),
                  ],

                  // --- 3. POPULAR CITIES / FILTERED LIST ---
                  if (_searchText.isEmpty || widget.popularCities.any((c) => c.toLowerCase().contains(_searchText.toLowerCase())))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                        _searchText.isEmpty ? "Popular Cities" : "Results",
                        style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 14, fontWeight: FontWeight.bold)
                      ),
                    ),

                  for (String city in widget.popularCities)
                    if (_searchText.isEmpty || city.toLowerCase().contains(_searchText.toLowerCase()))
                      _buildCityTile(city),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCityTile(String city, {bool isRecent = false}) {
    return GestureDetector(
      onTap: () {
        widget.onCitySelected(city);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: CupertinoColors.systemGrey5)),
          color: CupertinoColors.transparent, // Required for tap detection
        ),
        child: Row(
          children: [
            Icon(
              isRecent ? CupertinoIcons.time : CupertinoIcons.location_solid,
              color: isRecent ? CupertinoColors.systemGrey : CupertinoColors.activeBlue,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(city, style: const TextStyle(fontSize: 16)),
            const Spacer(),
            const Icon(CupertinoIcons.chevron_right, size: 14, color: CupertinoColors.systemGrey3),
          ],
        ),
      ),
    );
  }
}