import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/kolekta_colors.dart';
import '../../../shared/widgets/kolekta_button.dart';
import '../../../shared/widgets/kolekta_text_field.dart';
import '../../../shared/widgets/kolekta_logo_widget.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    this.onRegister,
    this.onLogin,
    this.onGoogleNeedsProfile,
  });

  final VoidCallback? onRegister;
  final VoidCallback? onLogin;
  final VoidCallback? onGoogleNeedsProfile;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _registered = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      fullName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      password: _passCtrl.text,
    );

    if (!mounted) return;

    if (success) {
      setState(() => _registered = true);
    } else {
      _showError(auth.errorMessage ?? 'Error al registrar');
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _registered
          ? _SuccessScreen(
              key: const ValueKey('success'),
              email: _emailCtrl.text.trim(),
              onGoToLogin: widget.onRegister,
            )
          : _FormScreen(
              key: const ValueKey('form'),
              formKey: _formKey,
              nameCtrl: _nameCtrl,
              emailCtrl: _emailCtrl,
              phoneCtrl: _phoneCtrl,
              passCtrl: _passCtrl,
              onRegister: _handleRegister,
              onLogin: widget.onLogin,
            ),
    );
  }
}

// ─── Pantalla de éxito ────────────────────────────────────

class _SuccessScreen extends StatefulWidget {
  const _SuccessScreen({super.key, required this.email, this.onGoToLogin});

  final String email;
  final VoidCallback? onGoToLogin;

  @override
  State<_SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<_SuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 56,
                    color: AppColors.success,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    Text(
                      '¡Cuenta creada!',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.displayMedium
                          .copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enviamos un correo de verificación a',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Revisa tu bandeja de entrada para activar tu cuenta.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              FadeTransition(
                opacity: _fadeAnim,
                child: KolektaButton(
                  label: 'Ir al inicio de sesión',
                  onPressed: widget.onGoToLogin,
                  icon: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 18),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pantalla de formulario ───────────────────────────────

class _FormScreen extends StatelessWidget {
  const _FormScreen({
    super.key,
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.passCtrl,
    required this.onRegister,
    this.onLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController passCtrl;
  final VoidCallback onRegister;
  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.loading;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

             

              const SizedBox(height: 20),

              const Center(
                child: KolektaLogoWidget(
                    height: 140, width: 140, showSlogan: false),
              ),

              const SizedBox(height: 16),

              Center(
                child: Column(
                  children: [
                    Text(
                      'Crea tu cuenta',
                      style: AppTextStyles.displayMedium
                          .copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Únete a la comunidad Kolekta',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

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
                  key: formKey,
                  child: Column(
                    children: [

                      const SizedBox(height: 16),

                      KolektaTextField(
                        controller: nameCtrl,
                        hint: 'Nombre completo',
                        prefixIcon: Icons.person_outline_rounded,
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            v!.trim().isEmpty ? 'Ingresa tu nombre' : null,
                      ),
                      const SizedBox(height: 12),
                      KolektaTextField(
                        controller: emailCtrl,
                        hint: 'Correo electrónico',
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v!.isEmpty) return 'Ingresa tu correo';
                          if (!v.contains('@')) return 'Correo inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      KolektaTextField(
                        controller: phoneCtrl,
                        hint: 'Teléfono (ej. 4771234567)',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v!.trim().isEmpty) return 'Ingresa tu teléfono';
                          if (v.trim().length < 10) return 'Mínimo 10 dígitos';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      KolektaTextField(
                        controller: passCtrl,
                        hint: 'Contraseña',
                        prefixIcon: Icons.lock_outline_rounded,
                        isPassword: true,
                        textInputAction: TextInputAction.done,
                        validator: (v) =>
                            v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                      ),
                      const SizedBox(height: 16),

                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: AppTextStyles.bodySmall
                              .copyWith(color: c.textSecondary),
                          children: [
                            const TextSpan(
                                text: 'Al registrarte, aceptas nuestros '),
                            TextSpan(
                              text: 'Términos',
                              style: AppTextStyles.link.copyWith(
                                fontSize: 12,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const TextSpan(text: ' y '),
                            TextSpan(
                              text: 'Privacidad',
                              style: AppTextStyles.link.copyWith(
                                fontSize: 12,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      KolektaButton(
                        label: 'Crear cuenta',
                        onPressed: isLoading ? null : onRegister,
                        isLoading: isLoading,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿Ya tienes cuenta? ',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: c.textSecondary),
                    ),
                    GestureDetector(
                      onTap: isLoading ? null : onLogin,
                      child: Text(
                        'Inicia sesión',
                        style: AppTextStyles.link.copyWith(
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}