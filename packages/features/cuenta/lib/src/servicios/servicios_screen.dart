import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'servicios_strings.dart';
import 'servicios_view_model.dart';

class ServiciosScreen extends StatefulWidget {
  const ServiciosScreen({super.key, required this.repository});

  final BarberServiceRepository repository;

  @override
  State<ServiciosScreen> createState() => _ServiciosScreenState();
}

class _ServiciosScreenState extends State<ServiciosScreen> {
  late final ServiciosViewModel _model;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _model = ServiciosViewModel(widget.repository)..load();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (ModalRoute.of(context)?.isCurrent == true) _model.load();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _model.dispose();
    super.dispose();
  }

  void _edit([BarberService? service]) {
    final id = service?.id ?? _model.newServiceId();
    showDialog<void>(
      context: context,
      builder: (context) => _ServiceEditor(
        details: service?.details,
        onSave: (name, price, duration) => _model.save(
          id: id,
          create: service == null,
          name: name,
          price: price,
          duration: duration,
        ),
      ),
    );
  }

  Future<void> _toggle(BarberService service) async {
    if (service.active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final strings = ServiciosStrings(context);
          return AlertDialog(
            title: Text(strings.deactivateTitle),
            content: Text(strings.deactivateBody(service.details.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(strings.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(strings.deactivate),
              ),
            ],
          );
        },
      );
      if (!mounted || confirmed != true) return;
    }
    await _model.toggleActive(service);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ServiciosStrings(context);
    final colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) => PopScope(
        canPop: !_model.saving,
        child: Scaffold(
          appBar: AppBar(
            title: Text(strings.title),
            leading: IconButton(
              icon: const BackButtonIcon(),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: _model.saving
                  ? null
                  : () => Navigator.maybePop(context),
            ),
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    strings.notice,
                    style: TextStyle(color: colors.onSecondaryContainer),
                  ),
                ),
              ),
              if (_model.busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (_model.error case final error?) ...[
                const SizedBox(height: 12),
                Text(
                  strings.error(error),
                  style: TextStyle(color: colors.error),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: _model.busy ? null : _model.load,
                    child: Text(strings.retry),
                  ),
                ),
              ] else if (!_model.loading && _model.services.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(strings.empty),
                ),
              for (final service in _model.services)
                _ServiceCard(
                  key: ValueKey(service.id),
                  service: service,
                  onEdit: _model.busy ? null : () => _edit(service),
                  onToggle: _model.busy ? null : () => _toggle(service),
                ),
            ],
          ),
          bottomNavigationBar: Material(
            elevation: 6,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed:
                    _model.busy || _model.error == ServiceFailure.permission
                    ? null
                    : _edit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: Text(strings.add),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    super.key,
    required this.service,
    required this.onEdit,
    required this.onToggle,
  });

  final BarberService service;
  final VoidCallback? onEdit;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = ServiciosStrings(context);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Text(service.details.name, style: theme.textTheme.titleLarge),
            Text(strings.details(context, service.details)),
            Text(
              service.active ? strings.active : strings.inactive,
              style: TextStyle(
                color: service.active
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(strings.edit),
                ),
                TextButton(
                  onPressed: onToggle,
                  child: Text(
                    service.active ? strings.deactivate : strings.reactivate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceEditor extends StatefulWidget {
  const _ServiceEditor({required this.details, required this.onSave});

  final ServiceDetails? details;
  final Future<void> Function(String name, String price, String duration)
  onSave;

  @override
  State<_ServiceEditor> createState() => _ServiceEditorState();
}

class _ServiceEditorState extends State<_ServiceEditor> {
  late final _name = TextEditingController(text: widget.details?.name);
  late final _price = TextEditingController(text: widget.details?.priceInput);
  late final _duration = TextEditingController(
    text: widget.details?.durationMinutes.toString() ?? '40',
  );
  bool _saving = false;
  ServiceFailure? _error;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_name.text, _price.text, _duration.text);
      if (mounted) Navigator.pop(context);
    } on ServiceFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  void _inputChanged(String _) => setState(() => _error = null);

  @override
  Widget build(BuildContext context) {
    final strings = ServiciosStrings(context);
    final canSave =
        !_saving &&
        [
          _name,
          _price,
          _duration,
        ].every((controller) => controller.text.trim().isNotEmpty);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        icon: const Icon(Icons.content_cut),
        title: Text(widget.details == null ? strings.add : strings.editTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            TextField(
              controller: _name,
              enabled: !_saving,
              onChanged: _inputChanged,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: strings.name,
                border: const OutlineInputBorder(),
              ),
            ),
            TextField(
              controller: _price,
              enabled: !_saving,
              onChanged: _inputChanged,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: strings.price,
                border: const OutlineInputBorder(),
              ),
            ),
            TextField(
              controller: _duration,
              enabled: !_saving,
              onChanged: _inputChanged,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: strings.duration,
                helperText: strings.durationRange,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error case final error?)
              Text(
                strings.error(error),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: canSave ? _save : null,
            child: Text(_saving ? strings.saving : strings.save),
          ),
        ],
      ),
    );
  }
}
