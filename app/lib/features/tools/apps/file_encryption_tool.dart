import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';

import 'tool_io.dart';
import 'tool_shell.dart';

/// File encryption with a password.
///
/// Format (all lengths in bytes):
///
///   4  magic "MTE1"
///   1  format version (1)
///   4  PBKDF2 iterations, big-endian
///   1  salt length (16)
///   1  nonce length (12)
///  16  salt
///  12  nonce
///  16  GCM authentication tag
///   n  ciphertext
///
/// The header is not secret: it carries only what is needed to derive the key
/// again. The original file name is not stored, so the `.enc` file still shows
/// what it was called. The screen says so.
const List<int> _magic = <int>[0x4d, 0x54, 0x45, 0x31];
const int _version = 1;
const int _iterations = 210000;
const int _saltLength = 16;
const int _nonceLength = 12;
const int _macLength = 16;

/// The largest file this tool will hold in memory. Both encryption and
/// decryption are whole-file operations in this design.
const int maxFileBytes = 128 * 1024 * 1024;

/// Thrown when the password does not authenticate the file.
class WrongPasswordException implements Exception {
  /// Create the error.
  const WrongPasswordException();
}

/// Encrypt [clear] with [password], returning the sealed file.
Future<Uint8List> encryptFileBytes(
  List<int> clear,
  String password, {
  int iterations = _iterations,
}) async {
  final salt = _randomBytes(_saltLength);
  final key = await _derive(password, salt, iterations);
  final box = await AesGcm.with256bits().encrypt(clear, secretKey: key);

  final header = BytesBuilder(copy: false)
    ..add(_magic)
    ..addByte(_version)
    ..add(<int>[
      (iterations >> 24) & 0xff,
      (iterations >> 16) & 0xff,
      (iterations >> 8) & 0xff,
      iterations & 0xff,
    ])
    ..addByte(_saltLength)
    ..addByte(_nonceLength)
    ..add(salt)
    ..add(box.nonce)
    ..add(box.mac.bytes);
  return Uint8List.fromList(<int>[...header.takeBytes(), ...box.cipherText]);
}

/// Decrypt a file produced by [encryptFileBytes].
///
/// Throws [FormatException] if the file is not in this format, and
/// [WrongPasswordException] if the password is wrong or the file was altered.
Future<Uint8List> decryptFileBytes(
  List<int> sealed,
  String password,
) async {
  final bytes = Uint8List.fromList(sealed);
  const fixed = 4 + 1 + 4 + 1 + 1;
  if (bytes.length < fixed + _saltLength + _nonceLength + _macLength) {
    throw const FormatException('This file is too short to be an encrypted '
        'Max Tools file.');
  }
  for (var index = 0; index < _magic.length; index++) {
    if (bytes[index] != _magic[index]) {
      throw const FormatException('This file was not encrypted by Max Tools.');
    }
  }
  if (bytes[4] != _version) {
    throw FormatException('This file uses encryption format ${bytes[4]}, '
        'which this version cannot read.');
  }
  final iterations =
      (bytes[5] << 24) | (bytes[6] << 16) | (bytes[7] << 8) | bytes[8];
  final saltLength = bytes[9];
  final nonceLength = bytes[10];
  var offset = fixed;
  final salt = bytes.sublist(offset, offset + saltLength);
  offset += saltLength;
  final nonce = bytes.sublist(offset, offset + nonceLength);
  offset += nonceLength;
  final mac = bytes.sublist(offset, offset + _macLength);
  offset += _macLength;
  final cipherText = bytes.sublist(offset);

  final key = await _derive(password, salt, iterations);
  try {
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
      secretKey: key,
    );
    return Uint8List.fromList(clear);
  } on SecretBoxAuthenticationError {
    throw const WrongPasswordException();
  }
}

Future<SecretKey> _derive(String password, List<int> salt, int iterations) {
  return Pbkdf2.hmacSha256(iterations: iterations, bits: 256).deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: salt,
  );
}

List<int> _randomBytes(int length) {
  final random = Random.secure();
  return List<int>.generate(length, (_) => random.nextInt(256));
}

enum _Mode { encrypt, decrypt }

/// Encrypts or decrypts one file with a password.
class FileEncryptionTool extends StatefulWidget {
  /// Create the tool.
  const FileEncryptionTool({super.key});

  @override
  State<FileEncryptionTool> createState() => _FileEncryptionToolState();
}

