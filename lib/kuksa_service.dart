import 'dart:io';
import 'package:grpc/grpc.dart';
import 'package:flutter/services.dart';

// Helper to determine the host dynamically
String getHost() {
  // If running on the actual Pi (AGL), it uses localhost for the internal broker
  // If running on Ubuntu, use the Pi's Ethernet IP
  // The isEmbedded check is simulated here by checking if it's linux but you might
  // need a more robust check in a real app depending on the environment.
  // For now we just use the fixed IP or localhost if that's what's needed.
  // Let's assume we can just use the provided IP for now or you can toggle it.
  const bool isEmbedded = true; // Set to true if running on the pi directly
  return (Platform.isLinux && !isEmbedded) ? '10.42.0.113' : 'localhost';
}

class KuksaConfig {
  final String hostname = getHost(); // Use the RPi IP or localhost
  final int port = 55555;
  final String tlsServerName = 'Server';
}

class KuksaService {
  late ClientChannel _channel;
  late String _token;

  ClientChannel get channel => _channel;
  String get token => _token;

  Future<void> initialize() async {
    final config = KuksaConfig();

    List<int> trustedCertificates;
    String token;

    // 1. Load the CA Certificate (Server.pem)
    // Try reading from the absolute path used by IVI homescreen demo
    final pemFile = File('/etc/kuksa-val/Server.pem');
    if (await pemFile.exists()) {
      trustedCertificates = await pemFile.readAsBytes();
      print('Loaded Server.pem from /etc/kuksa-val/');
    } else {
      // Fallback to assets
      final ByteData certData = await rootBundle.load('assets/Server.pem');
      trustedCertificates = certData.buffer.asUint8List();
      print('Loaded Server.pem from assets');
    }

    // 2. Load the Authorization Token
    final tokenFile = File(
      '/etc/xdg/AGL/flutter-ics-homescreen/flutter-ics-homescreen.token',
    );
    if (await tokenFile.exists()) {
      token = await tokenFile.readAsString();
      print('Loaded token from /etc/xdg/AGL/...');
    } else {
      // Fallback to assets
      token = await rootBundle.loadString(
        'assets/flutter-ics-homescreen.token',
      );
      print('Loaded token from assets');
    }
    _token = token.trim();

    // 3. Create Secure Channel
    _channel = ClientChannel(
      config.hostname,
      port: config.port,
      options: ChannelOptions(
        credentials: ChannelCredentials.secure(
          certificates: trustedCertificates,
          authority: config.tlsServerName,
        ),
      ),
    );

    print(
      'KUKSA Service Initialized: Connecting to ${config.hostname}:${config.port}',
    );
  }

  // Helper to create CallOptions with the JWT Token
  CallOptions get authOptions =>
      CallOptions(metadata: {'authorization': 'Bearer $_token'});

  // You will add your gRPC methods here later once the protos are generated.
  // Example: Getting a Value (Speed)
  /* Future<double> getVehicleSpeed() async {
    final stub = VALClient(_channel);
    final request = GetRequest()..entries.add(EntryRequest()..path = "Vehicle.Speed");
    final response = await stub.get(request, options: authOptions);
    return response.entries.first.value.doubleValue;
  }
  */
}
