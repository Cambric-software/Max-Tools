import 'package:flutter/material.dart';

/// The words shown by the app, in the languages the app actually speaks.
///
/// Two languages are shipped: English and Arabic. The Arabic here covers the
/// navigation, the home screen and every control on the settings screen. It
/// does **not** cover the long-form content inside individual tools, which is
/// still English in this release, and the settings screen says so rather than
/// letting a person discover it halfway through a task.
///
/// Keys are grouped by screen so a missing key is obvious. [text] falls back to
/// English and then to the key itself, which makes a gap visible instead of
/// blank.
class AppStrings {
  const AppStrings._(this.languageCode, this._values);

  /// `en` or `ar`.
  final String languageCode;

  final Map<String, String> _values;

  /// English strings.
  static const AppStrings english = AppStrings._('en', _en);

  /// Arabic strings.
  static const AppStrings arabic = AppStrings._('ar', _ar);

  /// The strings for a language code, falling back to English.
  static AppStrings forLanguage(String? code) =>
      code == 'ar' ? arabic : english;

  /// The strings for the language the app is currently rendered in.
  static AppStrings of(BuildContext context) =>
      forLanguage(Localizations.localeOf(context).languageCode);

  /// Whether these strings are Arabic.
  bool get isArabic => languageCode == 'ar';

  /// Look up one key.
  String text(String key) => _values[key] ?? _en[key] ?? key;

  /// Look up one key and fill `{name}` placeholders.
  String withValues(String key, Map<String, String> values) {
    String result = text(key);
    values.forEach((String name, String value) {
      result = result.replaceAll('{$name}', value);
    });
    return result;
  }

  static const Map<String, String> _en = <String, String>{
    // Home.
    'home.command_palette_tooltip': 'Command palette (Ctrl+K)',
    'home.settings_tooltip': 'Settings',
    'home.hero_subtitle': 'All your tools in one place. Version {version}.',
    'home.tools_title': 'Tools',
    'home.tools_subtitle': 'Every tool in one searchable place',
    'home.palette_title': 'Command Palette',
    'home.palette_subtitle': 'Ask in plain English — Ctrl+K anywhere',
    'home.cambric_title': 'Cambric',
    'home.cambric_subtitle':
        'This installation, your other Cambric products, and the licence',
    'home.updates_title': 'Updates',
    'home.updates_subtitle': 'Check, download and verify a new version',
    'home.cache_title': 'Cache',
    'home.cache_subtitle': 'View and clear cached data',
    'home.diagnostics_title': 'Diagnostics',
    'home.diagnostics_subtitle': 'System information and platform details',
    'home.settings_title': 'Settings',
    'home.settings_subtitle': 'Appearance, behaviour and storage',
    'home.quick_actions': 'Quick actions',
    'home.find_tool_title': 'Find a tool',
    'home.find_tool_subtitle':
        'Search everything by name or by what it does',
    'home.run_command_title': 'Run a command',
    'home.run_command_subtitle':
        'Type what you want instead of hunting through menus',
    'home.check_updates_title': 'Check for updates',
    'home.check_updates_subtitle': 'Download and verify the newest release',
    'home.cambric_quick_subtitle':
        'Product details and the other Cambric apps installed',
    'home.privacy_title': 'Privacy',
    'home.privacy_body':
        'Max Tools works on your machine. Nothing you open or convert is '
            'uploaded. The only network requests are release checks and '
            'updates you start yourself.',
    'home.copyright':
        'Copyright © 2026 Cambric Software. All rights reserved.',
    'home.version': 'Version {version}',

    // Settings.
    'settings.title': 'Settings',
    'settings.people_title': 'People',
    'settings.people_body':
        'Each person keeps their own theme, text size and language. A new '
            'person starts from the defaults, not from the settings of whoever '
            'is using the app now.',
    'settings.active': 'Active',
    'settings.me': 'Me',
    'settings.add_person': 'Add person',
    'settings.rename_person': 'Rename',
    'settings.delete_person': 'Delete',
    'settings.add_person_title': 'Add a person',
    'settings.rename_person_title': 'Rename this person',
    'settings.person_name_label': 'Name',
    'settings.person_fallback': 'Person {number}',
    'settings.delete_person_title': 'Delete this person?',
    'settings.delete_person_body':
        'Their theme, text size and language are removed. Files and tools are '
            'not deleted.',
    'settings.keep_one_person': 'At least one person must remain.',
    'settings.appearance_title': 'Appearance',
    'settings.appearance_body':
        'Choose how Max Tools looks. System follows your operating system '
            'setting, including when it changes at sunset.',
    'settings.system': 'System',
    'settings.light': 'Light',
    'settings.dark': 'Dark',
    'settings.high_contrast_title': 'High contrast',
    'settings.high_contrast_subtitle': 'Stronger borders and contrast.',
    'settings.accent_title': 'Accent colour',
    'settings.accent_help':
        'Used for buttons, links and highlights. Surfaces and warning colours '
            'stay the same.',
    'settings.text_size_title': 'Text size',
    'settings.text_size_help':
        'Scales text on top of your system setting. The app can be set between '
            '90% and 160%.',
    'settings.text_size_value': '{percent}%',
    'settings.text_size_preview': 'This is how body text looks.',
    'settings.language_title': 'Language',
    'settings.language_help':
        'Changes the menus, buttons and settings you see.',
    'settings.language_english': 'English',
    'settings.language_arabic': 'العربية',
    'settings.arabic_note':
        'Arabic covers the navigation, home screen and settings. The content '
            'inside individual tools is still English in this release.',
    'settings.english_note':
        'Arabic covers the navigation, home screen and settings. The content '
            'inside individual tools is still English in this release.',
    'settings.storage_title': 'Storage',
    'settings.cache_title': 'Cache',
    'settings.cache_subtitle':
        'See how much cached data is being held, and clear it',
    'settings.diagnostics_title': 'Diagnostics',
    'settings.diagnostics_subtitle':
        'Platform, build and storage details for support',
    'settings.updates_title': 'Updates',
    'settings.updates_enabled_auto':
        'Updates are enabled. Max Tools checks for a new release '
            'automatically, downloads it, and verifies its published checksum '
            'before installing.',
    'settings.updates_enabled_manual':
        'Updates are enabled. Max Tools checks for a new release when you ask, '
            'downloads it, and verifies its published checksum before '
            'installing.',
    'settings.updates_disabled':
        'Updates are disabled in this build. You can still check for a release '
            'manually.',
    'settings.check_updates': 'Check for updates',
    'settings.about_title': 'About',
    'settings.about_version': 'Version {version} · {publisher}',
    'settings.restore_title': 'Restore default settings',
    'settings.restore_subtitle':
        'Returns this person’s appearance to the defaults. Does not delete '
            'tools, files or history.',
    'settings.restore_dialog_title': 'Restore default settings?',
    'settings.restore_dialog_body':
        'This person’s appearance goes back to following the system. Your '
            'files, tools and history are untouched.',
    'settings.restore_done': 'Default settings restored.',
    'settings.copyright':
        'Copyright © 2026 Cambric Software. All rights reserved.',

    // Accents.
    'accent_blue': 'Blue',
    'accent_teal': 'Teal',
    'accent_purple': 'Purple',
    'accent_green': 'Green',
    'accent_amber': 'Amber',

    // Shared actions.
    'common.cancel': 'Cancel',
    'common.save': 'Save',
    'common.restore': 'Restore',
    'common.delete': 'Delete',
    'common.rename': 'Rename',
    'common.add': 'Add',
  };

