import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'discovery.dart';
import 'samsung_remote.dart';
import 'tv_remote_service.dart';
import 'settings_manager.dart';

/// Diálogo para busca e conexão com Smart TVs Samsung.
class TvConnectionDialog extends StatefulWidget {
  const TvConnectionDialog({super.key});

  /// Método estático utilitário para exibir o diálogo.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const TvConnectionDialog(),
    );
  }

  @override
  State<TvConnectionDialog> createState() => _TvConnectionDialogState();
}

class _TvConnectionDialogState extends State<TvConnectionDialog> {
  final TvDiscovery _discovery = TvDiscovery();
  StreamSubscription<TvInfo>? _subscription;
  final List<TvInfo> _tvs = [];
  bool _isSearching = false;
  final TextEditingController _ipController = TextEditingController();
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _loadSavedIp();
    _startSearch();
  }

  Future<void> _loadSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('last_tv_ip');
    if (savedIp != null && savedIp.isNotEmpty && mounted) {
      _ipController.text = savedIp;
    }
  }

  void _startSearch() {
    setState(() {
      _tvs.clear();
      _isSearching = true;
    });

    _subscription?.cancel();
    _subscription = _discovery.startDiscovery().listen(
      (tv) {
        if (mounted) {
          setState(() {
            if (!_tvs.contains(tv)) {
              _tvs.add(tv);
            }
          });
        }
      },
      onError: (err) {
        debugPrint('Erro na stream de busca: $err');
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
      },
    );
  }

  Future<void> _connectToTv(String ip, {String? name, String? brand}) async {
    final cleanIp = ip.trim();
    if (cleanIp.isEmpty) return;

    setState(() => _isConnecting = true);

    if (brand != null) {
      await SettingsManager().setTvBrand(brand);
    }

    final remote = UniversalRemote();
    final success = await remote.connect(cleanIp, tvName: name, brand: brand);

    if (mounted) {
      setState(() => _isConnecting = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conectado à TV em $cleanIp!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Não foi possível conectar. Verifique se a TV está ligada e na mesma rede Wi-Fi.',
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _discovery.stopDiscovery();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentConnectedIp = SamsungRemote().currentIp;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF222328) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho
              Row(
                children: [
                  Icon(
                    Icons.tv,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Smart TVs Samsung',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_isSearching)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Certifique-se de que a TV está ligada e conectada na mesma rede Wi-Fi.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),

              // Lista de TVs encontradas
              Expanded(
                child: _tvs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isSearching ? Icons.radar : Icons.tv_off,
                              size: 44,
                              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _isSearching
                                  ? 'Varrendo a rede local...'
                                  : 'Nenhuma TV encontrada automaticamente.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _isSearching ? null : _startSearch,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Buscar de novo'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _tvs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final tv = _tvs[index];
                          final isCurrent = currentConnectedIp == tv.ip &&
                              SamsungRemote().status == TvConnectionStatus.conectado;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: isCurrent
                                  ? Colors.green.withOpacity(0.2)
                                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                              child: Icon(
                                Icons.tv,
                                color: isCurrent ? Colors.green : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                            title: Text(
                              tv.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${tv.modelName.isNotEmpty ? '${tv.modelName} • ' : ''}${tv.ip}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            trailing: isCurrent
                                ? const Chip(
                                    label: Text(
                                      'Conectado',
                                      style: TextStyle(fontSize: 11, color: Colors.green),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  )
                                : const Icon(Icons.chevron_right),
                            onTap: _isConnecting ? null : () => _connectToTv(tv.ip, name: tv.name, brand: tv.brand),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Inserção manual de IP
              const Text(
                'Ou digite o endereço IP manualmente:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ipController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: 'Ex: 192.168.1.105',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isConnecting
                        ? null
                        : () => _connectToTv(_ipController.text),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isConnecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Conectar'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Dica: Na 1ª conexão, autorize o app na tela da TV com o controle original.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

