import 'dart:io';
import 'package:grpc/grpc.dart';
import 'package:flutter/services.dart';

// Helper to determine the host dynamically
String getHost() {
  const bool isEmbedded = false; // Set to true if running on the pi directly
  return (Platform.isLinux && !isEmbedded) ? '10.42.0.113' : '127.0.0.1';
}

class KuksaConfig {
  final String hostname = getHost(); // Use the RPi IP or 127.0.0.1
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

    // 1. Load the CA Certificate (Server.pem or CA.pem)
    final caFile = File('/etc/kuksa-val/CA.pem');
    final serverFile = File('/etc/kuksa-val/Server.pem');

    if (await caFile.exists()) {
      trustedCertificates = await caFile.readAsBytes();
      print('Loaded CA.pem from /etc/kuksa-val/');
    } else if (await serverFile.exists()) {
      trustedCertificates = await serverFile.readAsBytes();
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
    try {
      _channel = ClientChannel(
        config.hostname,
        port: config.port,
        options: ChannelOptions(
          credentials: ChannelCredentials.secure(
            certificates: trustedCertificates,
            authority: config.tlsServerName,
          ),
          connectionTimeout: const Duration(
            seconds: 5,
          ), // Fail fast if unreachable
        ),
      );
      print(
        'KUKSA Service Initialized: Connecting to ${config.hostname}:${config.port} | Token length: ${_token.length}',
      );
    } catch (e) {
      print('CRITICAL KUKSA INIT ERROR: $e');
      rethrow;
    }
  }

  // Helper to create CallOptions with the JWT Token
  CallOptions get authOptions =>
      CallOptions(metadata: {'authorization': 'Bearer $_token'});
}
