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
}
