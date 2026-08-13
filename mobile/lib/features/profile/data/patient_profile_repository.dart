import '../../../core/supabase/supabase_refs.dart';
import '../domain/entities/patient_profile.dart';

class PatientProfileRepository {
  Future<PatientProfile> fetch(String patientId) async {
    final row = await db.from('patients').select().eq('id', patientId).single();
    return PatientProfile.fromRow(row);
  }

  Future<PatientProfile> update(
    String patientId, {
    String? name,
    String? birthDate,
    String? gender,
  }) async {
    final row = await db
        .from('patients')
        .update({
          if (name != null) 'name': name,
          if (birthDate != null) 'birth_date': birthDate,
          if (gender != null) 'gender': gender,
        })
        .eq('id', patientId)
        .select()
        .single();
    return PatientProfile.fromRow(row);
  }

  /// Writes the health details.
  ///
  /// Separate from [update] because every field here is clearable: leaving
  /// blood type unknown has to be expressible, and a null-means-leave-alone
  /// signature cannot say the difference between "don't touch" and "erase".
  /// This one always writes all of them, so what the form shows is what is
  /// stored.
  Future<PatientProfile> updateHealth(
    String patientId, {
    required String? primaryCondition,
    required List<String> drugAllergies,
    required List<String> foodAllergies,
    required String? bloodType,
    required double? weightKg,
    required double? heightCm,
  }) async {
    final row = await db
        .from('patients')
        .update({
          'primary_condition': primaryCondition,
          'drug_allergies': drugAllergies,
          'food_allergies': foodAllergies,
          'blood_type': bloodType,
          'weight_kg': weightKg,
          'height_cm': heightCm,
        })
        .eq('id', patientId)
        .select()
        .single();
    return PatientProfile.fromRow(row);
  }
}
