import '../../../core/network/api_client.dart';
import '../domain/entities/doctor.dart';

class DoctorRepository {
  DoctorRepository(this._client);

  final ApiClient _client;

  Future<List<Doctor>> fetchAll() async {
    final json = await _client.get('/doctors') as List<dynamic>;
    return json.map((e) => Doctor.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Doctor> fetchOne(String id) async {
    final json = await _client.get('/doctors/$id') as Map<String, dynamic>;
    return Doctor.fromJson(json);
  }

  Future<Doctor> create({required String name, required String specialty, String? bio}) async {
    final json = await _client.post('/doctors', body: {
      'name': name,
      'specialty': specialty,
      if (bio != null && bio.isNotEmpty) 'bio': bio,
    }) as Map<String, dynamic>;
    return Doctor.fromJson(json);
  }

  Future<Doctor> update(
    String id, {
    required String name,
    required String specialty,
    String? bio,
  }) async {
    final json = await _client.patch('/doctors/$id', body: {
      'name': name,
      'specialty': specialty,
      'bio': bio,
    }) as Map<String, dynamic>;
    return Doctor.fromJson(json);
  }

  Future<Doctor> uploadPhoto(String id, {required List<int> fileBytes, required String fileName}) async {
    final json = await _client.uploadFile(
      '/doctors/$id/photo',
      fileBytes: fileBytes,
      fileName: fileName,
    ) as Map<String, dynamic>;
    return Doctor.fromJson(json);
  }
}
