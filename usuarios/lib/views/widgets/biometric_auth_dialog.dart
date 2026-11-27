import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// Diálogo interactivo para Autenticación Biométrica (Huella Dactilar y Reconocimiento Facial / Face ID)
class BiometricAuthDialog extends StatefulWidget {
  final String titulo;
  final String subtitulo;
  final String usuarioNombreOEmail;
  final VoidCallback onSuccess;

  const BiometricAuthDialog({
    super.key,
    this.titulo = 'Autenticación Biométrica',
    this.subtitulo = 'Confirma tu identidad para continuar',
    required this.usuarioNombreOEmail,
    required this.onSuccess,
  });

  /// Método estático para mostrar el diálogo fácilmente
  static Future<void> show(
    BuildContext context, {
    String titulo = 'Autenticación Biométrica',
    String subtitulo = 'Confirma tu identidad para continuar',
    required String usuarioNombreOEmail,
    required VoidCallback onSuccess,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BiometricAuthDialog(
        titulo: titulo,
        subtitulo: subtitulo,
        usuarioNombreOEmail: usuarioNombreOEmail,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<BiometricAuthDialog> createState() => _BiometricAuthDialogState();
}

class _BiometricAuthDialogState extends State<BiometricAuthDialog>
    with SingleTickerProviderStateMixin {
  // 0: Huella dactilar, 1: Reconocimiento Facial
  int _modoBiometrico = 0;
  bool _isScanning = false;
  bool _isSuccess = false;
  String _scanStatusText = 'Toca el sensor para escanear';

  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _iniciarEscaneo() async {
    if (_isScanning || _isSuccess) return;

    setState(() {
      _isScanning = true;
      _scanStatusText = _modoBiometrico == 0
          ? 'Escaneando huella dactilar...'
          : 'Reconociendo rostro frente a la cámara...';
    });

    // Simular escaneo de hardware biométrico de alta precisión (1.2 segundos)
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    setState(() {
      _isScanning = false;
      _isSuccess = true;
      _scanStatusText = _modoBiometrico == 0
          ? '¡Huella dactilar verificada con éxito!'
          : '¡Reconocimiento facial completado con éxito!';
    });

    // Breve pausa para mostrar el checkmark verde y retroalimentación positiva
    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.pastelMauve : AppTheme.primaryPurple;
    final textMain = AppTheme.getTextMain(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppTheme.getSurfaceCard(context),
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera con Icono y Título
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryExtraLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _modoBiometrico == 0
                        ? Icons.fingerprint_rounded
                        : Icons.face_retouching_natural_rounded,
                    color: primaryColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.titulo,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitulo,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Selector de Modo Biométrica: Huella vs Reconocimiento Facial
            Container(
              decoration: BoxDecoration(
                color: AppTheme.inputFill,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _isScanning || _isSuccess
                          ? null
                          : () => setState(() {
                                _modoBiometrico = 0;
                                _scanStatusText = 'Toca el sensor para escanear';
                              }),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _modoBiometrico == 0
                              ? AppTheme.getSurfaceCard(context)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _modoBiometrico == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fingerprint_rounded,
                              size: 18,
                              color: _modoBiometrico == 0
                                  ? primaryColor
                                  : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Huella Digital',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: _modoBiometrico == 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _modoBiometrico == 0
                                    ? primaryColor
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: _isScanning || _isSuccess
                          ? null
                          : () => setState(() {
                                _modoBiometrico = 1;
                                _scanStatusText = 'Mira al recuadro para escanear';
                              }),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _modoBiometrico == 1
                              ? AppTheme.getSurfaceCard(context)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _modoBiometrico == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.face_rounded,
                              size: 18,
                              color: _modoBiometrico == 1
                                  ? primaryColor
                                  : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Face ID / Facial',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: _modoBiometrico == 1
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _modoBiometrico == 1
                                    ? primaryColor
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tarjeta interactiva del sensor (Huella o Cámara Facial)
            Center(
              child: GestureDetector(
                onTap: _iniciarEscaneo,
                child: ScaleTransition(
                  scale: (_isScanning && !_isSuccess)
                      ? _pulseAnimation
                      : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isSuccess
                          ? AppTheme.successColor.withAlpha(30)
                          : (_isScanning
                              ? primaryColor.withAlpha(30)
                              : AppTheme.primaryExtraLight),
                      border: Border.all(
                        color: _isSuccess
                            ? AppTheme.successColor
                            : (_isScanning
                                ? primaryColor
                                : primaryColor.withAlpha(80)),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isSuccess
                              ? AppTheme.successColor.withAlpha(50)
                              : primaryColor.withAlpha(40),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isSuccess
                          ? const Icon(
                              Icons.check_circle_rounded,
                              size: 64,
                              color: AppTheme.successColor,
                            )
                          : (_modoBiometrico == 0
                              ? Icon(
                                  Icons.fingerprint_rounded,
                                  size: 68,
                                  color: _isScanning
                                      ? primaryColor
                                      : primaryColor.withAlpha(200),
                                )
                              : Icon(
                                  Icons.face_retouching_natural_rounded,
                                  size: 68,
                                  color: _isScanning
                                      ? primaryColor
                                      : primaryColor.withAlpha(200),
                                )),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Estado y retroalimentación del escaneo
            Text(
              _scanStatusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _isSuccess ? AppTheme.successColor : primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.usuarioNombreOEmail.isNotEmpty
                  ? 'Usuario: ${widget.usuarioNombreOEmail}'
                  : 'Toca el círculo para autenticar',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 22),

            // Botón de acción principal
            ElevatedButton(
              onPressed: (_isScanning || _isSuccess) ? null : _iniciarEscaneo,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isScanning
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _modoBiometrico == 0
                              ? Icons.fingerprint_rounded
                              : Icons.camera_alt_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _modoBiometrico == 0
                              ? 'Escanear Huella Dactilar'
                              : 'Reconocer Rostro (Face ID)',
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 8),

            // Botón Cancelar
            TextButton(
              onPressed: _isScanning ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar / Usar Contraseña o Código'),
            ),
          ],
        ),
      ),
    );
  }
}
