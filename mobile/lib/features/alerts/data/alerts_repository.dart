import '../../../core/supabase/supabase_refs.dart';
import '../domain/entities/alert.dart';

class AlertsRepository {
  /// RLS already limits rows to patients this user may see, so no patient
  /// filter is needed here — only the open/acknowledged distinction.
  Future<List<PatientAlert>> openAlerts() async {
    final rows = await db
        .from('alerts')
        .select()
        .eq('status', 'open')
        .order('created_at', ascending: false);
    return rows.map<PatientAlert>(PatientAlert.fromRow).toList();
  }

  Future<void> acknowledge(String id) async {
    await db.from('alerts').update({'status': 'acknowledged'}).eq('id', id);
  }
}
