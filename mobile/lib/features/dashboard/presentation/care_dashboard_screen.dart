import 'package:flutter/material.dart';

/// Placeholder for the caregiver/provider Care Dashboard (docs/architecture.md
/// §3 module 5): patient list, adherence + symptom trend summary, and open
/// alerts in one view. Wire up once the patient-list and trends endpoints
/// have client-side repositories.
class CareDashboardScreen extends StatelessWidget {
  const CareDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('แดชบอร์ดผู้ดูแล')),
      body: const Center(child: Text('เร็ว ๆ นี้ — Phase 2')),
    );
  }
}
