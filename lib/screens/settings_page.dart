import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

import 'package:doable_todo_list_app/l10n/app_localizations.dart';
import 'package:doable_todo_list_app/repositories/task_repository.dart';
import 'package:doable_todo_list_app/services/config_service.dart';
import 'package:doable_todo_list_app/services/notification_service.dart';

import '../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _prefsKeyNotifications = 'notifications_enabled';

  bool _notificationsEnabled = false;
  bool _loading = true;
  late TextEditingController _phonePrefixCtrl;

  @override
  void initState() {
    super.initState();
    _phonePrefixCtrl = TextEditingController();
    _loadPrefs();
  }

  @override
  void dispose() {
    _phonePrefixCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefsKeyNotifications) ?? false;
    final prefix = ConfigService.instance.defaultPhonePrefix;
    if (mounted) {
      setState(() {
        _notificationsEnabled = enabled;
        _phonePrefixCtrl.text = prefix;
        _loading = false;
      });
    }
  }

  Future<void> _savePhonePrefix(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    await ConfigService.instance.setDefaultPhonePrefix(trimmed);
  }

  Future<void> _setNotifications(bool value) async {
    // Ask permission when enabling; if denied, keep it disabled.
    if (value) {
      final granted = await _requestNotificationPermission();
      if (!mounted) return;
      if (!granted) {
        // Inform user and keep toggle off
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.notificationPermissionDenied)),
        );
        value = false;
      } else {

        try {
          final tasks = await TaskRepository().fetchAll();
          await NotificationService.rescheduleAllNotifications(tasks);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.notificationsEnabledAndScheduled)),
        );
        } catch (e) {
          print('Error rescheduling notifications: $e');
        }
      }
    } else {
      // When disabling notifications, cancel all scheduled notifications
      try {
        await NotificationService.cancelAllNotifications();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.allNotificationsCancelled)),
        );
      } catch (e) {
        print('Error cancelling notifications: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyNotifications, value);
    if (!mounted) return;
    setState(() => _notificationsEnabled = value);
  }

  // Request notification permission using awesome_notifications
  Future<bool> _requestNotificationPermission() async {
    return await NotificationService.requestPermissions();
  }

  Future<void> _sendTestNotification() async {
    // Check both system permission and user preference
    final isAllowed = await NotificationService.isNotificationAllowed();
    if (!isAllowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.notificationPermissionRequired)),
      );
      return;
    }

    if (!_notificationsEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.notificationsDisabledInSettings)),
      );
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 999999, // Use a high ID for test notifications
        channelKey: NotificationService.channelKey,
        title: l10n.testNotification,
        body: l10n.testNotificationBody,
        category: NotificationCategory.Reminder,
        payload: {'test': 'true'},
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.testNotificationSent)),
    );
  }

  Future<void> _confirmAndClearAll() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearAllDataTitle),
        content: Text(l10n.clearAllDataContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Wipe the tasks table
    await TaskRepository().clearAll();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.allDataCleared)),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.couldNotOpenUrl(url))),
      );
    }
  }

  EdgeInsets get _screenHPad {
    final w = MediaQuery.of(context).size.width;
    final hpad = (w * 0.05).clamp(16.0, 24.0);
    return EdgeInsets.symmetric(horizontal: hpad);
  }

  Widget _buildLanguageSelector(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final config = ConfigService.instance;
    final current = config.localeCode;

    String labelFor(String code) {
      switch (code) {
        case ConfigService.localeSystem:
          return l10n.languageSystem;
        case ConfigService.localeEn:
          return l10n.languageEn;
        case ConfigService.localeZh:
          return l10n.languageZh;
        default:
          return code;
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.language,
          style: TextStyle(fontSize: 16, color: blackColor, fontWeight: FontWeight.w600),
        ),
        DropdownButton<String>(
          value: current,
          underline: const SizedBox.shrink(),
          items: [
            ConfigService.localeSystem,
            ConfigService.localeEn,
            ConfigService.localeZh,
          ].map((code) {
            return DropdownMenuItem(
              value: code,
              child: Text(labelFor(code), style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: (v) async {
            if (v != null) {
              await config.setLocale(v);
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final version = '1.0.0';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          tooltip: AppLocalizations.of(context)!.back,
        ),
        title: Text(
          AppLocalizations.of(context)!.settings,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: _screenHPad.add(const EdgeInsets.only(bottom: 24, top: 8)),
          children: [
            // Language selector
            _buildLanguageSelector(context),
            const SizedBox(height: 16),

            // Notifications toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.notifications,
                  style: TextStyle(fontSize: 16, color: blackColor, fontWeight: FontWeight.w600),
                ),
                Switch(
                  value: _notificationsEnabled,
                  onChanged: _setNotifications,
                  activeThumbColor: blueColor,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Default phone prefix
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    AppLocalizations.of(context)!.defaultPhonePrefix,
                    style: TextStyle(fontSize: 16, color: blackColor, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _phonePrefixCtrl,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.defaultPhonePrefixHint,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.phone,
                    onSubmitted: _savePhonePrefix,
                    onTapOutside: (_) => _savePhonePrefix(_phonePrefixCtrl.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Clear All Data pill button
            SizedBox(
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: blackColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                onPressed: _confirmAndClearAll,
                child: Text(AppLocalizations.of(context)!.clearAllData),
              ),
            ),

            const SizedBox(height: 24),

            // Markdown 语法提示
            _MarkdownSyntaxHintSection(l10n: AppLocalizations.of(context)!),
            const SizedBox(height: 24),
            const Divider(height: 1),

            // About section
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.license,
                    style: TextStyle(fontSize: 14, color: descriptionColor, fontWeight: FontWeight.w600),
                  ),
                ),
                Text('MIT', style: TextStyle(fontSize: 14, color: descriptionColor, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.version,
                    style: TextStyle(fontSize: 14, color: descriptionColor, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(version, style: TextStyle(fontSize: 14, color: descriptionColor, fontWeight: FontWeight.w700)),
              ],
            ),

            // Spacer
            SizedBox(height: MediaQuery.of(context).size.height * 0.12),

            // Centered logo + version
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset('assets/trans_logo.svg', height: 56),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.versionLabel(version),
                  style: TextStyle(fontSize: 12, color: descriptionColor, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 32),

                // Social buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SocialIconButton(
                      asset: 'assets/twitter.svg',
                      tooltip: 'X',
                      onTap: () => _openUrl('https://x.com/AkhinAbr'),
                    ),
                    const SizedBox(width: 16),
                    _SocialIconButton(
                      asset: 'assets/github.svg',
                      tooltip: 'GitHub',
                      onTap: () => _openUrl('https://github.com/theakhinabraham'),
                    ),
                    const SizedBox(width: 16),
                    _SocialIconButton(
                      asset: 'assets/linkedin.svg',
                      tooltip: 'LinkedIn',
                      onTap: () => _openUrl('https://www.linkedin.com/in/theakhinabraham'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkdownSyntaxHintSection extends StatefulWidget {
  const _MarkdownSyntaxHintSection({required this.l10n});
  final AppLocalizations l10n;

  @override
  State<_MarkdownSyntaxHintSection> createState() =>
      _MarkdownSyntaxHintSectionState();
}

class _MarkdownSyntaxHintSectionState extends State<_MarkdownSyntaxHintSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    l10n.markdownSyntaxHint,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.blue.shade700,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: Colors.blue.shade200),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _hintRow('**粗体**', l10n.markdownHintBold),
                  const SizedBox(height: 8),
                  _hintRow('*斜体*', l10n.markdownHintItalic),
                  const SizedBox(height: 8),
                  _hintRow('# 标题', l10n.markdownHintHeading),
                  const SizedBox(height: 8),
                  _hintRow('- 列表', l10n.markdownHintList),
                  const SizedBox(height: 8),
                  _hintRow('- [ ] 任务', l10n.markdownHintTask),
                  const SizedBox(height: 8),
                  _hintRow('[链接](url)', l10n.markdownHintLink),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _hintRow(String syntax, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            syntax,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Colors.blue.shade700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            description,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  const _SocialIconButton({
    required this.asset,
    required this.onTap,
    required this.tooltip,
  });

  final String asset;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      customBorder: const CircleBorder(),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.04),
        ),
        alignment: Alignment.center,
        child: Tooltip(
          message: tooltip,
          child: SvgPicture.asset(
            asset,
            height: 32,
            width: 32,
            //colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}