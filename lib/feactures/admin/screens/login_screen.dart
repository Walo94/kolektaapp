import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/kolekta_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/kolekta_button.dart';
import '../../../shared/widgets/kolekta_text_field.dart';
import '../../../shared/widgets/kolekta_logo_widget.dart';
import '../providers/auth_provider.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.onLogin,
    this.onRegister,
  });

  final VoidCallback? onLogin;
  final VoidCallback? onRegister;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _localAuth = LocalAuthentication();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Login email/password ──────────────────────────────
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );

    if (!mounted) return;

    if (success) {
      widget.onLogin?.call();
    } else {
      _showError(auth.errorMessage ?? 'Error al iniciar sesión');
    }
  }

  // ── Login biométrico ──────────────────────────────────
  Future<void> _handleBiometricLogin() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Usa tu huella digital para iniciar sesión en Kolekta',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;
      if (!authenticated) return;

      final auth = context.read<AuthProvider>();
      final success = await auth.loginWithBiometrics();

      if (!mounted) return;

      if (success) {
        widget.onLogin?.call();
      } else {
        _showError(auth.errorMessage ?? 'Error al iniciar sesión con huella');
      }
    } catch (e) {
      if (mounted) _showError('Error al acceder a la huella digital');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.loading;
    final biometricEnabled = auth.biometricEnabled;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const KolektaLogoWidget(height: 180, width: 180),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: c.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          'Bienvenido de vuelta',
                          style: AppTextStyles.headingLarge
                              .copyWith(color: c.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SizedBox(height: 16),
                      KolektaTextField(
                        controller: _emailCtrl,
                        hint: 'Correo electrónico',
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            v!.isEmpty ? 'Ingresa tu correo' : null,
                      ),
                      const SizedBox(height: 12),
                      KolektaTextField(
                        controller: _passCtrl,
                        hint: 'Contraseña',
                        prefixIcon: Icons.lock_outline_rounded,
                        isPassword: true,
                        textInputAction: TextInputAction.done,
                        validator: (v) =>
                            v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: isLoading ? null : () => context.push(AppRoutes.forgotPassword),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            '¿Olvidaste tu contraseña?',
                            style: AppTextStyles.link.copyWith(
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      KolektaButton(
                        label: 'Ingresar',
                        onPressed: isLoading ? null : _handleLogin,
                        isLoading: isLoading,
                      ),

                      // ── Botón biométrico (solo si está activado) ──
                      if (biometricEnabled) ...[
                        const SizedBox(height: 16),
                        _BiometricButton(
                          isLoading: isLoading,
                          onTap: _handleBiometricLogin,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '¿No tienes cuenta? ',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: c.textSecondary),
                  ),
                  GestureDetector(
                    onTap: isLoading ? null : widget.onRegister,
                    child: Text(
                      'Regístrate gratis',
                      style: AppTextStyles.link.copyWith(
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Subwidgets ───────────────────────────────────────────

class _BiometricButton extends StatelessWidget {
  const _BiometricButton({
    required this.isLoading,
    required this.onTap,
  });

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: c.border, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: c.surface,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fingerprint_rounded,
                color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            Text(
              'Ingresar con huella digital',
              style:
                  AppTextStyles.buttonMedium.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}