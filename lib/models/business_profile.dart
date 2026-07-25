class BusinessProfile {
  final String cafeName;
  final String address;
  final String phone;
  final String gstin;
  final double taxPercentage;
  final String headerMessage;
  final String footerMessage;

  BusinessProfile({
    this.cafeName = 'Aroma Tea Cafe',
    this.address = '123 Tea Boulevard, Sector 5, Bangalore',
    this.phone = '+91 98765 43210',
    this.gstin = '29AAAAA0000A1Z5',
    this.taxPercentage = 5.0,
    this.headerMessage = 'Welcome to Aroma Tea Cafe!',
    this.footerMessage = 'Thank you! Visit Us Again.',
  });

  Map<String, dynamic> toJson() {
    return {
      'cafeName': cafeName,
      'address': address,
      'phone': phone,
      'gstin': gstin,
      'taxPercentage': taxPercentage,
      'headerMessage': headerMessage,
      'footerMessage': footerMessage,
    };
  }

  factory BusinessProfile.fromJson(Map<String, dynamic> json) {
    return BusinessProfile(
      cafeName: json['cafeName'] as String? ?? 'Aroma Tea Cafe',
      address: json['address'] as String? ?? '123 Tea Boulevard, Sector 5, Bangalore',
      phone: json['phone'] as String? ?? '+91 98765 43210',
      gstin: json['gstin'] as String? ?? '29AAAAA0000A1Z5',
      taxPercentage: (json['taxPercentage'] as num?)?.toDouble() ?? 5.0,
      headerMessage: json['headerMessage'] as String? ?? 'Welcome to Aroma Tea Cafe!',
      footerMessage: json['footerMessage'] as String? ?? 'Thank you! Visit Us Again.',
    );
  }

  BusinessProfile copyWith({
    String? cafeName,
    String? address,
    String? phone,
    String? gstin,
    double? taxPercentage,
    String? headerMessage,
    String? footerMessage,
  }) {
    return BusinessProfile(
      cafeName: cafeName ?? this.cafeName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      gstin: gstin ?? this.gstin,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      headerMessage: headerMessage ?? this.headerMessage,
      footerMessage: footerMessage ?? this.footerMessage,
    );
  }
}
