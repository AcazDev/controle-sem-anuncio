import 'package:flutter/material.dart';
import 'settings_manager.dart';

/// Diálogo de configurações do aplicativo
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const SettingsDialog(),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final SettingsManager _settings = SettingsManager();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E2024) : Colors.white;
    final sectionBg = isDark ? const Color(0xFF26282E) : const Color(0xFFF3F5FA);
    final primaryText = isDark ? Colors.white : const Color(0xFF2C3038);
    final secondaryText = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: dialogBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 12, top: 16, bottom: 8),
              child: Row(
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
                          Icons.settings_outlined,
                          color: Color(0xFF1254A8),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Configurações',
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
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Lista de configurações
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. CONEXÃO AUTOMÁTICA
                    _buildSectionTitle('CONEXÃO & VÍNCULO', primaryText),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: sectionBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                        ),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        activeColor: const Color(0xFF1254A8),
                        title: Text(
                          'Conectar automaticamente',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryText,
                          ),
                        ),
                        subtitle: Text(
                          'Manter conectado ou reconectar automaticamente após o primeiro vínculo com a TV',
                          style: TextStyle(fontSize: 12, color: secondaryText),
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1254A8).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.cable, color: Color(0xFF1254A8), size: 20),
                        ),
                        value: _settings.autoConnect,
                        onChanged: (val) {
                          setState(() {
                            _settings.setAutoConnect(val);
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 2. MODELO / DESIGN DO CONTROLE (MARCA DA TV)
                    _buildSectionTitle('MODELO & DESIGN DO CONTROLE', primaryText),
                    const SizedBox(height: 8),
                    Text(
                      'Altere o design, logotipo e estilo de acordo com a marca da sua TV:',
                      style: TextStyle(fontSize: 12, color: secondaryText),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: sectionBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                        ),
                      ),
                      child: Column(
                        children: SettingsManager.supportedBrands.map((brand) {
                          final isSelected = _settings.tvBrand == brand.id;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  _settings.setTvBrand(brand.id);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? brand.brandColor.withOpacity(isDark ? 0.25 : 0.12)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? brand.brandColor : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: brand.brandColor.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(brand.icon, color: brand.brandColor, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            brand.displayName,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                              color: isSelected ? brand.brandColor : primaryText,
                                            ),
                                          ),
                                          Text(
                                            brand.description,
                                            style: TextStyle(fontSize: 11, color: secondaryText),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.check_circle, color: brand.brandColor, size: 20)
                                    else
                                      Icon(Icons.circle_outlined, color: Colors.grey.shade400, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 3. ATALHOS DE STREAMING DO CONTROLE
                    _buildSectionTitle('ATALHOS DE STREAMING', primaryText),
                    const SizedBox(height: 8),
                    Text(
                      'Selecione de 1 até 4 aplicativos favoritos para os botões dedicados do controle:',
                      style: TextStyle(fontSize: 12, color: secondaryText),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: sectionBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                        ),
                      ),
                      child: Column(
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: SettingsManager.availableStreamingApps.map((app) {
                              final isSelected = _settings.selectedShortcuts.contains(app.id);
                              return FilterChip(
                                selected: isSelected,
                                showCheckmark: true,
                                checkmarkColor: app.textColor,
                                label: Text(
                                  app.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? app.textColor : primaryText,
                                  ),
                                ),
                                avatar: Icon(app.icon, size: 16, color: app.textColor),
                                backgroundColor: isDark ? const Color(0xFF2C2F36) : Colors.white,
                                selectedColor: app.textColor.withOpacity(0.18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: isSelected ? app.textColor : Colors.transparent,
                                  ),
                                ),
                                onSelected: (val) async {
                                  final ok = await _settings.toggleStreamingShortcut(app.id);
                                  if (!ok && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Selecione entre 1 e 4 atalhos de streaming.'),
                                        duration: Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                  setState(() {});
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          // Pré-visualização dos botões atuais
                          Text(
                            'Prévia no controle:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: secondaryText),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: _settings.activeStreamingShortcuts.map((shortcut) {
                              return Expanded(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? shortcut.backgroundColor : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: shortcut.textColor.withOpacity(0.4)),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    shortcut.buttonLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: shortcut.textColor,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 4. ATIVAR BOTÃO DE MICROFONE (BUSCA POR VOZ)
                    _buildSectionTitle('BUSCA POR VOZ / ÁUDIO', primaryText),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: sectionBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                        ),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        activeColor: const Color(0xFF1254A8),
                        title: Text(
                          'Botão de Microfone (Busca por Voz)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryText,
                          ),
                        ),
                        subtitle: Text(
                          'Ativa o botão de microfone no controle para pesquisar por voz caso a TV suporte recurso de áudio',
                          style: TextStyle(fontSize: 12, color: secondaryText),
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1254A8).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.mic, color: Color(0xFF1254A8), size: 20),
                        ),
                        value: _settings.voiceSearchEnabled,
                        onChanged: (val) {
                          setState(() {
                            _settings.setVoiceSearchEnabled(val);
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Botão Fechar / Pronto
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1254A8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Concluído', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
        color: textColor.withOpacity(0.7),
      ),
    );
  }
}

