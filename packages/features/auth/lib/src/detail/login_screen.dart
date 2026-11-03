import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'login_ui_state.dart';

/// UI only: receives state and callbacks, without Firebase or repositories.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.state,
    required this.onLogin,
    required this.onRegister,
    required this.onGoogleLogin,
    required this.onToggleRegistration,
    required this.onRetryProfile,
  });
  final LoginUiState state;
  final void Function(String, String) onLogin;
  final void Function(String, String, String) onRegister;
  final VoidCallback onGoogleLogin, onToggleRegistration, onRetryProfile;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _visible = false;
  @override
  void didUpdateWidget(covariant LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.isRegistering != widget.state.isRegistering) {
      _password.clear();
      _confirmation.clear();
      _visible = false;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !widget.state.isLoading &&
      _email.text.trim().isNotEmpty &&
      _password.text.trim().isNotEmpty &&
      (!widget.state.isRegistering || _confirmation.text.trim().isNotEmpty);
  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_canSubmit) return;
    if (widget.state.isRegistering) {
      widget.onRegister(_email.text.trim(), _password.text, _confirmation.text);
    } else {
      widget.onLogin(_email.text.trim(), _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final strings = AuthStrings(context);
    String t(String key) => strings.text(key);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );
    Widget error() => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Semantics(
        liveRegion: true,
        child: Text(
          authErrorMessage(state.error!, english: strings.english),
          style: TextStyle(color: colors.onErrorContainer),
        ),
      ),
    );
    InputDecoration field(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
    Widget button({required VoidCallback? onPressed, required Widget child}) =>
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: child,
          ),
        );
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 64).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Material(
                        color: colors.primaryContainer,
                        shape: shape,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: DefaultTextStyle.merge(
                            style: TextStyle(color: colors.onPrimaryContainer),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: colors.onPrimaryContainer
                                          .withValues(alpha: .12),
                                      child: Icon(
                                        Icons.content_cut_outlined,
                                        color: colors.onPrimaryContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      t('barber_app'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  t(
                                    state.isRegistering
                                        ? 'crea_tu_cuenta'
                                        : 'bienvenido',
                                  ),
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        color: colors.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  t(
                                    state.isRegistering
                                        ? 'registrate_para_reservar_tu_proximo_corte'
                                        : 'tu_barberia_en_un_solo_lugar_reserva_tu_turno_o_gestiona_tu_agenda_como_barbero',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Material(
                        color: colors.surfaceContainerLow,
                        shape: shape,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                t(
                                  state.isRegistering
                                      ? 'datos_de_tu_cuenta'
                                      : 'iniciar_sesion',
                                ),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (state.needsProfileRetry) ...[
                                Text(
                                  t(
                                    'falta_completar_tu_perfil_tu_cuenta_ya_esta_creada',
                                  ),
                                ),
                                if (state.error != null) error(),
                                const SizedBox(height: 16),
                                button(
                                  onPressed: state.isLoading
                                      ? null
                                      : widget.onRetryProfile,
                                  child: Text(
                                    t(
                                      state.isLoading
                                          ? 'procesando'
                                          : 'reintentar',
                                    ),
                                  ),
                                ),
                              ] else ...[
                                TextField(
                                  key: const Key('email'),
                                  controller: _email,
                                  enabled: !state.isLoading,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  autofillHints: const [AutofillHints.email],
                                  onChanged: (_) => setState(() {}),
                                  decoration: field(
                                    t('correo_electronico'),
                                    Icons.email_outlined,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  key: const Key('password'),
                                  controller: _password,
                                  enabled: !state.isLoading,
                                  obscureText: !_visible,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  textInputAction: state.isRegistering
                                      ? TextInputAction.next
                                      : TextInputAction.done,
                                  onSubmitted: (_) {
                                    if (!state.isRegistering) _submit();
                                  },
                                  onChanged: (_) => setState(() {}),
                                  decoration:
                                      field(
                                        t('contrasena'),
                                        Icons.lock_outlined,
                                      ).copyWith(
                                        suffixIcon: IconButton(
                                          onPressed: state.isLoading
                                              ? null
                                              : () => setState(
                                                  () => _visible = !_visible,
                                                ),
                                          tooltip: t(
                                            _visible
                                                ? 'ocultar_contrasena'
                                                : 'mostrar_contrasena',
                                          ),
                                          icon: Icon(
                                            _visible
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                          ),
                                        ),
                                      ),
                                ),
                                if (state.isRegistering) ...[
                                  const SizedBox(height: 16),
                                  TextField(
                                    key: const Key('confirmation'),
                                    controller: _confirmation,
                                    enabled: !state.isLoading,
                                    obscureText: !_visible,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _submit(),
                                    onChanged: (_) => setState(() {}),
                                    decoration: field(
                                      t('confirmar_contrasena'),
                                      Icons.lock_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    t(
                                      'usa_una_contrasena_de_al_menos_6_caracteres',
                                    ),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                                if (state.error != null) error(),
                                const SizedBox(height: 24),
                                button(
                                  onPressed: _canSubmit ? _submit : null,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (state.isLoading) ...[
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      Text(
                                        t(
                                          state.isLoading
                                              ? 'procesando'
                                              : state.isRegistering
                                              ? 'crear_cuenta'
                                              : 'ingresar',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  child: Row(
                                    children: [
                                      const Expanded(child: Divider()),
                                      const SizedBox(width: 12),
                                      Text(
                                        t('o_continua_con'),
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(child: Divider()),
                                    ],
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: state.isLoading
                                      ? null
                                      : () {
                                          FocusScope.of(context).unfocus();
                                          widget.onGoogleLogin();
                                        },
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF1F1F1F),
                                    minimumSize: const Size(0, 52),
                                    side: const BorderSide(
                                      color: Color(0xFF747775),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Opacity(
                                        opacity: state.isLoading ? .38 : 1,
                                        child: const GoogleMark(),
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: Text(t('continuar_con_google')),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: state.isLoading
                                      ? null
                                      : widget.onToggleRegistration,
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(0, 48),
                                  ),
                                  child: Text(
                                    t(
                                      state.isRegistering
                                          ? 'ya_tengo_cuenta_iniciar_sesion'
                                          : 'no_tengo_cuenta_registrarme',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
