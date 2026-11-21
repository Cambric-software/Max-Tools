import 'package:flutter/material.dart';

import '../../../core/config/cambric_config.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/settings/app_settings.dart';
import '../cache/cache_screen.dart';
import '../cambric/cambric_screen.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../updates/updates_screen.dart';

/// Application settings.
///
/// Every control on this screen has a visible effect. Appearance is stored per
/// person: the People section switches the whole app to another person's theme,
/// accent, text size and language in one tap.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.config});

  /// Product configuration, for the about and update sections.
  final CambricConfig config;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.text('settings.title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: <Widget>[
              _peopleSection(context, s),
              const SizedBox(height: 16),
              _appearanceSection(context, s),
              const SizedBox(height: 16),
              _languageSection(context, s),
              const SizedBox(height: 16),
              _storageSection(context, s),
              const SizedBox(height: 16),
              _updatesSection(context, s),
              const SizedBox(height: 16),
              _aboutSection(context, s),
              const SizedBox(height: 28),
              _footer(context, s),
            ],
          ),
        ),
      ),
    );
  }

  // ── people ───────────────────────────────────────────────────────────────

  Widget _peopleSection(BuildContext context, AppStrings s) {
    final AppSettings settings = AppSettings.instance;
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        settings.profiles,
        settings.activeProfileId,
      ]),
      builder: (BuildContext context, Widget? _) {
        final List<PersonProfile> profiles = settings.profiles.value;
        final String activeId = settings.activeProfileId.value;

        return _section(
          context,
          title: s.text('settings.people_title'),
          icon: Icons.people_outline,
          children: <Widget>[
            Text(
              s.text('settings.people_body'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            for (final PersonProfile profile in profiles)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Text(_initial(_displayName(profile, s))),
                ),
                title: Text(_displayName(profile, s)),
                subtitle: profile.id == activeId
                    ? Text(s.text('settings.active'))
                    : null,
                trailing: profile.id == activeId
                    ? Icon(
                        Icons.check_circle,
                        color: theme.colorScheme.primary,
                      )
                    : null,
                onTap: profile.id == activeId
                    ? null
                    : () => settings.selectProfile(profile.id),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                TextButton.icon(
                  icon: const Icon(Icons.person_add_alt_outlined),
                  label: Text(s.text('settings.add_person')),
                  onPressed: () => _addPerson(context, s),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(s.text('settings.rename_person')),
                  onPressed: () => _renameActive(context, s),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: Text(s.text('settings.delete_person')),
                  onPressed: profiles.length <= 1
                      ? null
                      : () => _deleteActive(context, s),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _addPerson(BuildContext context, AppStrings s) async {
    final String fallback = s.withValues(
      'settings.person_fallback',
      <String, String>{
        'number': '${AppSettings.instance.profiles.value.length + 1}',
      },
    );
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => _NameDialog(
        title: s.text('settings.add_person_title'),
        label: s.text('settings.person_name_label'),
        initial: '',
        hint: fallback,
        cancelLabel: s.text('common.cancel'),
        saveLabel: s.text('common.add'),
      ),
    );
    if (name == null) return;
    await AppSettings.instance.addProfile(name.trim().isEmpty ? fallback : name);
  }

  Future<void> _renameActive(BuildContext context, AppStrings s) async {
    final PersonProfile active = AppSettings.instance.activeProfile;
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => _NameDialog(
        title: s.text('settings.rename_person_title'),
        label: s.text('settings.person_name_label'),
        initial: _displayName(active, s),
        hint: active.name,
        cancelLabel: s.text('common.cancel'),
        saveLabel: s.text('common.save'),
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await AppSettings.instance.renameProfile(active.id, name);
  }

  Future<void> _deleteActive(BuildContext context, AppStrings s) async {
    final PersonProfile active = AppSettings.instance.activeProfile;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(s.text('settings.delete_person_title')),
        content: Text(s.text('settings.delete_person_body')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.text('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.text('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final bool removed =
        await AppSettings.instance.deleteProfile(active.id);
    if (!context.mounted) return;
    if (!removed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.text('settings.keep_one_person'))),
      );
    }
  }

  String _displayName(PersonProfile profile, AppStrings s) {
    if (profile.id == PersonProfile.defaults.id &&
        profile.name == PersonProfile.defaults.name) {
      return s.text('settings.me');
    }
    return profile.name;
  }

  String _initial(String name) {
    final String trimmed = name.trim();
    return trimmed.isEmpty
        ? '?'
        : String.fromCharCode(trimmed.runes.first);
  }

  // ── appearance ───────────────────────────────────────────────────────────

  Widget _appearanceSection(BuildContext context, AppStrings s) {
    final AppSettings settings = AppSettings.instance;
    final theme = Theme.of(context);

    return _section(
      context,
      title: s.text('settings.appearance_title'),
      icon: Icons.palette_outlined,
      children: <Widget>[
        Text(
          s.text('settings.appearance_body'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: settings.themeMode,
          builder: (BuildContext context, ThemeMode mode, Widget? _) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _themeChip(
                  label: s.text('settings.system'),
                  icon: Icons.brightness_auto_outlined,
                  selected: mode == ThemeMode.system,
                  onTap: () => settings.setThemeMode(ThemeMode.system),
                ),
                _themeChip(
                  label: s.text('settings.light'),
                  icon: Icons.light_mode_outlined,
                  selected: mode == ThemeMode.light,
                  onTap: () => settings.setThemeMode(ThemeMode.light),
                ),
                _themeChip(
                  label: s.text('settings.dark'),
                  icon: Icons.dark_mode_outlined,
                  selected: mode == ThemeMode.dark,
                  onTap: () => settings.setThemeMode(ThemeMode.dark),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          s.text('settings.accent_title'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          s.text('settings.accent_help'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<AppAccent>(
          valueListenable: settings.accent,
          builder: (BuildContext context, AppAccent current, Widget? _) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final AppAccent accent in AppAccent.values)
                  ChoiceChip(
                    avatar: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: accent.seed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    label: Text(s.text(accent.labelKey)),
                    selected: current == accent,
                    showCheckmark: false,
                    onSelected: (_) => settings.setAccent(accent),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        ValueListenableBuilder<double>(
          valueListenable: settings.textScale,
          builder: (BuildContext context, double scale, Widget? _) {
            final int percent = (scale * 100).round();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        s.text('settings.text_size_title'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      s.withValues(
                        'settings.text_size_value',
                        <String, String>{'percent': '$percent'},
                      ),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                Text(
                  s.text('settings.text_size_help'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                Slider(
                  value: scale,
                  min: AppSettings.minTextScale,
                  max: AppSettings.maxTextScale,
                  divisions: 14,
                  label: '$percent%',
                  onChanged: (double value) => settings.setTextScale(value),
                ),
                Card(
                  color: theme.colorScheme.surfaceContainerHigh,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      s.text('settings.text_size_preview'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<bool>(
          valueListenable: settings.highContrast,
          builder: (BuildContext context, bool highContrast, Widget? _) {
            return SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.text('settings.high_contrast_title')),
              subtitle: Text(s.text('settings.high_contrast_subtitle')),
              value: highContrast,
              onChanged: settings.setHighContrast,
            );
          },
        ),
      ],
    );
  }

  Widget _themeChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
    );
  }

  // ── language ─────────────────────────────────────────────────────────────

  Widget _languageSection(BuildContext context, AppStrings s) {
    final AppSettings settings = AppSettings.instance;
    final theme = Theme.of(context);

    return _section(
      context,
      title: s.text('settings.language_title'),
      icon: Icons.translate_outlined,
      children: <Widget>[
        Text(
          s.text('settings.language_help'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<String>(
          valueListenable: settings.languageCode,
          builder: (BuildContext context, String code, Widget? _) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: Text(s.text('settings.language_english')),
                  selected: code == 'en',
                  onSelected: (_) => settings.setLanguage('en'),
                ),
                ChoiceChip(
                  label: Text(s.text('settings.language_arabic')),
                  selected: code == 'ar',
                  onSelected: (_) => settings.setLanguage('ar'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Card(
          color: theme.colorScheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.text(
                      s.isArabic
                          ? 'settings.arabic_note'
                          : 'settings.english_note',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── storage ──────────────────────────────────────────────────────────────

  Widget _storageSection(BuildContext context, AppStrings s) {
    return _section(
      context,
      title: s.text('settings.storage_title'),
      icon: Icons.storage_outlined,
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cleaning_services_outlined),
          title: Text(s.text('settings.cache_title')),
          subtitle: Text(s.text('settings.cache_subtitle')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(context, const CacheScreen()),
        ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.monitor_heart_outlined),
          title: Text(s.text('settings.diagnostics_title')),
          subtitle: Text(s.text('settings.diagnostics_subtitle')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(context, const DiagnosticsScreen()),
        ),
      ],
    );
  }

  // ── updates ──────────────────────────────────────────────────────────────

  Widget _updatesSection(BuildContext context, AppStrings s) {
    final theme = Theme.of(context);
    final String message;
    if (!config.updatesEnabled) {
      message = s.text('settings.updates_disabled');
    } else if (config.automaticUpdateChecks) {
      message = s.text('settings.updates_enabled_auto');
    } else {
      message = s.text('settings.updates_enabled_manual');
    }

    return _section(
      context,
      title: s.text('settings.updates_title'),
      icon: Icons.system_update_alt_outlined,
      children: <Widget>[
        Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.system_update_alt_outlined),
            label: Text(s.text('settings.check_updates')),
            onPressed: () => _open(context, UpdatesScreen(config: config)),
          ),
        ),
      ],
    );
  }

  // ── about ────────────────────────────────────────────────────────────────

  Widget _aboutSection(BuildContext context, AppStrings s) {
    return _section(
      context,
      title: s.text('settings.about_title'),
      icon: Icons.info_outline,
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.layers_outlined),
          title: Text(config.productName),
          subtitle: Text(
            s.withValues(
              'settings.about_version',
              <String, String>{
                'version': config.version,
                'publisher': config.publisher ?? 'Cambric Software',
              },
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(
            context,
            CambricScreen(config: config),
          ),
        ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.restart_alt_outlined),
          title: Text(s.text('settings.restore_title')),
          subtitle: Text(s.text('settings.restore_subtitle')),
          onTap: () => _restoreDefaults(context, s),
        ),
      ],
    );
  }

  Future<void> _restoreDefaults(BuildContext context, AppStrings s) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(s.text('settings.restore_dialog_title')),
        content: Text(s.text('settings.restore_dialog_body')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.text('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.text('common.restore')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await AppSettings.instance.restoreDefaults();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.text('settings.restore_done'))),
    );
  }

  // ── layout helpers ───────────────────────────────────────────────────────

  Widget _section(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, AppStrings s) {
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Icon(
          Icons.copyright_rounded,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 6),
        Text(
          s.text('settings.copyright'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${config.productName} ${config.version}',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }
}

/// A one-field dialog that owns its controller.
///
/// The controller is disposed with the dialog rather than straight after
/// `showDialog` returns, because the route is still animating out at that point
/// and a disposed controller would throw during the exit frame.
class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.hint,
    required this.cancelLabel,
    required this.saveLabel,
  });

  final String title;
  final String label;
  final String initial;
  final String hint;
  final String cancelLabel;
  final String saveLabel;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(widget.saveLabel),
        ),
      ],
    );
  }
}
