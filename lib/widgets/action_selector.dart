import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:doable_todo_list_app/l10n/app_localizations.dart';
import 'package:doable_todo_list_app/models/action_item.dart';
import 'package:doable_todo_list_app/services/config_service.dart';
import 'package:doable_todo_list_app/utils/meeting_utils.dart';

class _ActionTypeOption {
  const _ActionTypeOption({this.value, required this.label});
  final String? value;
  final String label;
}

List<_ActionTypeOption> _buildActionTypeOptions(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return [
    _ActionTypeOption(value: null, label: l10n.actionTypeNoAction),
    _ActionTypeOption(value: 'navigation', label: '📍 ${l10n.actionTypeNavigation}'),
    _ActionTypeOption(value: 'phone', label: '📞 ${l10n.actionTypePhone}'),
    _ActionTypeOption(value: 'web', label: '🌐 ${l10n.actionTypeWeb}'),
    _ActionTypeOption(value: 'meeting', label: '🎥 ${l10n.actionTypeMeeting}'),
    _ActionTypeOption(value: 'message', label: '💬 ${l10n.actionTypeMessage}'),
  ];
}

/// 从完整号码中提取纯数字部分
String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

/// 校验完整电话号码（含前缀）：至少 10 位数字
bool _isValidFullPhone(String s) {
  final digits = _digitsOnly(s);
  return digits.length >= 10 && digits.length <= 15;
}

bool _isValidUrl(String s) {
  final t = s.trim();
  return t.startsWith('http://') || t.startsWith('https://');
}

/// 动作选择器：支持添加多个动作，通过 [onActionsChanged] 回传。
class ActionSelector extends StatefulWidget {
  const ActionSelector({
    super.key,
    this.showTitle = true,
    this.initialActions = const [],
    required this.onActionsChanged,
    this.onHasIncompleteChanged,
  });

  final bool showTitle;
  final List<ActionItem> initialActions;
  final void Function(List<ActionItem>) onActionsChanged;
  /// 当存在已选类型但数据未填完整的动作时为 true，用于保存前校验。
  final void Function(bool hasIncomplete)? onHasIncompleteChanged;

  @override
  State<ActionSelector> createState() => _ActionSelectorState();
}

class _ActionSelectorState extends State<ActionSelector> {
  static const double kRadius = 16;
  static const Color kBlue = Color(0xFF2563EB);

  late List<_ActionSlot> _slots;

