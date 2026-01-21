import 'package:flutter/cupertino.dart';

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
          color: CupertinoColors.transparent,
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