import 'package:flutter/material.dart';

import '../../../../core/i18n/app_locale.dart';

class SymptomCategory {
  const SymptomCategory(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

/// Fixed set matching the backend's `SYMPTOM_CATEGORIES` — keep in sync
/// with `backend/src/symptom-logs/dto/create-symptom-log.dto.ts`.
///
/// A getter, not a const list: the labels are translated, and a const list
/// would freeze whichever language was current when the library was first
/// touched. The keys are what the database stores and never change.
List<SymptomCategory> get symptomCategories => [
      SymptomCategory('head', t('ปวดหัว', 'Headache'),
          Icons.psychology_alt_outlined),
      SymptomCategory('stomach', t('ปวดท้อง', 'Stomach pain'),
          Icons.restaurant_outlined),
      SymptomCategory('skin', t('ผื่นแพ้/ผิวหนัง', 'Rash / skin'),
          Icons.healing_outlined),
      SymptomCategory('respiratory', t('ทางเดินหายใจ', 'Breathing'),
          Icons.air_outlined),
      SymptomCategory('joint', t('ปวดข้อ/กล้ามเนื้อ', 'Joints / muscles'),
          Icons.accessibility_new_outlined),
      SymptomCategory('other', t('อื่นๆ', 'Other'), Icons.more_horiz),
    ];

/// The category for a stored key, falling back to a neutral entry rather than
/// throwing — an old log may carry a key this build no longer lists.
SymptomCategory symptomCategoryFor(String? key) {
  return symptomCategories.firstWhere(
    (c) => c.key == key,
    orElse: () =>
        SymptomCategory('', t('ไม่ระบุหมวด', 'No category'), Icons.help_outline),
  );
}

String symptomCategoryLabel(String? key) => symptomCategoryFor(key).label;
