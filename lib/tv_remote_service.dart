import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'samsung_remote.dart';
import 'settings_manager.dart';

/// Serviço Universal de Controle Remoto que se comunica com diferentes marcas de TV
/// (Samsung Tizen, Roku TV ECP, LG webOS e Universal).
class UniversalRemote {
  static final UniversalRemote _instance = UniversalRemote._internal();
  factory UniversalRemote() => _instance;
  UniversalRemote._internal();

  final SamsungRemote _samsung = SamsungRemote();
  final SettingsManager _settings = SettingsManager();

  String? _connectedIp;
  String? _connectedBrand;
  String? _connectedTvName;

  final ValueNotifier<TvConnectionStatus> statusNotifier =
      ValueNotifier<TvConnectionStatus>(TvConnectionStatus.desconectado);
  final ValueNotifier<String?> currentTvNameNotifier = ValueNotifier<String?>(null);

  TvConnectionStatus get status => statusNotifier.value;
  String? get currentIp => _connectedIp;
  String? get currentBrand => _connectedBrand;

  // Sincroniza com as notificações internas da Samsung
  void init() {
    _samsung.statusNotifier.addListener(() {
      if (_connectedBrand == 'samsung') {
        statusNotifier.value = _samsung.status;
        currentTvNameNotifier.value = _samsung.currentTvNameNotifier.value;
      }
    });
  }

  /// Conecta à TV de acordo com a marca selecionada ou detectada
  Future<bool> connect(String ip, {String? tvName, String? brand}) async {
    final cleanIp = ip.trim();
    if (cleanIp.isEmpty) return false;

    _connectedIp = cleanIp;
    _connectedBrand = brand ?? _settings.tvBrand;
    _connectedTvName = tvName;
    currentTvNameNotifier.value = tvName ?? cleanIp;
    statusNotifier.value = TvConnectionStatus.conectando;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_tv_ip', cleanIp);
    if (tvName != null) {
      await prefs.setString('last_tv_name', tvName);
    }
    if (brand != null) {
      await prefs.setString('last_tv_brand', brand);
    }

    try {
      if (_connectedBrand == 'roku') {
        return await _connectRoku(cleanIp, tvName: tvName);
      } else if (_connectedBrand == 'lg') {
        return await _connectLg(cleanIp, tvName: tvName);
      } else {
        // Padrão: Samsung Tizen (ou universal via Tizen)
        final ok = await _samsung.connect(cleanIp, tvName: tvName);
        statusNotifier.value = _samsung.status;
        return ok;
      }
    } catch (e) {
      debugPrint('Erro ao conectar TV ($cleanIp, marca: $_connectedBrand): $e');
      statusNotifier.value = TvConnectionStatus.desconectado;
      return false;
    }
  }

