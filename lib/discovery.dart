import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Informações sobre uma Smart TV descoberta na rede local.
class TvInfo {
  final String ip;
  final String name;
  final String modelName;
  final String brand;

  const TvInfo({
    required this.ip,
    required this.name,
    required this.modelName,
    this.brand = 'samsung',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TvInfo && runtimeType == other.runtimeType && ip == other.ip;

  @override
  int get hashCode => ip.hashCode;

  @override
  String toString() => '$name ($modelName, $brand) em $ip';
}

/// Serviço de descoberta automática de TVs Samsung via varredura de sub-rede e SSDP.
class TvDiscovery {
  bool _isCancelled = false;
  final Set<String> _discoveredIps = <String>{};
  RawDatagramSocket? _ssdpSocket;

  /// Inicia a busca e retorna uma Stream de TVs encontradas sem duplicatas.
  Stream<TvInfo> startDiscovery() {
    _isCancelled = false;
    _discoveredIps.clear();

    late StreamController<TvInfo> controller;
    controller = StreamController<TvInfo>(
      onListen: () async {
        try {
          // Executa SSDP e varredura em paralelo
          final futures = <Future<void>>[
            _runSsdpDiscovery(controller),
            _runSubnetScan(controller),
          ];
          await Future.wait(futures);
        } catch (e) {
          debugPrint('Erro na descoberta de TVs: $e');
        } finally {
          if (!controller.isClosed) {
            await controller.close();
          }
          stopDiscovery();
        }
      },
      onCancel: () {
        stopDiscovery();
      },
    );

    return controller.stream;
  }

  /// Cancela qualquer busca em andamento.
  void stopDiscovery() {
    _isCancelled = true;
    try {
      _ssdpSocket?.close();
    } catch (_) {}
    _ssdpSocket = null;
  }

  /// Descoberta por SSDP (multicast M-SEARCH).
  Future<void> _runSsdpDiscovery(StreamController<TvInfo> controller) async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _ssdpSocket = socket;
      socket.broadcastEnabled = true;
      socket.multicastLoopback = false;

      const targetAddress = '239.255.255.250';
      const targetPort = 1900;

      // Mensagem M-SEARCH específica da Samsung
      const mSearchSamsung = 'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 2\r\n'
          'ST: urn:samsung.com:device:RemoteControlReceiver:1\r\n'
          '\r\n';

      // Mensagem M-SEARCH geral para reforço
      const mSearchGeneral = 'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 2\r\n'
          'ST: ssdp:all\r\n'
          '\r\n';

      final destination = InternetAddress(targetAddress);
      socket.send(utf8.encode(mSearchSamsung), destination, targetPort);
      socket.send(utf8.encode(mSearchGeneral), destination, targetPort);

      final subscription = socket.listen((event) async {
        if (_isCancelled) return;
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            final senderIp = datagram.address.address;
            if (!_discoveredIps.contains(senderIp)) {
              final tv = await verifySamsungTv(senderIp);
              if (tv != null && !_discoveredIps.contains(tv.ip) && !_isCancelled) {
                _discoveredIps.add(tv.ip);
                if (!controller.isClosed) {
                  controller.add(tv);
                }
              }
            }
          }
        }
      });