  @override
  void initState() {
    super.initState();
    _slots = widget.initialActions.isEmpty
        ? [_ActionSlot()]
        : widget.initialActions.map((a) => _ActionSlot.fromItem(a)).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyChanged());
  }

  @override
  void didUpdateWidget(ActionSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 仅当外部真正传入不同的初始数据时才同步（如编辑页加载任务时）。
    // 若新 initialActions 与当前 slots 产出一致，说明是父组件回传我们的数据，跳过 sync 避免输入时重建导致焦点丢失。
    if (_listEquals(oldWidget.initialActions, widget.initialActions)) return;
    final ourCurrentList = _slots.map((s) => s.toItemOrPartial()).toList();
    if (_listEquals(widget.initialActions, ourCurrentList)) return;
    _syncFromInitial();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyChanged());
  }

  static bool _listEquals(List<ActionItem> a, List<ActionItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i], y = b[i];
      if (x.type != y.type || x.data != y.data || x.target != y.target) return false;
    }
    return true;
  }

  void _syncFromInitial() {
    for (final s in _slots) {
      s.dispose();
    }
    _slots = widget.initialActions.isEmpty
        ? [_ActionSlot()]
        : widget.initialActions.map((a) => _ActionSlot.fromItem(a)).toList();
  }

  @override
  void dispose() {
    for (final s in _slots) {
      s.dispose();
    }
    super.dispose();
  }

  /// 只要有一个槽位为「无动作」，就不可添加新动作
  bool get _canAddAction =>
      _slots.every((s) => s.type != null && s.type!.isNotEmpty);

  void _addAction() {
    if (!_canAddAction) return;
    setState(() => _slots.add(_ActionSlot()));
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyChanged());
  }

  void _removeAt(int index) {
    if (_slots.length > 1) {
      _slots[index].dispose();
      setState(() => _slots.removeAt(index));
    } else {
      // 只剩一个时，重置为默认值
      _slots[index].resetToDefault();
      setState(() {});
    }
    _notifyChanged();
  }

  void _notifyChanged() {
    if (!mounted) return;
    final list = <ActionItem>[];
    bool hasIncomplete = false;
    for (final s in _slots) {
      list.add(s.toItemOrPartial());
      if (s.type != null && s.type!.isNotEmpty && s.toItem() == null) {
        hasIncomplete = true;
      }
    }
    widget.onActionsChanged(list);
    widget.onHasIncompleteChanged?.call(hasIncomplete);
  }

  Widget _buildFieldLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
    String? errorText,
    int maxLines = 1,
    TextInputType? keyboardType,
    required VoidCallback onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: const BorderSide(color: kBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
      style: const TextStyle(fontSize: 14, height: 1.4),
      onChanged: (_) => onChanged(),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      items: items,
      onChanged: onChanged,
      isExpanded: true,
    );
  }

  Widget _buildSlotContent(BuildContext context, _ActionSlot slot, int index) {
    final l10n = AppLocalizations.of(context)!;

    void onDataChanged() {
      setState(() {});
      _notifyChanged();
    }

    void onTypeChanged(String? value) {
      setState(() {
        slot.type = value;
        slot.dataController.clear();
        slot.targetController.clear();
        if (value == 'navigation') slot.targetController.text = 'gaode';
        if (value == 'meeting') slot.targetController.text = 'tencent';
        if (value == 'web') slot.dataController.text = 'https://';
        if (value == 'phone') slot.dataController.text = ConfigService.instance.defaultPhonePrefix;
      });
      _notifyChanged();
    }

    if (slot.type == null || slot.type!.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(context, l10n.actionType),
          _buildDropdown<String?>(
            value: slot.type,
            items: _buildActionTypeOptions(context)
                .map((o) => DropdownMenuItem<String?>(value: o.value, child: Text(o.label)))
                .toList(),
            onChanged: (v) => onTypeChanged(v),
          ),
        ],
      );
    }

    Widget content;
    switch (slot.type) {
      case 'navigation':
        const targets = ['gaode', 'baidu', 'google'];
        final current = slot.targetController.text.trim().isEmpty ? 'gaode' : slot.targetController.text.trim();
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel(context, l10n.destinationAddress),
            _buildTextField(context, controller: slot.dataController, hint: l10n.inputAddress, errorText: slot.hasRequiredError ? l10n.pleaseFillContent : null, onChanged: onDataChanged),
            const SizedBox(height: 16),
            _buildFieldLabel(context, l10n.navApp),
            _buildDropdown<String>(
              value: targets.contains(current) ? current : 'gaode',
              items: targets.map((t) {
                final name = t == 'gaode' ? l10n.gaode : (t == 'baidu' ? l10n.baidu : l10n.google);
                return DropdownMenuItem(value: t, child: Text(name));
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  slot.targetController.text = v;
                  onDataChanged();
                }
              },
            ),
          ],
        );
        break;
      case 'phone':
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel(context, l10n.phoneNumber),
            _buildTextField(
              context,
              controller: slot.dataController,
              hint: '${ConfigService.instance.defaultPhonePrefix} ${l10n.phoneNumberHint}',
              errorText: slot.hasPhoneError ? l10n.phoneError : (slot.hasRequiredError ? l10n.pleaseFillContent : null),
              keyboardType: TextInputType.phone,
              onChanged: onDataChanged,
            ),
          ],
        );
        break;
      case 'web':
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel(context, l10n.webUrl),
            _buildTextField(context, controller: slot.dataController, hint: 'https://', errorText: slot.hasUrlError ? l10n.urlError : (slot.hasRequiredError ? l10n.pleaseFillContent : null), keyboardType: TextInputType.url, onChanged: onDataChanged),
          ],
        );
        break;
      case 'meeting':
        const platforms = ['tencent', 'zoom', 'dingtalk'];
        final current = slot.targetController.text.trim().isEmpty ? 'tencent' : slot.targetController.text.trim();
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel(context, l10n.meetingIdOrLink),
            _buildTextField(context, controller: slot.dataController, hint: l10n.meetingIdOrLinkHint, errorText: slot.hasMeetingError ? l10n.meetingInvitationEmpty : null, onChanged: onDataChanged),
            const SizedBox(height: 16),
            _buildFieldLabel(context, l10n.meetingPlatform),
            _buildDropdown<String>(
              value: platforms.contains(current) ? current : 'tencent',
              items: [
                DropdownMenuItem(value: 'tencent', child: Text(l10n.tencentMeeting)),
                DropdownMenuItem(value: 'zoom', child: Text(l10n.zoom)),
                DropdownMenuItem(value: 'dingtalk', child: Text(l10n.dingtalk)),
              ],
              onChanged: (v) {
                if (v != null) {
                  slot.targetController.text = v;
                  onDataChanged();
                }
              },
            ),
          ],
        );
        break;
      case 'message':
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel(context, l10n.messageContent),
            _buildTextField(context, controller: slot.dataController, hint: l10n.messageContentHint, errorText: slot.hasRequiredError ? l10n.pleaseFillContent : null, maxLines: 3, onChanged: onDataChanged),
            const SizedBox(height: 16),
            _buildFieldLabel(context, l10n.contactOptional),
            _buildTextField(context, controller: slot.targetController, hint: l10n.contactHint, onChanged: onDataChanged),
          ],
        );
        break;
      default:
        content = const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(context, l10n.actionType),
        _buildDropdown<String?>(
          value: slot.type,
          items: _buildActionTypeOptions(context)
              .map((o) => DropdownMenuItem<String?>(value: o.value, child: Text(o.label)))
              .toList(),
          onChanged: (v) => onTypeChanged(v),
        ),
        const SizedBox(height: 16),
        content,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showTitle) ...[
              Text(
                l10n.addAction,
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 16),
            ],
            ...List.generate(_slots.length, (i) {
              final canRemove = true; // 始终可删除：多个时移除，单个时重置为默认
              final slotCard = Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadius),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildSlotContent(context, _slots[i], i),
                ),
              );
              final content = canRemove
                  ? ClipRect(
                      child: Slidable(
                        key: ValueKey('action_slot_$i'),
                        endActionPane: ActionPane(
                          motion: const ScrollMotion(),
                          extentRatio: 0.25,
                          children: [
                            CustomSlidableAction(
                              onPressed: (_) => _removeAt(i),
                              backgroundColor: Colors.red.shade400,
                              foregroundColor: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: const Icon(Icons.delete_outline, size: 24),
                            ),
                          ],
                        ),
                        child: slotCard,
                      ),
                    )
                  : slotCard;
              return Padding(
                padding: EdgeInsets.only(bottom: i < _slots.length - 1 ? 12 : 0),
                child: content,
              );
            }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _canAddAction ? _addAction : null,
                icon: const Icon(Icons.add, size: 20),
                label: Text(l10n.addAnotherAction),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kBlue,
                  side: const BorderSide(color: kBlue),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个动作槽：持有 type、dataController、targetController，以及校验逻辑。
