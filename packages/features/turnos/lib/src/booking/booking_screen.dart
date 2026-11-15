import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'booking_strings.dart';
import 'booking_view_model.dart';
import 'reference_photo.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    required this.repository,
    required this.photos,
    required this.initialName,
    this.original,
    this.initialBarberId,
  });

  final BookingRepository repository;
  final BookingPhotoRepository photos;
  final String initialName;
  final Appointment? original;
  final String? initialBarberId;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late final BookingViewModel _model;
  late final _name = TextEditingController(text: widget.initialName);
  final _scroll = ScrollController();
  bool _pickingPhoto = false;
  bool _photoError = false;

  @override
  void initState() {
    super.initState();
    _model = BookingViewModel(
      widget.repository,
      widget.photos,
      widget.original,
      initialBarberId: widget.initialBarberId,
    )..initialize();
  }

  @override
  void dispose() {
    _model.dispose();
    _name.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final slot = _model.slot;
    final week = _model.week;
    if (slot == null || week == null || _model.busy) return;
    FocusScope.of(context).unfocus();
    final strings = BookingStrings(context);
    final action = widget.original == null
        ? strings.confirm
        : strings.confirmEdit;
    final calendar = AgendaCalendar(week.zoneId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.event_available_outlined),
        title: Text(action),
        content: Text(
          [
            _model.barber!.name,
            strings.serviceOption(_model.service!),
            strings.date(calendar.dateOf(slot.start)),
            '${strings.interval(calendar, slot.start, slot.end)} · ${week.zoneId}',
          ].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final saved = await _model.confirm(_name.text);
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, _model.offset);
    } else if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  Future<void> _pickPhoto() async {
    if (_pickingPhoto || _model.confirming) return;
    setState(() {
      _pickingPhoto = true;
      _photoError = false;
    });
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        requestFullMetadata: false,
      );
      if (!mounted || picked == null) return;
      if (await picked.length() > 16 * 1024 * 1024) {
        throw BookingFailure.photoUpload;
      }
      final bytes = await picked.readAsBytes();
      if (mounted) _model.setPhoto(bytes);
    } catch (_) {
      if (mounted) setState(() => _photoError = true);
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = BookingStrings(context);
    final colors = Theme.of(context).colorScheme;
    final sidePadding = kIsWeb
        ? 16.0
        : (MediaQuery.sizeOf(context).width - 760).clamp(
                32.0,
                double.infinity,
              ) /
              2;
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) => PopScope(
        canPop: !_model.confirming,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.original == null ? strings.reserve : strings.edit,
            ),
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
            leading: IconButton(
              icon: const BackButtonIcon(),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: _model.confirming
                  ? null
                  : () => Navigator.maybePop(context),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            minimum: EdgeInsets.symmetric(
              horizontal: sidePadding,
              vertical: 16,
            ),
            child: FilledButton.icon(
              onPressed: _model.slot != null && !_model.busy && !_pickingPhoto
                  ? _confirm
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: _model.confirming
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.event_available_outlined),
              label: Text(
                _model.confirming
                    ? strings.confirming
                    : widget.original == null
                    ? strings.confirm
                    : strings.confirmEdit,
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              controller: _scroll,
              padding: EdgeInsets.symmetric(
                horizontal: sidePadding,
                vertical: 16,
              ),
              children: [
                if (_model.busy) const LinearProgressIndicator(),
                if (_model.failure case final failure?) ...[
                  const SizedBox(height: 12),
                  Text(
                    strings.error(failure),
                    style: TextStyle(color: colors.error),
                  ),
                  if (_model.slot == null &&
                      failure != BookingFailure.changed &&
                      failure != BookingFailure.notEditable)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: _model.busy ? null : _model.retry,
                        child: Text(
                          _model.service == null
                              ? strings.retry
                              : strings.refresh,
                        ),
                      ),
                    ),
                ],
                if (_model.busy || _model.failure != null)
                  const SizedBox(height: 12),
                _selections(strings),
                if (_model.service != null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    enabled: !_model.confirming,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: strings.name,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _photoArea(strings),
                  const SizedBox(height: 20),
                  Semantics(
                    header: true,
                    child: Text(
                      strings.availableTimes,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final (offset, label) in [
                        strings.current,
                        strings.next,
                      ].indexed)
                        ChoiceChip(
                          label: Text(label),
                          selected: _model.offset == offset,
                          onSelected: _model.busy
                              ? null
                              : (selected) {
                                  if (selected) _model.selectWeek(offset);
                                },
                        ),
                    ],
                  ),
                ],
                if (_model.week case final week?) ..._days(week, strings),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selections(BookingStrings strings) {
    final barber = _model.barber;
    final service = _model.service;
    final showEmpty = !_model.busy && _model.failure == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        _selector(
          label: strings.barber,
          icon: Icons.person_outline,
          value: barber == null ? null : _barberName(barber, strings),
          placeholder: showEmpty && _model.barbers.isEmpty
              ? strings.noBarbers
              : strings.chooseBarber,
          onTap: _model.busy || _model.barbers.isEmpty
              ? null
              : () async {
                  final selection = await _pickOption(
                    title: strings.chooseBarber,
                    options: _model.barbers,
                    current: barber,
                    name: (item) => _barberName(item, strings),
                  );
                  if (mounted && selection != null && selection != barber) {
                    await _model.selectBarber(selection);
                  }
                },
        ),
        _selector(
          label: strings.service,
          icon: Icons.content_cut,
          value: service == null ? null : strings.serviceName(service),
          details: service == null ? null : _serviceDetails(service, strings),
          placeholder: barber == null
              ? strings.barberFirst
              : showEmpty && _model.services.isEmpty
              ? strings.noServices
              : strings.chooseService,
          onTap: _model.busy || _model.services.isEmpty
              ? null
              : () async {
                  final selection = await _pickOption(
                    title: strings.chooseService,
                    options: _model.services,
                    current: service,
                    name: strings.serviceName,
                    details: (item) => _serviceDetails(item, strings),
                  );
                  if (mounted && selection != null && selection != service) {
                    await _model.selectService(selection);
                  }
                },
        ),
      ],
    );
  }

  String _barberName(BookingBarber barber, BookingStrings strings) =>
      barber.name.isEmpty ? strings.unknownName : barber.name;

  Widget _selector({
    required String label,
    required IconData icon,
    required String? value,
    required String placeholder,
    required VoidCallback? onTap,
    Widget? details,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: colors.surfaceContainerLow,
      child: ListTile(
        enabled: onTap != null,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          radius: 19,
          backgroundColor: colors.secondaryContainer,
          foregroundColor: colors.onSecondaryContainer,
          child: Icon(icon, size: 19),
        ),
        title: Text(label, style: theme.textTheme.labelLarge),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text(
              value ?? placeholder,
              style: value == null
                  ? theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    )
                  : theme.textTheme.titleMedium,
            ),
            ?details,
          ],
        ),
        trailing: onTap == null ? null : const Icon(Icons.expand_more),
      ),
    );
  }

  Future<T?> _pickOption<T extends Object>({
    required String title,
    required List<T> options,
    required T? current,
    required String Function(T) name,
    Widget Function(T)? details,
  }) => showDialog<T>(
    context: context,
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(title),
        scrollable: true,
        content: SizedBox(
          width: 420,
          child: Column(
            spacing: 8,
            children: [
              for (final option in options)
                Card.outlined(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Semantics(
                    selected: option == current,
                    child: ListTile(
                      selected: option == current,
                      selectedTileColor: colors.secondaryContainer,
                      selectedColor: colors.onSecondaryContainer,
                      title: Text(name(option)),
                      subtitle: details?.call(option),
                      trailing: option == current
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.pop(context, option),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(BookingStrings(context).cancel),
          ),
        ],
      );
    },
  );

  Widget _serviceDetails(BookingService service, BookingStrings strings) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        if (strings.servicePrice(service) case final price?)
          Text(
            price,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        Text(
          strings.serviceDuration(service),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _photoArea(BookingStrings strings) {
    final bytes = _model.photoBytes;
    final url = _model.existingPhoto;
    final hasPhoto = bytes != null || _model.hasExistingPhoto;
    final enabled = !_model.confirming && !_pickingPhoto;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.photo, style: Theme.of(context).textTheme.titleSmall),
        if (hasPhoto) ReferencePhoto(url: url, bytes: bytes, enabled: enabled),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: enabled ? _pickPhoto : null,
              icon: const Icon(Icons.photo_outlined),
              label: Text(hasPhoto ? strings.changePhoto : strings.addPhoto),
            ),
            if (hasPhoto)
              TextButton(
                onPressed: !enabled
                    ? null
                    : () {
                        setState(() => _photoError = false);
                        _model.setPhoto(null);
                      },
                child: Text(strings.removePhoto),
              ),
          ],
        ),
        if (_photoError)
          Text(
            strings.photoError,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }

  List<Widget> _days(BookingWeek week, BookingStrings strings) {
    if (week.slots.isEmpty) {
      return [
        const SizedBox(height: 12),
        Card.outlined(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text(
                  strings.noTimes,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                FilledButton.tonalIcon(
                  onPressed: _model.busy ? null : _model.retry,
                  icon: const Icon(Icons.refresh),
                  label: Text(strings.refresh),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    final calendar = AgendaCalendar(week.zoneId);
    final byDay = <DateTime, List<BookingSlot>>{};
    for (final slot in week.slots) {
      byDay.putIfAbsent(calendar.dateOf(slot.start), () => []).add(slot);
    }
    return [
      const SizedBox(height: 8),
      for (final (index, day) in byDay.entries.indexed)
        Card.outlined(
          key: ValueKey(day.key),
          child: ExpansionTile(
            initiallyExpanded: index == 0,
            title: Text(strings.date(day.key)),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final slot in day.value)
                    ChoiceChip(
                      label: Text(
                        strings.interval(calendar, slot.start, slot.end),
                      ),
                      selected: _model.slot == slot,
                      onSelected: _model.busy
                          ? null
                          : (selected) {
                              if (selected) _model.selectSlot(slot);
                            },
                    ),
                ],
              ),
            ],
          ),
        ),
    ];
  }
}