      // Aguarda 3 segundos por respostas SSDP
      await Future.delayed(const Duration(seconds: 3));
      await subscription.cancel();
      socket.close();
    } catch (_) {
      // Ignora falhas de multicast silenciosamente conforme especificação
    }
  }

  /// Descoberta por varredura da sub-rede /24 do dispositivo.
  Future<void> _runSubnetScan(StreamController<TvInfo> controller) async {
    final subnet = await _getLocalSubnet();
    if (subnet == null || _isCancelled) return;

    // Varre de 1 a 254 em lotes de 50
    const batchSize = 50;
    for (var i = 1; i <= 254; i += batchSize) {
      if (_isCancelled) break;

      final batch = <String>[];
      for (var j = i; j < i + batchSize && j <= 254; j++) {
        batch.add('$subnet.$j');
      }

      await Future.wait(
        batch.map((ip) => _probeHost(ip, controller)),
      );
    }
  }

  /// Testa se as portas comuns de Smart TVs (8002 Samsung, 8060 Roku, 3000 LG) estão abertas.
  Future<void> _probeHost(String ip, StreamController<TvInfo> controller) async {
    if (_isCancelled || _discoveredIps.contains(ip)) return;

    // 1. Tenta Roku TV (porta 8060 HTTP ECP)
    try {
      final socketRoku = await Socket.connect(ip, 8060, timeout: const Duration(milliseconds: 600));
      socketRoku.destroy();
      final tvRoku = await verifyRokuTv(ip);
      if (tvRoku != null && !_discoveredIps.contains(tvRoku.ip) && !_isCancelled) {
        _discoveredIps.add(tvRoku.ip);
        if (!controller.isClosed) controller.add(tvRoku);
        return;
      }
    } catch (_) {}

    // 2. Tenta Samsung Smart TV (porta 8002 WebSocket)
    try {
      final socketSamsung = await Socket.connect(ip, 8002, timeout: const Duration(milliseconds: 600));
      socketSamsung.destroy();
      final tvSamsung = await verifySamsungTv(ip);
      if (tvSamsung != null && !_discoveredIps.contains(tvSamsung.ip) && !_isCancelled) {
        _discoveredIps.add(tvSamsung.ip);
        if (!controller.isClosed) controller.add(tvSamsung);
        return;
      }
    } catch (_) {}

    // 3. Tenta LG Smart TV (porta 3000 webOS)
    try {
      final socketLg = await Socket.connect(ip, 3000, timeout: const Duration(milliseconds: 600));
      socketLg.destroy();
      final tvLg = TvInfo(ip: ip, name: 'LG Smart TV', modelName: 'webOS', brand: 'lg');
      if (!_discoveredIps.contains(tvLg.ip) && !_isCancelled) {
        _discoveredIps.add(tvLg.ip);
        if (!controller.isClosed) controller.add(tvLg);
        return;
      }
    } catch (_) {}
  }

  /// Obtém a sub-rede /24 preferindo wlan/en0 e faixas privadas.
  Future<String?> _getLocalSubnet() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      // Prioriza interfaces sem fio
      interfaces.sort((a, b) {
        final aName = a.name.toLowerCase();
        final bName = b.name.toLowerCase();
        final aIsWifi = aName.contains('wlan') || aName.contains('wi-fi') || aName.contains('en0');
        final bIsWifi = bName.contains('wlan') || bName.contains('wi-fi') || bName.contains('en0');
        if (aIsWifi && !bIsWifi) return -1;
        if (!aIsWifi && bIsWifi) return 1;
        return 0;
      });

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final ip = address.address;
          if (_isPrivateIp(ip)) {
            final parts = ip.split('.');
            if (parts.length == 4) {
              return '${parts[0]}.${parts[1]}.${parts[2]}';
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao obter sub-rede local: $e');
    }
    return null;
  }

  bool _isPrivateIp(String ip) {
    return ip.startsWith('192.168.') ||
        ip.startsWith('10.') ||
        ip.startsWith('172.16.') ||
        ip.startsWith('172.17.') ||
        ip.startsWith('172.18.') ||
        ip.startsWith('172.19.') ||
        ip.startsWith('172.2') ||
        ip.startsWith('172.30.') ||
        ip.startsWith('172.31.');
  }

  /// Confirma se o IP corresponde a uma TV Samsung consultando https://IP:8002/api/v2/.
  static Future<TvInfo?> verifySamsungTv(String ip) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      client.connectionTimeout = const Duration(milliseconds: 1500);

      final uri = Uri.parse('https://$ip:8002/api/v2/');
      final request = await client.getUrl(uri).timeout(const Duration(milliseconds: 1500));
      final response = await request.close().timeout(const Duration(milliseconds: 1500));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body);

        if (json is Map && json.containsKey('device')) {
          final device = json['device'];
          String name = 'Smart TV Samsung';
          String modelName = '';

          if (device is Map) {
            name = device['name']?.toString() ??
                device['device']?['name']?.toString() ??
                'Smart TV Samsung';
            modelName = device['modelName']?.toString() ??
                device['device']?['modelName']?.toString() ??
                device['model']?.toString() ??
                'Tizen';
          }

          return TvInfo(
            ip: ip,
            name: name,
            modelName: modelName,
            brand: 'samsung',
          );
        }
      }
    } catch (_) {
      // Não é Samsung ou não respondeu a tempo
    } finally {
      client?.close(force: true);
    }
    return null;
  }

  /// Confirma e obtém informações de uma Roku TV via ECP na porta 8060.
  static Future<TvInfo?> verifyRokuTv(String ip) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(milliseconds: 1500);

      final uri = Uri.parse('http://$ip:8060/query/device-info');
      final request = await client.getUrl(uri).timeout(const Duration(milliseconds: 1500));
      final response = await request.close().timeout(const Duration(milliseconds: 1500));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        String name = 'Roku TV';
        String modelName = 'Roku OS';

        // Extrai tags XML simples
        final nameMatch = RegExp(r'<user-device-name>(.*?)</user-device-name>').firstMatch(body);
        if (nameMatch != null && nameMatch.group(1) != null) {
          name = nameMatch.group(1)!;
        } else {
          final modelDesc = RegExp(r'<model-name>(.*?)</model-name>').firstMatch(body);
          if (modelDesc != null && modelDesc.group(1) != null) {
            name = 'Roku (${modelDesc.group(1)})';
          }
        }

        return TvInfo(
          ip: ip,
          name: name,
          modelName: modelName,
          brand: 'roku',
        );
      }
    } catch (_) {
      // Não é Roku
    } finally {
      client?.close(force: true);
    }
    return null;
  }
}

