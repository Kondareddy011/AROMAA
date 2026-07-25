class TokenCustomization {
  final bool printPriceOnToken;
  final bool printCustomerDetails;
  final double fontScale;

  TokenCustomization({
    this.printPriceOnToken = true,
    this.printCustomerDetails = true,
    this.fontScale = 1.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'printPriceOnToken': printPriceOnToken,
      'printCustomerDetails': printCustomerDetails,
      'fontScale': fontScale,
    };
  }

  factory TokenCustomization.fromJson(Map<String, dynamic> json) {
    return TokenCustomization(
      printPriceOnToken: json['printPriceOnToken'] as bool? ?? true,
      printCustomerDetails: json['printCustomerDetails'] as bool? ?? true,
      fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
    );
  }

  TokenCustomization copyWith({
    bool? printPriceOnToken,
    bool? printCustomerDetails,
    double? fontScale,
  }) {
    return TokenCustomization(
      printPriceOnToken: printPriceOnToken ?? this.printPriceOnToken,
      printCustomerDetails: printCustomerDetails ?? this.printCustomerDetails,
      fontScale: fontScale ?? this.fontScale,
    );
  }
}
