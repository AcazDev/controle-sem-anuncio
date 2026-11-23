import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'samsung_remote.dart';

/// Modelo de marca de TV / estilo do controle
class TvBrandOption {
  final String id;
  final String displayName;
  final String remoteBrandText;
  final Color brandColor;
  final IconData icon;
  final String description;

  const TvBrandOption({
    required this.id,
    required this.displayName,
    required this.remoteBrandText,
    required this.brandColor,
    required this.icon,
    required this.description,
  });
}

/// Modelo de aplicativo de streaming para os atalhos
class StreamingAppOption {
  final String id;
  final String displayName;
  final String buttonLabel;
  final String appId;
  final Color backgroundColor;
  final Color textColor;
  final IconData icon;

  const StreamingAppOption({
    required this.id,
    required this.displayName,
    required this.buttonLabel,
    required this.appId,
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
  });
}

/// Gerenciador reativo de preferências do aplicativo
class SettingsManager extends ChangeNotifier {
  static final SettingsManager _instance = SettingsManager._internal();
  factory SettingsManager() => _instance;
  SettingsManager._internal();

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  // 1. Manter conectado / Conexão automática
  bool _autoConnect = true;
  bool get autoConnect => _autoConnect;

  // 2. Modelo / Design de acordo com a marca da TV
  String _tvBrand = 'samsung';
  String get tvBrand => _tvBrand;

  // 3. Atalhos de streaming selecionados
  List<String> _selectedShortcuts = ['netflix', 'prime_video', 'globoplay'];
  List<String> get selectedShortcuts => List.unmodifiable(_selectedShortcuts);

  // 4. Ativar busca por voz (botão de microfone)
  bool _voiceSearchEnabled = true;
  bool get voiceSearchEnabled => _voiceSearchEnabled;

  // Catálogo de Marcas suportadas
  static const List<TvBrandOption> supportedBrands = [
    TvBrandOption(
      id: 'samsung',
      displayName: 'Samsung',
      remoteBrandText: 'SAMSUNG',
      brandColor: Color(0xFF1254A8),
      icon: Icons.tv,
      description: 'Design Smart Remote Tizen moderno',
    ),
    TvBrandOption(
      id: 'lg',
      displayName: 'LG (webOS)',
      remoteBrandText: 'LG webOS',
      brandColor: Color(0xFFA50034),
      icon: Icons.smart_screen,
      description: 'Estilo inspirado no Magic Remote LG',
    ),
    TvBrandOption(
      id: 'roku',
      displayName: 'Roku TV',
      remoteBrandText: 'ROKU TV',
      brandColor: Color(0xFF662D91),
      icon: Icons.live_tv,
      description: 'Design característico roxo e intuitivo',
    ),
    TvBrandOption(
      id: 'android_tv',
      displayName: 'Android / Google TV',
      remoteBrandText: 'GOOGLE TV',
      brandColor: Color(0xFF34A853),
      icon: Icons.android,
      description: 'Estilo minimalista Google / Chromecast',
    ),
    TvBrandOption(
      id: 'universal',
      displayName: 'Universal',
      remoteBrandText: 'UNIVERSAL',
      brandColor: Color(0xFF455A64),
      icon: Icons.settings_remote,
      description: 'Design neutro e versátil para todas as TVs',
    ),
  ];

