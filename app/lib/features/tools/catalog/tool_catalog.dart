/// The tools Max Tools ships with.
///
/// Every entry here is a working application: it has its own screen, it
/// explains itself on that screen, and it does something real. Nothing is
/// listed that is not implemented, and nothing that only works on one platform
/// pretends to work on another — each tool says so itself.
///
/// The previous catalog registered a hundred descriptors that mostly reshuffled
/// text through one generated form. This one is deliberately short.
library;

import 'package:flutter/material.dart';

import '../apps/api_tester_tool.dart';
import '../apps/colour_toolkit_tool.dart';
import '../apps/developer_toolkit_tool.dart';
import '../apps/archive_tool.dart';
import '../apps/disk_analyser_tool.dart';
import '../apps/duplicate_finder_tool.dart';
import '../apps/file_encryption_tool.dart';
import '../apps/file_shredder_tool.dart';
import '../apps/hash_tool.dart';
import '../apps/image_tool.dart';
import '../apps/notes_tool.dart';
import '../apps/password_vault_tool.dart';
import '../apps/pdf_tool.dart';
import '../apps/qr_tool.dart';
import '../apps/reading_aid_tool.dart';
import '../apps/security_scan_tool.dart';
import '../apps/system_actions_tool.dart';
import '../apps/system_command_tool.dart';
import '../apps/text_toolkit_tool.dart';
import '../apps/unit_converter_tool.dart';
import '../apps/wealth_tool.dart';
import '../tool_descriptor.dart';
import '../tool_registry.dart';

/// A screen tool's runner. The browser and the palette open [screen] instead of
/// calling this, so it exists only so a programmatic caller gets an honest
/// answer rather than a crash.
Future<ToolResult> _opensScreen(Map<String, dynamic> arguments) async =>
    const ToolResult.success('This tool opens its own screen.');

