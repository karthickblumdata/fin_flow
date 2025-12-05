class ActionButtonSetting {
  final String key;
  final bool showButton;
  final bool enablePopup;

  const ActionButtonSetting({
    required this.key,
    required this.showButton,
    required this.enablePopup,
  });

  ActionButtonSetting copyWith({
    bool? showButton,
    bool? enablePopup,
  }) {
    return ActionButtonSetting(
      key: key,
      showButton: showButton ?? this.showButton,
      enablePopup: enablePopup ?? this.enablePopup,
    );
  }

  factory ActionButtonSetting.fromJson(Map<String, dynamic> json) {
    final dynamic keyValue = json['key'];
    if (keyValue is! String) {
      throw const FormatException('Invalid key for action button setting');
    }

    return ActionButtonSetting(
      key: keyValue.trim(),
      showButton: json['showButton'] == true,
      enablePopup: json['enablePopup'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'showButton': showButton,
      'enablePopup': enablePopup,
    };
  }
}


