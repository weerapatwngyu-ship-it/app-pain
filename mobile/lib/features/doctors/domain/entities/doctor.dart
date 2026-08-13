/// A doctor in the directory.
///
/// Every optional field here describes a real person's practice, so each one
/// is shown only when it has been filled in — a listing renders fewer rows
/// rather than placeholder text, and nothing on the card is ever computed
/// into existence by the app.
class Doctor {
  const Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    this.userId,
    this.bio,
    this.photoUrl,
    this.credential,
    this.workplace,
    this.languages = const [],
    this.conditions = const [],
    this.consultFee,
    this.consultMinutes,
  });

  final String id;

  /// The account that signs in as this doctor, or null for a listing an admin
  /// created before (or without) an account — such a doctor appears in the
  /// directory but cannot read the messages patients send them.
  final String? userId;

  final String name;
  final String specialty;
  final String? bio;

  /// Absolute URL into Supabase Storage, or null when no photo was uploaded.
  final String? photoUrl;

  /// Qualification line, e.g. "แพทย์เวชปฏิบัติทั่วไป".
  final String? credential;

  /// Where they practise.
  final String? workplace;

  /// Languages they consult in, as written by the admin.
  final List<String> languages;

  /// What they will consult on, one entry per line on the profile.
  final List<String> conditions;

  /// Consultation fee in baht, and how long that consultation runs.
  final double? consultFee;
  final int? consultMinutes;

  bool get hasAccount => userId != null;

  /// Short code strip for the card, e.g. "TH/EN". Falls back to the raw
  /// entries when they are not names this recognises, rather than dropping a
  /// language the admin deliberately typed.
  String get languageBadge {
    if (languages.isEmpty) return '';
    const short = {
      'ไทย': 'TH', 'thai': 'TH', 'th': 'TH',
      'อังกฤษ': 'EN', 'english': 'EN', 'en': 'EN',
      'จีน': 'CN', 'chinese': 'CN', 'zh': 'CN',
      'ญี่ปุ่น': 'JP', 'japanese': 'JP', 'ja': 'JP',
    };
    return languages
        .map((l) => short[l.trim().toLowerCase()] ?? l.trim())
        .join('/');
  }

  /// Fee as it should read on a card. Null when no fee has been recorded —
  /// which is different from free, so the row is left out entirely.
  String? get feeText {
    final fee = consultFee;
    if (fee == null) return null;
    final whole = fee == fee.roundToDouble();
    return '฿${whole ? fee.round().toString() : fee.toStringAsFixed(2)}';
  }

  String? get durationText =>
      consultMinutes == null ? null : '$consultMinutes นาที';

  static List<String> _stringList(dynamic value) =>
      (value as List?)?.map((e) => e.toString()).toList() ?? const [];

  factory Doctor.fromRow(Map<String, dynamic> row) {
    return Doctor(
      id: row['id'] as String,
      userId: row['user_id'] as String?,
      name: row['name'] as String,
      specialty: row['specialty'] as String,
      bio: row['bio'] as String?,
      photoUrl: row['photo_url'] as String?,
      credential: row['credential'] as String?,
      workplace: row['workplace'] as String?,
      languages: _stringList(row['languages']),
      conditions: _stringList(row['conditions']),
      consultFee: (row['consult_fee'] as num?)?.toDouble(),
      consultMinutes: (row['consult_minutes'] as num?)?.toInt(),
    );
  }
}
