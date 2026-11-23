import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estados possíveis de conexão com a TV Samsung.
enum TvConnectionStatus {
  desconectado,
  conectando,
  conectado,
}

/// Gerenciador de conexão WebSocket e envio de comandos para Smart TVs Samsung (Tizen 2016+).
class SamsungRemote {
  static final SamsungRemote _instance = SamsungRemote._internal();
  factory SamsungRemote() => _instance;
  SamsungRemote._internal();

  WebSocket? _socket;
  String? _currentIp;
  Timer? _pingTimer;

  final ValueNotifier<TvConnectionStatus> statusNotifier =
      ValueNotifier<TvConnectionStatus>(TvConnectionStatus.desconectado);

  final ValueNotifier<String?> currentTvNameNotifier = ValueNotifier<String?>(null);

  TvConnectionStatus get status => statusNotifier.value;
  String? get currentIp => _currentIp;

  // Identificadores de aplicativos comuns para Samsung Tizen
  static const String appIdNetflix = '11101200001';
  static const String appIdPrimeVideo = '3201512006785';
  // O ID do Globoplay pode variar ligeiramente de acordo com o modelo/ano e região da TV
  static const String appIdGloboplay = '3201807016597';

  // Nomes de teclas suportadas pelo Tizen
  static const String keyPower = 'KEY_POWER';
  static const String keySource = 'KEY_SOURCE';
  static const String keyMute = 'KEY_MUTE';
  static const String keyVolUp = 'KEY_VOLUP';
  static const String keyVolDown = 'KEY_VOLDOWN';
  static const String keyChUp = 'KEY_CHUP';
  static const String keyChDown = 'KEY_CHDOWN';
  static const String keyUp = 'KEY_UP';
  static const String keyDown = 'KEY_DOWN';
  static const String keyLeft = 'KEY_LEFT';
  static const String keyRight = 'KEY_RIGHT';
  static const String keyEnter = 'KEY_ENTER';
  static const String keyReturn = 'KEY_RETURN';
  static const String keyHome = 'KEY_HOME';
  static const String keyPlay = 'KEY_PLAY';
  static const String keyPause = 'KEY_PAUSE';
  static const String keyMenu = 'KEY_MENU';
  static const String keyInfo = 'KEY_INFO';
  static const String keyRed = 'KEY_RED';
  static const String keyGreen = 'KEY_GREEN';
  static const String keyYellow = 'KEY_YELLOW';
  static const String keyCyan = 'KEY_CYAN'; // Botão Azul

  /// Conecta à TV pelo IP informado.
  /// Se houver token salvo para esse IP, ele é enviado na URL.
  Future<bool> connect(String ip, {String? tvName}) async {
    if (status == TvConnectionStatus.conectando && _currentIp == ip) {
      return false;
    }

    await disconnect();

    _currentIp = ip;
    if (tvName != null) {
      currentTvNameNotifier.value = tvName;
    }
    statusNotifier.value = TvConnectionStatus.conectando;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tv_token_$ip');
      final appNameB64 = base64Encode(utf8.encode('Controle Remoto'));

      var url = 'wss://$ip:8002/api/v2/channels/samsung.remote.control?name=$appNameB64';
      if (token != null && token.isNotEmpty) {
        url += '&token=$token';
      }

      // Cliente HTTP que ignora certificados autoassinados da Samsung
      final customClient = HttpClient();
      customClient.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      customClient.connectionTimeout = const Duration(seconds: 8);

      final socket = await WebSocket.connect(
        url,
        customClient: customClient,
      ).timeout(const Duration(seconds: 8));

      _socket = socket;
      statusNotifier.value = TvConnectionStatus.conectado;

      // Salva o último IP utilizado para reconexão automática
      await prefs.setString('last_tv_ip', ip);
      if (tvName != null) {
        await prefs.setString('last_tv_name', tvName);
      }

      _listenToSocket(socket, ip);
      _startHeartbeat();

      return true;
    } catch (e) {
      debugPrint('Erro ao conectar à TV Samsung ($ip): $e');
      _cleanUp();
      statusNotifier.value = TvConnectionStatus.desconectado;
      return false;
    }
  }

  void _listenToSocket(WebSocket socket, String ip) {
    socket.listen(
      (data) async {
        try {
          if (data is String) {
            final json = jsonDecode(data);
            final event = json['event']?.toString();

            if (event == 'ms.channel.connect') {
              // TV conectou com sucesso e pode ter fornecido um novo token
              final eventData = json['data'];
              if (eventData is Map && eventData['token'] != null) {
                final token = eventData['token'].toString();
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('tv_token_$ip', token);
                debugPrint('Token salvo para $ip: $token');
              }
              statusNotifier.value = TvConnectionStatus.conectado;
            } else if (event == 'ms.channel.timeOut' || event == 'ms.error') {
              debugPrint('Evento de desconexão da TV: $event');
              await disconnect();
            }
          }
        } catch (e) {
          debugPrint('Erro ao processar mensagem do WebSocket: $e');
        }
      },
      onError: (err) {
        debugPrint('Erro no WebSocket: $err');
        disconnect();
      },
      onDone: () {
        debugPrint('WebSocket finalizado pela TV');
        disconnect();
      },
      cancelOnError: true,
    );
  }

  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_socket != null && _socket!.readyState == WebSocket.open) {
        try {
          _socket!.pingInterval = const Duration(seconds: 10);
        } catch (_) {}
      } else {
        timer.cancel();
      }
    });
  }

  /// Desconecta do WebSocket atual.
  Future<void> disconnect() async {
    _cleanUp();
    statusNotifier.value = TvConnectionStatus.desconectado;
  }

  void _cleanUp() {
    _pingTimer?.cancel();
    _pingTimer = null;
    try {
      _socket?.close(WebSocketStatus.normalClosure, 'Desconectado pelo usuário');
    } catch (_) {}
    _socket = null;
  }

  /// Envia comando de tecla para a TV Samsung.
  bool sendKey(String keyCode) {
    if (_socket == null || _socket!.readyState != WebSocket.open) {
      debugPrint('Não conectado para enviar tecla: $keyCode');
      return false;
    }

    try {
      final payload = jsonEncode({
        'method': 'ms.remote.control',
        'params': {
          'Cmd': 'Click',
          'DataOfCmd': keyCode,
          'Option': 'false',
          'TypeOfRemote': 'SendRemoteKey',
        },
      });

      _socket!.add(payload);
      return true;
    } catch (e) {
      debugPrint('Falha ao enviar tecla $keyCode: $e');
      return false;
    }
  }

  /// Abre um aplicativo na Smart TV pelo seu App ID.
  bool launchApp(String appId) {
    if (_socket == null || _socket!.readyState != WebSocket.open) {
      debugPrint('Não conectado para abrir app: $appId');
      return false;
    }

    try {
      final payload = jsonEncode({
        'method': 'ms.channel.emit',
        'params': {
          'event': 'ed.apps.launch',
          'to': 'host',
          'data': {
            'action_type': 'DEEP_LINK',
            'appId': appId,
          },
        },
      });

      _socket!.add(payload);
      return true;
    } catch (e) {
      debugPrint('Falha ao abrir app $appId: $e');
      return false;
    }
  }
}

