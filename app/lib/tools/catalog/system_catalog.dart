/// File, path, URI and system tools.
///
/// Read-only by default: anything that creates, moves or deletes is marked
/// `readOnly: false` so the UI can label it and automation can require
/// confirmation.
library;

import 'dart:io';

import '../../tools/library/data/xml_service.dart';
import '../../tools/library/files/file_metadata_service.dart';
import '../../tools/library/security/encryption_service.dart';
import '../../tools/library/system/uri_service.dart';
import '../tool_descriptor.dart';

/// Tools that touch the filesystem, URLs and the machine.
List<ToolDescriptor> systemTools() => <ToolDescriptor>[
      // ── Path helpers ─────────────────────────────────────────────────────
      ToolDescriptor(
        id: 'paths.join',
        name: 'Join Paths',
        description: 'Join path segments with the platform separator.',
        category: ToolCategory.file,
        tags: <String>['path', 'join', 'combine'],
        synonyms: <String>['combine paths', 'build path'],
        parameters: const <ToolParameter>[
          ToolParameter(
            name: 'base',
            description: 'Starting path.',
            required: true,
          ),
          ToolParameter(
            name: 'part',
            description: 'Segment to append.',
            required: true,
          ),
        ],
        run: (args) async => ToolResult.success(
          '${args['base']}${Platform.pathSeparator}${args['part']}',
        ),
      ),
      ToolDescriptor(
        id: 'paths.basename',
        name: 'File Name',
        description: 'Return the final component of a path.',
        category: ToolCategory.file,
        tags: <String>['path', 'name', 'basename'],
        synonyms: <String>['file name', 'last part of path'],
        parameters: const <ToolParameter>[
          ToolParameter(
            name: 'path',
            description: 'Path to inspect.',
            required: true,
          ),
        ],
        run: (args) async =>
            ToolResult.success(_basename(args['path'] as String)),
      ),
      ToolDescriptor(
        id: 'paths.dirname',
        name: 'Folder Name',
        description: 'Return the parent folder of a path.',
        category: ToolCategory.file,
        tags: <String>['path', 'folder', 'dirname'],
        synonyms: <String>['parent folder', 'directory of path'],
        parameters: const <ToolParameter>[
          ToolParameter(
            name: 'path',
            description: 'Path to inspect.',
            required: true,
          ),
        ],
        run: (args) async => ToolResult.success(_dirname(args['path'] as String)),
      ),
      ToolDescriptor(
        id: 'paths.extension',
        name: 'File Extension',
        description: 'Return the extension of a path without the dot.',
        category: ToolCategory.file,
        tags: <String>['path', 'extension', 'suffix'],
        synonyms: <String>['file extension', 'file suffix'],
        parameters: const <ToolParameter>[
          ToolParameter(
            name: 'path',
            description: 'Path to inspect.',
            required: true,
          ),
        ],
        run: (args) async {
          final name = _basename(args['path'] as String);
          final dot = name.lastIndexOf('.');
          return ToolResult.success(dot > 0 ? name.substring(dot + 1) : '');
        },
      ),

      // ── Filesystem reads ────────────────────────────────────────────────
      ToolDescriptor(
        id: 'files.exists',
        name: 'Check Path Exists',
        description: 'Report whether a file or folder exists.',
        category: ToolCategory.file,
        tags: <String>['file', 'exists', 'check'],
        synonyms: <String>['does this file exist', 'check path'],
        parameters: const <ToolParameter>[
          ToolParameter(
            name: 'path',
            description: 'Path to check.',
            required: true,
          ),
        ],
        run: (args) async {
          final path = args['path'] as String;
          return ToolResult.success(<String, dynamic>{
            'exists': File(path).existsSync() || Directory(path).existsSync(),
          });
        },
      ),
      ToolDescriptor(
        id: 'files.metadata',
        name: 'File Details',
        description: 'Report size and modification time of a file.',
        category: ToolCategory.file,
        tags: <String>['file', 'size', 'metadata', 'modified'],
        synonyms: <String>['file size', 'file details', 'how big is this file'],
        parameters: const <ToolParameter>[
          ToolParameter(
            name: 'path',
            description: 'File to inspect.',
            required: true,
          ),
        ],
        run: (args) async {
          final file = File(args['path'] as String);
          final metadata = await FileMetadataService().read(file);
          if (metadata == null) {
            return ToolResult.failure('File not found: ${file.path}');
          }
          return ToolResult.success(<String, dynamic>{
            'path': file.path,
            'sizeBytes': metadata.sizeBytes,
            'modified': metadata.modified.toIso8601String(),
          });
        },
      ),
      ToolDescriptor(
        id: 'files.list',
        name: 'List Folder',
        description: 'List the files inside a folder.',
        category: ToolCategory.file,
        tags: <String>['file', 'list', 'directory', 'folder'],
        synonyms: <String>['list files', 'what is in this folder'],
        parameters: const <ToolParameter>[
          ToolParameter(
            name: 'path',
            description: 'Folder to list.',
            required: true,
          ),
          ToolParameter(
            name: 'limit',
            description: 'Maximum entries to return.',
            defaultValue: 200,
          ),
        ],
        run: (args) async {
          final directory = Directory(args['path'] as String);
          if (!await directory.exists()) {
            return ToolResult.failure('Folder not found: ${directory.path}');
          }
          final limit = args['limit'] as int? ?? 200;
          final entries = <String>[];
          try {
            await for (final entity in directory.list()) {
              if (entries.length >= limit) break;
              entries.add(_basename(entity.path));
            }
          } on FileSystemException catch (error) {
            return ToolResult.failure('Could not read folder: ${error.message}');
          }
          entries.sort();
          return ToolResult.success(<String, dynamic>{
            'count': entries.length,
            'entries': entries,
          });
        },
      ),
      ToolDescriptor(
        id: 'files.humanSize',
        name: 'Human File Size',
        description: 'Convert a byte count into a readable size.',
        category: ToolCategory.file,
        tags: <String>['size', 'bytes', 'format', 'readable'],
        synonyms: <String>['bytes to mb', 'human readable size'],
        parameters: const <ToolParameter>[
          ToolParameter(
            name: 'bytes',
            description: 'Number of bytes.',
            required: true,
          ),
        ],
        run: (args) async => ToolResult.success(_humanSize(args['bytes'] as int)),
      ),

      // ── URL tools ───────────────────────────────────────────────────────
      ToolDescriptor(
        id: 'url.validate',
        name: 'Validate URL',
        description: 'Check whether a URL parses and whether it uses HTTPS.',
        category: ToolCategory.network,
        tags: <String>['url', 'validate', 'https', 'link'],
        synonyms: <String>['is this a valid url', 'check link'],
        parameters: const <ToolParameter>[
          ToolParameter(
            name: 'url',
            description: 'The URL to check.',
            required: true,
          ),
        ],
        run: (args) async {
          final service = UriService();
          final url = args['url'] as String;
          return ToolResult.success(<String, dynamic>{
            'valid': service.isValid(url),
            'https': service.isHttps(url),
            'host': service.parse(url)?.host,
          });
        },
      ),
      ToolDescriptor(
        id: 'url.queryParams',
        name: 'URL Query Parameters',
        description: 'List the query parameters of a URL.',
        category: ToolCategory.network,
        tags: <String>['url', 'query', 'parameters'],
        synonyms: <String>['url parameters', 'query string'],
        parameters: const <ToolParameter>[
          ToolParameter(
            name: 'url',
            description: 'The URL to inspect.',
            required: true,
          ),
        ],
        run: (args) async => ToolResult.success(
          UriService().queryParams(args['url'] as String),
        ),
      ),
      ToolDescriptor(
        id: 'url.addParams',
        name: 'Add URL Parameters',
        description: 'Append query parameters to a URL.',
        category: ToolCategory.network,
        tags: <String>['url', 'query', 'parameters', 'build'],
        synonyms: <String>['add query parameters', 'build url'],
        parameters: const <ToolParameter>[
          ToolParameter(
            name: 'url',
            description: 'The base URL.',
            required: true,
          ),
          ToolParameter(
            name: 'params',
            description: 'Parameters as key=value pairs separated by commas.',
            required: true,
          ),
        ],
        run: (args) async {
          final params = <String, String>{};
          for (final pair in (args['params'] as String).split(',')) {
            final index = pair.indexOf('=');
            if (index > 0) {
              params[pair.substring(0, index).trim()] = pair.substring(index + 1).trim();
            }
          }
          if (params.isEmpty) {
            return const ToolResult.failure(
              'No key=value pairs found in "params".',
            );
          }
          return ToolResult.success(
            UriService().addQueryParams(args['url'] as String, params),
          );
        },
      ),

      // ── XML ─────────────────────────────────────────────────────────────
      ToolDescriptor(
        id: 'data.xml.extract',
        name: 'Extract XML Tag',
        description: 'Pull the text of every occurrence of an XML tag.',
        category: ToolCategory.data,
        tags: <String>['xml', 'extract', 'tag'],
        synonyms: <String>['read xml tag', 'extract xml'],
        parameters: const <ToolParameter>[
          ToolParameter(
            name: 'text',
            description: 'The XML source.',
            required: true,
          ),
          ToolParameter(
            name: 'tag',
            description: 'Tag name to extract.',
            required: true,
          ),
        ],
        run: (args) async => ToolResult.success(
          XmlService().extractAll(args['text'] as String, args['tag'] as String),
        ),
      ),
      ToolDescriptor(
        id: 'data.xml.escape',
        name: 'Escape XML',
        description: 'Escape text so it is safe inside XML.',
        category: ToolCategory.data,
        tags: <String>['xml', 'escape', 'encode'],
        synonyms: <String>['escape xml', 'xml encode'],
        parameters: const <ToolParameter>[
          ToolParameter(
            name: 'text',
            description: 'Text to escape.',
            required: true,
          ),
        ],
        run: (args) async =>
            ToolResult.success(XmlService().escape(args['text'] as String)),
      ),

      // ── Security ────────────────────────────────────────────────────────
      ToolDescriptor(
        id: 'security.obfuscate',
        name: 'Obfuscate Text',
        description: 'Lightweight reversible obfuscation with a key.',
        category: ToolCategory.security,
        tags: <String>['obfuscate', 'scramble', 'key'],
        synonyms: <String>['scramble text', 'obfuscate'],
        parameters: const <ToolParameter>[
          ToolParameter(
            name: 'text',
            description: 'Text to obfuscate.',
            required: true,
          ),
          ToolParameter(
            name: 'key',
            description: 'Key to use.',
            required: true,
          ),
        ],
        run: (args) async => ToolResult.success(
          EncryptionService().obfuscate(args['text'] as String, args['key'] as String),
        ),
      ),
      ToolDescriptor(
        id: 'security.deobfuscate',
        name: 'Deobfuscate Text',
        description: 'Reverse obfuscation using the same key.',
        category: ToolCategory.security,
        tags: <String>['deobfuscate', 'unscramble', 'key'],
        synonyms: <String>['unscramble text', 'deobfuscate'],
        parameters: const <ToolParameter>[
          ToolParameter(
            name: 'text',
            description: 'Obfuscated text.',
            required: true,
          ),
          ToolParameter(
            name: 'key',
            description: 'The key used to obfuscate.',
            required: true,
          ),
        ],
        run: (args) async => ToolResult.success(
          EncryptionService().deobfuscate(args['text'] as String, args['key'] as String),
        ),
      ),
      ToolDescriptor(
        id: 'security.generateKey',
        name: 'Generate Key',
        description: 'Generate a random key of the requested length.',
        category: ToolCategory.security,
        tags: <String>['key', 'random', 'generate', 'secret'],
        synonyms: <String>['make a key', 'random key'],
        parameters: const <ToolParameter>[
          ToolParameter(
            name: 'length',
            description: 'Key length in characters (8-128).',
            defaultValue: 24,
          ),
        ],
        run: (args) async {
          final length = args['length'] as int? ?? 24;
          if (length < 8 || length > 128) {
            return const ToolResult.failure('Key length must be between 8 and 128.');
          }
          return ToolResult.success(EncryptionService().generateKey(length));
        },
      ),

      // ── Writes (labelled as changing data) ──────────────────────────────
      ToolDescriptor(
        id: 'files.createFolder',
        name: 'Create Folder',
        description: 'Create a folder, including parents.',
        category: ToolCategory.file,
        readOnly: false,
        tags: <String>['folder', 'create', 'mkdir', 'directory'],
        synonyms: <String>['make folder', 'create directory'],
        parameters: const <ToolParameter>[
          ToolParameter(
            name: 'path',
            description: 'Folder to create.',
            required: true,
          ),
        ],
        run: (args) async {
          final directory = Directory(args['path'] as String);
          if (await directory.exists()) {
            return ToolResult.failure('Folder already exists: ${directory.path}');
          }
          try {
            await directory.create(recursive: true);
            return ToolResult.success(<String, dynamic>{
              'created': directory.path,
            });
          } on FileSystemException catch (error) {
            return ToolResult.failure('Could not create folder: ${error.message}');
          }
        },
      ),
    ];

String _basename(String path) {
  final normalised = path.replaceAll('/', r'\');
  final index = normalised.lastIndexOf(r'\');
  return index < 0 ? normalised : normalised.substring(index + 1);
}

String _dirname(String path) {
  final normalised = path.replaceAll('/', r'\');
  final index = normalised.lastIndexOf(r'\');
  if (index <= 0) return index == 0 ? r'\' : '.';
  return normalised.substring(0, index);
}

/// Format a byte count the way the file metadata service does.
String _humanSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
