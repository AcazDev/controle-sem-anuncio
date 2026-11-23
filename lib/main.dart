import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'neu_button.dart';
import 'samsung_remote.dart';
import 'tv_dialog.dart';
import 'settings_manager.dart';
import 'settings_dialog.dart';
import 'about_dialog.dart';
import 'voice_search_dialog.dart';
import 'tv_remote_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ControleRemotoApp());
}

class ControleRemotoApp extends StatefulWidget {
  const ControleRemotoApp({super.key});

  @override
  State<ControleRemotoApp> createState() => _ControleRemotoAppState();
}

class _ControleRemotoAppState extends State<ControleRemotoApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString('app_theme_mode');
    if (savedMode != null && mounted) {
      setState(() {
        if (savedMode == 'light') {
          _themeMode = ThemeMode.light;
        } else if (savedMode == 'dark') {
          _themeMode = ThemeMode.dark;
        } else {
          _themeMode = ThemeMode.system;
        }
      });
    }
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.dark;
        prefs.setString('app_theme_mode', 'dark');
      } else if (_themeMode == ThemeMode.dark) {
        _themeMode = ThemeMode.system;
        prefs.setString('app_theme_mode', 'system');
      } else {
        _themeMode = ThemeMode.light;
        prefs.setString('app_theme_mode', 'light');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const lightBg = Color(0xFFE8EBF2);
    const darkBg = Color(0xFF1B1C20);

    return MaterialApp(
      title: 'Controle Sem Anuncio',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: lightBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1254A8),
          brightness: Brightness.light,
          surface: lightBg,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3876D8),
          brightness: Brightness.dark,
          surface: darkBg,
        ),
      ),
      home: RemoteScreen(
        currentThemeMode: _themeMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class RemoteScreen extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final VoidCallback onToggleTheme;

  const RemoteScreen({
    super.key,
    required this.currentThemeMode,
    required this.onToggleTheme,
  });

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  final UniversalRemote _remote = UniversalRemote();
  final SettingsManager _settings = SettingsManager();
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _remote.init();
    _settings.addListener(_onSettingsUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initApp();
    });
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsUpdate);
    super.dispose();
  }

  void _onSettingsUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initApp() async {
    await _settings.loadSettings();

    // Exibe a página Sobre na primeira vez que o aplicativo for aberto
    final prefs = await SharedPreferences.getInstance();
    final hasSeenAbout = prefs.getBool('has_seen_about_dialog_first_time') ?? false;
    if (!hasSeenAbout && mounted) {
      await prefs.setBool('has_seen_about_dialog_first_time', true);
      await AboutAppDialog.show(context);
    }

    if (_settings.autoConnect && mounted) {
      _initConnection();
    }
  }

  Future<void> _initConnection() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('last_tv_ip');
    final savedName = prefs.getString('last_tv_name');
    final savedBrand = prefs.getString('last_tv_brand');

    if (savedIp != null && savedIp.isNotEmpty) {
      _remote.connect(savedIp, tvName: savedName, brand: savedBrand);
    } else {
      if (mounted) {
        TvConnectionDialog.show(context);
      }
    }
  }

  void _sendKey(String keyCode) {
    final sent = _remote.sendKey(keyCode);
    if (!sent && _remote.status != TvConnectionStatus.conectado) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('TV não conectada. Toque no ícone de TV no topo para conectar.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Conectar',
            onPressed: () => TvConnectionDialog.show(context),
          ),
        ),
      );
    }
  }

  void _openApp(String appId, String appName) {
    final sent = _remote.launchApp(appId);
    if (!sent && _remote.status != TvConnectionStatus.conectado) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Conecte à TV para abrir $appName.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showNumberPadSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF222328) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Teclado Numérico',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                for (var row in [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                  ['INFO', '0', 'MENU'],
                ]) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: row.map((keyLabel) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: NeuButton(
                          width: 72,
                          height: 52,
                          borderRadius: 14,
                          onPressed: () {
                            if (keyLabel == 'INFO') {
                              _sendKey(SamsungRemote.keyInfo);
                            } else if (keyLabel == 'MENU') {
                              _sendKey(SamsungRemote.keyMenu);
                            } else {
                              _sendKey('KEY_$keyLabel');
                            }
                          },
                          child: Text(
                            keyLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showColorPadSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF222328) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Botões Coloridos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildColorNeuButton('A', Colors.red, SamsungRemote.keyRed, 'Vermelho'),
                    _buildColorNeuButton('B', Colors.green, SamsungRemote.keyGreen, 'Verde'),
                    _buildColorNeuButton('C', Colors.amber.shade700, SamsungRemote.keyYellow, 'Amarelo'),
                    _buildColorNeuButton('D', Colors.blue, SamsungRemote.keyCyan, 'Azul'),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorNeuButton(String label, Color color, String keyCode, String tooltip) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NeuButton(
          width: 58,
          height: 58,
          isCircle: true,
          tooltip: tooltip,
          onPressed: () => _sendKey(keyCode),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF2C3038);
    final secondaryTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Barra superior
                  _buildTopBar(isDark, secondaryTextColor),

                  const SizedBox(height: 16),

                  // 2. Linha Power, SAMSUNG, Source
                  _buildPowerLine(primaryTextColor),

                  const SizedBox(height: 18),

                  // 3. Linha 123, Mudo, Cores
                  _buildNumMuteColorsLine(primaryTextColor),

                  const SizedBox(height: 22),

                  // 4. Anel Direcional (D-Pad) grande
                  _buildDirectionalPad(isDark),

                  const SizedBox(height: 22),

                  // 5. Linha Voltar, Home, Play/Pause
                  _buildNavLine(primaryTextColor),

                  const SizedBox(height: 22),

                  // 6. Dois Balancins (VOL e CH)
                  _buildRockersLine(isDark, primaryTextColor),

                  const SizedBox(height: 26),

                  // 7. Três botões de atalho (Netflix, Prime Video, Globoplay)
                  _buildAppShortcuts(isDark),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark, Color secondaryTextColor) {
    return ValueListenableBuilder<TvConnectionStatus>(
      valueListenable: _remote.statusNotifier,
      builder: (context, status, _) {
        Color statusColor;
        String statusText;

        switch (status) {
          case TvConnectionStatus.conectado:
            statusColor = Colors.greenAccent.shade700;
            final tvName = _remote.currentTvNameNotifier.value ?? _remote.currentIp ?? '';
            statusText = tvName.isNotEmpty ? 'Conectado ($tvName)' : 'Conectado';
            break;
          case TvConnectionStatus.conectando:
            statusColor = Colors.amber.shade700;
            statusText = 'Conectando...';
            break;
          case TvConnectionStatus.desconectado:
            statusColor = Colors.redAccent.shade700;
            statusText = 'Desconectado';
            break;
        }

        IconData themeIcon;
        if (widget.currentThemeMode == ThemeMode.light) {
          themeIcon = Icons.light_mode;
        } else if (widget.currentThemeMode == ThemeMode.dark) {
          themeIcon = Icons.dark_mode;
        } else {
          themeIcon = Icons.brightness_auto;
        }

        return Row(
          children: [
            // Indicador de status
            Expanded(
              child: GestureDetector(
                onTap: () => TvConnectionDialog.show(context),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        statusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: secondaryTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 1. Botão de Busca / Conectar TV
            NeuButton(
              width: 36,
              height: 36,
              isCircle: true,
              padding: EdgeInsets.zero,
              tooltip: 'Buscar / Conectar TV',
              onPressed: () => TvConnectionDialog.show(context),
              child: const Icon(Icons.settings_remote, size: 17),
            ),

            const SizedBox(width: 6),

            // 2. Botão de alternar tema (Automático / Claro / Escuro)
            NeuButton(
              width: 36,
              height: 36,
              isCircle: true,
              padding: EdgeInsets.zero,
              tooltip: 'Tema (Automático / Claro / Escuro)',
              onPressed: widget.onToggleTheme,
              child: Icon(themeIcon, size: 17),
            ),

            const SizedBox(width: 6),

            // 3. Botão de Configurações (Ícone de engrenagem)
            NeuButton(
              width: 36,
              height: 36,
              isCircle: true,
              padding: EdgeInsets.zero,
              tooltip: 'Configurações',
              onPressed: () => SettingsDialog.show(context),
              child: const Icon(Icons.settings_outlined, size: 17),
            ),

            const SizedBox(width: 6),

            // 4. Botão Sobre (?)
            NeuButton(
              width: 36,
              height: 36,
              isCircle: true,
              padding: EdgeInsets.zero,
              tooltip: 'Sobre o Aplicativo',
              onPressed: () => AboutAppDialog.show(context),
              child: const Icon(Icons.help_outline_rounded, size: 17),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPowerLine(Color primaryTextColor) {
    final brand = _settings.currentBrandOption;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Power (vermelho)
        NeuButton(
          width: 50,
          height: 50,
          isCircle: true,
          tooltip: 'Ligar / Desligar',
          onPressed: () => _sendKey(SamsungRemote.keyPower),
          child: const Icon(
            Icons.power_settings_new,
            color: Color(0xFFE53935),
            size: 24,
          ),
        ),

        // Rótulo da marca de acordo com o modelo selecionado (ex: SAMSUNG, LG webOS, ROKU TV, etc.)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            brand.remoteBrandText,
            key: ValueKey(brand.id),
            style: TextStyle(
              letterSpacing: brand.id == 'samsung' ? 4.0 : 2.5,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: brand.brandColor.withOpacity(0.9),
            ),
          ),
        ),

        // Source
        NeuButton(
          width: 50,
          height: 50,
          isCircle: true,
          tooltip: 'Fonte de Entrada (Source)',
          onPressed: () => _sendKey(SamsungRemote.keySource),
          child: const Icon(Icons.input, size: 20),
        ),
      ],
    );
  }

  Widget _buildNumMuteColorsLine(Color primaryTextColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Botão "123"
        NeuButton(
          width: 58,
          height: 44,
          borderRadius: 14,
          tooltip: 'Teclado Numérico',
          onPressed: _showNumberPadSheet,
          child: const Text(
            '123',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),

        // Botão Central: Microfone (se ativado nas configurações) ou Mudo (se desativado)
        if (_settings.voiceSearchEnabled)
          NeuButton(
            width: 58,
            height: 44,
            borderRadius: 14,
            tooltip: 'Busca por Voz (Microfone)',
            onPressed: () => VoiceSearchDialog.show(context),
            child: const Icon(
              Icons.mic,
              size: 22,
              color: Color(0xFF1254A8),
            ),
          )
        else
          NeuButton(
            width: 58,
            height: 44,
            borderRadius: 14,
            tooltip: 'Mudo',
            onPressed: () => _sendKey(SamsungRemote.keyMute),
            child: const Icon(Icons.volume_off, size: 20),
          ),

        // Botão 4 Cores (Vermelho, Verde, Amarelo, Azul)
        NeuButton(
          width: 58,
          height: 44,
          borderRadius: 14,
          tooltip: 'Botões Coloridos',
          onPressed: _showColorPadSheet,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tinyDot(Colors.red),
              const SizedBox(width: 3),
              _tinyDot(Colors.green),
              const SizedBox(width: 3),
              _tinyDot(Colors.amber),
              const SizedBox(width: 3),
              _tinyDot(Colors.blue),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tinyDot(Color color) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildDirectionalPad(bool isDark) {
    // Anel direcional grande com botões e OK central
    final padBaseColor = isDark ? const Color(0xFF25262B) : const Color(0xFFDEE1E8);

    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: padBaseColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0xFF33353C) : Colors.white,
            offset: const Offset(-5, -5),
            blurRadius: 10,
          ),
          BoxShadow(
            color: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFB0B6C7),
            offset: const Offset(5, 5),
            blurRadius: 10,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Seta Cima
          Positioned(
            top: 10,
            child: NeuButton(
              width: 56,
              height: 46,
              isFlat: true,
              isRepeat: true,
              tooltip: 'Cima',
              onPressed: () => _sendKey(SamsungRemote.keyUp),
              child: const Icon(Icons.keyboard_arrow_up, size: 28),
            ),
          ),

          // Seta Baixo
          Positioned(
            bottom: 10,
            child: NeuButton(
              width: 56,
              height: 46,
              isFlat: true,
              isRepeat: true,
              tooltip: 'Baixo',
              onPressed: () => _sendKey(SamsungRemote.keyDown),
              child: const Icon(Icons.keyboard_arrow_down, size: 28),
            ),
          ),

          // Seta Esquerda
          Positioned(
            left: 10,
            child: NeuButton(
              width: 46,
              height: 56,
              isFlat: true,
              isRepeat: true,
              tooltip: 'Esquerda',
              onPressed: () => _sendKey(SamsungRemote.keyLeft),
              child: const Icon(Icons.keyboard_arrow_left, size: 28),
            ),
          ),

          // Seta Direita
          Positioned(
            right: 10,
            child: NeuButton(
              width: 46,
              height: 56,
              isFlat: true,
              isRepeat: true,
              tooltip: 'Direita',
              onPressed: () => _sendKey(SamsungRemote.keyRight),
              child: const Icon(Icons.keyboard_arrow_right, size: 28),
            ),
          ),

          // Botão Central "OK"
          NeuButton(
            width: 74,
            height: 74,
            isCircle: true,
            tooltip: 'Confirmar / OK',
            onPressed: () => _sendKey(SamsungRemote.keyEnter),
            child: const Text(
              'OK',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavLine(Color primaryTextColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Voltar (KEY_RETURN)
        NeuButton(
          width: 54,
          height: 50,
          borderRadius: 16,
          tooltip: 'Voltar',
          onPressed: () => _sendKey(SamsungRemote.keyReturn),
          child: const Icon(Icons.undo, size: 20),
        ),

        // Home (KEY_HOME)
        NeuButton(
          width: 54,
          height: 50,
          borderRadius: 16,
          tooltip: 'Início (Home)',
          onPressed: () => _sendKey(SamsungRemote.keyHome),
          child: const Icon(Icons.home, size: 22),
        ),

        // Play / Pause
        NeuButton(
          width: 54,
          height: 50,
          borderRadius: 16,
          tooltip: _isPlaying ? 'Pausar' : 'Reproduzir',
          onPressed: () {
            if (_isPlaying) {
              _sendKey(SamsungRemote.keyPause);
            } else {
              _sendKey(SamsungRemote.keyPlay);
            }
            setState(() => _isPlaying = !_isPlaying);
          },
          child: Icon(
            _isPlaying ? Icons.pause : Icons.play_arrow,
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildRockersLine(bool isDark, Color primaryTextColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Balancim Volume (VOL)
        _buildRocker(
          label: 'VOL',
          topIcon: Icons.add,
          bottomIcon: Icons.remove,
          topTooltip: 'Aumentar Volume',
          bottomTooltip: 'Diminuir Volume',
          onTopPressed: () => _sendKey(SamsungRemote.keyVolUp),
          onBottomPressed: () => _sendKey(SamsungRemote.keyVolDown),
          isDark: isDark,
          primaryTextColor: primaryTextColor,
        ),

        const SizedBox(width: 24),

        // Balancim Canais (CH)
        _buildRocker(
          label: 'CH',
          topIcon: Icons.keyboard_arrow_up,
          bottomIcon: Icons.keyboard_arrow_down,
          topTooltip: 'Próximo Canal',
          bottomTooltip: 'Canal Anterior',
          onTopPressed: () => _sendKey(SamsungRemote.keyChUp),
          onBottomPressed: () => _sendKey(SamsungRemote.keyChDown),
          isDark: isDark,
          primaryTextColor: primaryTextColor,
        ),
      ],
    );
  }

  Widget _buildRocker({
    required String label,
    required IconData topIcon,
    required IconData bottomIcon,
    required String topTooltip,
    required String bottomTooltip,
    required VoidCallback onTopPressed,
    required VoidCallback onBottomPressed,
    required bool isDark,
    required Color primaryTextColor,
  }) {
    final rockerBg = isDark ? const Color(0xFF25262B) : const Color(0xFFDEE1E8);

    return Container(
      width: 66,
      height: 142,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: rockerBg,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0xFF33353C) : Colors.white,
            offset: const Offset(-4, -4),
            blurRadius: 8,
          ),
          BoxShadow(
            color: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFB0B6C7),
            offset: const Offset(4, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botão Superior com repetição contínua
          NeuButton(
            width: 54,
            height: 42,
            isFlat: true,
            isRepeat: true,
            borderRadius: 22,
            tooltip: topTooltip,
            onPressed: onTopPressed,
            child: Icon(topIcon, size: 22),
          ),

          // Rótulo Central
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: primaryTextColor.withOpacity(0.7),
            ),
          ),

          // Botão Inferior com repetição contínua
          NeuButton(
            width: 54,
            height: 42,
            isFlat: true,
            isRepeat: true,
            borderRadius: 22,
            tooltip: bottomTooltip,
            onPressed: onBottomPressed,
            child: Icon(bottomIcon, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildAppShortcuts(bool isDark) {
    final activeShortcuts = _settings.activeStreamingShortcuts;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: activeShortcuts.map((shortcut) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: NeuButton(
              height: 44,
              borderRadius: 14,
              tooltip: 'Abrir ${shortcut.displayName}',
              baseColor: isDark ? shortcut.backgroundColor : const Color(0xFFF0F3F8),
              onPressed: () => _openApp(shortcut.appId, shortcut.displayName),
              child: Text(
                shortcut.buttonLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: shortcut.textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: activeShortcuts.length > 3 ? 10 : 11,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
