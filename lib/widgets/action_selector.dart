import 'package:flutter/material.dart';

/// 动作类型选项：无动作、导航、电话、网页、会议、消息。
const List<_ActionTypeOption> _kActionTypeOptions = [
  _ActionTypeOption(value: null, label: '无动作'),
  _ActionTypeOption(value: 'navigation', label: '📍 导航'),
  _ActionTypeOption(value: 'phone', label: '📞 电话'),
  _ActionTypeOption(value: 'web', label: '🌐 网页'),
  _ActionTypeOption(value: 'meeting', label: '🎥 会议'),
  _ActionTypeOption(value: 'message', label: '💬 消息'),
];

class _ActionTypeOption {
  const _ActionTypeOption({this.value, required this.label});
  final String? value;
  final String label;
}

/// 中国手机号正则：1 开头，第二位 3-9，共 11 位数字。
final RegExp _chinaPhoneRegExp = RegExp(r'^1[3-9]\d{9}$');

/// http/https URL 前缀。
bool _isValidUrl(String s) {
  final t = s.trim();
  return t.startsWith('http://') || t.startsWith('https://');
}

/// 动作选择器：选择类型并填写对应 data/target，通过 [onActionChanged] 回传。
class ActionSelector extends StatefulWidget {
  const ActionSelector({
    super.key,
    this.showTitle = true,
    this.initialActionType,
    this.initialActionData,
    this.initialActionTarget,
    required this.onActionChanged,
  });

  final bool showTitle;
  final String? initialActionType;
  final String? initialActionData;
  final String? initialActionTarget;
  final void Function(String? type, String? data, String? target) onActionChanged;

  @override
  State<ActionSelector> createState() => _ActionSelectorState();
}

class _ActionSelectorState extends State<ActionSelector> {
  static const double kRadius = 16;
  static const Color kBlue = Color(0xFF2563EB);

  late String? _actionType;
  late TextEditingController _dataController;
  late TextEditingController _targetController;
  String? _phoneError;
  String? _urlError;
  String? _requiredError;

  @override
  void initState() {
    super.initState();
    _actionType = widget.initialActionType;
    _dataController = TextEditingController(text: widget.initialActionData ?? '');
    _targetController = TextEditingController(text: widget.initialActionTarget ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyChanged());
  }

