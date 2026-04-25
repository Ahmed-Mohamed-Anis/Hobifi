import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:hobby_haven/theme.dart';

typedef LocationResult = ({double latitude, double longitude, String displayAddress});

class LocationPickerWidget extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerWidget({super.key, this.initialLocation});

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  late final MapController _mapController;
  late LatLng _center;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<_NominatimResult> _searchResults = [];
  bool _isSearching = false;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _center = widget.initialLocation ?? const LatLng(30.0444, 31.2357); // Cairo default
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(query.trim()));
  }

  Future<void> _search(String query) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&countrycodes=eg',
      );
      final response = await http.get(uri, headers: {'User-Agent': 'com.hobifi.app'});
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _searchResults = data.map((e) => _NominatimResult.fromJson(e as Map<String, dynamic>)).toList();
          _isSearching = false;
        });
      } else {
        setState(() => _isSearching = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectResult(_NominatimResult result) {
    final latLng = LatLng(result.lat, result.lng);
    _mapController.move(latLng, 15);
    setState(() {
      _center = latLng;
      _searchResults = [];
      _searchController.text = result.displayName;
    });
  }

  Future<void> _confirm() async {
    setState(() => _isConfirming = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${_center.latitude}&lon=${_center.longitude}&format=json',
      );
      final response = await http.get(uri, headers: {'User-Agent': 'com.hobifi.app'});
      String address;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        address = data['display_name'] as String? ?? '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}';
      } else {
        address = '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}';
      }
      if (!mounted) return;
      Navigator.of(context).pop<LocationResult>((
        latitude: _center.latitude,
        longitude: _center.longitude,
        displayAddress: address,
      ));
    } catch (_) {
      if (mounted) {
        setState(() => _isConfirming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get address. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Location'),
        actions: [
          TextButton(
            onPressed: _isConfirming ? null : _confirm,
            child: _isConfirming
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search address...',
                prefixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults = []);
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerLowest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Search results dropdown
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: colorScheme.outlineVariant),
                itemBuilder: (context, i) {
                  final result = _searchResults[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.location_on_rounded, color: colorScheme.primary, size: 18),
                    title: Text(result.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => _selectResult(result),
                  );
                },
              ),
            ),

          const SizedBox(height: 8),

          // Map with crosshair pin
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 14,
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture) {
                        setState(() => _center = camera.center);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.hobifi.app',
                    ),
                  ],
                ),
                // Fixed crosshair pin
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_pin, color: AppColors.orange, size: 48),
                      const SizedBox(height: 24), // offset so pin tip is at center
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NominatimResult {
  final double lat;
  final double lng;
  final String displayName;

  const _NominatimResult({required this.lat, required this.lng, required this.displayName});

  factory _NominatimResult.fromJson(Map<String, dynamic> json) => _NominatimResult(
    lat: double.parse(json['lat'] as String),
    lng: double.parse(json['lon'] as String),
    displayName: json['display_name'] as String,
  );
}
