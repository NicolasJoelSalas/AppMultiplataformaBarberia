import 'package:core_ui/core_ui.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

class MiCuentaScreen extends StatefulWidget {
  const MiCuentaScreen({
    super.key,
    required this.profile,
    required this.editing,
    required this.onEditingChanged,
    required this.darkTheme,
    required this.onDarkThemeChanged,
    required this.language,
    required this.onLanguageChanged,
    required this.onSave,
    required this.onLogout,
    required this.onServices,
    required this.onLocation,
    this.saving = false,
    this.error,
  });

  final AccountProfile profile;
  final bool editing;
  final ValueChanged<bool> onEditingChanged;
  final bool darkTheme;
  final ValueChanged<bool> onDarkThemeChanged;
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final Future<bool> Function(String) onSave;
  final VoidCallback? onLogout;
  final VoidCallback onServices;
  final VoidCallback onLocation;
  final bool saving;
  final String? error;

  @override
  State<MiCuentaScreen> createState() => _MiCuentaScreenState();
}

class _MiCuentaScreenState extends State<MiCuentaScreen> {
  final _name = TextEditingController();

  bool get _english => Localizations.localeOf(context).languageCode == 'en';
  String _text(String es, String en) => _english ? en : es;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _languageLabel(AppLanguage language) => switch (language) {
    AppLanguage.system => _text(
      'Usar idioma del dispositivo',
      'Use device language',
    ),
    AppLanguage.spanish => 'Español',
    AppLanguage.english => 'English',
  };

  Future<void> _selectLanguage() async {
    final selected = await showDialog<AppLanguage>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(_text('Idioma', 'Language')),
        children: [
          for (final language in AppLanguage.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, language),
              child: Row(
                children: [
                  Icon(
                    language == widget.language
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  const SizedBox(width: 12),
                  Flexible(child: Text(_languageLabel(language))),
                ],
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
          ),
        ],
      ),
    );
    if (mounted && selected != null && selected != widget.language) {
      widget.onLanguageChanged(selected);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final name = _name.text.trim();
    if (await widget.onSave(name) && mounted) {
      _name.text = name;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_text('Cambios guardados.', 'Changes saved.'))),
      );
    }
  }

  void _leaveEditor() {
    FocusScope.of(context).unfocus();
    widget.onEditingChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final editing = widget.editing;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          editing
              ? _text('Modificar perfil', 'Edit profile')
              : _text('Mi cuenta', 'My account'),
        ),
        automaticallyImplyLeading: false,
        leading: editing
            ? IconButton(
                onPressed: widget.saving ? null : _leaveEditor,
                icon: const BackButtonIcon(),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              )
            : null,
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: ValueKey(editing),
          padding: const EdgeInsets.all(16),
          children: [
            _header(),
            if (widget.profile.offline) ...[
              const SizedBox(height: 16),
              Text(
                _text(
                  'Estás viendo tu perfil guardado. Conectate para guardar cambios.',
                  'You are viewing your saved profile. Connect to save changes.',
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (editing) _editor() else _options(),
            if (widget.error case final error?) ...[
              const SizedBox(height: 16),
              Text(error, style: TextStyle(color: colors.error)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final profile = widget.profile;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colors.onPrimaryContainer.withValues(alpha: .12),
              foregroundColor: colors.onPrimaryContainer,
              child: const Icon(Icons.person_outline, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.editing
                        ? _text('Datos personales', 'Personal details')
                        : profile.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.editing
                        ? _text(
                            'Actualizá el nombre de tu perfil.',
                            'Update your profile name.',
                          )
                        : profile.role == AccountRole.barber
                        ? _text('Cuenta de barbero', 'Barber account')
                        : _text('Cuenta de cliente', 'Client account'),
                    style: TextStyle(color: colors.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _options() {
    final barber = widget.profile.role == AccountRole.barber;
    return Column(
      children: [
        _option(
          Icons.edit_outlined,
          _text('Modificar perfil', 'Edit profile'),
          _text(
            'Actualizá tus datos personales',
            'Update your personal details',
          ),
          () {
            _name.text = widget.profile.name;
            widget.onEditingChanged(true);
          },
        ),
        if (barber) ...[
          const Divider(),
          _option(
            Icons.location_on_outlined,
            _text('Ubicación de la barbería', 'Barbershop location'),
            _text(
              'Marcá en el mapa dónde atendés',
              'Mark your shop on the map',
            ),
            widget.onLocation,
          ),
          const Divider(),
          _option(
            Icons.content_cut,
            _text('Mis servicios', 'My services'),
            _text(
              'Agregá, editá o desactivá tus servicios',
              'Add, edit or deactivate services',
            ),
            widget.onServices,
          ),
        ],
        const Divider(),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          secondary: const Icon(Icons.dark_mode_outlined),
          title: Text(_text('Modo oscuro', 'Dark mode')),
          subtitle: Text(
            widget.darkTheme
                ? _text('Activado', 'On')
                : _text('Desactivado · modo claro', 'Off · light mode'),
          ),
          value: widget.darkTheme,
          onChanged: widget.onDarkThemeChanged,
        ),
        const Divider(),
        _option(
          Icons.language,
          _text('Idioma', 'Language'),
          _languageLabel(widget.language),
          _selectLanguage,
        ),
        const Divider(),
        _option(
          Icons.logout,
          _text('Cerrar sesión', 'Sign out'),
          _text('Salir de tu cuenta', 'Sign out of your account'),
          widget.onLogout,
          color: Theme.of(context).colorScheme.error,
        ),
      ],
    );
  }

  Widget _option(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? onTap, {
    Color? color,
  }) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    leading: Icon(icon, color: color),
    title: Text(title, style: TextStyle(color: color)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    enabled: onTap != null,
    onTap: onTap,
  );

  Widget _editor() {
    final colors = Theme.of(context).colorScheme;
    final profile = widget.profile;
    final saving = widget.saving;
    const limit = UpdateProfileNameUseCase.maxLength;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder(
              valueListenable: _name,
              builder: (context, value, _) {
                final length = value.text.trim().length;
                return TextField(
                  controller: _name,
                  enabled: !saving,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: _text('Nombre', 'Name'),
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    counterText: '$length/$limit',
                    helperText: _text(
                      'Así aparecerás en la aplicación.',
                      'This is how you will appear in the app.',
                    ),
                    errorText: switch (length) {
                      0 => _text('Ingresá tu nombre.', 'Enter your name.'),
                      > limit => _text(
                        'El máximo es de $limit caracteres.',
                        'Use at most $limit characters.',
                      ),
                      _ => null,
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(_text('Correo electrónico', 'Email address')),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        profile.email.isEmpty
                            ? _text('Correo no disponible', 'Email unavailable')
                            : profile.email,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.lock_outline, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _text(
                'El correo está asociado a tu cuenta y no se puede editar.',
                'The email is linked to your account and is read-only.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            ValueListenableBuilder(
              valueListenable: _name,
              builder: (context, value, _) {
                final name = value.text.trim();
                final canSave =
                    !saving &&
                    name.isNotEmpty &&
                    name.length <= limit &&
                    name != profile.name;
                return FilledButton.icon(
                  onPressed: canSave ? _save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    saving
                        ? _text('Guardando…', 'Saving…')
                        : _text('Guardar cambios', 'Save changes'),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: saving ? null : _leaveEditor,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(_text('Volver a Mi cuenta', 'Back to My account')),
            ),
          ],
        ),
      ),
    );
  }
}