class _ActionSlot {
  _ActionSlot() {
    dataController = TextEditingController();
    targetController = TextEditingController();
  }

  _ActionSlot.fromItem(ActionItem a) {
    type = a.type.isNotEmpty ? a.type : null;
    final data = a.data?.trim() ?? '';
    dataController = TextEditingController(
      text: type == 'web' && data.isEmpty ? 'https://' : data,
    );
    targetController = TextEditingController(text: a.target ?? '');
    if (type == 'navigation' && targetController.text.isEmpty) targetController.text = 'gaode';
    if (type == 'meeting' && targetController.text.isEmpty) targetController.text = 'tencent';
  }

  String? type;
  late TextEditingController dataController;
  late TextEditingController targetController;

  bool get hasPhoneError {
    if (type != 'phone') return false;
    final t = dataController.text.trim();
    return t.isNotEmpty && !_isValidFullPhone(t);
  }

  bool get hasUrlError {
    if (type != 'web') return false;
    final t = dataController.text.trim();
    return t.isNotEmpty && !_isValidUrl(t);
  }

  /// 会议类型：数据为空或既无会议号也无 URL 时为 true。
  bool get hasMeetingError {
    if (type != 'meeting') return false;
    final t = dataController.text.trim();
    return t.isEmpty || !MeetingUtils.hasValidMeetingData(t);
  }

  bool get hasRequiredError =>
      type != null && type!.isNotEmpty && dataController.text.trim().isEmpty;

  /// 重置为默认值：无类型、清空数据。
  void resetToDefault() {
    type = null;
    dataController.clear();
    targetController.clear();
  }

  void dispose() {
    dataController.dispose();
    targetController.dispose();
  }

  ActionItem? toItem() {
    if (type == null || type!.isEmpty) return null;
    final raw = dataController.text.trim();
    if (raw.isEmpty) return null;
    String data = raw;
    if (type == 'phone') {
      if (!_isValidFullPhone(raw)) return null;
      data = raw.startsWith('+') ? raw : '${ConfigService.instance.defaultPhonePrefix}$raw';
    }
    if (type == 'web' && !_isValidUrl(data)) return null;
    if (type == 'meeting' && !MeetingUtils.hasValidMeetingData(data)) return null;
    return ActionItem(
      type: type!,
      data: data,
      target: targetController.text.trim().isEmpty ? null : targetController.text.trim(),
    );
  }

  /// 返回当前槽位的完整状态（含未完成、空槽），用于与父组件同步，避免输入时因 sync 丢失焦点和内容。
  ActionItem toItemOrPartial() {
    if (type == null || type!.isEmpty) {
      return const ActionItem(type: '', data: null, target: null);
    }
    String data = dataController.text.trim();
    if (type == 'phone' && data.isNotEmpty && !data.startsWith('+')) {
      data = '${ConfigService.instance.defaultPhonePrefix}$data';
    }
    return ActionItem(
      type: type!,
      data: data,
      target: targetController.text.isEmpty ? null : targetController.text,
    );
  }
}
