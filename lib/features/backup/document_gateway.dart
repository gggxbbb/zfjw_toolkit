import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

abstract interface class DocumentGateway {
  Future<String?> openBackup();
  Future<bool> save(String name, Uint8List bytes, String mimeType);
}

class SystemDocumentGateway implements DocumentGateway {
  @override
  Future<String?> openBackup() async {
    final file = await FilePicker.pickFile(
      dialogTitle: '选择完整 JSON 备份',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return null;
    // Bound input before decoding or allocating the full document.
    const limit = 64 * 1024 * 1024;
    final length = await file.length();
    if (length != null && length > limit) {
      throw const FormatException('备份超过 64 MB，无法导入');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      if (bytes.length + chunk.length > limit) {
        throw const FormatException('备份超过 64 MB，无法导入');
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }

  @override
  Future<bool> save(String name, Uint8List bytes, String mimeType) async =>
      await FilePicker.saveFile(
        fileName: name,
        bytes: bytes,
        mimeType: mimeType,
        dialogTitle: '保存导出文件',
      ) !=
      null;
}
