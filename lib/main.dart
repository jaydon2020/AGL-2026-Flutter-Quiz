import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:grpc/grpc.dart';

import 'src/generated/kuksa/val/v1/val.pbgrpc.dart' as kuksa_val;
import 'src/generated/kuksa/val/v1/types.pb.dart' as kuksa_types;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AGL GSoC 2026',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'AGL Flutter App Demo'),
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
  double _currentSpeed = 0.0;

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
    // 1. Establish the gRPC channel to the local databroker
    _channel = ClientChannel(
      '127.0.0.1',
      port: 55555,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );

    // 2. Initialize the generated KUKSA Client
    _client = kuksa_val.VALClient(_channel);

    // 3. Create the subscription request for Vehicle.Speed
    final request = kuksa_val.SubscribeRequest(
      entries: [
        kuksa_val.SubscribeEntry(
          path: 'Vehicle.Speed',
          view: kuksa_types.View.VIEW_CURRENT_VALUE,
          fields: [kuksa_types.Field.FIELD_VALUE],
        ),
      ],
    );

    // 4. Listen to the gRPC Stream
    try {
      final responseStream = _client.subscribe(request);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Applicant:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Jian De (Jaydon)',
                style: TextStyle(fontSize: 24, color: Colors.blue),
              ),
              const SizedBox(height: 20),
              const Text(
                'OS Version:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  _osVersion,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Vehicle Speed (KUKSA.val):',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  '${_currentSpeed.toStringAsFixed(1)} km/h',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _toggleImage,
                    child: Text(_showImage ? 'Hide Image' : 'Show Image'),
                  ),
                  ElevatedButton(
                    onPressed: _playSound,
                    child: const Text('Play Sound'),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              if (_showImage)
                SizedBox(
                  height: 200,
                  child: Image.asset(
                    'assets/agl_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Text('Image not found in assets/'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
