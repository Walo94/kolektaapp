import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/kolekta_colors.dart';
import '../../admin/providers/auth_provider.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();

  // ── Change password form ──────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  // ── Biometrics ────────────────────────────────────────
  bool _biometricAvailable = false;
  bool _checkingBiometric = true;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      setState(() {
        _biometricAvailable = canCheck && isDeviceSupported;
        _checkingBiometric = false;
      });
    } catch (_) {
      setState(() {
        _biometricAvailable = false;
        _checkingBiometric = false;
      });
    }
  }

  // ── Handlers ─────────────────────────────────────────

  Future<void> _handleChangePassword() async {
  if (!_formKey.currentState!.validate()) return;

  final auth = context.read<AuthProvider>();
  final biometricWasEnabled = auth.biometricEnabled; // ← guardar estado previo

  final success = await auth.changePassword(
    currentPassword: _currentPassCtrl.text,
    newPassword: _newPassCtrl.text,
  );

  if (!mounted) return;

  if (success) {
    _currentPassCtrl.clear();
    _newPassCtrl.clear();
    _confirmPassCtrl.clear();

    // Si la huella estaba activa, desactivarla con las credenciales viejas
    if (biometricWasEnabled) {
      await auth.disableBiometrics();
      _showSnack(
        'Contraseña actualizada. Reactiva la huella digital con tu nueva contraseña.',
        isError: false,
      );
    } else {
      _showSnack('Contraseña actualizada exitosamente', isError: false);
    }
  } else {
    _showSnack(auth.errorMessage ?? 'Error al cambiar la contraseña');
  }
}

  Future<void> _handleBiometricToggle(bool value) async {
    final auth = context.read<AuthProvider>();

    if (value) {
      bool authenticated = false;

      try {
        authenticated = await _localAuth.authenticate(
          localizedReason:
              'Confirma tu identidad para activar el acceso con huella digital',
          options: const AuthenticationOptions(
            biometricOnly: false, // ← clave: permite PIN como fallback
            stickyAuth: true,
          ),
        );
      } on Exception catch (e) {
        debugPrint('Biometric error: $e');
        authenticated = false;
      }

      if (!mounted) return;

      if (!authenticated) {
        _showSnack('No se pudo verificar tu huella digital');
        return;
      }

      _showBiometricCredentialsDialog();
    } else {
      await auth.disableBiometrics();
      if (mounted) {
        _showSnack('Acceso con huella digital desactivado', isError: false);
      }
    }
  }

  void _showBiometricCredentialsDialog() {
    final emailCtrl = TextEditingController(
      text: context.read<AuthProvider>().displayEmail,
    );
    final passCtrl = TextEditingController();
    final c = context.kolekta;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Confirma tu contraseña',
          style: AppTextStyles.headingMedium.copyWith(color: c.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Para activar la huella digital, ingresa tu contraseña actual. Se guardará de forma segura en este dispositivo.',
              style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 16),
            _PassField(
              controller: passCtrl,
              hint: 'Contraseña actual',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancelar',
                style: AppTextStyles.buttonMedium
                    .copyWith(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (passCtrl.text.length < 6) return;
              final auth = context.read<AuthProvider>();
              auth.saveBiometricCredentials(
                emailCtrl.text.trim(),
                passCtrl.text,
              );
              Navigator.of(dialogContext).pop();
              _showSnack('Huella digital activada', isError: false);
            },
            child: Text('Activar',
                style: AppTextStyles.buttonMedium
                    .copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleResendVerification() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.resendVerificationEmail();

    if (!mounted) return;

    if (success) {
      _showSnack(
        'Correo de verificación enviado. Revisa tu bandeja de entrada.',
        isError: false,
      );
    } else {
      _showSnack(auth.errorMessage ?? 'Error al reenviar el correo');
    }
  }

  void _showSnack(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.loading;
    final isEmailVerified = auth.user?.emailVerified ?? false;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: c.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Seguridad',
          style: AppTextStyles.headingMedium.copyWith(color: c.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Estado de verificación ──────────────────
            if (!isEmailVerified) ...[
              _VerificationBanner(
                isLoading: isLoading,
                onResend: _handleResendVerification,
              ),
              const SizedBox(height: 20),
            ],

            // ── Contraseña ──────────────────────────────
            Text(
              'Cambiar contraseña',
              style: AppTextStyles.headingSmall.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04), blurRadius: 10)
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _PassField(
                      controller: _currentPassCtrl,
                      hint: 'Contraseña actual',
                      show: _showCurrent,
                      onToggle: () =>
                          setState(() => _showCurrent = !_showCurrent),
                      validator: (v) =>
                          v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                    ),
                    const SizedBox(height: 12),
                    _PassField(
                      controller: _newPassCtrl,
                      hint: 'Nueva contraseña',
                      show: _showNew,
                      onToggle: () => setState(() => _showNew = !_showNew),
                      validator: (v) =>
                          v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                    ),
                    const SizedBox(height: 12),
                    _PassField(
                      controller: _confirmPassCtrl,
                      hint: 'Confirmar nueva contraseña',
                      show: _showConfirm,
                      onToggle: () =>
                          setState(() => _showConfirm = !_showConfirm),
                      validator: (v) => v != _newPassCtrl.text
                          ? 'Las contraseñas no coinciden'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _handleChangePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : Text('Actualizar contraseña',
                                style: AppTextStyles.buttonMedium
                                    .copyWith(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Huella digital ──────────────────────────
            Text(
              'Acceso biométrico',
              style: AppTextStyles.headingSmall.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04), blurRadius: 10)
                ],
              ),
              child: _checkingBiometric
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : !_biometricAvailable
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: c.orangeLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.fingerprint_rounded,
                                    color: AppColors.orange, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Huella digital',
                                        style: AppTextStyles.labelLarge
                                            .copyWith(color: c.textPrimary)),
                                    Text(
                                      'No disponible en este dispositivo',
                                      style: AppTextStyles.bodySmall
                                          .copyWith(color: c.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          secondary: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: auth.biometricEnabled
                                  ? c.primarySurface
                                  : c.orangeLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.fingerprint_rounded,
                              color: auth.biometricEnabled
                                  ? AppColors.primary
                                  : AppColors.orange,
                              size: 20,
                            ),
                          ),
                          title: Text('Huella digital',
                              style: AppTextStyles.labelLarge
                                  .copyWith(color: c.textPrimary)),
                          subtitle: Text(
                            auth.biometricEnabled
                                ? 'Activada · Inicia sesión sin contraseña'
                                : 'Inicia sesión con tu huella digital',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: c.textSecondary),
                          ),
                          value: auth.biometricEnabled,
                          activeColor: AppColors.primary,
                          onChanged: isLoading ? null : _handleBiometricToggle,
                        ),
            ),

            // ── Verificación de correo (si ya verificado) ──
            if (isEmailVerified) ...[
              const SizedBox(height: 24),
              Text(
                'Correo electrónico',
                style:
                    AppTextStyles.headingSmall.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04), blurRadius: 10)
                  ],
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: c.successLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.verified_rounded,
                            color: AppColors.success, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Correo verificado',
                                style: AppTextStyles.labelLarge
                                    .copyWith(color: c.textPrimary)),
                            Text(
                              auth.displayEmail,
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: c.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.check_circle_rounded,
                          color: AppColors.success, size: 20),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Subwidgets ───────────────────────────────────────────

/// Banner de alerta cuando el email no está verificado
class _VerificationBanner extends StatelessWidget {
  const _VerificationBanner({
    required this.isLoading,
    required this.onResend,
  });

  final bool isLoading;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.mark_email_unread_rounded,
                color: AppColors.orange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Correo sin verificar',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.warning),
                ),
                const SizedBox(height: 2),
                Text(
                  'Verifica tu correo para acceder a todas las funciones de Kolekta.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.warning),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: isLoading ? null : onResend,
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.orange),
                        )
                      : Text(
                          'Reenviar correo de verificación →',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primary,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de contraseña reutilizable dentro del screen
class _PassField extends StatefulWidget {
  const _PassField({
    required this.controller,
    required this.hint,
    this.show = false,
    this.onToggle,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final bool show;
  final VoidCallback? onToggle;
  final String? Function(String?)? validator;

  @override
  State<_PassField> createState() => _PassFieldState();
}

class _PassFieldState extends State<_PassField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = !widget.show;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      style: AppTextStyles.bodyMedium,
      validator: widget.validator,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
            color: AppColors.textHint,
          ),
          onPressed: () {
            setState(() => _obscure = !_obscure);
            widget.onToggle?.call();
          },
        ),
      ),
    );
  }
}
