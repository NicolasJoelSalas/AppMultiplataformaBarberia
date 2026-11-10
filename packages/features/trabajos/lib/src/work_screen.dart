import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    required this.title,
    required this.onReserve,
    required this.onDirections,
  });

  final WorkRepository repository;
  final bool barber;
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

  @override
  void initState() {
    super.initState();
    _model = WorkViewModel(widget.repository)..start();
    if (widget.barber && !kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recoverPhoto());
    }
  }

  Future<void> _recoverPhoto() async {
    try {
      final result = await _picker.retrieveLostData();
      final file = result.files?.firstOrNull;
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) _openEditor(photo: bytes);
    } catch (_) {
      // Lost data recovery is only supported by the Android picker.
    }
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  void _openEditor({WorkPost? post, Uint8List? photo}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PostEditor(
        model: _model,
        picker: _picker,
        post: post,
        recoveredPhoto: photo,
      ),
    );
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
        floatingActionButton: widget.barber && feed != null && !offline
            ? FloatingActionButton.extended(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(_text(context, 'Publicar', 'Publish')),
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
            fit: BoxFit.cover,
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
    this.recoveredPhoto,
  });

  final WorkViewModel model;
  final ImagePicker picker;
  final WorkPost? post;
  final Uint8List? recoveredPhoto;

  @override
  State<_PostEditor> createState() => _PostEditorState();
}

class _PostEditorState extends State<_PostEditor> {
  late final _description = TextEditingController(
    text: widget.post?.description,
  );
  late Uint8List? _photo = widget.recoveredPhoto;
  late String _id = widget.post?.id ?? widget.model.newPostId();
  bool _busy = false;
  String? _error;
  bool get _new => widget.post == null;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await widget.picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _id = widget.model.newPostId();
        _photo = bytes;
      });
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

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.model.save(_id, _description.text, image: _photo);
      if (mounted) {
        setState(() => _busy = false);
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
    canPop: !_busy,
    child: AlertDialog(
      scrollable: true,
      title: Text(
        _new
            ? _text(context, 'Nuevo trabajo', 'New post')
            : _text(context, 'Editar descripción', 'Edit description'),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_photo case final bytes?)
            Image.memory(bytes, height: 155, fit: BoxFit.contain),
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
            decoration: InputDecoration(
              labelText: _text(context, 'Descripción', 'Description'),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error case final error?) Text(error),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(_text(context, 'Volver', 'Back')),
        ),
        FilledButton(
          onPressed: _busy || (_new && _photo == null) ? null : _save,
          child: Text(_text(context, 'Guardar', 'Save')),
        ),
      ],
    ),
  );
}