  // Catálogo completo de Serviços de Streaming
  static const List<StreamingAppOption> availableStreamingApps = [
    StreamingAppOption(
      id: 'netflix',
      displayName: 'Netflix',
      buttonLabel: 'NETFLIX',
      appId: SamsungRemote.appIdNetflix,
      backgroundColor: Color(0xFF282424),
      textColor: Color(0xFFE50914),
      icon: Icons.movie_outlined,
    ),
    StreamingAppOption(
      id: 'prime_video',
      displayName: 'Prime Video',
      buttonLabel: 'prime video',
      appId: SamsungRemote.appIdPrimeVideo,
      backgroundColor: Color(0xFF22262B),
      textColor: Color(0xFF00A8E1),
      icon: Icons.play_arrow_outlined,
    ),
    StreamingAppOption(
      id: 'globoplay',
      displayName: 'Globoplay',
      buttonLabel: 'globo play',
      appId: SamsungRemote.appIdGloboplay,
      backgroundColor: Color(0xFF2B2222),
      textColor: Color(0xFFFB1548),
      icon: Icons.play_circle_outline,
    ),
    StreamingAppOption(
      id: 'youtube',
      displayName: 'YouTube',
      buttonLabel: 'YouTube',
      appId: '111299001912',
      backgroundColor: Color(0xFF2B2222),
      textColor: Color(0xFFFF0000),
      icon: Icons.video_library_outlined,
    ),
    StreamingAppOption(
      id: 'disney',
      displayName: 'Disney+',
      buttonLabel: 'Disney+',
      appId: '3201907018807',
      backgroundColor: Color(0xFF1B233A),
      textColor: Color(0xFF2D84FB),
      icon: Icons.star_border,
    ),
    StreamingAppOption(
      id: 'max',
      displayName: 'Max (HBO)',
      buttonLabel: 'MAX',
      appId: '3201601007250',
      backgroundColor: Color(0xFF1E2138),
      textColor: Color(0xFF0052FF),
      icon: Icons.theaters_outlined,
    ),
    StreamingAppOption(
      id: 'spotify',
      displayName: 'Spotify',
      buttonLabel: 'Spotify',
      appId: '3201606009684',
      backgroundColor: Color(0xFF1E2922),
      textColor: Color(0xFF1DB954),
      icon: Icons.music_note_outlined,
    ),
    StreamingAppOption(
      id: 'apple_tv',
      displayName: 'Apple TV+',
      buttonLabel: 'tv+',
      appId: '3201807016597',
      backgroundColor: Color(0xFF262626),
      textColor: Color(0xFFD4D4D4),
      icon: Icons.tv,
    ),
  ];

  TvBrandOption get currentBrandOption {
    return supportedBrands.firstWhere(
      (b) => b.id == _tvBrand,
      orElse: () => supportedBrands.first,
    );
  }

  List<StreamingAppOption> get activeStreamingShortcuts {
    final list = <StreamingAppOption>[];
    for (final id in _selectedShortcuts) {
      final app = availableStreamingApps.firstWhere(
        (a) => a.id == id,
        orElse: () => availableStreamingApps.first,
      );
      if (!list.contains(app)) {
        list.add(app);
      }
    }
    return list.isEmpty ? [availableStreamingApps[0], availableStreamingApps[1], availableStreamingApps[2]] : list;
  }

  /// Inicializa e carrega preferências salvas
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _autoConnect = prefs.getBool('setting_auto_connect') ?? true;
    _tvBrand = prefs.getString('setting_tv_brand') ?? 'samsung';
    _voiceSearchEnabled = prefs.getBool('setting_voice_search') ?? true;

    final savedShortcuts = prefs.getStringList('setting_streaming_shortcuts');
    if (savedShortcuts != null && savedShortcuts.isNotEmpty) {
      _selectedShortcuts = savedShortcuts;
    } else {
      _selectedShortcuts = ['netflix', 'prime_video', 'globoplay'];
    }

    _isLoaded = true;
    notifyListeners();
  }

  /// Alterna a opção de auto-conexão
  Future<void> setAutoConnect(bool value) async {
    _autoConnect = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setting_auto_connect', value);
  }

  /// Altera o modelo / design de acordo com a marca da TV
  Future<void> setTvBrand(String brandId) async {
    _tvBrand = brandId;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('setting_tv_brand', brandId);
  }

  /// Ativa ou desativa a busca por voz (microfone)
  Future<void> setVoiceSearchEnabled(bool value) async {
    _voiceSearchEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setting_voice_search', value);
  }

  /// Alterna a seleção de um atalho de streaming (mantendo entre 1 e 4 selecionados)
  Future<bool> toggleStreamingShortcut(String shortcutId) async {
    final current = List<String>.from(_selectedShortcuts);
    if (current.contains(shortcutId)) {
      if (current.length <= 1) {
        // Precisa ter pelo menos 1 atalho selecionado
        return false;
      }
      current.remove(shortcutId);
    } else {
      if (current.length >= 4) {
        // Limite máximo de 4 botões na linha
        return false;
      }
      current.add(shortcutId);
    }

    _selectedShortcuts = current;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('setting_streaming_shortcuts', current);
    return true;
  }
}

