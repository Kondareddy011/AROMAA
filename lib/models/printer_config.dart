class PrinterConfig {
  final String deviceName;
  final String macAddress;
  final bool isConnected;
  final int paperWidthMm; // 58 or 80
  final String cafeName;
  final String tagline;
  final String address;
  final String phone;
  final String gstin;
  final String footerMessage;
  final double taxPercentage;
  final bool taxEnabled;
  final bool autoPrintEnabled;
  final bool printPriceOnToken;
  final bool printCustomerDetails;
  final double fontScale;
  final String tokenResetTime;

  PrinterConfig({
    this.deviceName = 'Bluetooth Thermal Printer',
    this.macAddress = '00:11:22:33:44:55',
    this.isConnected = false,
    this.paperWidthMm = 58,
    this.cafeName = 'AROMAA CAFE',
    this.tagline = 'A Sip of Pure Joy & Warmth',
    this.address = 'Main Road, Cyber City, Jubilee Hills',
    this.phone = '+91 98765 43210',
    this.gstin = '36AAACA1234B1Z9',
    this.footerMessage = 'Thank you for visiting AROMAA Cafe! Have a blissful day ☕',
    this.taxPercentage = 0.0,
    this.taxEnabled = false,
    this.autoPrintEnabled = true,
    this.printPriceOnToken = true,
    this.printCustomerDetails = true,
    this.fontScale = 1.0,
    this.tokenResetTime = '2020-01-01T00:00:00.000',
  });

  PrinterConfig copyWith({
    String? deviceName,
    String? macAddress,
    bool? isConnected,
    int? paperWidthMm,
    String? cafeName,
    String? tagline,
    String? address,
    String? phone,
    String? gstin,
    String? footerMessage,
    double? taxPercentage,
    bool? taxEnabled,
    bool? autoPrintEnabled,
    bool? printPriceOnToken,
    bool? printCustomerDetails,
    double? fontScale,
    String? tokenResetTime,
  }) {
    return PrinterConfig(
      deviceName: deviceName ?? this.deviceName,
      macAddress: macAddress ?? this.macAddress,
      isConnected: isConnected ?? this.isConnected,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
      cafeName: cafeName ?? this.cafeName,
      tagline: tagline ?? this.tagline,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      gstin: gstin ?? this.gstin,
      footerMessage: footerMessage ?? this.footerMessage,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      taxEnabled: taxEnabled ?? this.taxEnabled,
      autoPrintEnabled: autoPrintEnabled ?? this.autoPrintEnabled,
      printPriceOnToken: printPriceOnToken ?? this.printPriceOnToken,
      printCustomerDetails: printCustomerDetails ?? this.printCustomerDetails,
      fontScale: fontScale ?? this.fontScale,
      tokenResetTime: tokenResetTime ?? this.tokenResetTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceName': deviceName,
      'macAddress': macAddress,
      'isConnected': isConnected,
      'paperWidthMm': paperWidthMm,
      'cafeName': cafeName,
      'tagline': tagline,
      'address': address,
      'phone': phone,
      'gstin': gstin,
      'footerMessage': footerMessage,
      'taxPercentage': taxPercentage,
      'taxEnabled': taxEnabled,
      'autoPrintEnabled': autoPrintEnabled,
      'printPriceOnToken': printPriceOnToken,
      'printCustomerDetails': printCustomerDetails,
      'fontScale': fontScale,
      'tokenResetTime': tokenResetTime,
    };
  }

  factory PrinterConfig.fromJson(Map<String, dynamic> json) {
    return PrinterConfig(
      deviceName: (json['deviceName'] ?? 'Bluetooth Thermal Printer').toString(),
      macAddress: (json['macAddress'] ?? '00:11:22:33:44:55').toString(),
      isConnected: json['isConnected'] as bool? ?? false,
      paperWidthMm: json['paperWidthMm'] as int? ?? 58,
      cafeName: (json['cafeName'] ?? 'AROMAA CAFE').toString(),
      tagline: (json['tagline'] ?? 'A Sip of Pure Joy & Warmth').toString(),
      address: (json['address'] ?? 'Main Road, Cyber City, Jubilee Hills').toString(),
      phone: (json['phone'] ?? '+91 98765 43210').toString(),
      gstin: (json['gstin'] ?? '36AAACA1234B1Z9').toString(),
      footerMessage: (json['footerMessage'] ?? 'Thank you for visiting AROMAA Cafe!').toString(),
      taxPercentage: double.tryParse((json['taxPercentage'] ?? '0.0').toString()) ?? 0.0,
      taxEnabled: json['taxEnabled'] as bool? ?? false,
      autoPrintEnabled: json['autoPrintEnabled'] as bool? ?? true,
      printPriceOnToken: json['printPriceOnToken'] as bool? ?? true,
      printCustomerDetails: json['printCustomerDetails'] as bool? ?? true,
      fontScale: double.tryParse((json['fontScale'] ?? '1.0').toString()) ?? 1.0,
      tokenResetTime: (json['tokenResetTime'] ?? '2020-01-01T00:00:00.000').toString(),
    );
  }
}