  @override
  void didUpdateWidget(ActionSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialActionType != widget.initialActionType ||
        oldWidget.initialActionData != widget.initialActionData ||
        oldWidget.initialActionTarget != widget.initialActionTarget) {
      _actionType = widget.initialActionType;
      _dataController.text = widget.initialActionData ?? '';
      _targetController.text = widget.initialActionTarget ?? '';
      _clearErrors();
      _notifyChanged();
    }
  }

  @override
  void dispose() {
    _dataController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _clearErrors() {
    _phoneError = null;
    _urlError = null;
    _requiredError = null;
  }

  void _notifyChanged() {
    if (!mounted) return;
    final type = _actionType;
    if (type == null || type.isEmpty) {
      widget.onActionChanged(null, null, null);
      return;
    }
    final data = _dataController.text.trim();
    final target = _targetController.text.trim();
    String? dataToSend = data.isEmpty ? null : data;
    String? targetToSend = target.isEmpty ? null : target;
    if (type == 'phone' && dataToSend != null && !_chinaPhoneRegExp.hasMatch(dataToSend)) {
      dataToSend = null;
    }
    if (type == 'web' && dataToSend != null && !_isValidUrl(dataToSend)) {
      dataToSend = null;
    }
    widget.onActionChanged(type, dataToSend, targetToSend);
  }

  void _onTypeChanged(String? value) {
    setState(() {
      _actionType = value;
      _dataController.clear();
      _targetController.clear();
      if (value == 'navigation') _targetController.text = 'gaode';
      if (value == 'meeting') _targetController.text = 'tencent';
      _clearErrors();
      _notifyChanged();
    });
  }

  void _onDataChanged() {
    setState(() {
      _phoneError = null;
      _urlError = null;
      _requiredError = null;
      if (_actionType == 'phone') {
        final t = _dataController.text.trim();
        if (t.isNotEmpty && !_chinaPhoneRegExp.hasMatch(t)) {
          _phoneError = '请输入正确的中国手机号（11 位）';
        }
      }
      if (_actionType == 'web') {
        final t = _dataController.text.trim();
        if (t.isNotEmpty && !_isValidUrl(t)) {
          _urlError = '请输入以 http:// 或 https:// 开头的网址';
        }
      }
      if (_actionType != null && _actionType!.isNotEmpty) {
        if (_dataController.text.trim().isEmpty) {
          _requiredError = '请填写内容';
        }
      }
      _notifyChanged();
    });
  }

  Widget _buildFieldLabel(String text) {
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    String? errorText,
    int maxLines = 1,
    TextInputType? keyboardType,
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
      onChanged: (_) => _onDataChanged(),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
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

  Widget _buildNavigationFields() {
    const targets = ['gaode', 'baidu', 'google'];
    final current = _targetController.text.trim().isEmpty ? 'gaode' : _targetController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('目的地地址'),
        _buildTextField(
          controller: _dataController,
          hint: '输入地址',
          errorText: _requiredError,
        ),
        const SizedBox(height: 16),
        _buildFieldLabel('导航应用'),
        _buildDropdown<String>(
          label: '导航应用',
          value: targets.contains(current) ? current : 'gaode',
          items: targets.map((t) {
            final name = t == 'gaode' ? '高德' : (t == 'baidu' ? '百度' : '谷歌');
            return DropdownMenuItem(value: t, child: Text(name));
          }).toList(),
          onChanged: (v) {
            if (v != null) {
              _targetController.text = v;
              setState(() => _notifyChanged());
            }
          },
        ),
      ],
    );
  }

  Widget _buildPhoneFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('电话号码'),
        _buildTextField(
          controller: _dataController,
          hint: '请输入中国手机号',
          errorText: _phoneError ?? _requiredError,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildWebFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('网页地址'),
        _buildTextField(
          controller: _dataController,
          hint: 'https://',
          errorText: _urlError ?? _requiredError,
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }

  Widget _buildMeetingFields() {
    const platforms = ['tencent', 'zoom', 'dingtalk'];
    final current = _targetController.text.trim().isEmpty ? 'tencent' : _targetController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('会议号或会议链接'),
        _buildTextField(
          controller: _dataController,
          hint: '会议号或完整链接',
          errorText: _requiredError,
        ),
        const SizedBox(height: 16),
        _buildFieldLabel('会议平台'),
        _buildDropdown<String>(
          label: '平台',
          value: platforms.contains(current) ? current : 'tencent',
          items: const [
            DropdownMenuItem(value: 'tencent', child: Text('腾讯会议')),
            DropdownMenuItem(value: 'zoom', child: Text('Zoom')),
            DropdownMenuItem(value: 'dingtalk', child: Text('钉钉')),
          ],
          onChanged: (v) {
            if (v != null) {
              _targetController.text = v;
              setState(() => _notifyChanged());
            }
          },
        ),
      ],
    );
  }

  Widget _buildMessageFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('消息内容'),
        _buildTextField(
          controller: _dataController,
          hint: '预设消息文本',
          errorText: _requiredError,
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        _buildFieldLabel('联系人（可选）'),
        _buildTextField(
          controller: _targetController,
          hint: '联系人标识',
        ),
      ],
    );
  }

  Widget _buildContentByType() {
    switch (_actionType) {
      case 'navigation':
        return _buildNavigationFields();
      case 'phone':
        return _buildPhoneFields();
      case 'web':
        return _buildWebFields();
      case 'meeting':
        return _buildMeetingFields();
      case 'message':
        return _buildMessageFields();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const Text(
                '添加动作',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
            ],
            _buildFieldLabel('动作类型'),
            DropdownButtonFormField<String?>(
              value: _actionType,
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
              items: _kActionTypeOptions
                  .map((o) => DropdownMenuItem<String?>(value: o.value, child: Text(o.label)))
                  .toList(),
              onChanged: _onTypeChanged,
              isExpanded: true,
            ),
            if (_actionType != null && _actionType!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildContentByType(),
            ],
          ],
        ),
      ),
    );
  }
}
