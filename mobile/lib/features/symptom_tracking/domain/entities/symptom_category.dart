import 'package:flutter/material.dart';

class SymptomCategory {
  const SymptomCategory(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

/// Fixed set matching the backend's `SYMPTOM_CATEGORIES` — keep in sync
/// with `backend/src/symptom-logs/dto/create-symptom-log.dto.ts`.
const symptomCategories = [
  SymptomCategory('head', 'ปวดหัว', Icons.psychology_alt_outlined),
  SymptomCategory('stomach', 'ปวดท้อง', Icons.restaurant_outlined),
  SymptomCategory('skin', 'ผื่นแพ้/ผิวหนัง', Icons.healing_outlined),
  SymptomCategory('respiratory', 'ทางเดินหายใจ', Icons.air_outlined),
  SymptomCategory('joint', 'ปวดข้อ/กล้ามเนื้อ', Icons.accessibility_new_outlined),
  SymptomCategory('other', 'อื่นๆ', Icons.more_horiz),
];

/// The category for a stored key, falling back to a neutral entry rather than
/// throwing — an old log may carry a key this build no longer lists.
SymptomCategory symptomCategoryFor(String? key) {
  return symptomCategories.firstWhere(
    (c) => c.key == key,
    orElse: () => const SymptomCategory('', 'ไม่ระบุหมวด', Icons.help_outline),
  );
}

String symptomCategoryLabel(String? key) => symptomCategoryFor(key).label;
