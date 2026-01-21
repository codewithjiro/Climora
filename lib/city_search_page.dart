import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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

  void _submitCity(String city) {
    if (city.trim().isNotEmpty) {
      Navigator.pop(context);
      widget.onCitySelected(city.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = CupertinoTheme.of(context).brightness == Brightness.dark;
    final Color containerColor = isDarkMode ? const Color(0xFF1C1C1E) : CupertinoColors.white;
    final Color textColor = isDarkMode ? CupertinoColors.white : CupertinoColors.black;
    final Color searchBarColor = isDarkMode ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey5;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text("Select Location", style: TextStyle(fontFamily: 'SFPro')),
        backgroundColor: CupertinoColors.systemGroupedBackground,
        border: null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Hero(
                tag: 'searchBar',
                child: CupertinoSearchTextField(
                  controller: _textController,
                  placeholder: "Search city (e.g. Manila)",
                  backgroundColor: searchBarColor,
                  style: TextStyle(color: textColor, fontFamily: 'SFPro'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  borderRadius: BorderRadius.circular(12),
                  onSubmitted: _submitCity,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  if (_searchText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: containerColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CupertinoListTile(
                          onTap: () => _submitCity(_searchText),
                          leading: const Icon(CupertinoIcons.add_circled_solid, color: CupertinoColors.activeGreen),
                          title: Text("Search \"$_searchText\"", style: TextStyle(fontWeight: FontWeight.w500, color: textColor, fontFamily: 'SFPro')),
                          trailing: const Icon(CupertinoIcons.arrow_right, color: CupertinoColors.systemGrey3, size: 16),
                        ),
                      ),
                    ),

                  if (widget.recentSearches.isNotEmpty && _searchText.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text("RECENTLY SEARCHED",
                          style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, fontFamily: 'SFPro')
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: containerColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < widget.recentSearches.length; i++) ...[
                            _buildCityTile(widget.recentSearches[i], textColor, isRecent: true, isLast: i == widget.recentSearches.length - 1),
                          ]
                        ],
                      ),
                    ),
                  ],

                  if (_searchText.isEmpty || widget.popularCities.any((c) => c.toLowerCase().contains(_searchText.toLowerCase()))) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Text(
                          _searchText.isEmpty ? "POPULAR CITIES" : "RESULTS",
                          style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, fontFamily: 'SFPro')
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: containerColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ...widget.popularCities
                              .where((city) => _searchText.isEmpty || city.toLowerCase().contains(_searchText.toLowerCase()))
                              .toList()
                              .asMap()
                              .entries
                              .map((entry) => _buildCityTile(entry.value, textColor, isLast: entry.key == widget.popularCities.length - 1))
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCityTile(String city, Color textColor, {bool isRecent = false, bool isLast = false}) {
    return Column(
      children: [
        CupertinoListTile(
          onTap: () => _submitCity(city),
          leading: Icon(
            isRecent ? CupertinoIcons.clock : CupertinoIcons.location_solid,
            color: isRecent ? CupertinoColors.systemGrey : CupertinoColors.activeBlue,
            size: 20,
          ),
          title: Text(city, style: TextStyle(fontSize: 16, color: textColor, fontFamily: 'SFPro')),
          trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: CupertinoColors.systemGrey3),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 50, endIndent: 0, color: CupertinoColors.systemGrey5),
      ],
    );
  }
}