/// Build the registry the application runs with.
ToolRegistry buildDefaultRegistry() {
  final registry = ToolRegistry();
  registry.registerAll(<ToolDescriptor>[
    ToolDescriptor(
      id: 'security.scan',
      name: 'Antivirus & scan',
      description: 'Check a folder with your system antivirus, or review it '
          'for disguised and hidden programs.',
      category: ToolCategory.security,
      icon: Icons.security,
      howTo: 'Choose a folder, then run your system antivirus or a quick '
          'pattern check.',
      tags: const <String>[
        'antivirus', 'virus', 'malware', 'scan', 'security', 'defender',
        'clamav', 'trojan', 'unsafe', 'check',
      ],
      synonyms: const <String>[
        'scan my computer for viruses',
        'is this file safe',
        'check for malware',
        'run an antivirus scan',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const SecurityScanTool(),
    ),
    ToolDescriptor(
      id: 'security.vault',
      name: 'Password vault',
      description: 'Store passwords encrypted on this device behind one '
          'master password.',
      category: ToolCategory.security,
      icon: Icons.lock_outline,
      howTo: 'Create a master password, then add entries. Tap an entry to edit '
          'it, or the key to copy its password. The vault locks when you leave '
          'the app.',
      tags: const <String>[
        'password', 'vault', 'passwords', 'login', 'credentials', 'encrypted',
        'aes', 'pbkdf2', 'master password', 'secure', 'store', 'keychain',
      ],
      synonyms: const <String>[
        'save a password',
        'store my passwords',
        'password manager',
        'encrypted password list',
        'remember this login',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const PasswordVaultTool(),
    ),
    ToolDescriptor(
      id: 'money.wealth',
      name: 'Wealth',
      description: 'Net worth, money in and out, budgets and three financial '
          'calculators, with charts.',
      category: ToolCategory.money,
      icon: Icons.savings_outlined,
      howTo: 'Record what you own and owe, then log money in and out to see '
          'where it goes.',
      tags: const <String>[
        'money', 'wealth', 'net worth', 'budget', 'savings', 'investment',
        'loan', 'interest', 'compound', 'finance', 'income', 'expense',
        'assets', 'liabilities', 'chart',
      ],
      synonyms: const <String>[
        'how much am i worth',
        'track my spending',
        'savings calculator',
        'compound interest',
        'loan repayment',
        'budget planner',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const WealthTool(),
    ),
    ToolDescriptor(
      id: 'developer.toolkit',
      name: 'Developer toolkit',
      description: 'Base64, URL, JSON, HTML entities, UUIDs, timestamps, '
          'regular expressions and CSV.',
      category: ToolCategory.developer,
      icon: Icons.terminal,
      howTo: 'Pick a task, paste the text, and read the result. Bad input is '
          'reported as an error.',
      tags: const <String>[
        'developer', 'base64', 'url', 'encode', 'decode', 'json', 'format',
        'minify', 'html', 'entities', 'uuid', 'timestamp', 'epoch', 'regex',
        'csv', 'convert', 'programmer',
      ],
      synonyms: const <String>[
        'encode base64',
        'decode base64',
        'format json',
        'pretty print json',
        'generate a uuid',
        'convert timestamp',
        'test a regular expression',
        'csv to json',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const DeveloperToolkitTool(),
    ),
    ToolDescriptor(
      id: 'file.checksum',
      name: 'Hash & checksum',
      description: 'Fingerprint text or a file and verify a published '
          'checksum.',
      category: ToolCategory.file,
      icon: Icons.fingerprint,
      howTo: 'Choose a file or type text, then paste the checksum a publisher '
          'listed to confirm the download is intact.',
      tags: const <String>[
        'hash', 'checksum', 'sha256', 'sha1', 'sha512', 'md5', 'digest',
        'verify', 'integrity', 'download', 'fingerprint', 'compare',
      ],
      synonyms: const <String>[
        'sha256 of this file',
        'verify a checksum',
        'check the download is complete',
        'hash some text',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const HashTool(),
    ),
    ToolDescriptor(
      id: 'everyday.units',
      name: 'Unit converter',
      description: 'Length, mass, temperature, area, volume, speed, time, '
          'storage, pressure and energy.',
      category: ToolCategory.everyday,
      icon: Icons.straighten,
      howTo: 'Choose what you are measuring, enter a number and pick the two '
          'units.',
      tags: const <String>[
        'unit', 'convert', 'converter', 'length', 'mass', 'weight',
        'temperature', 'celsius', 'fahrenheit', 'kelvin', 'area', 'volume',
        'speed', 'time', 'bytes', 'storage', 'pressure', 'energy', 'metric',
        'imperial',
      ],
      synonyms: const <String>[
        'convert centimetres to inches',
        'celsius to fahrenheit',
        'kilograms to pounds',
        'kilometres to miles',
        'megabytes to gigabytes',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const UnitConverterTool(),
    ),
    ToolDescriptor(
      id: 'documents.text',
      name: 'Text & documents',
      description: 'Word and character counts, case changes, tidy-up and find '
          'and replace.',
      category: ToolCategory.documents,
      icon: Icons.article_outlined,
      howTo: 'Paste your text; counts update as you type and the buttons '
          'reshape the whole text.',
      tags: const <String>[
        'text', 'word count', 'character count', 'case', 'uppercase',
        'lowercase', 'title case', 'sort lines', 'deduplicate', 'find',
        'replace', 'slug', 'documents', 'writing', 'essay', 'copy',
      ],
      synonyms: const <String>[
        'count the words',
        'how many characters',
        'make this uppercase',
        'sort these lines',
        'remove duplicate lines',
        'find and replace',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const TextToolkitTool(),
    ),
    ToolDescriptor(
      id: 'documents.notes',
      name: 'Notes',
      description: 'Write, search, pin and edit notes that stay on this '
          'device.',
      category: ToolCategory.documents,
      icon: Icons.sticky_note_2_outlined,
      howTo: 'Press Write a note. The first line becomes the title if you '
          'leave the title empty. Pin the notes you need often.',
      tags: const <String>[
        'note', 'notes', 'notepad', 'memo', 'write', 'writing', 'list',
        'todo', 'shopping', 'reminder', 'search', 'pin', 'journal', 'draft',
      ],
      synonyms: const <String>[
        'write a note',
        'keep a note',
        'notepad',
        'save a memo',
        'make a shopping list',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const NotesTool(),
    ),
    ToolDescriptor(
      id: 'documents.reading',
      name: 'Accessibility & reading',
      description: 'Measure how hard text is to read and reshape the page for '
          'comfortable reading.',
      category: ToolCategory.documents,
      icon: Icons.accessibility_new,
      howTo: 'Paste text to see its reading ease and grade, then adjust size, '
          'spacing and line length until the preview is comfortable.',
      tags: const <String>[
        'accessibility', 'reading', 'readability', 'flesch', 'dyslexia',
        'font size', 'line spacing', 'contrast', 'plain english', 'grade',
        'reading time', 'legibility', 'large text', 'easy read',
      ],
      synonyms: const <String>[
        'is this easy to read',
        'how readable is this',
        'make text easier to read',
        'reading level',
        'accessibility check',
        'dyslexia friendly text',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const ReadingAidTool(),
    ),
    ToolDescriptor(
      id: 'media.colour',
      name: 'Colour & design',
      description: 'Hex, RGB and HSL, WCAG readability checks and a palette '
          'built from one colour.',
      category: ToolCategory.media,
      icon: Icons.palette_outlined,
      howTo: 'Type a colour to see it in every notation; add a second colour '
          'to check contrast.',
      tags: const <String>[
        'colour', 'color', 'hex', 'rgb', 'hsl', 'palette', 'contrast',
        'accessibility', 'wcag', 'design', 'swatch', 'harmony', 'tint',
        'shade',
      ],
      synonyms: const <String>[
        'hex to rgb',
        'is this text readable',
        'check colour contrast',
        'make a colour palette',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const ColourToolkitTool(),
    ),
    ToolDescriptor(
      id: 'media.image',
      name: 'Image resize & convert',
      description: 'Resize a photo, convert between JPEG, PNG and WebP, and '
          'see exactly how much smaller it became.',
      category: ToolCategory.media,
      icon: Icons.photo_size_select_large,
      howTo: 'Choose an image, set a new width or keep the current one, pick '
          'JPEG, PNG or WebP, then process. The result is written beside the '
          'original.',
      tags: const <String>[
        'image', 'photo', 'picture', 'resize', 'resize image', 'compress',
        'convert', 'jpeg', 'jpg', 'png', 'webp', 'shrink', 'scale',
        'thumbnail', 'quality',
      ],
      synonyms: const <String>[
        'make this photo smaller',
        'resize an image',
        'convert png to jpg',
        'compress a picture',
        'change image size',
        'convert to webp',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const ImageTool(),
    ),
    ToolDescriptor(
      id: 'media.qr',
      name: 'QR & barcode',
      description: 'Make QR codes and common barcodes, save them as PNG, and '
          'read a QR code from an image.',
      category: ToolCategory.media,
      icon: Icons.qr_code_2,
      howTo: 'Type the content, pick a format and press Save PNG. To read a '
          'code, choose an image of it and press Read the code.',
      tags: const <String>[
        'qr', 'qr code', 'barcode', 'code128', 'ean13', 'code39', 'scan',
        'scan qr', 'read qr', 'generate qr', 'label', 'link', 'wifi',
      ],
      synonyms: const <String>[
        'make a qr code',
        'scan a qr code',
        'read a qr code from a picture',
        'create a barcode',
        'qr code for a link',
        'share wifi as a qr code',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const QrTool(),
    ),
    ToolDescriptor(
      id: 'documents.pdf',
      name: 'PDF builder',
      description: 'Turn text or a set of images into a clean PDF, with page '
          'size, text size and page numbers.',
      category: ToolCategory.documents,
      icon: Icons.picture_as_pdf_outlined,
      howTo: 'Choose Text or Images, set the page size, choose where to save '
          'it, then press Build. Each image becomes one page.',
      tags: const <String>[
        'pdf', 'make pdf', 'create pdf', 'text to pdf', 'images to pdf',
        'scan', 'document', 'page', 'print', 'a4', 'letter', 'convert',
      ],
      synonyms: const <String>[
        'turn this text into a pdf',
        'make a pdf from photos',
        'create a pdf document',
        'images to one pdf',
        'save this as a pdf',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const PdfTool(),
    ),
    ToolDescriptor(
      id: 'file.diskUsage',
      name: 'Disk analyser',
      description: 'Measure a folder and show which of its contents is using '
          'the space.',
      category: ToolCategory.file,
      icon: Icons.pie_chart_outline,
      howTo: 'Choose a folder and press Analyse. Its immediate contents are '
          'listed largest first, so the top line is where to look.',
      tags: const <String>[
        'disk', 'space', 'storage', 'size', 'folder', 'drive', 'full',
        'cleanup', 'analyse', 'analyze', 'usage', 'big files', 'largest',
      ],
      synonyms: const <String>[
        'what is taking up space',
        'why is my drive full',
        'which folder is biggest',
        'analyse disk usage',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const DiskAnalyserTool(),
    ),
    ToolDescriptor(
      id: 'file.archive',
      name: 'Archive (zip)',
      description: 'Zip a file or folder, and extract archives with a guard '
          'against paths that try to escape.',
      category: ToolCategory.file,
      icon: Icons.folder_zip_outlined,
      howTo: 'Choose Zip to compress a file or folder, or Extract to unpack a '
          '.zip. The result is written beside the source unless you choose a '
          'destination.',
      tags: const <String>[
        'zip', 'archive', 'unzip', 'extract', 'compress', 'folder', 'files',
        'backup', 'package', 'bundle', 'deflate', 'tar',
      ],
      synonyms: const <String>[
        'zip a folder',
        'unzip this file',
        'make a zip',
        'extract an archive',
        'compress these files',
        'open a zip',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const ArchiveTool(),
    ),
    ToolDescriptor(
      id: 'file.encrypt',
      name: 'File encryption',
      description: 'Lock one file with a password using AES-256-GCM, and '
          'unlock it again.',
      category: ToolCategory.file,
      icon: Icons.lock_outline,
      howTo: 'Choose a file, enter a password twice and press Encrypt. A .enc '
          'copy is written beside the original. Enter the same password to '
          'decrypt it.',
      tags: const <String>[
        'encrypt', 'decrypt', 'encryption', 'password', 'aes', 'gcm',
        'pbkdf2', 'lock', 'unlock', 'private', 'secure', 'file', 'cipher',
      ],
      synonyms: const <String>[
        'encrypt a file',
        'password protect a file',
        'lock a file with a password',
        'decrypt this file',
        'make a file private',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const FileEncryptionTool(),
    ),
    ToolDescriptor(
      id: 'file.shred',
      name: 'File shredder',
      description: 'Overwrite one file before deleting it, with a typed '
          'confirmation and an honest account of the limits.',
      category: ToolCategory.file,
      icon: Icons.delete_forever,
      howTo: 'Choose a file, pick how many overwrite passes, press Shred the '
          'file, then type DELETE. It cannot be undone.',
      tags: const <String>[
        'shred', 'shredder', 'delete', 'erase', 'wipe', 'secure delete',
        'overwrite', 'privacy', 'file', 'remove', 'destroy', 'sensitive',
      ],
      synonyms: const <String>[
        'delete a file permanently',
        'erase a file for good',
        'shred this file',
        'wipe a sensitive file',
        'securely delete',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const FileShredderTool(),
    ),
    ToolDescriptor(
      id: 'file.duplicates',
      name: 'Duplicate finder',
      description: 'Find files with identical contents and show every copy of '
          'each.',
      category: ToolCategory.file,
      icon: Icons.content_copy_outlined,
      howTo: 'Choose a folder and press Find duplicates. Matching copies are '
          'grouped. Nothing is deleted here — you remove the extras yourself.',
      tags: const <String>[
        'duplicate', 'duplicates', 'copies', 'same file', 'wasted space',
        'cleanup', 'dedupe', 'tidy', 'storage', 'identical',
      ],
      synonyms: const <String>[
        'find duplicate files',
        'same file twice',
        'how much space am i wasting',
        'remove copies of the same file',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const DuplicateFinderTool(),
    ),
    ToolDescriptor(
      id: 'network.api',
      name: 'HTTP / API tester',
      description: 'Send one HTTP request and see the status, headers and body '
          'the server actually returned.',
      category: ToolCategory.network,
      icon: Icons.api,
      howTo: 'Choose a method, type the full address, add headers one per line '
          'and press Send. The response is shown unedited, with the time it '
          'took.',
      tags: const <String>[
        'http', 'api', 'request', 'rest', 'json', 'endpoint', 'get', 'post',
        'put', 'patch', 'delete', 'headers', 'status code', 'curl', 'webhook',
        'server', 'response',
      ],
      synonyms: const <String>[
        'test an api endpoint',
        'send a get request',
        'send a post request',
        'check what a server returns',
        'debug an http request',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const ApiTesterTool(),
    ),
    ToolDescriptor(
      id: 'system.actions',
      name: 'System actions',
      description: 'List, copy, move, rename and delete files and folders on '
          'this machine, with confirmation for destructive steps.',
      category: ToolCategory.system,
      icon: Icons.terminal,
      howTo: 'Choose an action, enter the path (and a destination when copying, '
          'moving or renaming), then run it. Deletes ask for confirmation.',
      tags: const <String>[
        'file', 'folder', 'directory', 'delete', 'remove', 'copy', 'move',
        'rename', 'list', 'system', 'action', 'path',
      ],
      synonyms: const <String>[
        'delete a file',
        'delete a folder',
        'list files in a folder',
        'copy a file',
        'move a file',
        'rename a file',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const SystemActionsTool(),
    ),
    ToolDescriptor(
      id: 'system.command',
      name: 'System command',
      description: 'Type a file or folder action in plain English and run it, '
          'with a preview and confirmation.',
      category: ToolCategory.system,
      icon: Icons.terminal,
      howTo: 'Type what you want, e.g. "delete a file called 1 in folder 2", '
          'then parse and run. Destructive actions ask for confirmation.',
      tags: const <String>[
        'command', 'natural language', 'file', 'folder', 'delete', 'move',
        'copy', 'rename', 'list', 'system',
      ],
      synonyms: const <String>[
        'delete a file called 1 in folder 2',
        'list files in a folder',
        'move a file',
        'copy a file',
        'rename a file',
      ],
      run: _opensScreen,
      screen: (BuildContext context) => const SystemCommandTool(),
    ),
  ]);
  return registry;
}
