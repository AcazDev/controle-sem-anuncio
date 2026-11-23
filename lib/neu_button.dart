import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget com estética neumórfica 3D (Neu3D) para botões do controle remoto.
/// Suporta modo normal, circular, flat e repetição contínua ao manter pressionado.
class NeuButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final double borderRadius;
  final bool isCircle;
  final bool isFlat;
  final bool isRepeat;
  final Color? baseColor;
  final Color? lightShadowColor;
  final Color? darkShadowColor;
  final EdgeInsetsGeometry? padding;
  final String? tooltip;

  const NeuButton({
    super.key,
    required this.child,
    this.onPressed,
    this.width,
    this.height,
    this.borderRadius = 22.0,
    this.isCircle = false,
    this.isFlat = false,
    this.isRepeat = false,
    this.baseColor,
    this.lightShadowColor,
    this.darkShadowColor,
    this.padding,
    this.tooltip,
  });

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _isPressed = false;
  Timer? _initialTimer;
  Timer? _periodicTimer;

  void _triggerPress() {
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  void _handleTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    _triggerPress();

    if (widget.isRepeat) {
      _initialTimer?.cancel();
      _periodicTimer?.cancel();

      // Espera inicial de 400 ms e depois dispara a cada 120 ms
      _initialTimer = Timer(const Duration(milliseconds: 400), () {
        _periodicTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
          _triggerPress();
        });
      });
    }
  }

  void _handleTapUp(TapUpDetails _) {
    _cleanupPress();
  }

  void _handleTapCancel() {
    _cleanupPress();
  }

  void _cleanupPress() {
    _initialTimer?.cancel();
    _periodicTimer?.cancel();
    _initialTimer = null;
    _periodicTimer = null;
    if (mounted && _isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  void dispose() {
    _initialTimer?.cancel();
    _periodicTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Paleta de cores do tema
    final defaultBaseColor = isDark ? const Color(0xFF2A2B31) : const Color(0xFFE8EBF2);
    final baseColor = widget.baseColor ?? defaultBaseColor;

    final lightShadow = widget.lightShadowColor ??
        (isDark ? const Color(0xFF3C3E46) : const Color(0xFFFFFFFF));
    final darkShadow = widget.darkShadowColor ??
        (isDark ? const Color(0xFF0E0F12) : const Color(0xFFB4BACB));

    // Variações de tom para o gradiente diagonal
    final highlight = Color.alphaBlend(
      isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.45),
      baseColor,
    );
    final lowlight = Color.alphaBlend(
      isDark ? Colors.black.withOpacity(0.35) : Colors.black.withOpacity(0.08),
      baseColor,
    );

    // Gradiente normal (claro para escuro) e invertido (quando pressionado)
    final gradient = widget.isFlat && !_isPressed
        ? null
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isPressed ? [lowlight, highlight] : [highlight, lowlight],
          );

    // Duas sombras no estado de repouso; sem sombras quando pressionado (efeito afundado)
    final List<BoxShadow> shadows;
    if (_isPressed || widget.isFlat) {
      shadows = const [];
    } else {
      shadows = [
        BoxShadow(
          color: lightShadow,
          offset: const Offset(-6, -6),
          blurRadius: 12,
        ),
        BoxShadow(
          color: darkShadow,
          offset: const Offset(6, 6),
          blurRadius: 12,
        ),
      ];
    }

    final shape = widget.isCircle ? BoxShape.circle : BoxShape.rectangle;
    final borderRadius = widget.isCircle ? null : BorderRadius.circular(widget.borderRadius);

    Widget content = GestureDetector(
      onTapDown: widget.onPressed != null ? _handleTapDown : null,
      onTapUp: widget.onPressed != null ? _handleTapUp : null,
      onTapCancel: widget.onPressed != null ? _handleTapCancel : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: widget.width,
          height: widget.height,
          padding: widget.padding ?? const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isFlat && !_isPressed ? Colors.transparent : baseColor,
            shape: shape,
            borderRadius: borderRadius,
            gradient: gradient,
            boxShadow: shadows,
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );

    if (widget.tooltip != null) {
      content = Tooltip(
        message: widget.tooltip!,
        child: content,
      );
    }

    return content;
  }
}
