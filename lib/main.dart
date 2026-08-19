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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bhaaji Market'),
        actions: [
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
          labelTextStyle: MaterialStateProperty.all(
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
                              const Text("Check 'Live Map' or 'Explorer'."),
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
// 2. LIVE MAP INTERACTIVE (WITH EDIT & DELETE SUPPORT)
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

  // --- EDIT SPOT DIALOG (WITH INTERACTIVE PIN MOVEMENT) ---
  void _editBazaarDialog(Map<String, dynamic> bazaar) {
    final nameController = TextEditingController(text: bazaar['name'] ?? '');
    final localityController = TextEditingController(text: bazaar['locality'] ?? '');
    final landmarkController = TextEditingController(text: bazaar['landmark'] ?? '');
    final schedules = bazaar['bazaar_schedules'] as List<dynamic>? ?? [];

    double updatedLat = (bazaar['latitude'] as num).toDouble();
    double updatedLng = (bazaar['longitude'] as num).toDouble();
    final MapController editMapController = MapController();

    int selectedDay = schedules.isNotEmpty ? (schedules[0]['day_of_week'] ?? 0) : 0;
    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    showDialog(
      context: context,
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
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: selectedDay,
                    decoration: const InputDecoration(
                      labelText: "Operating Day",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    items: List.generate(
                      days.length,
                      (idx) => DropdownMenuItem(value: idx, child: Text(days[idx])),
                    ),
                    onChanged: (val) => setDialogState(() => selectedDay = val!),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "📍 Tap on map to reposition pin:",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 180,
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
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Position: ${updatedLat.toStringAsFixed(5)}, ${updatedLng.toStringAsFixed(5)}",
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final bazaarId = bazaar['id'];
                await supabase.from('bazaars').update({
                  'name': nameController.text.trim(),
                  'locality': localityController.text.trim(),
                  'landmark': landmarkController.text.trim(),
                  'latitude': updatedLat,
                  'longitude': updatedLng,
                }).eq('id', bazaarId);

                if (schedules.isNotEmpty) {
                  await supabase
                      .from('bazaar_schedules')
                      .update({'day_of_week': selectedDay})
                      .eq('bazaar_id', bazaarId);
                }

                if (ctx.mounted) Navigator.pop(ctx);
                _fetchBazaarsForMap();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Bazaar spot updated!"),
                    backgroundColor: Color(0xFF2E7D32),
                  ),
                );
              },
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }

  // --- DELETE SPOT DIALOG ---
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
              final bazaarId = bazaar['id'];
              await supabase.from('bazaar_schedules').delete().eq('bazaar_id', bazaarId);
              await supabase.from('bazaars').delete().eq('id', bazaarId);

              if (ctx.mounted) Navigator.pop(ctx);
              _fetchBazaarsForMap();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Bazaar spot removed."), backgroundColor: Colors.red),
              );
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final schedules = bazaar['bazaar_schedules'] as List<dynamic>? ?? [];
        final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        final bool isToday = _isBazaarToday(bazaar);

        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      bazaar['name'] ?? 'Bhaaji Market',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isToday ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isToday ? "ACTIVE TODAY" : "OTHER DAYS",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isToday ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "📍 Locality: ${bazaar['locality']} ${bazaar['landmark'] != null ? '(${bazaar['landmark']})' : ''}",
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
              const Text("Operating Days & Times:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (schedules.isEmpty)
                const Text("No fixed schedules added yet.")
              else
                ...schedules.map((s) => Text("• ${days[s['day_of_week']]}: ${s['start_time']} - ${s['end_time']}")),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text("Edit Spot"),
                      onPressed: () {
                        Navigator.pop(context);
                        _editBazaarDialog(bazaar);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text("Delete"),
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteBazaar(bazaar);
                      },
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
                    Navigator.pop(context);
                    final uri = Uri.parse(
                      "https://www.google.com/maps/search/?api=1&query=${bazaar['latitude']},${bazaar['longitude']}",
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ),
            ],
          ),
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
                            Text("Open Today", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(radius: 5, backgroundColor: Color(0xFFE65100)),
                            SizedBox(width: 6),
                            Text("Other Days", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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

  late int _selectedDay;
  bool _isSaving = false;
  bool _isLocating = false;

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
    _selectedDay = DateTime.now().weekday % 7;
    _pinpointCurrentLocation();
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

      await supabase.from('bazaar_schedules').insert({
        'bazaar_id': newBazaarId,
        'day_of_week': _selectedDay,
        'start_time': '15:30:00',
        'end_time': '21:00:00',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Bhaaji Market added! Synced live across all devices.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );

      _nameController.clear();
      _localityController.clear();
      _landmarkController.clear();
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
                          TextButton.icon(
                            icon: _isLocating
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.my_location, size: 16),
                            label: const Text("Use Live GPS"),
                            onPressed: _isLocating ? null : _pinpointCurrentLocation,
                          ),
                        ],
                      ),
                      const Text(
                        "Tap anywhere on the map to place the market pin:",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
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
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _selectedDay,
                decoration: const InputDecoration(
                  labelText: "Operating Day of Week",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                items: List.generate(
                  _days.length,
                  (index) => DropdownMenuItem(
                    value: index,
                    child: Text(_days[index]),
                  ),
                ),
                onChanged: (val) => setState(() => _selectedDay = val!),
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