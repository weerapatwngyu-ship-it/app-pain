import '../../../core/i18n/app_locale.dart';

/// One heading with its paragraphs.
class LegalSection {
  const LegalSection({required this.heading, required this.paragraphs});

  final String heading;
  final List<String> paragraphs;
}

class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String intro;
  final List<LegalSection> sections;
}

/// Written from what the code actually does — the tables it stores, the
/// policies that decide who may read them, and where a request leaves the
/// phone. A policy that describes a different app is worse than none, so
/// anything changed in the schema or in the pharmacy search belongs here too.
///
/// It is a plain-language disclosure, not a lawyer's document. Have it
/// reviewed before the app is put in front of real patients.
LegalDocument get privacyPolicy => LegalDocument(
      title: t('นโยบายความเป็นส่วนตัว', 'Privacy policy'),
      intro: t(
        'MediGo เก็บข้อมูลสุขภาพเพื่อใช้ติดตามการรักษาของคุณเท่านั้น '
            'หน้านี้อธิบายว่าเก็บอะไร เก็บไว้ที่ไหน ใครเห็นได้ '
            'และคุณควบคุมอะไรได้',
        'MediGo stores health information for one purpose: following your own '
            'treatment. This page says what is stored, where it is kept, who '
            'can read it, and what you control.',
      ),
      sections: [
        LegalSection(
          heading: t('ข้อมูลที่เก็บ', 'What is stored'),
          paragraphs: [
            t(
              'ข้อมูลบัญชี: ชื่อ นามสกุล วันเกิด เพศ อีเมล เบอร์โทรศัพท์ '
                  'และรูปโปรไฟล์ถ้าคุณใส่ไว้',
              'Account details: first and last name, date of birth, gender, '
                  'email, phone number, and a profile photo if you add one.',
            ),
            t(
              'ข้อมูลสุขภาพที่คุณกรอกเอง: โรคประจำตัว ยาที่แพ้ อาหารที่แพ้ '
                  'กรุ๊ปเลือด น้ำหนัก ส่วนสูง',
              'Health details you enter yourself: ongoing conditions, drug '
                  'allergies, food allergies, blood type, weight and height.',
            ),
            t(
              'ยาที่แพทย์สั่งให้คุณ พร้อมเวลาที่ต้องกิน และบันทึกว่าแต่ละมื้อ '
                  'คุณกินแล้วหรือข้าม',
              'Medication your doctor prescribes, the times it is due, and '
                  'whether each dose was taken or skipped.',
            ),
            t(
              'บันทึกอาการที่คุณจดไว้ และข้อความที่คุยกับแพทย์หรือกับผู้ป่วยคนอื่น',
              'Symptom entries you record, and messages with doctors or with '
                  'other patients.',
            ),
          ],
        ),
        LegalSection(
          heading: t('เก็บไว้ที่ไหน', 'Where it is kept'),
          paragraphs: [
            t(
              'ข้อมูลอยู่บน Supabase (ฐานข้อมูล PostgreSQL และที่เก็บไฟล์) '
                  'ทุกตารางเปิด Row Level Security ไว้ หมายความว่าแต่ละแถว '
                  'อ่านได้เฉพาะบัญชีที่กฎอนุญาต ไม่ใช่ทุกคนที่เข้าระบบได้',
              'Data lives on Supabase (a PostgreSQL database and file '
                  'storage). Row Level Security is enabled on every table, so '
                  'each row is readable only by the accounts the rules allow — '
                  'not by anyone who is merely signed in.',
            ),
            t(
              'บนเครื่องของคุณเก็บไว้เท่าที่จำเป็น: ภาษาที่เลือก '
                  'รายการเตือนกินยา และมื้อที่คุณกดยืนยันไว้ตอนออฟไลน์ '
                  'จนกว่าจะส่งขึ้นเซิร์ฟเวอร์ได้',
              'On your phone only what is needed: your language choice, your '
                  'reminders, and doses you confirmed while offline until they '
                  'reach the server.',
            ),
          ],
        ),
        LegalSection(
          heading: t('ใครเห็นข้อมูลของคุณ', 'Who can see it'),
          paragraphs: [
            t(
              'คุณเอง',
              'You.',
            ),
            t(
              'แพทย์ที่ดูแลคุณ — สิทธิ์นี้เกิดขึ้นเมื่อมีการเริ่มสนทนากันในแอป '
                  'และคุณเพิกถอนได้เองที่ ตั้งค่า > ตั้งค่าความเป็นส่วนตัว',
              'Doctors caring for you — access begins when a conversation is '
                  'started in the app, and you can withdraw it yourself under '
                  'Settings > Privacy settings.',
            ),
            t(
              'ผู้ดูแลระบบ ซึ่งจำเป็นต่อการอนุมัติบัญชีแพทย์และแก้ปัญหาการใช้งาน',
              'Administrators, which is required to approve doctor accounts '
                  'and to resolve problems.',
            ),
            t(
              'ผู้ป่วยคนอื่นเห็นได้เพียง "ชื่อที่แสดง" ของคุณ และเห็นเฉพาะเมื่อ '
                  'คุณเปิดฟีเจอร์คุยกับผู้ป่วยด้วยกันเท่านั้น '
                  'ยา อาการ และประวัติของคุณไม่ถูกแชร์ในนั้นเลย',
              'Other patients see only your display name, and only if you turn '
                  'on patient-to-patient chat. Your medication, symptoms and '
                  'record are never shared there.',
            ),
          ],
        ),
        LegalSection(
          heading: t('ตำแหน่งที่อยู่', 'Location'),
          paragraphs: [
            t(
              'ใช้ตำแหน่งเฉพาะตอนคุณกดค้นหาร้านยาหรือคลินิกใกล้ตัว '
                  'พิกัดถูกส่งไปที่ OpenStreetMap เพื่อค้นหาในรอบนั้น '
                  'แอปไม่เก็บพิกัดของคุณไว้',
              'Your location is used only when you search for nearby '
                  'pharmacies or clinics. The coordinates go to OpenStreetMap '
                  'for that search. The app does not store them.',
            ),
          ],
        ),
        LegalSection(
          heading: t('สิ่งที่คุณควบคุมได้', 'What you control'),
          paragraphs: [
            t(
              'แก้หรือล้างข้อมูลสุขภาพของคุณได้ที่ โปรไฟล์ > ข้อมูลส่วนตัว',
              'Edit or clear your health details under Profile > Personal '
                  'details.',
            ),
            t(
              'ปิดการคุยกับผู้ป่วยด้วยกันได้ทุกเมื่อ เมื่อปิดแล้วไม่มีใครเห็นชื่อคุณ',
              'Turn patient-to-patient chat off at any time; once off, nobody '
                  'can see your name.',
            ),
            t(
              'เพิกถอนสิทธิ์การเข้าถึงของแพทย์แต่ละคนได้เอง',
              'Withdraw any individual doctor’s access yourself.',
            ),
            t(
              'ต้องการลบบัญชีและข้อมูลทั้งหมด ติดต่อผู้ดูแลระบบ',
              'To delete your account and everything in it, contact an '
                  'administrator.',
            ),
          ],
        ),
        LegalSection(
          heading: t('สิ่งที่เราไม่ทำ', 'What we do not do'),
          paragraphs: [
            t(
              'ไม่ขายข้อมูลของคุณ ไม่นำไปใช้โฆษณา และไม่ส่งต่อให้บุคคลอื่น '
                  'นอกเหนือจากที่ระบุไว้ข้างต้น',
              'We do not sell your data, use it for advertising, or pass it to '
                  'anyone beyond those listed above.',
            ),
          ],
        ),
      ],
    );