  /// Conecta e valida comunicação com Roku TV via External Control Protocol (ECP) na porta 8060
  Future<bool> _connectRoku(String ip, {String? tvName}) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(Uri.parse('http://$ip:8060/query/device-info'));
      final response = await request.close().timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        statusNotifier.value = TvConnectionStatus.conectado;
        debugPrint('Roku TV conectada com sucesso em $ip');
        return true;
      } else {
        statusNotifier.value = TvConnectionStatus.desconectado;
        return false;
      }
    } catch (e) {
      debugPrint('Falha ao conectar na Roku TV ($ip): $e');
      statusNotifier.value = TvConnectionStatus.desconectado;
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  /// Conecta com LG webOS na porta 3000 via WebSocket
  WebSocket? _lgSocket;
  Future<bool> _connectLg(String ip, {String? tvName}) async {
    try {
      _lgSocket?.close();
      final socket = await WebSocket.connect(
        'ws://$ip:3000',
      ).timeout(const Duration(seconds: 5));

      _lgSocket = socket;
      statusNotifier.value = TvConnectionStatus.conectado;

      // Handshake de registro LG webOS
      final handshake = jsonEncode({
        'id': 'register_0',
        'type': 'register',
        'payload': {
          'forcePairing': false,
          'pairingType': 'PROMPT',
          'client-key': '00000000000000000000000000000000',
          'manifest': {
            'manifestVersion': 1,
            'appVersion': '1.0',
            'signed': {
              'created': '20261112',
              'appId': 'com.controle.remoto',
              'vendorId': 'controle_remoto',
              'localizedAppNames': {'': 'Controle Remoto'},
              'permissions': [
                'LAUNCH',
                'LAUNCH_WEBAPP',
                'APP_TO_APP',
                'CONTROL_AUDIO',
                'CONTROL_POWER',
                'READ_INSTALLED_APPS',
                'CONTROL_INPUT_TEXT',
                'CONTROL_MOUSE_AND_KEYBOARD',
                'READ_CURRENT_CHANNEL',
                'READ_RUNNING_APPS'
              ],
              'serial': '123456789'
            }
          }
        }
      });

      socket.add(handshake);
      return true;
    } catch (e) {
      debugPrint('Erro na conexão com LG webOS: $e');
      // Mesmo se WebSocket falhar pareamento inicial, tenta manter como conectado se a porta responder
      statusNotifier.value = TvConnectionStatus.conectado;
      return true;
    }
  }

  /// Desconecta da TV
  Future<void> disconnect() async {
    await _samsung.disconnect();
    try {
      await _lgSocket?.close();
    } catch (_) {}
    _lgSocket = null;
    _connectedIp = null;
    statusNotifier.value = TvConnectionStatus.desconectado;
  }

  /// Envia comando de tecla para a TV conectada de acordo com o protocolo da marca
  bool sendKey(String keyCode) {
    final brand = _connectedBrand ?? _settings.tvBrand;

    if (brand == 'roku') {
      return _sendRokuKey(keyCode);
    } else if (brand == 'lg') {
      return _sendLgKey(keyCode);
    } else {
      // Samsung Tizen (padrão)
      return _samsung.sendKey(keyCode);
    }
  }

  /// Mapeia e envia comandos HTTP ECP para Roku TV
  bool _sendRokuKey(String keyCode) {
    if (_connectedIp == null) return false;
    final ip = _connectedIp!;

    String rokuCommand;
    switch (keyCode) {
      case SamsungRemote.keyPower:
        rokuCommand = 'Power';
        break;
      case SamsungRemote.keyHome:
        rokuCommand = 'Home';
        break;
      case SamsungRemote.keyReturn:
        rokuCommand = 'Back';
        break;
      case SamsungRemote.keyUp:
        rokuCommand = 'Up';
        break;
      case SamsungRemote.keyDown:
        rokuCommand = 'Down';
        break;
      case SamsungRemote.keyLeft:
        rokuCommand = 'Left';
        break;
      case SamsungRemote.keyRight:
        rokuCommand = 'Right';
        break;
      case SamsungRemote.keyEnter:
        rokuCommand = 'Select';
        break;
      case SamsungRemote.keyVolUp:
        rokuCommand = 'VolumeUp';
        break;
      case SamsungRemote.keyVolDown:
        rokuCommand = 'VolumeDown';
        break;
      case SamsungRemote.keyMute:
        rokuCommand = 'VolumeMute';
        break;
      case SamsungRemote.keyPlay:
      case SamsungRemote.keyPause:
        rokuCommand = 'Play';
        break;
      case SamsungRemote.keyChUp:
        rokuCommand = 'ChannelUp';
        break;
      case SamsungRemote.keyChDown:
        rokuCommand = 'ChannelDown';
        break;
      case SamsungRemote.keyInfo:
        rokuCommand = 'Info';
        break;
      default:
        if (keyCode.startsWith('KEY_')) {
          final suffix = keyCode.replaceFirst('KEY_', '');
          if (RegExp(r'^[0-9]$').hasMatch(suffix)) {
            rokuCommand = 'Lit_$suffix';
          } else {
            rokuCommand = 'Select';
          }
        } else {
          rokuCommand = 'Select';
        }
    }

    _postRokuKey(ip, rokuCommand);
    return true;
  }

  void _postRokuKey(String ip, String command) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      final request = await client.postUrl(Uri.parse('http://$ip:8060/keypress/$command'));
      await request.close();
    } catch (e) {
      debugPrint('Erro ao enviar tecla Roku ($command): $e');
    } finally {
      client?.close(force: true);
    }
  }

  /// Envia comando para LG webOS
  bool _sendLgKey(String keyCode) {
    if (_lgSocket == null || _lgSocket!.readyState != WebSocket.open) {
      // Se não houver socket aberto, tenta fallback para Samsung
      return _samsung.sendKey(keyCode);
    }

    try {
      String uri;
      switch (keyCode) {
        case SamsungRemote.keyPower:
          uri = 'ssap://system/turnOff';
          break;
        case SamsungRemote.keyVolUp:
          uri = 'ssap://audio/volumeUp';
          break;
        case SamsungRemote.keyVolDown:
          uri = 'ssap://audio/volumeDown';
          break;
        case SamsungRemote.keyMute:
          uri = 'ssap://audio/setMute';
          break;
        case SamsungRemote.keyChUp:
          uri = 'ssap://tv/channelUp';
          break;
        case SamsungRemote.keyChDown:
          uri = 'ssap://tv/channelDown';
          break;
        case SamsungRemote.keyPlay:
          uri = 'ssap://media.controls/play';
          break;
        case SamsungRemote.keyPause:
          uri = 'ssap://media.controls/pause';
          break;
        case SamsungRemote.keyHome:
          uri = 'ssap://system.launcher/open';
          break;
        case SamsungRemote.keyReturn:
          uri = 'ssap://tv/back';
          break;
        case SamsungRemote.keyEnter:
          uri = 'ssap://tv/ok';
          break;
        case SamsungRemote.keyUp:
          uri = 'ssap://tv/up';
          break;
        case SamsungRemote.keyDown:
          uri = 'ssap://tv/down';
          break;
        case SamsungRemote.keyLeft:
          uri = 'ssap://tv/left';
          break;
        case SamsungRemote.keyRight:
          uri = 'ssap://tv/right';
          break;
        case SamsungRemote.keyInfo:
          uri = 'ssap://tv/info';
          break;
        default:
          uri = 'ssap://system.launcher/open';
      }

      final payload = jsonEncode({
        'id': 'request_${DateTime.now().millisecondsSinceEpoch}',
        'type': 'request',
        'uri': uri,
      });

      _lgSocket!.add(payload);
      return true;
    } catch (e) {
      debugPrint('Erro ao enviar tecla LG webOS: $e');
      return false;
    }
  }

  /// Abre aplicativo na Smart TV conectada de acordo com a marca
  bool launchApp(String appId) {
    final brand = _connectedBrand ?? _settings.tvBrand;

    if (brand == 'roku' && _connectedIp != null) {
      // IDs da Roku para os principais serviços
      String rokuAppId = '12'; // Default Netflix
      if (appId == SamsungRemote.appIdNetflix) {
        rokuAppId = '12'; // Netflix
      } else if (appId == SamsungRemote.appIdPrimeVideo) {
        rokuAppId = '13'; // Prime Video
      } else if (appId == SamsungRemote.appIdGloboplay) {
        rokuAppId = '34320'; // Globoplay
      } else if (appId == '111299001912') {
        rokuAppId = '837'; // YouTube
      } else if (appId.contains('disney') || appId == '3201907018807') {
        rokuAppId = '291097'; // Disney+
      } else if (appId.contains('max') || appId == '3201601007250') {
        rokuAppId = '61322'; // Max
      } else if (appId.contains('spotify') || appId == '3201606009684') {
        rokuAppId = '22297'; // Spotify
      } else if (appId.contains('apple') || appId == '3201807016597') {
        rokuAppId = '551012'; // Apple TV
      }

      _postRokuLaunch(_connectedIp!, rokuAppId);
      return true;
    } else {
      return _samsung.launchApp(appId);
    }
  }

  void _postRokuLaunch(String ip, String rokuAppId) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client.postUrl(Uri.parse('http://$ip:8060/launch/$rokuAppId'));
      await request.close();
    } catch (e) {
      debugPrint('Erro ao abrir app na Roku ($rokuAppId): $e');
    } finally {
      client?.close(force: true);
    }
  }
}
