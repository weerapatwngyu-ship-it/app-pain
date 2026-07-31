import 'package:flutter/material.dart';

import '../../domain/auth_repository.dart';
import '../../domain/entities/user.dart';
import 'onboarding_theme.dart';
import 'set_pin_screen.dart';

const _healthConsentText =
    'MedTrack ขอความยินยอมในการเก็บ ใช้ และเปิดเผยข้อมูลสุขภาพของท่าน (เช่น '
    'ตารางยา บันทึกการกินยา และบันทึกอาการ) เพื่อให้ท่านได้รับการดูแลที่ต่อเนื่องและ '
    'เหมาะสม หากท่านไม่ให้ความยินยอม หรือถอนความยินยอมในภายหลัง MedTrack อาจไม่สามารถ '
    'ให้บริการติดตามยาและอาการแก่ท่านได้';

const _marketingConsentText =
    'ท่านยินยอมให้ MedTrack จัดเก็บและใช้ข้อมูลของท่านเพื่อแจ้งข่าวสาร โปรโมชัน '
    'และสิทธิประโยชน์ต่าง ๆ ที่เกี่ยวข้องกับสุขภาพ ท่านสามารถยกเลิกความยินยอมนี้ได้ทุกเมื่อ '
    'โดยไม่กระทบต่อการใช้งานฟีเจอร์หลักของแอป';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({
    super.key,
    required this.authRepository,
    required this.phone,
    required this.onAuthenticated,
  });

  final AuthRepository authRepository;
  final String phone;
  final ValueChanged<AppUser> onAuthenticated;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool? _consentHealth;
  bool? _consentMarketing;

  bool get _canContinue => _consentHealth != null && _consentMarketing != null;

  void _continue() {
    if (_consentHealth == false) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('จำเป็นต้องให้ความยินยอม'),
          content: const Text(
            'MedTrack ต้องใช้ข้อมูลสุขภาพของท่านในการติดตามยาและอาการ '
            'หากไม่ยินยอมจะไม่สามารถใช้งานแอปต่อได้',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('กลับไปพิจารณาอีกครั้ง'),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SetPinScreen(
          authRepository: widget.authRepository,
          phone: widget.phone,
          consentHealth: _consentHealth!,
          consentMarketing: _consentMarketing!,
          onAuthenticated: widget.onAuthenticated,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OnboardingHeader(
                icon: Icons.arrow_back,
                onIconTap: () => Navigator.of(context).pop(),
                title: 'การขออนุญาตเข้าถึงข้อมูลส่วนตัว',
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    const Text(
                      'Consent for Health Information (จำเป็น)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    _ConsentBox(text: _healthConsentText),
                    const SizedBox(height: 12),
                    _ConsentButtons(
                      value: _consentHealth,
                      onChanged: (value) => setState(() => _consentHealth = value),
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: OnboardingColors.border),
                    const SizedBox(height: 12),
                    const Text(
                      'Consent for Marketing Purposes',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    _ConsentBox(text: _marketingConsentText),
                    const SizedBox(height: 12),
                    _ConsentButtons(
                      value: _consentMarketing,
                      onChanged: (value) => setState(() => _consentMarketing = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OnboardingPrimaryButton(
                label: 'ถัดไป',
                onPressed: _canContinue ? _continue : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentBox extends StatelessWidget {
  const _ConsentBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: OnboardingColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: Text(text, style: const TextStyle(color: OnboardingColors.textMuted, height: 1.5)),
      ),
    );
  }
}

class _ConsentButtons extends StatelessWidget {
  const _ConsentButtons({required this.value, required this.onChanged});

  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ChoiceButton(
            label: 'ยินยอม',
            selected: value == true,
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ChoiceButton(
            label: 'ไม่ยินยอม',
            selected: value == false,
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? OnboardingColors.teal.withOpacity(0.12) : null,
        side: BorderSide(color: selected ? OnboardingColors.teal : OnboardingColors.border),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? OnboardingColors.teal : OnboardingColors.text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
