import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

// --- CONFIGURATION ---
const String supabaseUrl = 'https://lmuvkqsohmodrxveuxdr.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxtdXZrcXNvaG1vZHJ4dmV1eGRyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY4NjY5NzQsImV4cCI6MjEwMjQ0Mjk3NH0.Goel2mRQgBs2hUIjG5sVUZDpO1f8XJ_su2WX0a9u1vE';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const AthawadeBazaarApp());
}

final supabase = Supabase.instance.client;

class AthawadeBazaarApp extends StatelessWidget {
  const AthawadeBazaarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bhaaji Market',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          primary: const Color(0xFF2E7D32),
        ),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  RealtimeChannel? _proximityChannel;

  double _currentLat = 18.5204;
  double _currentLng = 73.8567;

  final List<Widget> _screens = const [
    TodayBazaarsScreen(),
    BazaarMapScreen(),
    ExploreBazaarsScreen(),
    AddBazaarScreen(),
    VeggieQuizScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _listenForNearbyNewBazaars();
  }

  @override
  void dispose() {
    _proximityChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
      );
      _currentLat = pos.latitude;
      _currentLng = pos.longitude;
    } catch (_) {}
  }

  void _listenForNearbyNewBazaars() {
    _proximityChannel = supabase
        .channel('public:proximity_alert')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bazaars',
          callback: (payload) {
            final newRecord = payload.newRecord;
            final double? bLat = (newRecord['latitude'] as num?)?.toDouble();
            final double? bLng = (newRecord['longitude'] as num?)?.toDouble();
            final String bName = newRecord['name'] ?? 'New Athawade Bazaar';
            final String bLocality = newRecord['locality'] ?? 'Nearby Area';

            if (bLat != null && bLng != null) {
              final double distanceInMeters = Geolocator.distanceBetween(
                _currentLat,
                _currentLng,
                bLat,
                bLng,
              );
              final double distanceInKm = distanceInMeters / 1000.0;

              if (distanceInKm <= 50.0 && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 6),
                    backgroundColor: const Color(0xFF2E7D32),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    content: Row(
                      children: [
                        const Icon(Icons.add_location_alt, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "🚨 New Bazaar Nearby: $bName",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              Text(
                                "📍 $bLocality (${distanceInKm.toStringAsFixed(1)} km away)",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    action: SnackBarAction(
                      label: "VIEW",
                      textColor: Colors.amberAccent,
                      onPressed: () {
                        setState(() => _currentIndex = 0);
                      },
                    ),
                  ),
                );
              }
            }
          },
        )
        .subscribe();
  }

  void _shareApp() async {
    const String shareText =
        '🥬 *Bhaaji Market - Shetkari Athawade Bazaar*\n\n'
        'Find weekly farmers markets near you with live schedules, timings, and GPS navigation!\n\n'
        '📲 Download here:\n'
        'https://github.com/aero2mech/aathawade_bazaar/releases/latest';

    final Uri sendUri = Uri.parse(
        'https://api.whatsapp.com/send?text=${Uri.encodeComponent(shareText)}');

    try {
      await launchUrl(sendUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      final Uri smsUri =
          Uri.parse('sms:?body=${Uri.encodeComponent(shareText)}');
      await launchUrl(smsUri, mode: LaunchMode.externalApplication);
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text("Bhaaji Market Guide"),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("📍 **Today**: View markets active today with distance calculation[cite: 3].", style: TextStyle(fontSize: 13)),
              SizedBox(height: 8),
              Text("🗺️ **Live Map**: Green pins are open today; orange pins are other days[cite: 3]. Tap any pin to navigate, check live stock, edit, or leave reviews!", style: TextStyle(fontSize: 13)),
              SizedBox(height: 8),
              Text("⚡ **Live Veggie Signals**: Check live stock & quality reported by shoppers/farmers that automatically expire after the market closes!", style: TextStyle(fontSize: 13)),
              SizedBox(height: 8),
              Text("📅 **Explorer**: Browse farmers markets by specific days of the week[cite: 3].", style: TextStyle(fontSize: 13)),
              SizedBox(height: 8),
              Text("➕ **Add Spot**: Pinpoint new markets on the expandable map and publish them live[cite: 3].", style: TextStyle(fontSize: 13)),
              SizedBox(height: 8),
              Text("🎮 **Veggie Quiz**: Test your vegetable knowledge!", style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Got it!"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bhaaji Market'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'App Guide & Help',
            onPressed: _showHelpDialog,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share App',
            onPressed: _shareApp,
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 65,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: "Today",
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: "Live Map",
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: "Explorer",
            ),
            NavigationDestination(
              icon: Icon(Icons.add_location_alt_outlined),
              selectedIcon: Icon(Icons.add_location_alt),
              label: "Add Spot",
            ),
            NavigationDestination(
              icon: Icon(Icons.psychology_outlined),
              selectedIcon: Icon(Icons.psychology),
              label: "Veggie Quiz",
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 1. TODAY'S ACTIVE MARKETS
// ==========================================
class TodayBazaarsScreen extends StatefulWidget {
  const TodayBazaarsScreen({super.key});

  @override
  State<TodayBazaarsScreen> createState() => _TodayBazaarsScreenState();
}

class _TodayBazaarsScreenState extends State<TodayBazaarsScreen> {
  bool _isLoading = true;
  String? _statusNote;
  List<Map<String, dynamic>> _bazaars = [];
  RealtimeChannel? _realtimeChannel;

  double _userLat = 18.5204;
  double _userLng = 73.8567;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToRealtime() {
    _realtimeChannel = supabase
        .channel('public:bazaars_today')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bazaars',
          callback: (payload) => _loadData(),
        )
        .subscribe();
  }

  Future<void> _loadData() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );

      if (serviceEnabled) {
        LocationPermission perm = await Geolocator.checkPermission().timeout(
          const Duration(seconds: 1),
          onTimeout: () => LocationPermission.denied,
        );

        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission().timeout(
            const Duration(seconds: 2),
            onTimeout: () => LocationPermission.denied,
          );
        }

        if (perm == LocationPermission.whileInUse ||
            perm == LocationPermission.always) {
          Position pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 4),
          );
          _userLat = pos.latitude;
          _userLng = pos.longitude;
        }
      }
    } catch (_) {}

    final int todayWeekday = DateTime.now().weekday % 7;

    try {
      final response = await supabase.rpc('get_nearby_bazaars', params: {
        'user_lat': _userLat,
        'user_lng': _userLng,
        'target_day': todayWeekday,
        'radius_meters': 50000,
      });

      if (mounted) {
        setState(() {
          _bazaars = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusNote = "Query notice: $e";
          _isLoading = false;
        });
      }
    }
  }

  void _openMap(double lat, double lng) async {
    final uri =
        Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String dayName = DateFormat('EEEE').format(DateTime.now());

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_statusNote != null)
                  Container(
                    width: double.infinity,
                    color: Colors.amber.shade100,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      _statusNote!,
                      style:
                          TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                Expanded(
                  child: _bazaars.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.storefront,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                "No active bazaars scheduled today ($dayName).",
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              const Text("Check 'Live Map' or 'Explorer'[cite: 3]."),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _bazaars.length,
                          itemBuilder: (context, index) {
                            final item = _bazaars[index];
                            final double distanceKm =
                                (item['distance_meters'] as num) / 1000;

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item['name'] ?? 'Bhaaji Market',
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Chip(
                                          avatar: const Icon(
                                              Icons.directions_walk,
                                              size: 16),
                                          label: Text(
                                              "${distanceKm.toStringAsFixed(1)} km"),
                                          backgroundColor: Colors.green.shade50,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "📍 ${item['locality']}${item['landmark'] != null && item['landmark'].toString().isNotEmpty ? ' - ${item['landmark']}' : ''}",
                                      style: TextStyle(
                                          color: Colors.grey.shade700),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time,
                                            size: 16, color: Colors.orange),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Timings: ${item['start_time']} to ${item['end_time']}",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green.shade700,
                                          foregroundColor: Colors.white,
                                        ),
                                        icon: const Icon(Icons.navigation),
                                        label: const Text("Navigate to Bazaar"),
                                        onPressed: () => _openMap(
                                          (item['latitude'] as num).toDouble(),
                                          (item['longitude'] as num).toDouble(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ==========================================
// 2. LIVE MAP
// ==========================================
class BazaarMapScreen extends StatefulWidget {
  const BazaarMapScreen({super.key});

  @override
  State<BazaarMapScreen> createState() => _BazaarMapScreenState();
}

class _BazaarMapScreenState extends State<BazaarMapScreen> {
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _allBazaars = [];
  bool _isLoading = true;
  double _centerLat = 18.5204;
  double _centerLng = 73.8567;
  RealtimeChannel? _mapRealtimeChannel;

  @override
  void initState() {
    super.initState();
    _fetchBazaarsForMap();
    _subscribeMapRealtime();
  }

  @override
  void dispose() {
    _mapRealtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeMapRealtime() {
    _mapRealtimeChannel = supabase
        .channel('public:bazaars_map')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bazaars',
          callback: (payload) => _fetchBazaarsForMap(),
        )
        .subscribe();
  }

  Future<void> _fetchBazaarsForMap() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
      );
      _centerLat = pos.latitude;
      _centerLng = pos.longitude;
    } catch (_) {}

    try {
      final data = await supabase.from('bazaars').select(
          'id, name, locality, landmark, latitude, longitude, bazaar_schedules(id, day_of_week, start_time, end_time)');

      if (mounted) {
        setState(() {
          _allBazaars = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isBazaarToday(Map<String, dynamic> bazaar) {
    final int todayWeekday = DateTime.now().weekday % 7;
    final schedules = bazaar['bazaar_schedules'] as List<dynamic>? ?? [];
    return schedules.any((s) => s['day_of_week'] == todayWeekday);
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final String hour = tod.hour.toString().padLeft(2, '0');
    final String min = tod.minute.toString().padLeft(2, '0');
    return '$hour:$min:00';
  }

  TimeOfDay _parseTimeString(String? timeStr, TimeOfDay fallback) {
    if (timeStr == null || timeStr.isEmpty) return fallback;
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
    return fallback;
  }

  void _editBazaarDialog(Map<String, dynamic> bazaar) {
    final nameController = TextEditingController(text: bazaar['name'] ?? '');
    final localityController = TextEditingController(text: bazaar['locality'] ?? '');
    final landmarkController = TextEditingController(text: bazaar['landmark'] ?? '');
    final schedules = bazaar['bazaar_schedules'] as List<dynamic>? ?? [];

    double updatedLat = (bazaar['latitude'] as num).toDouble();
    double updatedLng = (bazaar['longitude'] as num).toDouble();
    final MapController editMapController = MapController();

    final Set<int> selectedDays = schedules
        .map((s) => (s['day_of_week'] as num).toInt())
        .toSet();
    if (selectedDays.isEmpty) selectedDays.add(DateTime.now().weekday % 7);

    String? initialStartStr = schedules.isNotEmpty ? schedules[0]['start_time'] : null;
    String? initialEndStr = schedules.isNotEmpty ? schedules[0]['end_time'] : null;

    TimeOfDay startTime = _parseTimeString(initialStartStr, const TimeOfDay(hour: 15, minute: 30));
    TimeOfDay endTime = _parseTimeString(initialEndStr, const TimeOfDay(hour: 21, minute: 0));

    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    bool isSavingEdit = false;
    bool isMapExpanded = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Edit Bazaar Spot"),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Bazaar Name",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.storefront),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: localityController,
                    decoration: const InputDecoration(
                      labelText: "Locality / Area",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: landmarkController,
                    decoration: const InputDecoration(
                      labelText: "Landmark",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "⏰ Operating Timings:",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text("Opens: ${startTime.format(context)}"),
                          onPressed: () async {
                            final picked = await showTimePicker(context: context, initialTime: startTime);
                            if (picked != null) {
                              setDialogState(() => startTime = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time_filled, size: 16),
                          label: Text("Closes: ${endTime.format(context)}"),
                          onPressed: () async {
                            final picked = await showTimePicker(context: context, initialTime: endTime);
                            if (picked != null) {
                              setDialogState(() => endTime = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "📅 Select Operating Days[cite: 3]:",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: List.generate(days.length, (idx) {
                      final isSelected = selectedDays.contains(idx);
                      return FilterChip(
                        label: Text(days[idx]),
                        selected: isSelected,
                        selectedColor: const Color(0xFFC8E6C9),
                        checkmarkColor: const Color(0xFF2E7D32),
                        onSelected: (bool selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedDays.add(idx);
                            } else if (selectedDays.length > 1) {
                              selectedDays.remove(idx);
                            }
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "📍 Relocate Pin on Map[cite: 3]:",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      IconButton(
                        tooltip: isMapExpanded ? "Collapse" : "Expand Map",
                        icon: Icon(isMapExpanded ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.green.shade800),
                        onPressed: () => setDialogState(() => isMapExpanded = !isMapExpanded),
                      ),
                    ],
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: isMapExpanded ? 320 : 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: FlutterMap(
                      mapController: editMapController,
                      options: MapOptions(
                        initialCenter: latlong.LatLng(updatedLat, updatedLng),
                        initialZoom: 15.0,
                        onTap: (_, point) {
                          setDialogState(() {
                            updatedLat = point.latitude;
                            updatedLng = point.longitude;
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.aathawade_bazaar',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: latlong.LatLng(updatedLat, updatedLng),
                              width: 36,
                              height: 36,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 36,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSavingEdit ? null : () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              onPressed: isSavingEdit
                  ? null
                  : () async {
                      setDialogState(() => isSavingEdit = true);
                      try {
                        final String bazaarId = bazaar['id'];
                        final String startTimeFormatted = _formatTimeOfDay(startTime);
                        final String endTimeFormatted = _formatTimeOfDay(endTime);

                        await supabase.from('bazaars').update({
                          'name': nameController.text.trim(),
                          'locality': localityController.text.trim(),
                          'landmark': landmarkController.text.trim(),
                          'latitude': updatedLat,
                          'longitude': updatedLng,
                        }).eq('id', bazaarId);

                        final allDays = [0, 1, 2, 3, 4, 5, 6];
                        final daysToRemove = allDays.where((d) => !selectedDays.contains(d)).toList();

                        if (daysToRemove.isNotEmpty) {
                          await supabase
                              .from('bazaar_schedules')
                              .delete()
                              .eq('bazaar_id', bazaarId)
                              .inFilter('day_of_week', daysToRemove);
                        }

                        final upsertList = selectedDays.map((day) => {
                          'bazaar_id': bazaarId,
                          'day_of_week': day,
                          'start_time': startTimeFormatted,
                          'end_time': endTimeFormatted,
                        }).toList();

                        await supabase
                            .from('bazaar_schedules')
                            .upsert(upsertList, onConflict: 'bazaar_id,day_of_week');

                        if (ctx.mounted) Navigator.pop(ctx);
                        _fetchBazaarsForMap();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Bazaar spot updated successfully!"),
                              backgroundColor: Color(0xFF2E7D32),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSavingEdit = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Failed to update: $e"), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isSavingEdit
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteBazaar(Map<String, dynamic> bazaar) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Bazaar Spot?"),
        content: Text("Are you sure you want to permanently remove \"${bazaar['name']}\"?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                final bazaarId = bazaar['id'];
                await supabase.from('bazaar_schedules').delete().eq('bazaar_id', bazaarId);
                await supabase.from('bazaars').delete().eq('id', bazaarId);

                if (ctx.mounted) Navigator.pop(ctx);
                _fetchBazaarsForMap();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Bazaar spot removed."), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to delete: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showBazaarBottomSheet(Map<String, dynamic> bazaar) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final schedules = bazaar['bazaar_schedules'] as List<dynamic>? ?? [];
        final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        final bool isToday = _isBazaarToday(bazaar);
        final String bazaarId = bazaar['id'];

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return BazaarDetailsAndReviewsSheet(
              bazaar: bazaar,
              bazaarId: bazaarId,
              isToday: isToday,
              schedules: schedules,
              days: days,
              scrollController: scrollController,
              onEdit: () {
                Navigator.pop(context);
                _editBazaarDialog(bazaar);
              },
              onDelete: () {
                Navigator.pop(context);
                _deleteBazaar(bazaar);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        mini: true,
        tooltip: 'My Location',
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: Colors.blue),
        onPressed: () {
          _mapController.move(latlong.LatLng(_centerLat, _centerLng), 13);
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: latlong.LatLng(_centerLat, _centerLng),
                    initialZoom: 12.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.aathawade_bazaar',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: latlong.LatLng(_centerLat, _centerLng),
                          width: 32,
                          height: 32,
                          child: const Icon(Icons.my_location, color: Colors.blue, size: 26),
                        ),
                        ..._allBazaars.map((bazaar) {
                          final double lat = (bazaar['latitude'] as num).toDouble();
                          final double lng = (bazaar['longitude'] as num).toDouble();
                          final bool isToday = _isBazaarToday(bazaar);

                          return Marker(
                            point: latlong.LatLng(lat, lng),
                            width: 32,
                            height: 32,
                            child: GestureDetector(
                              onTap: () => _showBazaarBottomSheet(bazaar),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isToday ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 3.5,
                                      offset: const Offset(0, 1.5),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isToday ? Icons.storefront : Icons.location_on,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(radius: 5, backgroundColor: Color(0xFF2E7D32)),
                            SizedBox(width: 6),
                            Text("Open Today[cite: 3]", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(radius: 5, backgroundColor: Color(0xFFE65100)),
                            SizedBox(width: 6),
                            Text("Other Days[cite: 3]", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ==========================================
// DETAILS BOTTOM SHEET WITH LIVE VEGGIE SIGNALS
// ==========================================
class BazaarDetailsAndReviewsSheet extends StatefulWidget {
  final Map<String, dynamic> bazaar;
  final String bazaarId;
  final bool isToday;
  final List<dynamic> schedules;
  final List<String> days;
  final ScrollController scrollController;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const BazaarDetailsAndReviewsSheet({
    super.key,
    required this.bazaar,
    required this.bazaarId,
    required this.isToday,
    required this.schedules,
    required this.days,
    required this.scrollController,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<BazaarDetailsAndReviewsSheet> createState() => _BazaarDetailsAndReviewsSheetState();
}

class _BazaarDetailsAndReviewsSheetState extends State<BazaarDetailsAndReviewsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _veggieNameController = TextEditingController();
  final TextEditingController _veggieNoteController = TextEditingController();
  
  String _selectedRole = 'Customer';
  String _selectedQuality = 'Fresh / A Grade';
  int _userRating = 5;
  bool _isSubmittingReview = false;
  bool _isSubmittingSignal = false;
  
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _liveSignals = [];
  bool _isLoading = true;
  RealtimeChannel? _signalsRealtimeChannel;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _subscribeToLiveSignals();
  }

  @override
  void dispose() {
    _signalsRealtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToLiveSignals() {
    _signalsRealtimeChannel = supabase
        .channel('public:live_veggie_signals_${widget.bazaarId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'live_veggie_signals',
          callback: (payload) => _fetchData(),
        )
        .subscribe();
  }

  Future<void> _fetchData() async {
    try {
      final reviewsRes = await supabase
          .from('bazaar_reviews')
          .select('*')
          .eq('bazaar_id', widget.bazaarId)
          .order('created_at', ascending: false);

      // Only fetch active (non-expired) live signals
      final signalsRes = await supabase
          .from('live_veggie_signals')
          .select('*')
          .eq('bazaar_id', widget.bazaarId)
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _reviews = List<Map<String, dynamic>>.from(reviewsRes);
          _liveSignals = List<Map<String, dynamic>>.from(signalsRes);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addReview() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() => _isSubmittingReview = true);
    try {
      await supabase.from('bazaar_reviews').insert({
        'bazaar_id': widget.bazaarId,
        'reviewer_name': _nameController.text.trim().isEmpty ? 'Shopper' : _nameController.text.trim(),
        'user_role': _selectedRole,
        'rating': _userRating,
        'comment': _commentController.text.trim(),
      });
      _commentController.clear();
      _fetchData();
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  Future<void> _addLiveSignal() async {
    if (_veggieNameController.text.trim().isEmpty) return;
    setState(() => _isSubmittingSignal = true);
    try {
      await supabase.from('live_veggie_signals').insert({
        'bazaar_id': widget.bazaarId,
        'reporter_name': _nameController.text.trim().isEmpty ? 'Shopper' : _nameController.text.trim(),
        'veggie_name': _veggieNameController.text.trim(),
        'quality_grade': _selectedQuality,
        'note': _veggieNoteController.text.trim(),
        'expires_at': DateTime.now().add(const Duration(hours: 4)).toIso8601String(),
      });
      _veggieNameController.clear();
      _veggieNoteController.clear();
      _fetchData();
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isSubmittingSignal = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double avgRating = _reviews.isEmpty
        ? 0.0
        : (_reviews.map((r) => r['rating'] as int).reduce((a, b) => a + b) / _reviews.length);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ListView(
        controller: widget.scrollController,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.bazaar['name'] ?? 'Bhaaji Market',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isToday ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.isToday ? "ACTIVE TODAY" : "OTHER DAYS",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.isToday ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "📍 Locality: ${widget.bazaar['locality']} ${widget.bazaar['landmark'] != null ? '(${widget.bazaar['landmark']})' : ''}",
            style: TextStyle(color: Colors.grey.shade700),
          ),
          if (_reviews.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(
                  "${avgRating.toStringAsFixed(1)} / 5.0 (${_reviews.length} reviews)",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          const Text("Operating Days & Times:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (widget.schedules.isEmpty)
            const Text("No fixed schedules added yet.")
          else
            ...widget.schedules.map((s) => Text("• ${widget.days[s['day_of_week']]}: ${s['start_time']} - ${s['end_time']}")),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text("Edit Spot"),
                  onPressed: widget.onEdit,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text("Delete"),
                  onPressed: widget.onDelete,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.navigation),
              label: const Text("Navigate via Google Maps"),
              onPressed: () async {
                final uri = Uri.parse(
                  "https://www.google.com/maps/search/?api=1&query=${widget.bazaar['latitude']},${widget.bazaar['longitude']}",
                );
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ),
          const Divider(height: 28),

          // --- LIVE VEGGIE STOCK & QUALITY FEED (SELF-EXPIRING) ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("⚡ Live Veggie Stock & Quality", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(10)),
                child: const Text("REAL-TIME", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            color: const Color(0xFFF1F8E9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Report Veggie Availability & Quality:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _veggieNameController,
                          decoration: const InputDecoration(
                            hintText: "e.g., Spinach (पालक) / Mangoes",
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedQuality,
                        items: ['Fresh / A Grade', 'Standard', 'Limited Stock']
                            .map((q) => DropdownMenuItem(value: q, child: Text(q, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedQuality = val!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _veggieNoteController,
                          decoration: const InputDecoration(
                            hintText: "Price / Stall Note (e.g., ₹20/bunch at stall 2)",
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                        onPressed: _isSubmittingSignal ? null : _addLiveSignal,
                        child: _isSubmittingSignal
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Post"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_liveSignals.isEmpty)
            const Text("No active stock signals for today yet. Be the first to tag what is fresh!", style: TextStyle(fontSize: 12, color: Colors.grey))
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _liveSignals.map((sig) {
                final isFresh = sig['quality_grade'] == 'Fresh / A Grade';
                return Chip(
                  avatar: Text(isFresh ? '🟢' : '🟡'),
                  label: Text("${sig['veggie_name']} (${sig['quality_grade']})${sig['note'] != null && sig['note'].toString().isNotEmpty ? ' - ${sig['note']}' : ''}"),
                  backgroundColor: isFresh ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                );
              }).toList(),
            ),

          const Divider(height: 28),
          const Text("💬 Comments & Community Updates", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            color: Colors.grey.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Your Rating:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Row(
                        children: List.generate(5, (idx) {
                          return GestureDetector(
                            onTap: () => setState(() => _userRating = idx + 1),
                            child: Icon(
                              idx < _userRating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 22,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text("Posting as: ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text("🛍️ Customer", style: TextStyle(fontSize: 12)),
                        selected: _selectedRole == 'Customer',
                        selectedColor: const Color(0xFFC8E6C9),
                        onSelected: (val) {
                          if (val) setState(() => _selectedRole = 'Customer');
                        },
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text("🌾 Shopkeeper", style: TextStyle(fontSize: 12)),
                        selected: _selectedRole == 'Shopkeeper',
                        selectedColor: const Color(0xFFFFE0B2),
                        onSelected: (val) {
                          if (val) setState(() => _selectedRole = 'Shopkeeper');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: "Your Name / Stall Name (Optional)",
                      prefixIcon: Icon(Icons.person_outline, size: 18),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: _selectedRole == 'Shopkeeper' 
                          ? "e.g., Fresh mangoes & organic spinach available today at Stall #4!"
                          : "e.g., Fresh vegetables, easy bike parking, gets crowded after 6 PM.",
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                      onPressed: _isSubmittingReview ? null : _addReview,
                      child: _isSubmittingReview
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("Post Update"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_reviews.isEmpty)
            const Text("No comments yet. Share first review or stall update!", style: TextStyle(fontSize: 12, color: Colors.grey))
          else
            ..._reviews.map((r) {
              final isShopkeeper = r['user_role'] == 'Shopkeeper';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isShopkeeper ? const Color(0xFFFFF8E1) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isShopkeeper ? Colors.amber.shade300 : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              r['reviewer_name'] ?? 'Shopper', 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isShopkeeper ? const Color(0xFFFFE082) : const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isShopkeeper ? "🌾 Shopkeeper / Farmer" : "🛍️ Shopper",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isShopkeeper ? Colors.brown.shade800 : Colors.green.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: List.generate(
                            (r['rating'] as num).toInt(),
                            (_) => const Icon(Icons.star, color: Colors.amber, size: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(r['comment'] ?? '', style: const TextStyle(fontSize: 13)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ==========================================
// 3. EXPLORE BY DAY SCREEN
// ==========================================
class ExploreBazaarsScreen extends StatefulWidget {
  const ExploreBazaarsScreen({super.key});

  @override
  State<ExploreBazaarsScreen> createState() => _ExploreBazaarsScreenState();
}

class _ExploreBazaarsScreenState extends State<ExploreBazaarsScreen> {
  int _selectedDay = 1;
  bool _isLoading = false;
  List<Map<String, dynamic>> _results = [];

  final List<String> _days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];

  @override
  void initState() {
    super.initState();
    _fetchByDay();
  }

  Future<void> _fetchByDay() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('bazaar_schedules')
          .select('day_of_week, start_time, end_time, bazaars(name, locality, landmark, latitude, longitude)')
          .eq('day_of_week', _selectedDay);

      if (mounted) {
        setState(() {
          _results = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: List.generate(_days.length, (index) {
                final isSelected = _selectedDay == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(_days[index]),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedDay = index);
                        _fetchByDay();
                      }
                    },
                  ),
                );
              }),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(child: Text("No bazaars registered for ${_days[_selectedDay]}."))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          final bazaar = item['bazaars'] as Map<String, dynamic>?;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE8F5E9),
                                child: Icon(Icons.store, color: Color(0xFF2E7D32)),
                              ),
                              title: Text(
                                bazaar?['name'] ?? 'Bhaaji Market',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                "📍 ${bazaar?['locality'] ?? ''} • ⏰ ${item['start_time']} - ${item['end_time']}",
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. ADD & PINPOINT BAZAAR SCREEN
// ==========================================
class AddBazaarScreen extends StatefulWidget {
  const AddBazaarScreen({super.key});

  @override
  State<AddBazaarScreen> createState() => _AddBazaarScreenState();
}

class _AddBazaarScreenState extends State<AddBazaarScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _localityController = TextEditingController();
  final _landmarkController = TextEditingController();
  final MapController _miniMapController = MapController();

  final Set<int> _selectedDays = {};
  TimeOfDay _startTime = const TimeOfDay(hour: 15, minute: 30);
  TimeOfDay _endTime = const TimeOfDay(hour: 21, minute: 0);

  bool _isSaving = false;
  bool _isLocating = false;
  bool _isMapFullscreen = false;

  double _pinnedLat = 18.5204;
  double _pinnedLng = 73.8567;

  final List<String> _days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDays.add(DateTime.now().weekday % 7);
    _pinpointCurrentLocation();
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final String hour = tod.hour.toString().padLeft(2, '0');
    final String min = tod.minute.toString().padLeft(2, '0');
    return '$hour:$min:00';
  }

  Future<void> _pinpointCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        setState(() {
          _pinnedLat = pos.latitude;
          _pinnedLng = pos.longitude;
        });
        _miniMapController.move(latlong.LatLng(_pinnedLat, _pinnedLng), 15);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _submitBazaar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one operating day.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final bazaarRes = await supabase.from('bazaars').insert({
        'name': _nameController.text.trim(),
        'locality': _localityController.text.trim(),
        'landmark': _landmarkController.text.trim(),
        'latitude': _pinnedLat,
        'longitude': _pinnedLng,
        'verified': true,
      }).select().single();

      final String newBazaarId = bazaarRes['id'];
      final String startTimeFormatted = _formatTimeOfDay(_startTime);
      final String endTimeFormatted = _formatTimeOfDay(_endTime);

      final scheduleInserts = _selectedDays.map((day) => {
        'bazaar_id': newBazaarId,
        'day_of_week': day,
        'start_time': startTimeFormatted,
        'end_time': endTimeFormatted,
      }).toList();

      await supabase.from('bazaar_schedules').insert(scheduleInserts);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Bhaaji Market added for all selected days!'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );

      _nameController.clear();
      _localityController.clear();
      _landmarkController.clear();
      setState(() {
        _selectedDays.clear();
        _selectedDays.add(DateTime.now().weekday % 7);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "📍 Pinpoint Location",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              TextButton.icon(
                                icon: _isLocating
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.my_location, size: 16),
                                label: const Text("GPS"),
                                onPressed: _isLocating ? null : _pinpointCurrentLocation,
                              ),
                              IconButton(
                                tooltip: _isMapFullscreen ? "Collapse" : "Expand Map",
                                icon: Icon(_isMapFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.green.shade800),
                                onPressed: () => setState(() => _isMapFullscreen = !_isMapFullscreen),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Text(
                        "Tap anywhere on the map to place the market pin:",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: _isMapFullscreen ? 360 : 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: FlutterMap(
                          mapController: _miniMapController,
                          options: MapOptions(
                            initialCenter: latlong.LatLng(_pinnedLat, _pinnedLng),
                            initialZoom: 14.0,
                            onTap: (_, point) {
                              setState(() {
                                _pinnedLat = point.latitude;
                                _pinnedLng = point.longitude;
                              });
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.aathawade_bazaar',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: latlong.LatLng(_pinnedLat, _pinnedLng),
                                  width: 36,
                                  height: 36,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 36,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.pin_drop, size: 16, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            "Selected: ${_pinnedLat.toStringAsFixed(5)}, ${_pinnedLng.toStringAsFixed(5)}",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Bazaar Name",
                  hintText: "e.g., Ravet Shetkari Bazaar",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.storefront),
                ),
                validator: (v) => v!.isEmpty ? "Enter market name" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _localityController,
                decoration: const InputDecoration(
                  labelText: "Locality / Area",
                  hintText: "e.g., Ravet, Punawale, Wakad",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
                validator: (v) => v!.isEmpty ? "Enter locality" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _landmarkController,
                decoration: const InputDecoration(
                  labelText: "Landmark (Optional)",
                  hintText: "e.g., Near D-Mart / Bus Stop",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
              ),
              const SizedBox(height: 14),
              const Text("⏰ Operating Timings:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text("Opens: ${_startTime.format(context)}"),
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: _startTime);
                        if (picked != null) setState(() => _startTime = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time_filled, size: 16),
                      label: Text("Closes: ${_endTime.format(context)}"),
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: _endTime);
                        if (picked != null) setState(() => _endTime = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "Select Operating Day(s)[cite: 3]:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: List.generate(_days.length, (index) {
                  final isSelected = _selectedDays.contains(index);
                  return FilterChip(
                    label: Text(_days[index]),
                    selected: isSelected,
                    selectedColor: const Color(0xFFC8E6C9),
                    checkmarkColor: const Color(0xFF2E7D32),
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedDays.add(index);
                        } else if (_selectedDays.length > 1) {
                          _selectedDays.remove(index);
                        }
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_circle_outline),
                onPressed: _isSaving ? null : _submitBazaar,
                label: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text("Save & Publish Live", style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 5. VEGGIE KNOWLEDGE MINI-GAME SCREEN
// ==========================================
class VeggieQuizScreen extends StatefulWidget {
  const VeggieQuizScreen({super.key});

  @override
  State<VeggieQuizScreen> createState() => _VeggieQuizScreenState();
}

class _VeggieQuizScreenState extends State<VeggieQuizScreen> {
  int _currentIndex = 0;
  int _score = 0;
  bool _answered = false;
  int? _selectedChoice;

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'What vegetable is this?',
      'icon': '🍅',
      'options': ['Tomato (टोमॅटो)', 'Brinjal (वांगं)', 'Potato (बटाटा)', 'Onion (कांदा)'],
      'answer': 0,
    },
    {
      'question': 'What is this leafy green vegetable called?',
      'icon': '🥬',
      'options': ['Cabbage (कोबी)', 'Spinach (पालक)', 'Coriander (कोथिंबीर)', 'Fenugreek (मेथी)'],
      'answer': 1,
    },
    {
      'question': 'Identify this purple vegetable:',
      'icon': '🍆',
      'options': ['Carrot (गाजर)', 'Radish (मुळा)', 'Brinjal (वांगं)', 'Beetroot (बीट)'],
      'answer': 2,
    },
    {
      'question': 'Identify this root vegetable:',
      'icon': '🥔',
      'options': ['Sweet Potato (रताळे)', 'Potato (बटाटा)', 'Garlic (लसूण)', 'Ginger (आले)'],
      'answer': 1,
    },
    {
      'question': 'What is this green pod vegetable called?',
      'icon': '🫛',
      'options': ['Green Peas (वाटाणा)', 'Green Chilli (हिरवी मिरची)', 'Beans (घेवडा)', 'Cucumber (काकडी)'],
      'answer': 0,
    },
    {
      'question': 'What vegetable is this crunchy orange root?',
      'icon': '🥕',
      'options': ['Carrot (गाजर)', 'Radish (मुळा)', 'Turnip (शलगम)', 'Sweet Corn (मका)'],
      'answer': 0,
    },
  ];

  void _answerQuestion(int idx) {
    if (_answered) return;
    setState(() {
      _answered = true;
      _selectedChoice = idx;
      if (idx == _questions[_currentIndex]['answer']) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    setState(() {
      _answered = false;
      _selectedChoice = null;
      _currentIndex++;
    });
  }

  void _resetQuiz() {
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _answered = false;
      _selectedChoice = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= _questions.length) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("🎉", style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                const Text("Quiz Completed!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Your Score: $_score / ${_questions.length}", style: const TextStyle(fontSize: 18, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  icon: const Icon(Icons.replay),
                  label: const Text("Play Again"),
                  onPressed: _resetQuiz,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final q = _questions[_currentIndex];

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Question ${_currentIndex + 1}/${_questions.length}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                Chip(
                  backgroundColor: Colors.green.shade50,
                  label: Text("Score: $_score", style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(q['icon'], style: const TextStyle(fontSize: 80)),
            ),
            const SizedBox(height: 16),
            Text(
              q['question'],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...List.generate(q['options'].length, (idx) {
              Color btnColor = Colors.white;
              Color textColor = Colors.black87;
              if (_answered) {
                if (idx == q['answer']) {
                  btnColor = Colors.green.shade100;
                  textColor = Colors.green.shade900;
                } else if (idx == _selectedChoice) {
                  btnColor = Colors.red.shade100;
                  textColor = Colors.red.shade900;
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnColor,
                    foregroundColor: textColor,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 1,
                  ),
                  onPressed: () => _answerQuestion(idx),
                  child: Text(q['options'][idx], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                ),
              );
            }),
            const Spacer(),
            if (_answered)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _nextQuestion,
                child: Text(_currentIndex < _questions.length - 1 ? "Next Question" : "View Final Score", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}