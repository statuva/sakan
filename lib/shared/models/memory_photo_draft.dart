import 'dart:typed_data';

class MemoryPhotoDraft {
  const MemoryPhotoDraft({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
}
