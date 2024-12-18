import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // Importing Geolocator
import 'aco.dart'; // Importing your ACO algorithm
import 'nodes.dart'; // Importing the nodes data

class TrailMapScreen extends StatefulWidget {
  const TrailMapScreen({super.key});

  @override
  _TrailMapScreenState createState() => _TrailMapScreenState();
}

class _TrailMapScreenState extends State<TrailMapScreen> {
  bool _showPath = false;
  List<LatLng> _pathCoordinates = [];
  LatLng? _currentLocation; // User's current location
  LatLng? _selectedEndpoint; // User-selected endpoint
  List<String> distances = []; // To store the distance labels between nodes
  double _zoomLevel = 13.0; // Default zoom level
  String _currentHeading = "N/A"; // Current compass heading

  // Update the endpoints to have only one option
  final List<LatLng> endpoints = [
    LatLng(10.930394, 122.016875), // Add more endpoints here if needed
  ];

  final List<String> endpointImages = [
    'assets/images/checkpoint1.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  void _startLocationTracking() {
    LocationSettings locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _currentHeading = "${position.heading.toStringAsFixed(2)}°"; // Compass heading
      });
    });
  }

  void _onStartPressed() {
    if (_currentLocation == null || _selectedEndpoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Unable to fetch current location or endpoint."),
      ));
      return;
    }

    setState(() {
      _showPath = true;

      // Construct the list of checkpoints
      final List<LatLng> checkpoints = [
        _currentLocation!,
        ...Nodes.checkpoints, // Reference to the checkpoints from nodes.dart
        _selectedEndpoint!, // Adding selected endpoint
      ];

      // Run the ACO algorithm
      final acoAlgorithm = ACOAlgorithm(nodes: checkpoints);
      _pathCoordinates = acoAlgorithm.findShortestPath(checkpoints);

      // Calculate distances between consecutive points
      distances.clear();
      for (int i = 0; i < _pathCoordinates.length - 1; i++) {
        double distance = Geolocator.distanceBetween(
          _pathCoordinates[i].latitude,
          _pathCoordinates[i].longitude,
          _pathCoordinates[i + 1].latitude,
          _pathCoordinates[i + 1].longitude,
        );
        distances.add("${distance.toStringAsFixed(2)} meters");
      }
    });
  }

  void _selectEndpoint(LatLng endpoint, int index) {
    setState(() {
      _selectedEndpoint = endpoint;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Endpoint ${index + 1} selected!"),
    ));
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel < 18.0) ? _zoomLevel + 1 : 18.0;
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel > 8.0) ? _zoomLevel - 1 : 8.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trail Navigation'),
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.compass_calibration),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text("Current Heading: $_currentHeading"),
              ));
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.green),
              child: Text(
                'Settings',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              title: const Text('Toggle Path Visibility'),
              trailing: Switch(
                value: _showPath,
                onChanged: (bool value) {
                  setState(() {
                    _showPath = value;
                  });
                },
              ),
            ),
            const Divider(),
            for (int i = 0; i < endpoints.length; i++)
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.asset(
                    endpointImages[i],
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Text('Endpoint ${i + 1}'),
                onTap: () {
                  Navigator.of(context).pop(); // Close drawer
                  _selectEndpoint(endpoints[i], i);
                },
              ),
          ],
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              center: _currentLocation ?? LatLng(10.941987, 122.004955),
              zoom: _zoomLevel,
              maxZoom: 18.0,
              minZoom: 8.0,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
              ),
              if (_showPath)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _pathCoordinates,
                      strokeWidth: 4.0,
                      color: Colors.blueAccent,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      builder: (ctx) => const Icon(
                        Icons.my_location,
                        color: Colors.green,
                      ),
                    ),
                  if (_selectedEndpoint != null)
                    Marker(
                      point: _selectedEndpoint!,
                      builder: (ctx) => const Icon(
                        Icons.flag,
                        color: Colors.red,
                      ),
                    ),
                  for (int i = 0; i < endpoints.length; i++)
                    Marker(
                      point: endpoints[i],
                      builder: (ctx) => GestureDetector(
                        onTap: () {
                          _selectEndpoint(endpoints[i], i);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Distance to this point: ${distances.isNotEmpty && i < distances.length ? distances[i] : "N/A"}'),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.zoom_in),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.zoom_out),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onStartPressed,
        label: const Text('Start Navigation'),
        icon: const Icon(Icons.directions),
      ),
    );
  }
}