LegalDocument get termsOfUse => LegalDocument(
      title: t('ข้อตกลงและเงื่อนไข', 'Terms and conditions'),
      intro: t(
        'MediGo เป็นเครื่องมือช่วยให้คุณติดตามการรักษาของตัวเอง '
            'ไม่ใช่เครื่องมือวินิจฉัยโรค และไม่ใช้แทนการพบแพทย์',
        'MediGo is a tool to help you follow your own treatment. It does not '
            'diagnose anything and does not replace seeing a doctor.',
      ),
      sections: [
        LegalSection(
          heading: t('กรณีฉุกเฉิน', 'Emergencies'),
          paragraphs: [
            t(
              'อย่าใช้แอปนี้ในกรณีฉุกเฉิน ข้อความในแอปไม่มีใครเฝ้าตลอดเวลา '
                  'หากมีอาการรุนแรง เช่น เจ็บแน่นหน้าอก หายใจไม่ออก '
                  'แขนขาอ่อนแรง พูดไม่ชัด ให้โทร 1669 ทันที',
              'Do not use this app in an emergency. Messages here are not '
                  'monitored around the clock. For severe symptoms — chest '
                  'pain, trouble breathing, weakness in an arm or leg, slurred '
                  'speech — call 1669 immediately.',
            ),
          ],
        ),
        LegalSection(
          heading: t('การเตือนกินยา', 'Medication reminders'),
          paragraphs: [
            t(
              'การเตือนทำงานบนโทรศัพท์ของคุณ จึงขึ้นอยู่กับสิทธิ์การแจ้งเตือน '
                  'การประหยัดแบตเตอรี่ และเครื่องต้องเปิดอยู่ '
                  'อย่าใช้แอปเป็นเครื่องเตือนอย่างเดียวสำหรับยาที่ขาดไม่ได้',
              'Reminders run on your phone, so they depend on notification '
                  'permissions, battery saving, and the phone being on. Do not '
                  'rely on the app alone for medication you cannot miss.',
            ),
            t(
              'ยาและเวลาที่แสดงมาจากที่แพทย์สั่งไว้ในระบบ หากเห็นว่าไม่ถูกต้อง '
                  'ให้ถามแพทย์ก่อนกินยา',
              'The medication and times shown come from what your doctor '
                  'entered. If something looks wrong, ask them before taking '
                  'it.',
            ),
          ],
        ),
        LegalSection(
          heading: t('ข้อมูลในคลินิกออนไลน์', 'Information in the online clinic'),
          paragraphs: [
            t(
              'บทความในคลินิกออนไลน์เป็นความรู้ทั่วไป ไม่ใช่คำแนะนำสำหรับ '
                  'อาการของคุณโดยเฉพาะ อาการเดียวกันเกิดได้จากหลายสาเหตุ',
              'The articles in the online clinic are general information, not '
                  'advice about your particular case. The same symptom can '
                  'have many causes.',
            ),
            t(
              'ข้อความในห้องคุยกับผู้ป่วยด้วยกันเป็นความเห็นของผู้ป่วยเอง '
                  'ไม่ใช่คำแนะนำทางการแพทย์',
              'Messages in patient-to-patient chat are the opinions of other '
                  'patients, not medical advice.',
            ),
          ],
        ),
        LegalSection(
          heading: t('บัญชีของคุณ', 'Your account'),
          paragraphs: [
            t(
              'ข้อมูลสุขภาพที่กรอกไว้จะถูกใช้ในการดูแลคุณ '
                  'การกรอกไม่ครบหรือไม่ถูกต้อง เช่น ไม่ระบุยาที่แพ้ '
                  'อาจทำให้การดูแลคลาดเคลื่อน',
              'The health details you enter are used in caring for you. '
                  'Leaving them out or entering them wrongly — an unrecorded '
                  'drug allergy, for instance — can lead care astray.',
            ),
            t(
              'ดูแลบัญชีของคุณให้ปลอดภัย อย่าให้ผู้อื่นเข้าใช้ '
                  'สิ่งที่เกิดขึ้นภายใต้บัญชีของคุณถือเป็นความรับผิดชอบของคุณ',
              'Keep your account secure and do not let others use it. What '
                  'happens under your account is your responsibility.',
            ),
          ],
        ),
        LegalSection(
          heading: t('การเปลี่ยนแปลง', 'Changes'),
          paragraphs: [
            t(
              'แอปอาจมีการปรับปรุง เปลี่ยนแปลง หรือหยุดให้บริการบางช่วง '
                  'และเงื่อนไขนี้อาจถูกแก้ไขได้',
              'The app may be improved, changed, or unavailable at times, and '
                  'these terms may be updated.',
            ),
          ],
        ),
      ],
    );
