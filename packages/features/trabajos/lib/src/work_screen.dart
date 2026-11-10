import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'work_view_model.dart';

String _text(BuildContext context, String es, String en) =>
    Localizations.localeOf(context).languageCode == 'en' ? en : es;

class WorkScreen extends StatefulWidget {
  const WorkScreen({
    super.key,
    required this.repository,
    required this.barber,
    required this.active,
    required this.title,
    required this.onReserve,
    required this.onDirections,
  });

  final WorkRepository repository;
  final bool barber;
  final bool active;
  final String title;
  final ValueChanged<String> onReserve;
  final ValueChanged<String> onDirections;

  @override
  State<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends State<WorkScreen> {
  late final WorkViewModel _model;
  final _picker = ImagePicker();
  bool _deleting = false;
  bool _restoringDraft = false;
  bool _draftLoaded = false;
  bool _editorOpen = false;
  WorkDraft? _recoveredDraft;

  @override
  void initState() {
    super.initState();
    _model = WorkViewModel(widget.repository)..start();
    _restoreWhenVisible();
  }

  @override
  void didUpdateWidget(covariant WorkScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) _restoreWhenVisible();
  }

  void _restoreWhenVisible() {
    if (!widget.barber || !widget.active || _draftLoaded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active) unawaited(_restoreDraft());
    });
  }

  Future<void> _restoreDraft() async {
    if (_restoringDraft || _draftLoaded) return;
    setState(() => _restoringDraft = true);
    WorkDraft? draft;
    try {
      draft = await _model.readDraft();
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final result = await _picker.retrieveLostData();
        final file = result.files?.firstOrNull;
        if (file != null && draft != null) {
          draft = WorkDraft(
            id: _model.newPostId(),
            description: draft.description,
            photo: await file.readAsBytes(),
          );
          if (mounted) await _model.saveDraft(draft);
        }
      }
    } catch (_) {
      // Keep the saved draft if the picker cannot restore its pending photo.
    }
    if (!mounted) return;
    setState(() {
      _recoveredDraft = draft;
      _restoringDraft = false;
      _draftLoaded = true;
    });
    if (draft != null &&
        widget.active &&
        ModalRoute.of(context)?.isCurrent == true) {
      await _openEditor();
    }
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _openEditor({WorkPost? post}) async {
    if (_editorOpen || _restoringDraft) return;
    _editorOpen = true;
    final draft = post == null ? _recoveredDraft : null;
    if (draft != null) setState(() => _recoveredDraft = null);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PostEditor(
          model: _model,
          picker: _picker,
          post: post,
          draft: draft,
        ),
      );
    } finally {
      _editorOpen = false;
    }
  }

  Future<void> _delete(WorkPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _text(context, '¿Eliminar este trabajo?', 'Delete this post?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_text(context, 'Volver', 'Back')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_text(context, 'Eliminar', 'Delete')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _deleting) return;
    setState(() => _deleting = true);
    try {
      await _model.delete(post);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _text(
                context,
                'No se pudo eliminar el trabajo.',
                'Could not delete the post.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) {
      final feed = _model.feed;
      final offline = _model.offline;
      final colors = Theme.of(context).colorScheme;
      const actionSize = Size(112, 48);
      final filledActionStyle = FilledButton.styleFrom(minimumSize: actionSize);
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          automaticallyImplyLeading: false,
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
        ),
        floatingActionButton:
            widget.barber &&
                (_recoveredDraft != null || (feed != null && !offline))
            ? FloatingActionButton.extended(
                onPressed: _restoringDraft || !_draftLoaded
                    ? null
                    : _openEditor,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(
                  _recoveredDraft == null
                      ? _text(context, 'Publicar', 'Publish')
                      : _text(context, 'Continuar borrador', 'Continue draft'),
                ),
              )
            : null,
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  widget.barber ? 88 : 24,
                ),
                itemCount: (feed?.posts.length ?? 0) + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    if (offline) {
                      return ListTile(
                        leading: const Icon(Icons.cloud_off_outlined),
                        title: Text(
                          _text(
                            context,
                            'Mostrando trabajos guardados',
                            'Showing saved posts',
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: _model.start,
                          child: Text(_text(context, 'Reintentar', 'Retry')),
                        ),
                      );
                    }
                    if (feed == null) return const LinearProgressIndicator();
                    if (feed.posts.isEmpty) {
                      return Text(
                        _text(
                          context,
                          'Todavía no hay trabajos publicados.',
                          'No posts yet.',
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                  final post = feed!.posts[index - 1];
                  return Card(
                    key: ValueKey(post.id),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PostImage(
                          key: ValueKey((post.id, post.imageUrl, offline)),
                          model: _model,
                          post: post,
                        ),
                        ListTile(
                          title: Text(post.barberName),
                          subtitle: post.description.isEmpty
                              ? null
                              : Text(post.description),
                        ),
                        if (!offline &&
                            (widget.barber
                                ? post.isOwn
                                : post.barberId.isNotEmpty))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: widget.barber
                                  ? [
                                      FilledButton.tonalIcon(
                                        onPressed: _deleting
                                            ? null
                                            : () => _openEditor(post: post),
                                        style: filledActionStyle,
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                        ),
                                        label: Text(
                                          _text(context, 'Editar', 'Edit'),
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: _deleting
                                            ? null
                                            : () => _delete(post),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: actionSize,
                                          foregroundColor: colors.error,
                                        ),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                        ),
                                        label: Text(
                                          _text(context, 'Eliminar', 'Delete'),
                                        ),
                                      ),
                                    ]
                                  : [
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            widget.onDirections(post.barberId),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: actionSize,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.directions_outlined,
                                          size: 18,
                                        ),
                                        label: Text(
                                          _text(
                                            context,
                                            'Cómo llegar',
                                            'Directions',
                                          ),
                                        ),
                                      ),
                                      FilledButton.icon(
                                        onPressed: () =>
                                            widget.onReserve(post.barberId),
                                        style: filledActionStyle,
                                        icon: const Icon(
                                          Icons.event_available_outlined,
                                          size: 18,
                                        ),
                                        label: Text(
                                          _text(context, 'Reservar', 'Book'),
                                        ),
                                      ),
                                    ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PostImage extends StatefulWidget {
  const _PostImage({super.key, required this.model, required this.post});

  final WorkViewModel model;
  final WorkPost post;

  @override
  State<_PostImage> createState() => _PostImageState();
}

class _PostImageState extends State<_PostImage> {
  late final _image = widget.model.readImage(widget.post);

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 4 / 3,
    child: FutureBuilder<Uint8List?>(
      future: _image,
      builder: (context, snapshot) {
        final placeholder = Center(
          child: Text(
            _text(context, 'Imagen no disponible', 'Image unavailable'),
          ),
        );
        if (snapshot.data case final bytes?) {
          return Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => placeholder,
          );
        }
        return snapshot.connectionState == ConnectionState.waiting
            ? const Center(child: CircularProgressIndicator())
            : placeholder;
      },
    ),
  );
}

class _PostEditor extends StatefulWidget {
  const _PostEditor({
    required this.model,
    required this.picker,
    this.post,
    this.draft,
  });

  final WorkViewModel model;
  final ImagePicker picker;
  final WorkPost? post;
  final WorkDraft? draft;

  @override
  State<_PostEditor> createState() => _PostEditorState();
}

class _PostEditorState extends State<_PostEditor> {
  late final _description = TextEditingController(
    text: widget.draft?.description ?? widget.post?.description,
  );
  late Uint8List? _photo = widget.draft?.photo;
  late String _id = widget.draft?.id ?? widget.model.newPostId();
  late WorkFraming _framing = widget.draft?.framing ?? const WorkFraming();
  bool _busy = false;
  bool _confirming = false;
  bool _draftError = false;
  late bool _storedDraft = widget.draft != null;
  Future<void>? _draftWrite;
  String? _error;
  bool get _new => widget.post == null;
  bool get _dirty =>
      _photo != null || _description.text != (widget.post?.description ?? '');

  WorkDraft get _draft => WorkDraft(
    id: _id,
    description: _description.text,
    photo: _photo,
    framing: _framing,
  );

  @override
  void initState() {
    super.initState();
    if (_new) unawaited(_persistDraft());
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _persistDraft() => _draftWrite = _writeDraft();

  Future<void> _writeDraft() async {
    try {
      await widget.model.saveDraft(_draft);
      _storedDraft = true;
      if (mounted && _draftError) setState(() => _draftError = false);
    } catch (_) {
      if (mounted && !_draftError) setState(() => _draftError = true);
    }
  }

  Future<void> _discardDraft() async {
    await _draftWrite;
    if (_storedDraft) await widget.model.discardDraft();
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!kIsWeb) {
        // Flush the draft before opening an external activity on Android.
        await _persistDraft();
        if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      }
      final file = await widget.picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      setState(() {
        _id = widget.model.newPostId();
        _photo = bytes;
        _framing = const WorkFraming();
      });
      await _persistDraft();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _text(
            context,
            'No se pudo abrir la foto.',
            'Could not open the photo.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestClose() async {
    if (_busy || _confirming) return;
    if (_dirty) {
      _confirming = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            _text(context, '¿Descartar los cambios?', 'Discard changes?'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_text(context, 'Seguir editando', 'Keep editing')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_text(context, 'Descartar', 'Discard')),
            ),
          ],
        ),
      );
      _confirming = false;
      if (discard != true) return;
    }
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (!_new) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _busy = true);
    try {
      await _discardDraft();
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _text(
            context,
            'No se pudo descartar el borrador.',
            'Could not discard the draft.',
          );
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_new) {
        await widget.model.publish(_draft);
        if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
        await _discardDraft();
      } else {
        await widget.model.editDescription(widget.post!, _description.text);
      }
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _text(
            context,
            'No se pudo guardar. Revisá tu conexión y volvé a intentar.',
            'Could not save. Check your connection and try again.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_requestClose());
    },
    child: AlertDialog(
      scrollable: true,
      title: Text(
        _new
            ? _text(context, 'Nuevo trabajo', 'New post')
            : _text(context, 'Editar descripción', 'Edit description'),
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_photo case final bytes?) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 224),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    alignment: Alignment(
                      _framing.horizontal,
                      _framing.vertical,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(_text(context, 'Ajustar encuadre', 'Adjust framing')),
              _framingControl(
                label: _text(context, 'Horizontal', 'Horizontal'),
                value: _framing.horizontal,
                onChanged: (value) => setState(() {
                  _framing = WorkFraming(
                    horizontal: value,
                    vertical: _framing.vertical,
                  );
                }),
              ),
              _framingControl(
                label: _text(context, 'Vertical', 'Vertical'),
                value: _framing.vertical,
                onChanged: (value) => setState(() {
                  _framing = WorkFraming(
                    horizontal: _framing.horizontal,
                    vertical: value,
                  );
                }),
              ),
            ],
            if (_new)
              Wrap(
                children: [
                  if (!kIsWeb)
                    TextButton.icon(
                      onPressed: _busy ? null : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(_text(context, 'Cámara', 'Camera')),
                    ),
                  TextButton.icon(
                    onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      kIsWeb
                          ? _text(context, 'Elegir archivo', 'Choose file')
                          : _text(context, 'Galería', 'Gallery'),
                    ),
                  ),
                ],
              ),
            TextField(
              controller: _description,
              enabled: !_busy,
              maxLength: SaveWorkPost.maxDescription,
              maxLines: 3,
              onChanged: _new ? (_) => unawaited(_persistDraft()) : null,
              decoration: InputDecoration(
                labelText: _text(context, 'Descripción', 'Description'),
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_draftError)
              Text(
                _text(
                  context,
                  'No se pudo guardar el borrador en este dispositivo.',
                  'Could not save the draft on this device.',
                ),
              ),
            if (_error case final error?) Text(error),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _requestClose,
          child: Text(_text(context, 'Volver', 'Back')),
        ),
        FilledButton(
          onPressed: _busy || (_new && _photo == null) ? null : _save,
          child: Text(_text(context, 'Guardar', 'Save')),
        ),
      ],
    ),
  );

  Widget _framingControl({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Semantics(
        label: label,
        child: Slider(
          min: -1,
          value: value,
          onChanged: _busy ? null : onChanged,
          onChangeEnd: (_) => unawaited(_persistDraft()),
        ),
      ),
    ],
  );
}
