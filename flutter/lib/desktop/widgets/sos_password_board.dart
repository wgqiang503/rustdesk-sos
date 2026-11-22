import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/animated_rotation_widget.dart';
import 'package:flutter_hbb/common/widgets/custom_password.dart';
import 'package:flutter_hbb/common/widgets/dialog.dart'
    show requestDesktopSettingsUnlock;
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:get/get.dart';

class SosPasswordBoard extends StatefulWidget {
  const SosPasswordBoard({super.key, required this.model});

  final ServerModel model;

  @override
  State<SosPasswordBoard> createState() => _SosPasswordBoardState();
}

class _SosPasswordBoardState extends State<SosPasswordBoard> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _rules = [
    DigitValidationRule(),
    UppercaseValidationRule(),
    LowercaseValidationRule(),
    MinCharactersValidationRule(8),
  ];
  late final int _maxLength = bind.mainMaxEncryptLen();
  late Future<bool?> _permanentPasswordSet;
  late final StreamSubscription<DesktopTabState> _tabSubscription;
  bool _homeSelected = true;
  bool _preferPermanent = true;
  bool _authorizing = false;
  bool _editing = false;
  bool _saving = false;
  bool _reveal = false;
  String? _error;

  bool get _canChangePassword =>
      !bind.isDisableSettings() && !isChangePermanentPasswordDisabled();

  bool _canEditNow() =>
      _canChangePassword &&
      bind.mainGetOptionSync(key: kOptionApproveMode) != 'click' &&
      bind.mainGetOptionSync(key: kOptionVerificationMethod) !=
          kUseTemporaryPassword;

  Future<bool?> _readPermanentPasswordState() async {
    try {
      return (await bind.mainGetCommon(key: 'permanent-password-set')) ==
          'true';
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _permanentPasswordSet = _readPermanentPasswordState();
    _tabSubscription = Get.find<DesktopTabController>().state.listen((state) {
      final selected = state.selected == 0;
      if (!mounted || _homeSelected == selected) return;
      _homeSelected = selected;
      if (selected) {
        setState(() => _permanentPasswordSet = _readPermanentPasswordState());
      } else {
        _cancelEdit();
      }
    });
  }

  @override
  void dispose() {
    _tabSubscription.cancel();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _beginEdit() async {
    if (_authorizing || _editing || !_homeSelected || !_canEditNow()) return;
    setState(() => _authorizing = true);
    var authorized = false;
    try {
      authorized =
          !bind.mainIsInstalled() || await requestDesktopSettingsUnlock();
    } catch (_) {
      if (mounted) showToast(translate('Failed'));
    } finally {
      if (mounted) setState(() => _authorizing = false);
    }
    if (!mounted || !authorized || !_homeSelected || !_canEditNow()) return;
    setState(() => _editing = true);
  }

  void _clearDraft() {
    _password.clear();
    _confirmation.clear();
    _editing = false;
    _reveal = false;
    _error = null;
  }

  void _cancelEdit() {
    if (_editing && !_saving) setState(_clearDraft);
  }

  Future<void> _save() async {
    if (!_editing || _saving || !_homeSelected) return;
    if (!_canEditNow()) {
      _cancelEdit();
      showToast(translate('Failed'));
      return;
    }

    final password = _password.text.trim();
    if (password.isEmpty) {
      setState(() => _error = translate('Empty Password'));
      return;
    }
    final violations = _rules.where((rule) => !rule.validate(password));
    if (violations.isNotEmpty) {
      setState(() => _error = violations.map((rule) => rule.name).join(', '));
      return;
    }
    if (_confirmation.text.trim() != password) {
      setState(() => _error = translate('The confirmation is not identical.'));
      return;
    }

    setState(() {
      _saving = true;
      _reveal = false;
      _error = null;
    });
    var saved = false;
    try {
      saved = await bind.mainSetPermanentPasswordWithResult(password: password);
    } catch (_) {
      // Keep bridge exceptions out of the UI and logs: inputs are credentials.
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved) {
        _clearDraft();
        _permanentPasswordSet = Future.value(true);
        _preferPermanent = true;
      } else if (!_homeSelected) {
        _clearDraft();
      } else {
        _error = translate('Failed');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final acceptsPassword = model.approveMode != 'click';
    final canUsePermanent =
        acceptsPassword && model.verificationMethod != kUseTemporaryPassword;
    final canUseOneTime =
        acceptsPassword && model.verificationMethod != kUsePermanentPassword;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 13, 16, 13),
      padding: const EdgeInsets.only(left: 7),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(width: 2, color: MyTheme.accent)),
      ),
      child: _editing && canUsePermanent && _canChangePassword
          ? _buildEditor(context)
          : FutureBuilder<bool?>(
              future: _permanentPasswordSet,
              builder: (context, snapshot) {
                final hasPermanent = snapshot.data == true;
                final both = canUsePermanent && canUseOneTime && hasPermanent;
                final showPermanent = canUsePermanent &&
                    (!canUseOneTime || both && _preferPermanent);
                return _buildDisplay(context, showPermanent, canUseOneTime,
                    both, canUsePermanent, snapshot);
              },
            ),
    );
  }

  Widget _buildDisplay(
    BuildContext context,
    bool showPermanent,
    bool canUseOneTime,
    bool both,
    bool canUsePermanent,
    AsyncSnapshot<bool?> status,
  ) {
    final controller = widget.model.serverPasswd;
    final showOneTime = !showPermanent && canUseOneTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          showPermanent
              ? '固定密码'
              : translate(showOneTime ? 'One-time Password' : 'Password'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Row(
          children: [
            Expanded(
              child: showOneTime
                  ? GestureDetector(
                      onDoubleTap: () {
                        Clipboard.setData(ClipboardData(text: controller.text));
                        showToast(translate('Copied'));
                      },
                      child: TextField(
                        controller: controller,
                        readOnly: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ).workaroundFreezeLinuxMint(),
                    )
                  : Text(!showPermanent
                      ? '–'
                      : status.data == true
                          ? '••••••••　已设置'
                          : status.hasData
                              ? '未设置'
                              : status.connectionState == ConnectionState.done
                                  ? translate('Failed')
                                  : '…'),
            ),
            if (showOneTime)
              Tooltip(
                message: translate('Refresh Password'),
                child: AnimatedRotationWidget(
                  onPressed: () => bind.mainUpdateTemporaryPassword(),
                  child: const SizedBox(
                    width: 34,
                    height: 36,
                    child: Icon(Icons.refresh, size: 20),
                  ),
                ),
              ),
            if (canUsePermanent && _canChangePassword)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: translate('Change Password'),
                iconSize: 20,
                onPressed: _authorizing ? null : _beginEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        if (both)
          TextButton(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: () => setState(() => _preferPermanent = !showPermanent),
            child: Text(showPermanent ? '显示一次性密码' : '显示固定密码'),
          ),
      ],
    );
  }

  Widget _buildEditor(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _cancelEdit,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _password,
            autofocus: true,
            enabled: !_saving,
            obscureText: !_reveal,
            keyboardType: TextInputType.visiblePassword,
            enableSuggestions: false,
            autocorrect: false,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            enableIMEPersonalizedLearning: false,
            maxLength: _maxLength,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: '新固定密码',
              counterText: '',
              suffixIcon: IconButton(
                tooltip: _reveal ? '隐藏输入' : '显示输入',
                onPressed:
                    _saving ? null : () => setState(() => _reveal = !_reveal),
                icon: Icon(_reveal ? Icons.visibility_off : Icons.visibility),
              ),
            ),
          ).workaroundFreezeLinuxMint(),
          TextField(
            controller: _confirmation,
            enabled: !_saving,
            obscureText: true,
            keyboardType: TextInputType.visiblePassword,
            enableSuggestions: false,
            autocorrect: false,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            enableIMEPersonalizedLearning: false,
            maxLength: _maxLength,
            decoration: InputDecoration(
              labelText: translate('Confirmation'),
              counterText: '',
            ),
            onSubmitted: (_) => _save(),
          ).workaroundFreezeLinuxMint(),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: _saving ? null : _cancelEdit,
                  child: Text(translate('Cancel')),
                ),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '保存中…' : translate('Save')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
