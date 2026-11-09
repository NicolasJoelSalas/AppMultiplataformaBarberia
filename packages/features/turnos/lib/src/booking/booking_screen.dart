import 'package:domain/domain.dart';
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
  });

  final BookingRepository repository;
  final BookingPhotoRepository photos;
  final String initialName;
  final Appointment? original;

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
    _model = BookingViewModel(widget.repository, widget.photos, widget.original)
      ..initialize();
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
            minimum: const EdgeInsets.all(16),
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
              padding: const EdgeInsets.all(16),
              children: [
                Text(strings.instructions),
                if (_model.busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
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
                const SizedBox(height: 16),
                DropdownButtonFormField<BookingBarber>(
                  key: ValueKey(('barber', _model.barber)),
                  initialValue: _model.barber,
                  decoration: InputDecoration(
                    labelText: strings.barber,
                    border: const OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: [
                    for (final item in _model.barbers)
                      DropdownMenuItem(
                        value: item,
                        child: Text(
                          item.name.isEmpty ? strings.unknownName : item.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _model.busy || _model.barbers.isEmpty
                      ? null
                      : (item) {
                          if (item != null) _model.selectBarber(item);
                        },
                ),
                if (!_model.busy &&
                    _model.failure == null &&
                    _model.barbers.isEmpty)
                  Text(strings.noBarbers),
                if (_model.barber != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<BookingService>(
                    key: ValueKey(('service', _model.barber, _model.service)),
                    initialValue: _model.service,
                    decoration: InputDecoration(
                      labelText: strings.service,
                      border: const OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: [
                      for (final item in _model.services)
                        DropdownMenuItem(
                          value: item,
                          child: Text(
                            strings.serviceOption(item),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _model.busy || _model.services.isEmpty
                        ? null
                        : (item) {
                            if (item != null) _model.selectService(item);
                          },
                  ),
                  if (!_model.busy &&
                      _model.failure == null &&
                      _model.services.isEmpty)
                    Text(strings.noServices),
                ],
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
                  const SizedBox(height: 12),
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

  Widget _photoArea(BookingStrings strings) {
    final bytes = _model.photoBytes;
    final url = _model.existingPhoto;
    final hasPhoto = bytes != null || url != null;
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
        Text(strings.noTimes),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: _model.busy ? null : _model.retry,
            child: Text(strings.refresh),
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
