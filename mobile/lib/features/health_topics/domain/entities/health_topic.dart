import 'package:flutter/material.dart';
import '../../../../core/i18n/app_locale.dart';

/// One entry in the online-clinic catalogue: a health subject a patient can
/// read about and then ask staff about.
///
/// Deliberately separate from `SymptomCategory`, which exists to tag a daily
/// symptom log. These are subjects ("เบาหวาน", "เลิกบุหรี่"), not things that
/// happened today, and mixing them would put "เลิกบุหรี่" in a list whose job
/// is answering "what hurt today?".
class HealthTopic {
  const HealthTopic({
    required this.key,
    required this.label,
    required this.icon,
    required this.summary,
    required this.commonSigns,
    required this.seeDoctorWhen,
    required this.selfCare,
    this.specialtyKeywords = const [],
  });

  final String key;
  final String label;
  final IconData icon;

  /// One or two lines under the title.
  final String summary;

  final List<String> commonSigns;

  /// Symptoms that mean "stop reading and get seen" — listed on every topic
  /// because the app must never read as a substitute for being examined.
  final List<String> seeDoctorWhen;

  final List<String> selfCare;

  /// Matched (case-insensitively, as substrings) against `doctors.specialty`
  /// to suggest who to ask. No match just means the full directory is shown.
  final List<String> specialtyKeywords;
}

/// Shown on every topic detail screen. The app hands out general health
/// information; it does not examine anyone, so it must not read as a diagnosis.
String get healthTopicDisclaimer => t(
      'ข้อมูลนี้เป็นความรู้ทั่วไปเพื่อประกอบความเข้าใจ ไม่ใช่การวินิจฉัยโรค '
          'อาการเดียวกันอาจเกิดได้จากหลายสาเหตุ หากไม่แน่ใจหรืออาการไม่ดีขึ้น '
          'ควรปรึกษาแพทย์หรือเภสัชกรโดยตรง',
      'This is general information to help you understand a subject, not a '
          'diagnosis. The same symptom can have many causes. If you are unsure '
          'or things are not improving, speak to a doctor or pharmacist.',
    );

/// The catalogue, rebuilt when the language changes and cached in between.
///
/// It cannot be a const list any more — every string in it is translated, and
/// a const list would freeze whichever language happened to be current when
/// the library was first touched. A bare getter would work too, but this is
/// indexed from inside list builders, where rebuilding all seventeen entries
/// for every tile is real work done many times a frame.
///
/// The English is a translation of the Thai beside it, not separate advice.
/// specialtyKeywords stay Thai on purpose — they are matched against
/// `doctors.specialty`, which the directory stores in Thai.
List<HealthTopic> get healthTopics {
  final locale = LocaleController.instance.locale;
  if (_topicsLocale != locale || _topics == null) {
    _topics = _buildHealthTopics();
    _topicsLocale = locale;
  }
  return _topics!;
}

List<HealthTopic>? _topics;
AppLocale? _topicsLocale;

