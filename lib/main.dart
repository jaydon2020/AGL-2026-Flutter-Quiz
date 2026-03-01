import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:grpc/grpc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'src/generated/kuksa/val/v1/val.pbgrpc.dart' as kuksa_val;
import 'src/generated/kuksa/val/v1/types.pb.dart' as kuksa_types;
import 'widgets/glass_panel.dart';
import 'widgets/speed_gauge.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AGL IVI Flutter Demo Dashboard Updated',
      themeMode: ThemeMode.dark, // Force dark mode as per HTML
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF020617), // bg-background-dark
        textTheme: GoogleFonts.exo2TextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF1E3A8A),
        ),
      ),
      home: const MyHomePage(title: 'AGL IVI Flutter Demo Dashboard Updated'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _osVersion = 'Unknown';
  bool _showImage = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late ClientChannel _channel;
  late kuksa_val.VALClient _client;
  double _currentSpeed = 65.0; // Default matches HTML
  bool _kuksaConnected = false;

  @override
  void initState() {
    super.initState();
    _readOsVersion();
    _initKuksaConnection();
  }

  Future<void> _readOsVersion() async {
    try {
      final file = File('/etc/os-release');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        for (final line in lines) {
          if (line.startsWith('PRETTY_NAME=')) {
            setState(() {
              _osVersion = line.substring(12).replaceAll('"', '');
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Error reading OS version: $e');
    }
    setState(() {
      _osVersion = 'Could not read /etc/os-release';
    });
  }

  void _initKuksaConnection() async {
    _channel = ClientChannel(
      '127.0.0.1',
      port: 55555,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );

    _client = kuksa_val.VALClient(_channel);

    final request = kuksa_val.SubscribeRequest(
      entries: [
        kuksa_val.SubscribeEntry(
          path: 'Vehicle.Speed',
          view: kuksa_types.View.VIEW_CURRENT_VALUE,
          fields: [kuksa_types.Field.FIELD_VALUE],
        ),
      ],
    );

    try {
      final responseStream = _client.subscribe(request);
      setState(() {
        _kuksaConnected = true;
      });
      responseStream.listen(
        (kuksa_val.SubscribeResponse response) {
          for (var update in response.updates) {
            if (update.entry.path == 'Vehicle.Speed') {
              setState(() {
                _currentSpeed = update.entry.value.float;
              });
            }
          }
        },
        onError: (error) {
          debugPrint('KUKSA gRPC Error: $error');
        },
      );
    } catch (e) {
      debugPrint('Failed to subscribe: $e');
    }
  }

  void _toggleImage() {
    setState(() {
      _showImage = !_showImage;
    });
  }

  Future<void> _playSound() async {
    try {
      await _audioPlayer.play(AssetSource('sound.mp3'));
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  @override
  void dispose() {
    _channel.shutdown();
    _audioPlayer.dispose();
    super.dispose();
  }

  Widget _buildInteractiveButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: const Color(
          0xFF3B82F6,
        ).withValues(alpha: 0.2), // primary/20
        highlightColor: const Color(
          0xFF3B82F6,
        ).withValues(alpha: 0.1), // primary/10
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromRGBO(30, 58, 138, 0.8), // blue-900/80
                Color(0xFF0F172A), // slate-900
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color.fromRGBO(59, 130, 246, 0.3), // blue-500/30
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(23, 37, 84, 0.5), // blue-950/50
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color.fromRGBO(
                      96,
                      165,
                      250,
                      0.3,
                    ), // blue-400/30
                  ),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: const Color(0xFF3B82F6), // primary
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFE2E8F0), // slate-200
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient Image (Simulated wave)
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Image.asset(
                'assets/agl_logo.png', // Replace with real wave if available, or just use the gradient
                fit: BoxFit.cover,
                colorBlendMode: BlendMode.overlay,
              ),
            ),
          ),
          // Deep Blue to Dark Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.fromRGBO(30, 58, 138, 0.2), // blue-900/20
                    Color.fromRGBO(2, 6, 23, 0.8), // background-dark/80
                    Color(0xFF020617), // background-dark
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Section: Glass Panel Profile
                  GlassPanel(
                    padding: const EdgeInsets.all(24),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color.fromRGBO(30, 58, 138, 0.4),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(
                                  23,
                                  37,
                                  84,
                                  0.6,
                                ), // blue-950/60
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color.fromRGBO(
                                    96,
                                    165,
                                    250,
                                    0.3,
                                  ), // blue-400/30
                                ),
                              ),
                              child: const Icon(
                                Icons.person_outline,
                                size: 40,
                                color: Color(0xFF3B82F6), // primary
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Jane Doe',
                              style: GoogleFonts.orbitron(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(
                                  30,
                                  58,
                                  138,
                                  0.3,
                                ), // blue-900/30
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color.fromRGBO(
                                    59,
                                    130,
                                    246,
                                    0.2,
                                  ), // blue-500/20
                                ),
                              ),
                              child: Text(
                                'AGL Version: $_osVersion (from /etc/os-release)',
                                style: GoogleFonts.sourceCodePro(
                                  fontSize: 14,
                                  color: const Color(0xFFBFDBFE), // blue-200
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Middle Section: Interactive Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildInteractiveButton(
                          icon: Icons.image_outlined,
                          label: 'DISPLAY IMAGE',
                          onTap: _toggleImage,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInteractiveButton(
                          icon: Icons.volume_up_outlined,
                          label: 'PLAY SOUND',
                          onTap: _playSound,
                        ),
                      ),
                    ],
                  ),

                  // If show image is toggled, an overlay or container in the middle
                  if (_showImage)
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: Center(
                        child: GlassPanel(
                          padding: const EdgeInsets.all(16),
                          child: Image.asset(
                            'assets/agl_logo.png',
                            height: 100,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                  const Spacer(),

                  // Bottom Section: Dashboard Metrics (The Gauge)
                  Column(
                    children: [
                      Text(
                        'DASHBOARD METRICS',
                        style: GoogleFonts.orbitron(
                          fontSize: 14,
                          color: const Color.fromRGBO(
                            59,
                            130,
                            246,
                            0.8,
                          ), // primary 80%
                          letterSpacing: 2.8, // 0.2em roughly
                        ),
                      ),
                      const SizedBox(height: 24),
                      SpeedGauge(speed: _currentSpeed, maxSpeed: 220.0),
                      const SizedBox(height: 24),
                      // Slider matching HTML
                      GlassPanel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '0',
                                    style: GoogleFonts.orbitron(
                                      fontSize: 12,
                                      color: const Color(0xFF93C5FD),
                                    ),
                                  ),
                                  Text(
                                    'SPEED',
                                    style: GoogleFonts.orbitron(
                                      fontSize: 12,
                                      color: const Color(0xFF93C5FD),
                                    ),
                                  ),
                                  Text(
                                    '220',
                                    style: GoogleFonts.orbitron(
                                      fontSize: 12,
                                      color: const Color(0xFF93C5FD),
                                    ),
                                  ),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: const Color(
                                    0xFF1E3A8A,
                                  ), // secondary
                                  inactiveTrackColor: const Color.fromRGBO(
                                    30,
                                    58,
                                    138,
                                    0.5,
                                  ), // blue-900/50
                                  thumbColor: const Color(
                                    0xFF3B82F6,
                                  ), // primary
                                  overlayColor: const Color(
                                    0xFF3B82F6,
                                  ).withValues(alpha: 0.2),
                                  trackHeight: 4,
                                ),
                                child: Slider(
                                  value: _currentSpeed,
                                  min: 0,
                                  max: 220,
                                  onChanged: (value) {
                                    setState(() {
                                      _currentSpeed = value;
                                    });
                                  },
                                ),
                              ),
                              Text(
                                _kuksaConnected
                                    ? 'Subscribed to Kuksa gRPC'
                                    : 'Fallback Slider Mode',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
