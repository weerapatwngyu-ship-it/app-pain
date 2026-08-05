import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../data/doctor_repository.dart';
import '../domain/entities/doctor.dart';

/// Add/edit form for a doctor profile — `doctor` null means create mode.
class DoctorFormScreen extends StatefulWidget {
  const DoctorFormScreen({
    super.key,
    required this.repository,
    this.doctor,
  });

  final DoctorRepository repository;
  final Doctor? doctor;

  @override
  State<DoctorFormScreen> createState() => _DoctorFormScreenState();
}

class _DoctorFormScreenState extends State<DoctorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _specialtyController;
  late final TextEditingController _bioController;

  XFile? _pickedPhoto;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.doctor != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.doctor?.name ?? '');
    _specialtyController = TextEditingController(text: widget.doctor?.specialty ?? '');
    _bioController = TextEditingController(text: widget.doctor?.bio ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specialtyController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('ถ่ายรูป'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('เลือกจากคลังภาพ'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1024, imageQuality: 85);
    if (picked == null) return;
    setState(() => _pickedPhoto = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      Doctor doctor;
      if (_isEditing) {
        doctor = await widget.repository.update(
          widget.doctor!.id,
          name: _nameController.text.trim(),
          specialty: _specialtyController.text.trim(),
          bio: _bioController.text.trim(),
        );
      } else {
        doctor = await widget.repository.create(
          name: _nameController.text.trim(),
          specialty: _specialtyController.text.trim(),
          bio: _bioController.text.trim(),
        );
      }

      if (_pickedPhoto != null) {
        final bytes = await _pickedPhoto!.readAsBytes();
        doctor = await widget.repository.uploadPhoto(
          doctor.id,
          fileBytes: bytes,
          fileName: _pickedPhoto!.name,
        );
      }

      if (mounted) Navigator.of(context).pop(doctor);
    } catch (_) {
      if (mounted) setState(() => _error = 'บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingPhotoUrl =
        widget.doctor?.photoUrl != null ? widget.doctor!.photoUrl! : null;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'แก้ไขข้อมูลแพทย์' : 'เพิ่มโปรไฟล์แพทย์')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: OnboardingColors.teal,
                      backgroundImage: _pickedPhoto != null
                          ? null
                          : (existingPhotoUrl != null ? NetworkImage(existingPhotoUrl) : null),
                      child: _pickedPhoto == null && existingPhotoUrl == null
                          ? const Icon(Icons.medical_services_outlined, color: Colors.white, size: 40)
                          : null,
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: OnboardingColors.teal,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'ชื่อแพทย์*'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อแพทย์' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _specialtyController,
              decoration: const InputDecoration(labelText: 'ความเชี่ยวชาญ/แผนก*'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกความเชี่ยวชาญ' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(labelText: 'ข้อมูลเพิ่มเติม (ไม่บังคับ)'),
              maxLines: 4,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            OnboardingPrimaryButton(
              label: _isEditing ? 'บันทึกการแก้ไข' : 'เพิ่มโปรไฟล์แพทย์',
              onPressed: _saving ? null : _save,
              loading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}