class _FileEncryptionToolState extends State<FileEncryptionTool> {
  final TextEditingController _path = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  _Mode _mode = _Mode.encrypt;
  bool _busy = false;
  String? _status;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _path.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final chosen = await pickFile(context, start: _path.text.trim());
    if (chosen == null) return;
    setState(() {
      _path.text = chosen;
      _result = null;
      _error = null;
    });
  }

  Future<void> _start() async {
    final path = _path.text.trim();
    final password = _password.text;
    if (path.isEmpty) {
      setState(() => _error = 'Choose a file first.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = _mode == _Mode.encrypt
          ? 'Choose a password. Without it the file cannot be recovered.'
          : 'Enter the password used to lock the file.');
      return;
    }
    if (_mode == _Mode.encrypt) {
      if (password.length < 10) {
        setState(() => _error = 'Use at least 10 characters. Longer is better '
            'than complicated.');
        return;
      }
      if (password != _confirm.text) {
        setState(() => _error = 'The two passwords do not match.');
        return;
      }
    }
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type != FileSystemEntityType.file) {
      setState(() => _error = 'That is not a file this tool can open.');
      return;
    }

    final file = File(path);
    final size = await file.length();
    if (size > maxFileBytes) {
      setState(() => _error = 'This file is ${formatBytes(size)}. The limit is '
          '${formatBytes(maxFileBytes)}, because the whole file is held in '
          'memory. Use a dedicated encryption tool for larger files.');
      return;
    }

    setState(() {
      _busy = true;
      _status = _mode == _Mode.encrypt ? 'Encrypting…' : 'Decrypting…';
      _result = null;
      _error = null;
    });

    try {
      final bytes = await file.readAsBytes();
      final output = _mode == _Mode.encrypt
          ? await encryptFileBytes(bytes, password)
          : await decryptFileBytes(bytes, password);
      final destination = _outputPath(path);
      await _write(destination, output);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _password.clear();
        _confirm.clear();
        _result = _mode == _Mode.encrypt
            ? 'Locked ${formatBytes(size)} into ${formatBytes(output.length)}.\n\n'
                '$destination'
            : 'Unlocked ${formatBytes(output.length)}.\n\n$destination';
      });
    } on WrongPasswordException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _error = 'That password did not unlock this file, or the file has been '
            'altered.';
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _error = error.message;
      });
    } on FileSystemException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _error = 'The file could not be ${_mode == _Mode.encrypt ? 'read' : 'written'}: '
            '${error.message}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _error = 'Something went wrong: $error';
      });
    }
  }

  String _outputPath(String input) {
    final base = _mode == _Mode.encrypt
        ? '$input.enc'
        : input.toLowerCase().endsWith('.enc')
            ? input.substring(0, input.length - 4)
            : '$input.decrypted';
    if (!File(base).existsSync() && !Directory(base).existsSync()) return base;
    final dot = base.lastIndexOf('.');
    for (var attempt = 2; attempt < 1000; attempt++) {
      final candidate = dot <= 0
          ? '$base ($attempt)'
          : '${base.substring(0, dot)} ($attempt)${base.substring(dot)}';
      if (!File(candidate).existsSync() && !Directory(candidate).existsSync()) {
        return candidate;
      }
    }
    throw const FileSystemException('No free output name was available.');
  }

  Future<void> _write(String path, List<int> bytes) async {
    final temporary = File('$path.part');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ToolShell(
      title: 'File encryption',
      howTo: 'Choose one file, enter a password, and press Encrypt. The locked '
          'copy is written beside the original; the original is left alone. '
          'Decrypt reverses it.',
      children: <Widget>[
        ToolSection(
          title: 'What are you doing?',
          icon: Icons.swap_horiz,
          children: <Widget>[
            SegmentedButton<_Mode>(
              segments: const <ButtonSegment<_Mode>>[
                ButtonSegment<_Mode>(
                  value: _Mode.encrypt,
                  label: Text('Encrypt'),
                  icon: Icon(Icons.lock_outline, size: 18),
                ),
                ButtonSegment<_Mode>(
                  value: _Mode.decrypt,
                  label: Text('Decrypt'),
                  icon: Icon(Icons.lock_open, size: 18),
                ),
              ],
              selected: <_Mode>{_mode},
              onSelectionChanged: _busy
                  ? null
                  : (Set<_Mode> selection) => setState(() {
                        _mode = selection.first;
                        _result = null;
                        _error = null;
                      }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _path,
              onChanged: (_) => setState(() {
                _result = null;
                _error = null;
              }),
              decoration: const InputDecoration(
                labelText: 'File path',
                hintText: 'Choose a file, or paste its full path.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Choose file'),
            ),
          ],
        ),
        ToolSection(
          title: 'Password',
          icon: Icons.key_outlined,
          children: <Widget>[
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _mode == _Mode.encrypt
                    ? 'Password for the locked file'
                    : 'Password used to lock it',
                border: const OutlineInputBorder(),
              ),
            ),
            if (_mode == _Mode.encrypt) ...<Widget>[
              const SizedBox(height: 10),
              TextField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Type the password again',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _start,
                icon: Icon(
                  _mode == _Mode.encrypt ? Icons.lock_outline : Icons.lock_open,
                  size: 18,
                ),
                label: Text(
                  _busy
                      ? (_status ?? 'Working…')
                      : _mode == _Mode.encrypt
                          ? 'Encrypt the file'
                          : 'Decrypt the file',
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.check_circle_outline,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _result!,
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        ToolSection(
          title: 'What this protects, and what it does not',
          icon: Icons.info_outline,
          children: <Widget>[
            const ToolNote(
              'AES-256-GCM with PBKDF2-HMAC-SHA256, 210,000 rounds and a '
              'random salt. Tampering breaks decryption instead of silently '
              'changing the file.',
            ),
            const ToolNote(
              'The password is the only key. If it is forgotten there is no '
              'recovery, and a short password can be guessed offline.',
              warning: true,
            ),
            const ToolNote(
              'The original file is left in place. Delete it yourself if you '
              'only want the locked copy, and remember that deletion may leave '
              'recoverable blocks on flash storage.',
            ),
            const ToolNote(
              'The locked file keeps the original name with .enc added. If the '
              'name itself is sensitive, rename the locked file.',
            ),
            ToolNote(
              'Files are processed whole, in memory, with a limit of '
              '${formatBytes(maxFileBytes)}.',
            ),
          ],
        ),
      ],
    );
  }
}
