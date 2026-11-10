import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'booking_strings.dart';

class ReferencePhoto extends StatelessWidget {
  const ReferencePhoto({super.key, this.url, this.bytes, this.enabled = true});

  final String? url;
  final Uint8List? bytes;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final strings = BookingStrings(context);
    final source = url == null ? null : Uri.tryParse(url!);
    if (bytes == null &&
        (source?.scheme != 'https' || source?.host.isNotEmpty != true)) {
      return Text(strings.photoError);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 160,
            height: 104,
            child: _image(strings, BoxFit.cover),
          ),
        ),
        TextButton.icon(
          onPressed: !enabled
              ? null
              : () => showDialog<void>(
                  context: context,
                  builder: (context) => Dialog(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            tooltip: MaterialLocalizations.of(context)
                                .closeButtonTooltip,
                            icon: const Icon(Icons.close),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: MediaQuery.sizeOf(context).height * .55,
                          child: InteractiveViewer(
                            child: _image(strings, BoxFit.contain),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          icon: const Icon(Icons.zoom_in),
          label: Text(strings.viewPhoto),
        ),
      ],
    );
  }

  Widget _image(BookingStrings strings, BoxFit fit) {
    Widget error(BuildContext context, Object error, StackTrace? stack) =>
        Center(child: Text(strings.photoError));
    final local = bytes;
    return local == null
        ? Image.network(
            url!,
            fit: fit,
            semanticLabel: strings.photo,
            errorBuilder: error,
          )
        : Image.memory(
            local,
            fit: fit,
            semanticLabel: strings.photo,
            errorBuilder: error,
          );
  }
}
