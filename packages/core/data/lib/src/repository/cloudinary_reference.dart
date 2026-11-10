bool isCloudinaryReferenceUrl(String value) {
  final uri = Uri.tryParse(value);
  return value.length <= 2048 &&
      value.trim() == value &&
      uri?.host == 'res.cloudinary.com' &&
      RegExp(r'^https://res[.]cloudinary[.]com/[^/]+/image/upload/.+$')
          .hasMatch(value);
}
