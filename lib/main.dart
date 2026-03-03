import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import 'src/generated/kuksa/val/v1/val.pbgrpc.dart' as kuksa_val;
import 'src/generated/kuksa/val/v1/types.pb.dart' as kuksa_types;
import 'widgets/glass_panel.dart';
import 'widgets/speed_gauge.dart';

import 'kuksa_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final kuksa = KuksaService();
  try {
    await kuksa.initialize();
  } catch (e) {
    debugPrint(
      'KuksaService initialization failed (maybe missing exact token/pem?): $e',
    );
  }
  runApp(MyApp(kuksa: kuksa));
}

class MyApp extends StatelessWidget {
  final KuksaService kuksa;
  const MyApp({super.key, required this.kuksa});

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
      home: MyHomePage(
        title: 'AGL IVI Flutter Demo Dashboard Updated',
        kuksa: kuksa,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final KuksaService kuksa;
  const MyHomePage({super.key, required this.title, required this.kuksa});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _osVersion = 'Unknown';
  String _kernelVersion = 'Unknown';
  bool _showImage = false;
  static const MethodChannel _audioChannel = MethodChannel(
    'xyz.luan/audioplayers',
  );
  final String _playerId = 'test_player_id';
  String _statusMessage = '';
  bool _isError = false;

  late kuksa_val.VALClient _client;
  double _currentSpeed = 65.0; // Default matches HTML
  bool _kuksaConnected = false;

  @override
  void initState() {
    super.initState();
    _readOsVersion();
    _readKernelVersion();
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

  Future<void> _readKernelVersion() async {
    try {
      final result = await Process.run('uname', ['-r']);
      if (result.exitCode == 0) {
        setState(() {
          _kernelVersion = result.stdout.toString().trim();
        });
        return;
      }
    } catch (e) {
      debugPrint('Error reading kernel version: $e');
    }
    setState(() {
      _kernelVersion = 'Could not read kernel version';
    });
  }

  void _initKuksaConnection() async {
    setState(() {
      _kuksaConnected = false;
    });

    _client = kuksa_val.VALClient(widget.kuksa.channel);

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
      final responseStream = _client.subscribe(
        request,
        options: widget.kuksa.authOptions,
      );
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
          setState(() {
            _kuksaConnected = false;
          });
        },
        onDone: () {
          setState(() {
            _kuksaConnected = false;
          });
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('Failed to subscribe: $e');
      setState(() {
        _kuksaConnected = false;
      });
    }
  }

  Future<void> _setKuksaSpeed(double speed) async {
    if (!_kuksaConnected) return;

    final entry = kuksa_val.EntryUpdate(
      entry: kuksa_types.DataEntry(
        path: 'Vehicle.Speed',
        value: kuksa_types.Datapoint(float: speed),
      ),
      fields: [kuksa_types.Field.FIELD_VALUE],
    );

    final request = kuksa_val.SetRequest(updates: [entry]);

    try {
      final response = await _client.set(
        request,
        options: widget.kuksa.authOptions,
      );
      if (response.hasError()) {
        debugPrint('KUKSA Set Error: ${response.error.message}');
      }
    } catch (e) {
      debugPrint('Failed to set speed: $e');
    }
  }

  void _toggleImage() {
    setState(() {
      _showImage = !_showImage;
    });
  }

  Future<void> _playSound() async {
    try {
      // For the AGL C++ backend, we likely need a real absolute path across the filesystem.
      // We will extract the bundled asset into the app's temporary directory.
      final byteData = await rootBundle.load('assets/sound.mp3');
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/sound.mp3');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      final String filePath = tempFile.path;

      // Step 0: Tell C++ to create the player instance
      await _audioChannel.invokeMethod('create', {'playerId': _playerId});

      // Step 1: Tell C++ to load the file
      await _audioChannel.invokeMethod('setSourceUrl', {
        'playerId': _playerId,
        'url': filePath,
        'isLocal': true,
      });

      // Step 2: Tell C++ to push the audio to PipeWire
      await _audioChannel.invokeMethod('resume', {'playerId': _playerId});

      setState(() {
        _statusMessage = 'Audio played successfully!';
        _isError = false;
      });
    } catch (e) {
      debugPrint('Error playing audio: $e');
      setState(() {
        _statusMessage = 'Error playing audio: $e';
        _isError = true;
      });
    }
  }

  @override
  void dispose() {
    // Tell the C++ backend to free up the audio resources for this playerId
    _audioChannel.invokeMethod('release', {'playerId': _playerId});
    widget.kuksa.channel.shutdown();
    super.dispose();
  }

  Widget _buildInfoBox(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(30, 58, 138, 0.3), // blue-900/30
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color.fromRGBO(59, 130, 246, 0.3), // blue-500/30
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF60A5FA)), // blue-400
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.sourceCodePro(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFBFDBFE), // blue-200
              ),
            ),
          ),
        ],
      ),
    );
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildInfoBox(
                              Icons.badge_outlined,
                              'Name: JianDe (Jaydon2020)',
                            ),
                            const SizedBox(height: 12),
                            _buildInfoBox(
                              Icons.system_update_alt_outlined,
                              'AGL Version: $_osVersion',
                            ),
                            const SizedBox(height: 12),
                            _buildInfoBox(
                              Icons.memory_outlined,
                              'Kernel: $_kernelVersion',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

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

                  const SizedBox(height: 16),

                  // KUKSA Connection Controls
                  Row(
                    children: [
                      InkWell(
                        onTap: _initKuksaConnection,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6), // primary
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'CONNECT',
                            style: GoogleFonts.orbitron(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status indicator
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kuksaConnected
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.red.withValues(alpha: 0.2),
                          border: Border.all(
                            color: _kuksaConnected ? Colors.green : Colors.red,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _kuksaConnected ? Icons.link : Icons.link_off,
                          color: _kuksaConnected
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          size: 24,
                        ),
                      ),
                    ],
                  ),

                  // Audio Status Message
                  if (_statusMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.sourceCodePro(
                          color: _isError
                              ? Colors.redAccent
                              : Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

                  const SizedBox(height: 16),

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
                                  onChangeEnd: (value) {
                                    _setKuksaSpeed(value);
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
