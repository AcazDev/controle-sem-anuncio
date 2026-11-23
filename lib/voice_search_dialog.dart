import 'package:flutter/material.dart';
import 'neu_button.dart';
import 'samsung_remote.dart';
import 'tv_remote_service.dart';

/// Diálogo moderno e interativo de busca por voz com a Smart TV
class VoiceSearchDialog extends StatefulWidget {
  const VoiceSearchDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const VoiceSearchDialog(),
    );
  }

  @override
  State<VoiceSearchDialog> createState() => _VoiceSearchDialogState();
}

class _VoiceSearchDialogState extends State<VoiceSearchDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final TextEditingController _textSearchController = TextEditingController();
  final UniversalRemote _remote = UniversalRemote();
  bool _isListening = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Envia o sinal de ativação de voz para a TV conectada
    _triggerTvVoiceCommand();
  }

  void _triggerTvVoiceCommand() {
    // Tenta comandos comuns de voz e busca suportados pelas Smart TVs
    _remote.sendKey('KEY_VOICE');
  }

  @override
  void dispose() {
    _animController.dispose();
    _textSearchController.dispose();
    super.dispose();
  }

  void _searchOnYoutube(String query) {
    if (query.trim().isEmpty) return;
    _remote.launchApp('111299001912'); // YouTube App
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Buscando "$query" no YouTube da TV...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E2024) : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF2C3038);
    final secondaryText = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final isConnected = _remote.status == TvConnectionStatus.conectado;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: dialogBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra superior do diálogo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1254A8).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mic,
                          color: Color(0xFF1254A8),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Busca por Voz',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Animação de Microfone e Ondas Sonoras
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  final scale = 1.0 + (_animController.value * 0.18);
                  final opacity = 0.6 - (_animController.value * 0.4);

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Onda externa 1
                      Container(
                        width: 110 * scale,
                        height: 110 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1254A8).withOpacity(opacity.clamp(0.0, 1.0)),
                        ),
                      ),
                      // Onda externa 2
                      Container(
                        width: 90 * (1.0 + (_animController.value * 0.1)),
                        height: 90 * (1.0 + (_animController.value * 0.1)),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1254A8).withOpacity(0.2),
                        ),
                      ),
                      // Botão central do Microfone
                      NeuButton(
                        width: 76,
                        height: 76,
                        isCircle: true,
                        tooltip: 'Pressionar para falar',
                        onPressed: () {
                          _triggerTvVoiceCommand();
                          setState(() => _isListening = !_isListening);
                        },
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_off,
                          size: 34,
                          color: const Color(0xFF1254A8),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              // Status e instrução
              Text(
                _isListening
                    ? (isConnected
                        ? 'Ouvindo... Fale o comando ou nome do conteúdo'
                        : 'Comando de voz ativado na TV')
                    : 'Toque no microfone para falar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primaryText,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Caso sua TV possua assistente de voz (Bixby/Alexa/Google), ela responderá ao comando diretamente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryText,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 18),

              // Campo para busca rápida por texto (alternativa prática)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF282A30) : const Color(0xFFF1F3F8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _textSearchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (val) => _searchOnYoutube(val),
                  decoration: InputDecoration(
                    hintText: 'Ou digite para buscar na TV...',
                    hintStyle: TextStyle(fontSize: 13, color: secondaryText),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send_rounded, size: 18),
                      tooltip: 'Enviar busca',
                      onPressed: () => _searchOnYoutube(_textSearchController.text),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Botões de ação rápida
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Pesquisar na TV', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        _remote.sendKey('KEY_SEARCH');
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1254A8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.mic, size: 18),
                      label: const Text('Reenviar Voz', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        _triggerTvVoiceCommand();
                        setState(() => _isListening = true);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