List<HealthTopic> _buildHealthTopics() => <HealthTopic>[
  HealthTopic(
    key: 'quit_smoking',
    label: t('เลิกบุหรี่', 'Quitting smoking'),
    icon: Icons.smoke_free,
    summary: t('การเลิกบุหรี่ลดความเสี่ยงโรคหัวใจและมะเร็งได้ตั้งแต่ปีแรกที่หยุด', 'Quitting cuts heart-disease and cancer risk from the first year'),
    commonSigns: [
      t('อยากสูบมากในช่วง 1–2 สัปดาห์แรกหลังหยุด', 'Strong cravings in the first 1–2 weeks after stopping'),
      t('หงุดหงิด นอนไม่หลับ สมาธิสั้นลงชั่วคราว', 'Irritability, poor sleep, briefly worse concentration'),
      t('ไอมีเสมหะมากขึ้นช่วงแรก เพราะปอดเริ่มขับสิ่งตกค้าง', 'More coughing with phlegm at first, as the lungs start clearing out'),
    ],
    seeDoctorWhen: [
      t('ไอเป็นเลือด หรือไอเรื้อรังเกิน 3 สัปดาห์', 'Coughing blood, or a cough lasting over 3 weeks'),
      t('เจ็บหน้าอก เหนื่อยง่ายผิดปกติ', 'Chest pain, or unusual breathlessness'),
      t('เคยพยายามเลิกเองหลายครั้งแล้วไม่สำเร็จ — มียาและคลินิกช่วยได้', 'Several attempts to quit alone have failed — medication and clinics can help'),
    ],
    selfCare: [
      t('กำหนดวันเลิกให้ชัดเจน แล้วบอกคนรอบตัวให้ช่วยสนับสนุน', 'Set a firm quit date and tell people around you so they can support you'),
      t('เลี่ยงสถานการณ์ที่เคยกระตุ้นให้สูบ เช่น กาแฟ วงเหล้า', 'Avoid situations that used to trigger smoking — coffee, drinking with friends'),
      t('ดื่มน้ำ เคี้ยวหมากฝรั่ง หรือหายใจลึกๆ เมื่อรู้สึกอยากสูบ', 'Drink water, chew gum or breathe deeply when a craving hits'),
      t('สายด่วนเลิกบุหรี่ 1600 ให้คำปรึกษาฟรี', 'The quit-smoking helpline 1600 gives free advice'),
    ],
    specialtyKeywords: [t('ปอด', 'Lungs'), 'อายุรกรรม', 'เวชศาสตร์ครอบครัว'],
  ),
  HealthTopic(
    key: 'kidney',
    label: t('ไต', 'Kidneys'),
    icon: Icons.water_drop_outlined,
    summary: t('ไตกรองของเสียออกจากเลือด โรคไตระยะแรกมักไม่มีอาการจนตรวจเจอ', 'Kidneys filter waste from blood. Early kidney disease usually has no symptoms until it is tested for.'),
    commonSigns: [
      t('บวมที่เท้า ข้อเท้า หรือรอบดวงตา', 'Swelling in the feet, ankles or around the eyes'),
      t('ปัสสาวะเป็นฟองมาก สีผิดปกติ หรือปริมาณเปลี่ยนไป', 'Very foamy urine, an odd colour, or a change in how much'),
      t('อ่อนเพลีย เบื่ออาหาร คันตามตัว', 'Tiredness, loss of appetite, itchy skin'),
    ],
    seeDoctorWhen: [
      t('ปัสสาวะเป็นเลือด หรือปัสสาวะไม่ออก', 'Blood in the urine, or unable to pass urine'),
      t('บวมมากขึ้นเร็ว ร่วมกับเหนื่อยหอบ', 'Swelling worsening quickly along with breathlessness'),
      t('เป็นเบาหวานหรือความดันสูง ควรตรวจการทำงานของไตทุกปี', 'With diabetes or high blood pressure, have kidney function checked yearly'),
    ],
    selfCare: [
      t('ลดอาหารรสเค็ม ของหมักดอง และอาหารแปรรูป', 'Cut back on salty, pickled and processed food'),
      t('ดื่มน้ำให้เพียงพอ เว้นแต่แพทย์สั่งจำกัดน้ำ', 'Drink enough water, unless your doctor has restricted fluids'),
      t('เลี่ยงยาแก้ปวดกลุ่ม NSAIDs ติดต่อกันนานโดยไม่ปรึกษาแพทย์', 'Avoid long runs of NSAID painkillers without asking a doctor'),
      t('คุมความดันและน้ำตาลให้อยู่ในเกณฑ์', 'Keep blood pressure and blood sugar in range'),
    ],
    specialtyKeywords: [t('ไต', 'Kidneys'), 'อายุรกรรม'],
  ),
  HealthTopic(
    key: 'digestive',
    label: t('ทางเดินอาหาร', 'Digestion'),
    icon: Icons.lunch_dining_outlined,
    summary: t('ตั้งแต่หลอดอาหารถึงลำไส้ — อาการปวดท้องมีได้หลายสาเหตุมาก', 'From the oesophagus to the bowel — stomach pain has many possible causes'),
    commonSigns: [
      t('ปวดท้อง จุกแน่น ท้องอืดหลังอาหาร', 'Stomach pain, fullness or bloating after eating'),
      t('แสบร้อนกลางอก เรอเปรี้ยว', 'Heartburn, acid reflux'),
      t('ท้องเสียหรือท้องผูกสลับกัน', 'Diarrhoea and constipation alternating'),
    ],
    seeDoctorWhen: [
      t('อาเจียนเป็นเลือด หรือถ่ายดำเหมือนยางมะตอย', 'Vomiting blood, or black tarry stools'),
      t('น้ำหนักลดโดยไม่ตั้งใจ กลืนลำบาก', 'Unintended weight loss, difficulty swallowing'),
      t('ปวดท้องรุนแรงเฉียบพลัน หรือปวดจนนอนไม่ได้', 'Sudden severe stomach pain, or pain that stops you sleeping'),
    ],
    selfCare: [
      t('กินอาหารตรงเวลา เคี้ยวช้าๆ เลี่ยงกินแล้วนอนทันที', 'Eat at regular times, chew slowly, do not lie down straight after eating'),
      t('ลดของทอด ของมัน เผ็ดจัด กาแฟ และแอลกอฮอล์', 'Cut down fried, fatty and very spicy food, coffee and alcohol'),
      t('กินผักผลไม้และดื่มน้ำให้พอ ช่วยเรื่องท้องผูก', 'Fruit, vegetables and enough water help with constipation'),
    ],
    specialtyKeywords: [t('ทางเดินอาหาร', 'Digestion'), 'อายุรกรรม'],
  ),
  HealthTopic(
    key: 'lung',
    label: t('ปอด', 'Lungs'),
    icon: Icons.air,
    summary: t('ไอเรื้อรังและเหนื่อยง่ายเป็นสัญญาณที่ไม่ควรปล่อยผ่าน', 'A lasting cough and getting out of breath easily should not be ignored'),
    commonSigns: [
      t('ไอเรื้อรัง มีเสมหะ หรือไอตอนกลางคืน', 'A lasting cough, phlegm, or coughing at night'),
      t('หายใจมีเสียงหวีด แน่นหน้าอก', 'Wheezing, chest tightness'),
      t('เหนื่อยง่ายกว่าเดิมเมื่อออกแรงเท่าเดิม', 'Getting breathless sooner than you used to for the same effort'),
    ],
    seeDoctorWhen: [
      t('หายใจลำบากจนพูดไม่เป็นประโยค หรือปากเล็บเขียว', 'Too breathless to finish a sentence, or blue lips or nails'),
      t('ไอเป็นเลือด', 'Coughing blood'),
      t('ไข้สูงร่วมกับหอบเหนื่อย', 'High fever together with breathlessness'),
    ],
    selfCare: [
      t('เลี่ยงควันบุหรี่ ควันธูป และฝุ่น PM2.5', 'Avoid cigarette smoke, incense smoke and PM2.5 dust'),
      t('ใส่หน้ากากเมื่อค่าฝุ่นสูง', 'Wear a mask when dust levels are high'),
      t('ฉีดวัคซีนไข้หวัดใหญ่ตามคำแนะนำของแพทย์', 'Have the flu vaccine as your doctor advises'),
    ],
    specialtyKeywords: [t('ปอด', 'Lungs'), 'อายุรกรรม'],
  ),
  HealthTopic(
    key: 'allergy',
    label: t('ภูมิแพ้', 'Allergies'),
    icon: Icons.grass_outlined,
    summary: t('ร่างกายตอบสนองไวเกินต่อสิ่งที่ปกติไม่เป็นอันตราย', 'The body reacting too strongly to something normally harmless'),
    commonSigns: [
      t('จาม คัดจมูก น้ำมูกใส โดยเฉพาะตอนเช้า', 'Sneezing, blocked nose, clear runny nose, especially in the morning'),
      t('คันตา คันจมูก คันคอ', 'Itchy eyes, nose and throat'),
      t('ผื่นลมพิษ ผิวแห้งคัน', 'Hives, dry itchy skin'),
    ],
    seeDoctorWhen: [
      t('หายใจไม่ออก หน้าบวม ปากบวม หลังกินอาหารหรือยา — ฉุกเฉิน ไปโรงพยาบาลทันที', 'Trouble breathing, swollen face or lips after food or medicine — emergency, go to hospital now'),
      t('ต้องใช้ยาแก้แพ้แทบทุกวันติดต่อกันนาน', 'Needing antihistamines almost daily for a long stretch'),
      t('ผื่นลามทั้งตัวหรือมีไข้ร่วมด้วย', 'A rash spreading over the body, or with a fever'),
    ],
    selfCare: [
      t('หาสิ่งกระตุ้นให้เจอ เช่น ไรฝุ่น ขนสัตว์ เกสร อาหารบางชนิด', 'Work out the trigger — dust mites, animal hair, pollen, certain foods'),
      t('ซักผ้าปูที่นอนด้วยน้ำร้อนทุกสัปดาห์ ลดพรมและตุ๊กตาผ้า', 'Wash bedding in hot water weekly; cut down on rugs and soft toys'),
      t('ล้างจมูกด้วยน้ำเกลือช่วยลดอาการคัดจมูกได้', 'A saline nasal rinse helps with congestion'),
    ],
    specialtyKeywords: [t('ภูมิแพ้', 'Allergies'), 'ผิวหนัง', 'หู คอ จมูก'],
  ),
  HealthTopic(
    key: 'hypertension',
    label: t('ความดัน', 'Blood pressure'),
    icon: Icons.favorite_border,
    summary: t('ความดันสูงมักไม่มีอาการ แต่ทำลายหัวใจ ไต และสมองอย่างเงียบๆ', 'High blood pressure usually has no symptoms, but quietly damages the heart, kidneys and brain'),
    commonSigns: [
      t('ส่วนใหญ่ไม่มีอาการเลย — รู้ได้จากการวัดเท่านั้น', 'Usually no symptoms at all — only a reading tells you'),
      t('บางรายปวดหัวตุบๆ ท้ายทอย โดยเฉพาะตอนเช้า', 'Some people get a throbbing headache at the back of the head, especially in the morning'),
      t('เวียนหัว ใจสั่น เลือดกำเดาไหลบ่อย', 'Dizziness, palpitations, frequent nosebleeds'),
    ],
    seeDoctorWhen: [
      t('เจ็บแน่นหน้าอก แขนขาอ่อนแรง พูดไม่ชัด ปากเบี้ยว — ฉุกเฉิน โทร 1669 ทันที', 'Chest tightness, weak limbs, slurred speech, drooping face — emergency, call 1669 now'),
      t('วัดความดันได้สูงกว่า 180/110 ซ้ำหลายครั้ง', 'Readings repeatedly above 180/110'),
      t('ปวดหัวรุนแรงผิดปกติร่วมกับตาพร่า', 'An unusually severe headache with blurred vision'),
    ],
    selfCare: [
      t('วัดความดันที่บ้านสม่ำเสมอ จดบันทึกไว้ให้แพทย์ดู', 'Measure at home regularly and note the readings for your doctor'),
      t('ลดเค็ม — เป้าหมายเกลือไม่เกินวันละ 1 ช้อนชา', 'Less salt — aim for under a teaspoon a day'),
      t('ออกกำลังกายแบบแอโรบิก 150 นาทีต่อสัปดาห์', '150 minutes of aerobic exercise a week'),
      t('กินยาตามแพทย์สั่งต่อเนื่อง ห้ามหยุดเองเมื่อรู้สึกดีขึ้น', 'Keep taking prescribed medicine; do not stop on your own because you feel better'),
    ],
    specialtyKeywords: ['หัวใจ', 'อายุรกรรม'],
  ),
  HealthTopic(
    key: 'elderly',
    label: t('สูงอายุ', 'Older age'),
    icon: Icons.elderly_outlined,
    summary: t('ดูแลผู้สูงวัย — เรื่องล้ม ยาหลายชนิด และความจำ', 'Caring for older people — falls, multiple medicines, and memory'),
    commonSigns: [
      t('เดินช้าลง ทรงตัวไม่ดี เคยลื่นล้ม', 'Walking more slowly, poor balance, past falls'),
      t('กินยาหลายชนิดจากหลายแพทย์', 'Taking several medicines prescribed by different doctors'),
      t('หลงลืมบ่อยขึ้นจนกระทบชีวิตประจำวัน', 'Forgetfulness often enough to affect daily life'),
    ],
    seeDoctorWhen: [
      t('ล้มแล้วลุกไม่ได้ หรือล้มศีรษะกระแทก', 'A fall they cannot get up from, or a fall hitting the head'),
      t('สับสนเฉียบพลัน จำคนใกล้ตัวไม่ได้', 'Sudden confusion, not recognising close family'),
      t('น้ำหนักลดเร็วโดยไม่ทราบสาเหตุ', 'Rapid unexplained weight loss'),
    ],
    selfCare: [
      t('จัดบ้านให้ปลอดภัย — ราวจับในห้องน้ำ ไฟสว่าง ไม่มีของเกะกะพื้น', 'Make the home safe — grab rails in the bathroom, good lighting, nothing to trip over'),
      t('รวบรวมยาทั้งหมดให้แพทย์หรือเภสัชกรทบทวนปีละครั้ง', 'Take every medicine to a doctor or pharmacist for review once a year'),
      t('ออกกำลังกายเบาๆ ฝึกการทรงตัว และรับแดดยามเช้า', 'Gentle exercise, balance practice, and morning sunlight'),
    ],
    specialtyKeywords: ['ผู้สูงอายุ', 'เวชศาสตร์ครอบครัว', 'อายุรกรรม'],
  ),
  HealthTopic(
    key: 'diabetes',
    label: t('เบาหวาน', 'Diabetes'),
    icon: Icons.bloodtype_outlined,
    summary: t('ระดับน้ำตาลในเลือดสูงเรื้อรัง คุมได้ด้วยอาหาร ยา และการติดตาม', 'Persistently high blood sugar, managed with diet, medication and monitoring'),
    commonSigns: [
      t('ปัสสาวะบ่อย โดยเฉพาะตอนกลางคืน', 'Passing urine often, especially at night'),
      t('หิวน้ำบ่อย ปากแห้ง', 'Constant thirst, dry mouth'),
      t('น้ำหนักลดทั้งที่กินปกติ แผลหายช้า ตาพร่า', 'Losing weight while eating normally, slow-healing wounds, blurred vision'),
    ],
    seeDoctorWhen: [
      t('มือสั่น เหงื่อแตก ใจสั่น สับสน — อาจน้ำตาลต่ำ ให้กินน้ำหวานทันทีแล้วพบแพทย์', 'Shaking, sweating, palpitations, confusion — possibly low blood sugar. Take something sweet at once, then see a doctor.'),
      t('หายใจหอบลึก ลมหายใจมีกลิ่นผลไม้ ซึม — ฉุกเฉิน', 'Deep laboured breathing, fruity breath, drowsiness — emergency'),
      t('มีแผลที่เท้าที่ไม่หายภายในไม่กี่วัน', 'A foot wound that has not healed within a few days'),
    ],
    selfCare: [
      t('ตรวจน้ำตาลตามที่แพทย์แนะนำ และจดค่าไว้', 'Test blood sugar as your doctor advises and write the numbers down'),
      t('ลดข้าวขาว น้ำหวาน ขนม เพิ่มผักและโปรตีน', 'Less white rice, sweet drinks and snacks; more vegetables and protein'),
      t('ตรวจเท้าตัวเองทุกวัน หารอยแผลหรือรอยแดง', 'Check your feet daily for cuts or red patches'),
      t('กินยา/ฉีดอินซูลินให้ตรงเวลา', 'Take tablets or inject insulin on time'),
    ],
    specialtyKeywords: [t('เบาหวาน', 'Diabetes'), 'ต่อมไร้ท่อ', 'อายุรกรรม'],
  ),
  HealthTopic(
    key: 'epilepsy',
    label: t('ลมชัก', 'Epilepsy'),
    icon: Icons.bolt_outlined,
    summary: t('ภาวะที่สมองปล่อยคลื่นไฟฟ้าผิดปกติเป็นครั้งคราว', 'A condition where the brain occasionally fires abnormal electrical activity'),
    commonSigns: [
      t('เกร็งกระตุกทั้งตัว หรือเหม่อลอยชั่วครู่แล้วจำไม่ได้', 'Whole-body stiffening and jerking, or briefly blanking out with no memory of it'),
      t('กลิ่นหรือความรู้สึกแปลกๆ นำมาก่อนชัก', 'An odd smell or sensation just before a seizure'),
      t('สับสน ง่วงมากหลังชักหยุด', 'Confusion and heavy drowsiness after a seizure stops'),
    ],
    seeDoctorWhen: [
      t('ชักนานเกิน 5 นาที หรือชักซ้ำโดยไม่ฟื้นระหว่างครั้ง — ฉุกเฉิน โทร 1669', 'A seizure over 5 minutes, or repeated seizures without waking in between — emergency, call 1669'),
      t('ชักครั้งแรกในชีวิต', 'A first-ever seizure'),
      t('ชักบ่อยขึ้นทั้งที่กินยาสม่ำเสมอ', 'Seizures becoming more frequent despite taking medication regularly'),
    ],
    selfCare: [
      t('กินยากันชักตรงเวลา ห้ามหยุดยาเอง', 'Take anti-seizure medicine on time; never stop it yourself'),
      t('นอนให้พอ เลี่ยงแอลกอฮอล์และการอดนอน', 'Sleep enough; avoid alcohol and sleep deprivation'),
      t('เมื่อมีคนชัก: จับนอนตะแคง เอาของแข็งออกจากรอบตัว ห้ามงัดปาก จับเวลาไว้', 'If someone has a seizure: roll them on their side, clear hard objects away, never force anything into the mouth, and time it'),
    ],
    specialtyKeywords: ['ระบบประสาท', 'สมอง'],
  ),
  HealthTopic(
    key: 'mental_health',
    label: t('สุขภาพจิต', 'Mental health'),
    icon: Icons.self_improvement_outlined,
    summary: t('ความเครียด ซึมเศร้า วิตกกังวล — รักษาได้เหมือนโรคทางกาย', 'Stress, depression, anxiety — treatable like any physical illness'),
    commonSigns: [
      t('เบื่อ ไม่อยากทำสิ่งที่เคยชอบ ต่อเนื่องเกิน 2 สัปดาห์', 'Losing interest in things you used to enjoy, for more than 2 weeks'),
      t('นอนไม่หลับหรือนอนมากเกินไป', 'Sleeping too little or too much'),
      t('ใจสั่น กังวลจนรบกวนการใช้ชีวิต', 'Palpitations, worry that gets in the way of daily life'),
    ],
    seeDoctorWhen: [
      t('มีความคิดทำร้ายตัวเองหรือไม่อยากมีชีวิตอยู่ — โทรสายด่วนสุขภาพจิต 1323 ได้ตลอด 24 ชม.', 'Thoughts of harming yourself or not wanting to live — the mental health helpline 1323 answers 24 hours'),
      t('อาการกระทบการทำงาน การเรียน หรือความสัมพันธ์', 'It is affecting work, study or relationships'),
      t('ใช้เหล้าหรือสารเสพติดเพื่อรับมือกับอารมณ์', 'Using alcohol or drugs to cope with how you feel'),
    ],
    selfCare: [
      t('บอกคนที่ไว้ใจได้ อย่าเก็บไว้คนเดียว', 'Tell someone you trust; do not carry it alone'),
      t('รักษาเวลานอนให้สม่ำเสมอ และออกกำลังกายเบาๆ', 'Keep regular sleeping hours and take gentle exercise'),
      t('ลดคาเฟอีนและการเลื่อนดูโซเชียลก่อนนอน', 'Less caffeine, and less scrolling before bed'),
    ],
    specialtyKeywords: ['จิตเวช', t('สุขภาพจิต', 'Mental health')],
  ),
  HealthTopic(
    key: 'herbal',
    label: t('สมุนไพร', 'Herbal remedies'),
    icon: Icons.eco_outlined,
    summary: t('สมุนไพรก็มีฤทธิ์ยา จึงตีกับยาแผนปัจจุบันได้', 'Herbs act like drugs, so they can interact with prescribed medicine'),
    commonSigns: [
      t('ใช้ฟ้าทะลายโจร ขมิ้นชัน หรือกระชายร่วมกับยาประจำตัว', 'Taking andrographis, turmeric or fingerroot alongside regular medicine'),
      t('ซื้ออาหารเสริมสมุนไพรที่โฆษณาว่ารักษาได้สารพัดโรค', 'Buying herbal supplements advertised as curing all sorts of illnesses'),
    ],
    seeDoctorWhen: [
      t('กินสมุนไพรแล้วมีผื่น ตัวเหลือง ตาเหลือง หรือปัสสาวะเข้ม', 'A rash, yellow skin or eyes, or dark urine after taking herbs'),
      t('กินยาละลายลิ่มเลือด ยาเบาหวาน หรือยาความดันอยู่ ควรถามก่อนใช้สมุนไพรทุกครั้ง', 'On blood thinners, diabetes or blood-pressure medicine — always ask before taking any herb'),
      t('เป็นโรคตับหรือโรคไตอยู่เดิม', 'Existing liver or kidney disease'),
    ],
    selfCare: [
      t('แจ้งแพทย์และเภสัชกรทุกครั้งว่ากินสมุนไพรอะไรอยู่', 'Always tell your doctor and pharmacist which herbs you take'),
      t('เลือกผลิตภัณฑ์ที่มีเลขทะเบียน อย.', 'Choose products with an FDA registration number'),
      t('ระวังคำโฆษณาที่อ้างว่าหายขาดหรือรักษาได้ทุกโรค', 'Be wary of claims of a complete cure or of treating every disease'),
    ],
    specialtyKeywords: ['เภสัช', 'แพทย์แผนไทย'],
  ),
  HealthTopic(
    key: 'vitamin',
    label: t('วิตามิน', 'Vitamins'),
    icon: Icons.medication_outlined,
    summary: t('คนที่กินอาหารครบหมู่ส่วนใหญ่ไม่จำเป็นต้องเสริมวิตามิน', 'Most people eating a balanced diet do not need supplements'),
    commonSigns: [
      t('อ่อนเพลียเรื้อรัง (มีได้หลายสาเหตุ ไม่ใช่แค่ขาดวิตามิน)', 'Persistent tiredness (many causes, not just vitamin deficiency)'),
      t('กินมังสวิรัติเคร่งครัด อาจขาดวิตามิน B12', 'A strict vegetarian diet can run short of vitamin B12'),
      t('ไม่ค่อยโดนแดด อาจขาดวิตามิน D', 'Little sun exposure can mean low vitamin D'),
    ],
    seeDoctorWhen: [
      t('อ่อนเพลียมากจนทำงานไม่ไหว ควรตรวจหาสาเหตุก่อนซื้อวิตามินกินเอง', 'Too tired to work — find the cause before buying supplements yourself'),
      t('ตั้งครรภ์หรือวางแผนตั้งครรภ์ — ต้องการโฟลิกตามคำแนะนำแพทย์', 'Pregnant or planning to be — folic acid as your doctor advises'),
      t('กินวิตามิน A, D, E, K ขนาดสูงติดต่อกันนาน อาจสะสมจนเป็นพิษ', 'High doses of vitamins A, D, E or K over a long period can build up to toxic levels'),
    ],
    selfCare: [
      t('เน้นได้สารอาหารจากอาหารจริงก่อนเสมอ', 'Get nutrients from real food first'),
      t('อ่านฉลากปริมาณ อย่ากินซ้ำซ้อนหลายยี่ห้อพร้อมกัน', 'Read the doses on the label; do not double up across brands'),
      t('เก็บให้พ้นมือเด็ก — วิตามินธาตุเหล็กเกินขนาดอันตรายมากในเด็ก', 'Keep away from children — an iron overdose is very dangerous for them'),
    ],
    specialtyKeywords: ['เภสัช', 'โภชนาการ'],
  ),
  HealthTopic(
    key: 'genetics',
    label: t('พันธุศาสตร์', 'Genetics'),
    icon: Icons.biotech_outlined,
    summary: t('โรคที่ถ่ายทอดในครอบครัว และการวางแผนตรวจคัดกรอง', 'Conditions that run in families, and planning screening'),
    commonSigns: [
      t('มีคนในครอบครัวเป็นมะเร็งเต้านม ลำไส้ หรือรังไข่ตั้งแต่อายุน้อย', 'A family member with breast, bowel or ovarian cancer at a young age'),
      t('มีประวัติธาลัสซีเมียหรือโรคเลือดในครอบครัว', 'A family history of thalassaemia or other blood disorders'),
      t('ญาติสายตรงเป็นโรคหัวใจก่อนวัยอันควร', 'A close relative with heart disease unusually early'),
    ],
    seeDoctorWhen: [
      t('วางแผนมีบุตรและมีประวัติโรคทางพันธุกรรมในครอบครัว', 'Planning a child with a family history of an inherited condition'),
      t('ญาติสายตรงตั้งแต่ 2 คนขึ้นไปเป็นโรคเดียวกัน', 'Two or more close relatives with the same condition'),
      t('ต้องการรู้ว่าควรเริ่มตรวจคัดกรองมะเร็งเมื่อไหร่', 'Wanting to know when to start cancer screening'),
    ],
    selfCare: [
      t('ทำผังประวัติสุขภาพครอบครัวไว้ อย่างน้อย 3 รุ่น', 'Draw up a family health history covering at least 3 generations'),
      t('เก็บผลตรวจเก่าไว้ให้ครบ', 'Keep all your past test results'),
      t('ปรึกษาแพทย์ก่อนซื้อชุดตรวจพันธุกรรมออนไลน์ — การแปลผลสำคัญกว่าตัวผล', 'Ask a doctor before buying an online genetic test — interpreting it matters more than the result'),
    ],
    specialtyKeywords: [t('พันธุศาสตร์', 'Genetics'), 'สูตินรีเวช'],
  ),
  HealthTopic(
    key: 'checkup',
    label: t('ตรวจสุขภาพ', 'Health checks'),
    icon: Icons.monitor_heart_outlined,
    summary: t('ตรวจอะไร เมื่อไหร่ ตามอายุและความเสี่ยงของแต่ละคน', 'What to check and when, based on your age and risks'),
    commonSigns: [
      t('ไม่มีอาการ แต่ถึงเวลาตรวจตามช่วงอายุ', 'No symptoms, but due for a check at your age'),
      t('มีปัจจัยเสี่ยง เช่น สูบบุหรี่ อ้วน ประวัติครอบครัว', 'Risk factors such as smoking, obesity or family history'),
    ],
    seeDoctorWhen: [
      t('มีอาการผิดปกติ — ไม่ต้องรอรอบตรวจประจำปี', 'Something is wrong — do not wait for the annual check'),
      t('ผลตรวจครั้งก่อนมีค่าผิดปกติที่ยังไม่ได้ติดตาม', 'An abnormal result from last time that was never followed up'),
    ],
    selfCare: [
      t('อายุ 35 ปีขึ้นไป ควรตรวจความดัน น้ำตาล ไขมันเป็นระยะ', 'From 35, have blood pressure, sugar and cholesterol checked periodically'),
      t('งดอาหาร 8–12 ชม. ก่อนเจาะเลือดตรวจน้ำตาลและไขมัน', 'Fast 8–12 hours before blood sugar and cholesterol tests'),
      t('พกรายการยาที่กินอยู่ไปด้วยทุกครั้ง', 'Bring a list of everything you take, every time'),
    ],
    specialtyKeywords: [t('ตรวจสุขภาพ', 'Health checks'), 'เวชศาสตร์ครอบครัว', 'อายุรกรรม'],
  ),
  HealthTopic(
    key: 'dental',
    label: t('ทันตกรรม', 'Dental'),
    icon: Icons.medical_information_outlined,
    summary: t('สุขภาพช่องปากเชื่อมโยงกับเบาหวานและโรคหัวใจมากกว่าที่คิด', 'Oral health is linked to diabetes and heart disease more than people expect'),
    commonSigns: [
      t('เสียวฟันเวลาดื่มน้ำเย็นหรือร้อน', 'Sensitive teeth with cold or hot drinks'),
      t('เลือดออกตามไรฟันเวลาแปรงฟัน', 'Gums bleeding when brushing'),
      t('มีกลิ่นปาก เหงือกบวมแดง', 'Bad breath, swollen red gums'),
    ],
    seeDoctorWhen: [
      t('ปวดฟันจนนอนไม่หลับ หรือหน้าบวม มีไข้ — ต้องรีบพบทันตแพทย์', 'Toothache that stops you sleeping, or a swollen face with fever — see a dentist urgently'),
      t('ฟันโยกในผู้ใหญ่', 'A loose tooth in an adult'),
      t('มีแผลในปากที่ไม่หายภายใน 2 สัปดาห์', 'A mouth ulcer that has not healed in 2 weeks'),
    ],
    selfCare: [
      t('แปรงฟันวันละ 2 ครั้ง ครั้งละ 2 นาที ด้วยยาสีฟันผสมฟลูออไรด์', 'Brush twice a day for 2 minutes with fluoride toothpaste'),
      t('ใช้ไหมขัดฟันทุกวัน', 'Floss every day'),
      t('พบทันตแพทย์เพื่อตรวจและขูดหินปูนทุก 6 เดือน', 'See a dentist for a check and scale every 6 months'),
    ],
    specialtyKeywords: [t('ทันตกรรม', 'Dental'), 'ทันตแพทย์'],
  ),
  HealthTopic(
    key: 'anti_aging',
    label: t('ชะลอวัย', 'Ageing well'),
    icon: Icons.spa_outlined,
    summary: t('สิ่งที่มีหลักฐานรองรับจริง คือ นอน อาหาร ออกกำลังกาย และกันแดด', 'What actually has evidence behind it: sleep, diet, exercise and sun protection'),
    commonSigns: [
      t('ผิวแห้ง เหี่ยวย่น จุดด่างดำจากแดดสะสม', 'Dry skin, wrinkles, dark patches from years of sun'),
      t('มวลกล้ามเนื้อลดลงตามอายุ', 'Muscle mass falling with age'),
      t('นอนหลับไม่ลึกเท่าเดิม', 'Sleep is not as deep as it was'),
    ],
    seeDoctorWhen: [
      t('ก่อนเริ่มฮอร์โมนทดแทนหรืออาหารเสริมราคาสูงทุกชนิด', 'Before starting hormone replacement or any expensive supplement'),
      t('ไฝหรือจุดบนผิวที่โตขึ้น เปลี่ยนสี หรือมีเลือดออก', 'A mole or spot that grows, changes colour or bleeds'),
      t('อ่อนเพลียหรือน้ำหนักเปลี่ยนเร็วผิดปกติ', 'Unusual tiredness or rapid weight change'),
    ],
    selfCare: [
      t('ทาครีมกันแดดทุกวัน — ป้องกันริ้วรอยได้ดีที่สุดและถูกที่สุด', 'Sunscreen every day — the cheapest and most effective anti-wrinkle step there is'),
      t('ออกกำลังกายแบบมีแรงต้าน รักษามวลกล้ามเนื้อ', 'Resistance exercise to keep muscle mass'),
      t('นอน 7–9 ชั่วโมง และงดบุหรี่', 'Sleep 7–9 hours and do not smoke'),
      'ระวังคำโฆษณา "คืนความอ่อนเยาว์" ที่ไม่มีงานวิจัยรองรับ',
    ],
    specialtyKeywords: ['ผิวหนัง', 'เวชศาสตร์ชะลอวัย'],
  ),
  HealthTopic(
    key: 'general',
    label: t('ทั่วไป', 'General'),
    icon: Icons.local_hospital_outlined,
    summary: t('ไม่แน่ใจว่าอาการเข้าหมวดไหน ถามรวมได้ที่นี่', 'Not sure which topic fits? Ask here.'),
    commonSigns: [
      t('ไข้ ไอ เจ็บคอ', 'Fever, cough, sore throat'),
      t('ปวดเมื่อยตามตัว อ่อนเพลีย', 'Aching body, tiredness'),
      t('สงสัยเรื่องยาที่กินอยู่', 'Questions about medicine you are taking'),
    ],
    seeDoctorWhen: [
      t('ไข้สูงเกิน 3 วัน หรือไข้ร่วมกับซึม สับสน', 'A high fever over 3 days, or fever with drowsiness or confusion'),
      t('อาการแย่ลงเรื่อยๆ แทนที่จะดีขึ้น', 'Getting steadily worse instead of better'),
      t('เจ็บหน้าอก หายใจไม่ออก แขนขาอ่อนแรง — โทร 1669 ทันที', 'Chest pain, trouble breathing, weak limbs — call 1669 now'),
    ],
    selfCare: [
      t('พักผ่อนให้พอ ดื่มน้ำมากๆ', 'Rest enough and drink plenty of water'),
      t('จดอาการและวันที่เริ่มไว้ ช่วยให้แพทย์วินิจฉัยง่ายขึ้น', 'Note the symptoms and when they started — it helps the doctor'),
      t('อย่าใช้ยาปฏิชีวนะเองโดยไม่มีข้อบ่งชี้', 'Do not take antibiotics on your own without a reason to'),
    ],
    specialtyKeywords: [t('ทั่วไป', 'General'), 'เวชศาสตร์ครอบครัว', 'อายุรกรรม'],
  ),
];

HealthTopic? healthTopicByKey(String key) {
  for (final topic in healthTopics) {
    if (topic.key == key) return topic;
  }
  return null;
}

String healthTopicLabel(String key) => healthTopicByKey(key)?.label ?? key;