  static const Map<String, String> _ar = <String, String>{
    // Home.
    'home.command_palette_tooltip': 'لوحة الأوامر (Ctrl+K)',
    'home.settings_tooltip': 'الإعدادات',
    'home.hero_subtitle': 'كل أدواتك في مكان واحد. الإصدار {version}.',
    'home.tools_title': 'الأدوات',
    'home.tools_subtitle': 'كل أداة في مكان واحد قابل للبحث',
    'home.palette_title': 'لوحة الأوامر',
    'home.palette_subtitle': 'اكتب ما تريد بلغة واضحة — Ctrl+K في أي مكان',
    'home.cambric_title': 'Cambric',
    'home.cambric_subtitle':
        'هذا التثبيت، ومنتجات Cambric الأخرى لديك، والترخيص',
    'home.updates_title': 'التحديثات',
    'home.updates_subtitle': 'تحقّق من إصدار جديد ونزّله وتحقّق منه',
    'home.cache_title': 'ذاكرة التخزين المؤقت',
    'home.cache_subtitle': 'اعرض البيانات المخزّقة مؤقتًا وامسحها',
    'home.diagnostics_title': 'التشخيص',
    'home.diagnostics_subtitle': 'معلومات النظام وتفاصيل المنصة',
    'home.settings_title': 'الإعدادات',
    'home.settings_subtitle': 'المظهر والسلوك والتخزين',
    'home.quick_actions': 'إجراءات سريعة',
    'home.find_tool_title': 'ابحث عن أداة',
    'home.find_tool_subtitle': 'ابحث في كل شيء بالاسم أو بما يفعله',
    'home.run_command_title': 'نفّذ أمرًا',
    'home.run_command_subtitle':
        'اكتب ما تريد بدلًا من البحث في القوائم',
    'home.check_updates_title': 'التحقق من التحديثات',
    'home.check_updates_subtitle': 'نزّل أحدث إصدار وتحقّق منه',
    'home.cambric_quick_subtitle':
        'تفاصيل المنتج وتطبيقات Cambric الأخرى المثبّتة',
    'home.privacy_title': 'الخصوصية',
    'home.privacy_body':
        'يعمل Max Tools على جهازك. لا يُرفع أي شيء تفتحه أو تحوّله. الطلبات '
            'الشبكية الوحيدة هي فحوص الإصدارات والتحديثات التي تبدأها بنفسك.',
    'home.copyright':
        'حقوق النشر © 2026 Cambric Software. جميع الحقوق محفوظة.',
    'home.version': 'الإصدار {version}',

    // Settings.
    'settings.title': 'الإعدادات',
    'settings.people_title': 'الأشخاص',
    'settings.people_body':
        'يحتفظ كل شخص بمظهره وحجم نصه ولغته. يبدأ الشخص الجديد من الإعدادات '
            'الافتراضية، لا من إعدادات من يستخدم التطبيق الآن.',
    'settings.active': 'نشط',
    'settings.me': 'أنا',
    'settings.add_person': 'إضافة شخص',
    'settings.rename_person': 'إعادة تسمية',
    'settings.delete_person': 'حذف',
    'settings.add_person_title': 'إضافة شخص',
    'settings.rename_person_title': 'إعادة تسمية هذا الشخص',
    'settings.person_name_label': 'الاسم',
    'settings.person_fallback': 'الشخص {number}',
    'settings.delete_person_title': 'حذف هذا الشخص؟',
    'settings.delete_person_body':
        'سيُحذف مظهره وحجم نصه ولغته. لا تُحذف الملفات أو الأدوات.',
    'settings.keep_one_person': 'يجب أن يبقى شخص واحد على الأقل.',
    'settings.appearance_title': 'المظهر',
    'settings.appearance_body':
        'اختر شكل Max Tools. يتبع «النظام» إعداد نظام التشغيل، بما في ذلك '
            'تغيّره عند الغروب.',
    'settings.system': 'النظام',
    'settings.light': 'فاتح',
    'settings.dark': 'داكن',
    'settings.high_contrast_title': 'تباين عالٍ',
    'settings.high_contrast_subtitle': 'حدود وتباين أقوى.',
    'settings.accent_title': 'لون التمييز',
    'settings.accent_help':
        'يُستخدم للأزرار والروابط والإبرازات. تبقى الأسطح وألوان التحذير كما هي.',
    'settings.text_size_title': 'حجم النص',
    'settings.text_size_help':
        'يكبّر النص فوق إعداد نظامك. يمكن ضبط التطبيق بين ٩٠٪ و١٦٠٪.',
    'settings.text_size_value': '{percent}٪',
    'settings.text_size_preview': 'هكذا يبدو نص المتن.',
    'settings.language_title': 'اللغة',
    'settings.language_help': 'يغيّر القوائم والأزرار والإعدادات التي تراها.',
    'settings.language_english': 'English',
    'settings.language_arabic': 'العربية',
    'settings.arabic_note':
        'تغطي العربية التنقل والشاشة الرئيسية والإعدادات. محتوى الأدوات '
            'الفردية ما زال بالإنجليزية في هذا الإصدار.',
    'settings.english_note':
        'تغطي العربية التنقل والشاشة الرئيسية والإعدادات. محتوى الأدوات '
            'الفردية ما زال بالإنجليزية في هذا الإصدار.',
    'settings.storage_title': 'التخزين',
    'settings.cache_title': 'ذاكرة التخزين المؤقت',
    'settings.cache_subtitle': 'اعرض حجم البيانات المخزّقة مؤقتًا وامسحها',
    'settings.diagnostics_title': 'التشخيص',
    'settings.diagnostics_subtitle':
        'تفاصيل المنصة والبناء والتخزين للدعم',
    'settings.updates_title': 'التحديثات',
    'settings.updates_enabled_auto':
        'التحديثات مفعّلة. يتحقّق Max Tools من إصدار جديد تلقائيًا، وينزّله، '
            'ويتحقّق من بصمة التحقق المنشورة قبل التثبيت.',
    'settings.updates_enabled_manual':
        'التحديثات مفعّلة. يتحقّق Max Tools من إصدار جديد عندما تطلب ذلك، '
            'وينزّله، ويتحقّق من بصمة التحقق المنشورة قبل التثبيت.',
    'settings.updates_disabled':
        'التحديثات معطّلة في هذا الإصدار. ما زال بإمكانك التحقق من إصدار يدويًا.',
    'settings.check_updates': 'التحقق من التحديثات',
    'settings.about_title': 'حول',
    'settings.about_version': 'الإصدار {version} · {publisher}',
    'settings.restore_title': 'استعادة الإعدادات الافتراضية',
    'settings.restore_subtitle':
        'يعيد مظهر هذا الشخص إلى الإعدادات الافتراضية. لا يحذف الأدوات أو '
            'الملفات أو السجل.',
    'settings.restore_dialog_title': 'استعادة الإعدادات الافتراضية؟',
    'settings.restore_dialog_body':
        'يعود مظهر هذا الشخص إلى اتباع النظام. ملفاتك وأدواتك وسجلك لا تتأثر.',
    'settings.restore_done': 'تمت استعادة الإعدادات الافتراضية.',
    'settings.copyright':
        'حقوق النشر © 2026 Cambric Software. جميع الحقوق محفوظة.',

    // Accents.
    'accent_blue': 'أزرق',
    'accent_teal': 'أخضر مزرق',
    'accent_purple': 'بنفسجي',
    'accent_green': 'أخضر',
    'accent_amber': 'كهرماني',

    // Shared actions.
    'common.cancel': 'إلغاء',
    'common.save': 'حفظ',
    'common.restore': 'استعادة',
    'common.delete': 'حذف',
    'common.rename': 'إعادة تسمية',
    'common.add': 'إضافة',
  };
}
