import 'package:flutter/material.dart';
import '../../../../core/i18n/app_locale.dart';

/// A number, threshold or hotline worth remembering, shown as a label and the
/// thing it means. Kept as a pair rather than one sentence so the screen can
/// set the figure apart — a reader scanning for "what counts as high?" should
/// find it without reading a paragraph.
class TopicFact {
  const TopicFact(this.label, this.value);

  /// The figure itself: "< 120/80", "1669", "2 สัปดาห์".
  final String label;

  /// What it means in one line.
  final String value;
}

/// A belief that is common and wrong, paired with what is actually the case.
/// These earn their place: several of them (forcing a spoon into the mouth of
/// someone having a seizure, stopping blood-pressure tablets once the reading
/// comes down) describe things that hurt people.
class TopicMyth {
  const TopicMyth(this.claim, this.fact);

  final String claim;
  final String fact;
}

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
    required this.overview,
    required this.commonSigns,
    required this.seeDoctorWhen,
    required this.selfCare,
    this.riskFactors = const [],
    this.riskTitle,
    this.keyFacts = const [],
    this.myths = const [],
    this.specialtyKeywords = const [],
  });

  final String key;
  final String label;
  final IconData icon;

  /// One or two lines under the title.
  final String summary;

  /// A paragraph explaining what the subject actually is, before the lists
  /// start. Without it the screen jumps straight from a one-line summary into
  /// "common symptoms", which tells a reader what to look for but never what
  /// they are looking at.
  final String overview;

  final List<String> commonSigns;

  /// Symptoms that mean "stop reading and get seen" — listed on every topic
  /// because the app must never read as a substitute for being examined.
  final List<String> seeDoctorWhen;

  final List<String> selfCare;

  /// Why it happens and who it happens to.
  final List<String> riskFactors;

  /// Overrides the risk section's heading. "สาเหตุและปัจจัยเสี่ยง" is right for
  /// a disease and wrong for a subject like ตรวจสุขภาพ, where the same list is
  /// really "who needs checking more often".
  final String? riskTitle;

  final List<TopicFact> keyFacts;

  final List<TopicMyth> myths;

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
    overview: t('บุหรี่มีสารเคมีมากกว่า 7,000 ชนิด นิโคตินคือตัวที่ทำให้ติด ส่วนน้ำมันดินและคาร์บอนมอนอกไซด์คือตัวที่ทำลายปอดและหลอดเลือด ร่างกายเริ่มฟื้นตัวตั้งแต่ 20 นาทีแรกหลังมวนสุดท้าย และความเสี่ยงลดลงเรื่อยๆ ตามระยะเวลาที่หยุดได้ การกลับไปสูบซ้ำเป็นเรื่องปกติในการเลิก ไม่ใช่ความล้มเหลว คนส่วนใหญ่ต้องพยายามหลายครั้งกว่าจะสำเร็จ', 'Cigarettes contain over 7,000 chemicals. Nicotine is what makes them addictive; tar and carbon monoxide are what damage the lungs and blood vessels. The body starts recovering within 20 minutes of the last cigarette, and the risk keeps falling the longer you stay stopped. Slipping back is a normal part of quitting, not a failure — most people need several attempts before it sticks.'),
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
    riskFactors: [
      t('นิโคตินกระตุ้นให้สมองหลั่งโดพามีน สมองจึงเรียนรู้ว่าต้องสูบเพื่อให้รู้สึกปกติ', 'Nicotine triggers dopamine in the brain, which then expects a cigarette just to feel normal'),
      t('ความเครียด แอลกอฮอล์ และการอยู่กับคนที่สูบ เป็นตัวกระตุ้นให้กลับไปสูบซ้ำที่พบบ่อยที่สุด', 'Stress, alcohol and being around smokers are the commonest triggers for going back'),
      t('บุหรี่ไฟฟ้ายังมีนิโคติน จึงไม่ได้ตัดวงจรการติด', 'E-cigarettes still contain nicotine, so they do not break the addiction'),
      t('ควันมือสองทำร้ายเด็กและคนในบ้าน โดยเฉพาะเด็กที่เป็นหอบหืด', 'Second-hand smoke harms children and others at home, especially children with asthma'),
    ],
    keyFacts: [
      TopicFact(t('20 นาที', '20 minutes'), t('ชีพจรและความดันเริ่มกลับสู่ปกติ', 'Pulse and blood pressure start returning to normal')),
      TopicFact(t('2–12 สัปดาห์', '2–12 weeks'), t('การไหลเวียนเลือดและการทำงานของปอดดีขึ้น', 'Circulation and lung function improve')),
      TopicFact(t('1 ปี', '1 year'), t('ความเสี่ยงโรคหัวใจลดลงราวครึ่งหนึ่งของคนที่ยังสูบ', 'Heart-disease risk falls to about half that of a continuing smoker')),
      TopicFact('1600', t('สายด่วนเลิกบุหรี่ ปรึกษาฟรี', 'Free quit-smoking helpline')),
    ],
    myths: [
      TopicMyth(
        t('สูบน้อยลงก็พอแล้ว ไม่ต้องเลิกสนิท', 'Cutting down is enough, I do not need to stop completely'),
        t('การลดจำนวนมวนลดความเสี่ยงได้น้อยมาก เพราะคนที่ลดมักสูบลึกและนานขึ้นต่อมวน ประโยชน์ที่ชัดเจนเกิดเมื่อหยุดสนิท', 'Cutting down lowers the risk very little — people who cut down tend to inhale more deeply and hold it longer. The clear benefit comes from stopping completely.'),
      ),
      TopicMyth(
        t('เลิกแล้วจะอ้วน ไม่เลิกดีกว่า', 'I will put on weight if I quit, so better not to'),
        t('น้ำหนักอาจขึ้นราว 2–4 กก. แต่ความเสี่ยงจากบุหรี่สูงกว่าน้ำหนักที่ขึ้นมาก และคุมได้ด้วยอาหารและการออกกำลังกาย', 'Weight may rise by 2–4 kg, but that is far less harmful than continuing to smoke, and diet and exercise keep it in check.'),
      ),
    ],
    specialtyKeywords: [t('ปอด', 'Lungs'), 'อายุรกรรม', 'เวชศาสตร์ครอบครัว'],
  ),
  HealthTopic(
    key: 'kidney',
    label: t('ไต', 'Kidneys'),
    icon: Icons.water_drop_outlined,
    summary: t('ไตกรองของเสียออกจากเลือด โรคไตระยะแรกมักไม่มีอาการจนตรวจเจอ', 'Kidneys filter waste from blood. Early kidney disease usually has no symptoms until it is tested for.'),
    overview: t('ไตสองข้างกรองเลือดราว 180 ลิตรต่อวัน เพื่อขับของเสีย ปรับสมดุลน้ำและเกลือแร่ และช่วยคุมความดัน โรคไตเรื้อรังค่อยๆ ทำให้การกรองแย่ลงโดยแทบไม่มีสัญญาณเตือน กว่าจะรู้สึกผิดปกติมักเสียการทำงานไปมากแล้ว การตรวจเลือดหาค่า eGFR และตรวจปัสสาวะหาโปรตีนรั่ว จึงเป็นวิธีเดียวที่จับได้ตั้งแต่ระยะที่ยังชะลอได้', 'The two kidneys filter about 180 litres of blood a day — clearing waste, balancing water and minerals, and helping control blood pressure. Chronic kidney disease erodes that filtering with almost no warning; by the time anything feels wrong, much function is usually gone. A blood test for eGFR and a urine test for leaked protein are the only way to catch it while it can still be slowed.'),
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
    riskFactors: [
      t('เบาหวานและความดันโลหิตสูง เป็นสาเหตุอันดับหนึ่งและสองของโรคไตเรื้อรัง', 'Diabetes and high blood pressure are the first and second causes of chronic kidney disease'),
      t('กินเค็มจัดประจำ ทำให้ความดันสูงขึ้นและไตทำงานหนักขึ้น', 'A consistently salty diet raises blood pressure and makes the kidneys work harder'),
      t('ใช้ยาแก้ปวด NSAIDs หรือยาชุดต่อเนื่องเป็นเวลานาน', 'Long-term use of NSAID painkillers or unlabelled combination pills'),
      t('นิ่วในไต ติดเชื้อทางเดินปัสสาวะซ้ำๆ และประวัติโรคไตในครอบครัว', 'Kidney stones, repeated urinary infections, and kidney disease in the family'),
    ],
    keyFacts: [
      TopicFact('eGFR ≥ 90', t('การทำงานของไตอยู่ในเกณฑ์ปกติ', 'Kidney function in the normal range')),
      TopicFact(t('eGFR < 60 นานเกิน 3 เดือน', 'eGFR < 60 for over 3 months'), t('เข้าเกณฑ์โรคไตเรื้อรัง', 'Meets the definition of chronic kidney disease')),
      TopicFact(t('เกลือ < 1 ช้อนชา/วัน', 'Salt < 1 teaspoon a day'), t('ราว 2,000 มก. โซเดียม รวมที่ซ่อนอยู่ในน้ำปลาและซุปก้อน', 'About 2,000 mg of sodium, counting what hides in fish sauce and stock cubes')),
      TopicFact(t('ปีละ 1 ครั้ง', 'Once a year'), t('ความถี่ตรวจไต เมื่อเป็นเบาหวานหรือความดันสูง', 'How often to check kidney function with diabetes or high blood pressure')),
    ],
    myths: [
      TopicMyth(
        t('ดื่มน้ำเยอะๆ ช่วยล้างไตให้สะอาด', 'Drinking lots of water flushes the kidneys clean'),
        t('น้ำมากเกินไปไม่ได้ฟอกไต และในผู้ที่ไตเสื่อมแล้วอาจทำให้บวมและเกลือแร่ผิดปกติ ควรดื่มตามที่แพทย์แนะนำ', 'Extra water does not cleanse anything, and in someone whose kidneys are already failing it can cause swelling and mineral imbalance. Drink the amount your doctor advises.'),
      ),
      TopicMyth(
        t('ไม่ปวดหลังแปลว่าไตยังดี', 'No back pain means the kidneys are fine'),
        t('โรคไตเรื้อรังส่วนใหญ่ไม่ปวดเลย และอาการปวดหลังมักมาจากกล้ามเนื้อมากกว่าไต ต้องตรวจเลือดและปัสสาวะเท่านั้นจึงจะรู้', 'Chronic kidney disease is usually painless, and back pain far more often comes from muscle than from the kidneys. Only blood and urine tests can tell.'),
      ),
    ],
    specialtyKeywords: [t('ไต', 'Kidneys'), 'อายุรกรรม'],
  ),
  HealthTopic(
    key: 'digestive',
    label: t('ทางเดินอาหาร', 'Digestion'),
    icon: Icons.lunch_dining_outlined,
    summary: t('ตั้งแต่หลอดอาหารถึงลำไส้ — อาการปวดท้องมีได้หลายสาเหตุมาก', 'From the oesophagus to the bowel — stomach pain has many possible causes'),
    overview: t('ทางเดินอาหารยาวราว 9 เมตรตั้งแต่ปากถึงทวารหนัก ทำหน้าที่ย่อย ดูดซึม และกำจัดกาก อาการปวดท้องจึงครอบคลุมตั้งแต่เรื่องเล็กอย่างอาหารไม่ย่อย ไปจนถึงแผลในกระเพาะและมะเร็ง สิ่งที่ช่วยแยกได้มากที่สุดคือ ตำแหน่งที่ปวด ความสัมพันธ์กับมื้ออาหาร และอาการร่วม เช่น น้ำหนักลดหรือถ่ายเป็นเลือด ซึ่งเป็นสัญญาณที่ต้องตรวจเสมอ', 'The digestive tract runs about 9 metres from mouth to anus, breaking food down, absorbing it and clearing the waste. Stomach pain therefore covers everything from simple indigestion to an ulcer or cancer. What narrows it down most is where it hurts, how it relates to meals, and what comes with it — weight loss or blood in the stool always needs investigating.'),
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
    riskFactors: [
      t('กินแล้วเอนตัวนอนทันที มื้อใหญ่ ของทอด กาแฟ และแอลกอฮอล์ กระตุ้นกรดไหลย้อน', 'Lying down straight after eating, large meals, fried food, coffee and alcohol all trigger reflux'),
      t('เชื้อ H. pylori เป็นสาเหตุสำคัญของแผลในกระเพาะ ตรวจพบและรักษาให้หายขาดได้ด้วยยาปฏิชีวนะ', 'H. pylori is a major cause of stomach ulcers — it can be tested for and cured with antibiotics'),
      t('ยาแก้ปวด NSAIDs และแอสไพริน กัดเยื่อบุกระเพาะอาหาร', 'NSAID painkillers and aspirin erode the stomach lining'),
      t('ความเครียดและการนอนน้อย ทำให้ลำไส้แปรปรวนกำเริบ', 'Stress and short sleep set off irritable bowel symptoms'),
    ],
    keyFacts: [
      TopicFact(t('2–3 ชั่วโมง', '2–3 hours'), t('ควรเว้นหลังมื้ออาหารก่อนเอนตัวนอน', 'Leave this long after eating before lying down')),
      TopicFact(t('25 กรัม/วัน', '25 g a day'), t('ใยอาหารที่แนะนำ ช่วยเรื่องท้องผูก', 'Recommended fibre intake, which helps constipation')),
      TopicFact(t('อายุ 45–50 ปี', 'Age 45–50'), t('ช่วงที่แนะนำให้เริ่มคัดกรองมะเร็งลำไส้ใหญ่', 'When bowel-cancer screening is usually advised to start')),
      TopicFact(t('2 สัปดาห์', '2 weeks'), t('กินยาลดกรดนานกว่านี้แล้วไม่ดีขึ้น ควรพบแพทย์', 'Antacids for longer than this without improvement means see a doctor')),
    ],
    myths: [
      TopicMyth(
        t('ปวดท้องบ่อยๆ ซื้อยาลดกรดกินเองไปเรื่อยๆ ได้', 'Frequent stomach pain can just be managed with antacids from the shop'),
        t('ยาลดกรดบรรเทาอาการได้จริง แต่ก็บังอาการของแผลในกระเพาะและมะเร็งระยะแรกไปด้วย ถ้าต้องกินเกิน 2 สัปดาห์ ควรตรวจหาสาเหตุ', 'Antacids do relieve the symptom, but they also mask ulcers and early cancer. Needing them beyond 2 weeks means the cause should be looked for.'),
      ),
      TopicMyth(
        t('ดื่มนมช่วยรักษาแผลในกระเพาะ', 'Milk heals a stomach ulcer'),
        t('นมลดแสบได้ชั่วครู่ แต่โปรตีนและแคลเซียมในนมกระตุ้นให้หลั่งกรดตามมามากกว่าเดิม จึงไม่ใช่การรักษา', 'Milk soothes briefly, but its protein and calcium then trigger more acid than before. It is not a treatment.'),
      ),
    ],
    specialtyKeywords: [t('ทางเดินอาหาร', 'Digestion'), 'อายุรกรรม'],
  ),
  HealthTopic(
    key: 'lung',
    label: t('ปอด', 'Lungs'),
    icon: Icons.air,
    summary: t('ไอเรื้อรังและเหนื่อยง่ายเป็นสัญญาณที่ไม่ควรปล่อยผ่าน', 'A lasting cough and getting out of breath easily should not be ignored'),
    overview: t('ปอดแลกออกซิเจนเข้าและคาร์บอนไดออกไซด์ออกราวสองหมื่นครั้งต่อวัน โรคปอดที่พบบ่อยในไทยคือ หอบหืด ถุงลมโป่งพอง (COPD) วัณโรค และผลสะสมจากฝุ่น PM2.5 ทั้งหมดนี้เริ่มต้นด้วยอาการคล้ายกันคือไอและเหนื่อยง่าย จึงแยกกันด้วยอาการอย่างเดียวไม่ได้ ต้องอาศัยการเอกซเรย์ปอดและการตรวจสมรรถภาพปอดเป็นตัวตัดสิน', 'The lungs exchange oxygen and carbon dioxide around twenty thousand times a day. The common lung conditions in Thailand are asthma, COPD, tuberculosis and the cumulative effect of PM2.5 dust. They all begin the same way — a cough and getting breathless easily — so symptoms alone cannot separate them. A chest X-ray and lung function testing are what settle it.'),
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
    riskFactors: [
      t('บุหรี่เป็นสาเหตุหลักของถุงลมโป่งพองและมะเร็งปอด', 'Smoking is the main cause of COPD and lung cancer'),
      t('ฝุ่น PM2.5 ควันธูป ควันจากการเผา และควันครัวในที่ระบายอากาศไม่ดี', 'PM2.5 dust, incense and field-burning smoke, and cooking smoke in a poorly ventilated kitchen'),
      t('ไรฝุ่น ขนสัตว์ อากาศเย็น และการติดเชื้อทางเดินหายใจ กระตุ้นหอบหืดกำเริบ', 'Dust mites, animal hair, cold air and chest infections set off asthma attacks'),
      t('วัณโรคยังพบได้ทั่วไปในไทย ติดต่อทางการไอจาม และรักษาหายขาดได้หากกินยาครบ', 'Tuberculosis is still common in Thailand, spreads by coughing, and is fully curable if the full course is taken'),
    ],
    keyFacts: [
      TopicFact(t('PM2.5 เกิน 37.5', 'PM2.5 above 37.5'), t('ไมโครกรัม/ลบ.ม. เริ่มมีผลต่อสุขภาพ ควรใส่หน้ากาก N95', 'µg/m³ starts affecting health — wear an N95 mask')),
      TopicFact(t('ไอเกิน 2 สัปดาห์', 'A cough beyond 2 weeks'), t('ควรตรวจหาวัณโรค โดยเฉพาะถ้ามีไข้ต่ำๆ ตอนเย็นและเหงื่อออกกลางคืน', 'Should be checked for TB, especially with a low evening fever and night sweats')),
      TopicFact(t('6 เดือน', '6 months'), t('ระยะเวลากินยาวัณโรคจนครบ การหยุดกลางคันทำให้เชื้อดื้อยา', 'The full TB treatment course — stopping early breeds drug resistance')),
      TopicFact('1669', t('โทรทันทีเมื่อหายใจไม่ออกหรือริมฝีปากเขียว', 'Call at once for severe breathlessness or blue lips')),
    ],
    myths: [
      TopicMyth(
        t('ไอเรื้อรังเป็นเพราะอากาศ เดี๋ยวก็หายเอง', 'A long cough is just the weather, it will pass'),
        t('ไอเกิน 3 สัปดาห์ควรตรวจเสมอ อาจเป็นวัณโรค หอบหืด กรดไหลย้อน หรือมะเร็งปอด ซึ่งรักษาได้ดีกว่ามากเมื่อเจอเร็ว', 'A cough over 3 weeks always deserves a check — TB, asthma, reflux or lung cancer all do far better when found early.'),
      ),
      TopicMyth(
        t('ไม่สูบบุหรี่ก็ไม่มีทางเป็นมะเร็งปอด', 'Non-smokers cannot get lung cancer'),
        t('ควันมือสอง ฝุ่น PM2.5 ควันจากการทำอาหาร และก๊าซเรดอน ทำให้คนที่ไม่เคยสูบเป็นมะเร็งปอดได้เช่นกัน', 'Second-hand smoke, PM2.5, cooking fumes and radon gas all cause lung cancer in people who never smoked.'),
      ),
    ],
    specialtyKeywords: [t('ปอด', 'Lungs'), 'อายุรกรรม'],
  ),
  HealthTopic(
    key: 'allergy',
    label: t('ภูมิแพ้', 'Allergies'),
    icon: Icons.grass_outlined,
    summary: t('ร่างกายตอบสนองไวเกินต่อสิ่งที่ปกติไม่เป็นอันตราย', 'The body reacting too strongly to something normally harmless'),
    overview: t('ภูมิแพ้เกิดเมื่อระบบภูมิคุ้มกันจดจำสารที่ปกติไม่เป็นอันตราย เช่น ไรฝุ่นหรือเกสร ว่าเป็นศัตรู แล้วปล่อยฮิสตามีนออกมา จึงเกิดอาการคัน จาม บวม อาการเป็นๆ หายๆ ตามการสัมผัสสิ่งกระตุ้น และมักถ่ายทอดในครอบครัว หัวใจของการรักษาคือหาสิ่งกระตุ้นให้เจอแล้วเลี่ยง ส่วนยาช่วยคุมอาการระหว่างนั้น', 'An allergy is the immune system treating something harmless — dust mites, pollen — as a threat and releasing histamine, which produces the itching, sneezing and swelling. Symptoms come and go with exposure, and they tend to run in families. The core of treatment is identifying the trigger and avoiding it; medication controls symptoms in the meantime.'),
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
    riskFactors: [
      t('ไรฝุ่นในที่นอน หมอน และพรม เป็นสิ่งกระตุ้นที่พบบ่อยที่สุดในบ้านคนไทย', 'Dust mites in mattresses, pillows and rugs are the commonest trigger in Thai homes'),
      t('ขนและรังแคสัตว์เลี้ยง เกสรดอกไม้ และเชื้อราจากความชื้นในบ้าน', 'Pet hair and dander, pollen, and mould from damp'),
      t('อาหาร เช่น กุ้ง ปู นมวัว ไข่ และถั่วลิสง โดยเฉพาะในเด็ก', 'Foods such as shrimp, crab, cow milk, egg and peanut, especially in children'),
      t('พ่อหรือแม่เป็นภูมิแพ้ ลูกมีโอกาสเป็นสูงขึ้นชัดเจน', 'A parent with allergies markedly raises a child chance of having them'),
    ],
    keyFacts: [
      TopicFact('55–60 °C', t('อุณหภูมิน้ำที่ใช้ซักผ้าปูที่นอนแล้วฆ่าไรฝุ่นได้', 'The water temperature that actually kills dust mites in bedding')),
      TopicFact(t('ทุก 1–2 สัปดาห์', 'Every 1–2 weeks'), t('ความถี่ที่ควรซักผ้าปูที่นอนและปลอกหมอน', 'How often to wash sheets and pillowcases')),
      TopicFact(t('30 นาที', '30 minutes'), t('ช่วงเวลาที่อาการแพ้รุนแรงมักเกิดหลังได้รับสิ่งกระตุ้น', 'The window in which a severe reaction usually appears after exposure')),
      TopicFact('1669', t('โทรทันทีเมื่อหน้าบวม ปากบวม หรือหายใจไม่ออก', 'Call at once for a swollen face or lips, or trouble breathing')),
    ],
    myths: [
      TopicMyth(
        t('ภูมิแพ้เป็นแล้วเป็นตลอดชีวิต รักษาไม่ได้', 'Once you have allergies you have them for life'),
        t('คุมได้ดีมากด้วยการเลี่ยงสิ่งกระตุ้นร่วมกับยา บางรายรักษาด้วยวัคซีนภูมิแพ้จนดีขึ้นชัดเจน และเด็กจำนวนมากหายได้เองเมื่อโตขึ้น', 'They can be controlled very well by avoiding triggers plus medication, some people improve markedly with immunotherapy, and many children grow out of them.'),
      ),
      TopicMyth(
        t('กินยาแก้แพ้ติดต่อกันแล้วจะดื้อยา', 'Taking antihistamines regularly makes you resistant to them'),
        t('ยาแก้แพ้ไม่ทำให้ดื้อยา แต่การต้องกินแทบทุกวันเป็นสัญญาณว่ายังคุมสิ่งกระตุ้นไม่ได้ ควรปรึกษาแพทย์เพื่อหาต้นเหตุ', 'Antihistamines do not cause resistance, but needing them nearly every day means the trigger is still unmanaged — worth seeing a doctor about the cause.'),
      ),
    ],
    specialtyKeywords: [t('ภูมิแพ้', 'Allergies'), 'ผิวหนัง', 'หู คอ จมูก'],
  ),
  HealthTopic(
    key: 'hypertension',
    label: t('ความดัน', 'Blood pressure'),
    icon: Icons.favorite_border,
    summary: t('ความดันสูงมักไม่มีอาการ แต่ทำลายหัวใจ ไต และสมองอย่างเงียบๆ', 'High blood pressure usually has no symptoms, but quietly damages the heart, kidneys and brain'),
    overview: t('ความดันโลหิตคือแรงที่เลือดดันผนังหลอดเลือด ตัวเลขบนคือขณะหัวใจบีบ ตัวล่างคือขณะหัวใจคลาย เมื่อความดันสูงต่อเนื่อง ผนังหลอดเลือดจะหนาและแข็งขึ้น เพิ่มความเสี่ยงอัมพาต หัวใจวาย และไตวาย โดยที่ผู้ป่วยส่วนใหญ่ไม่รู้สึกผิดปกติอะไรเลยตลอดหลายปี นี่คือเหตุผลที่ต้องวัด ไม่ใช่รอให้มีอาการ', 'Blood pressure is the force of blood against the vessel walls — the upper number while the heart squeezes, the lower while it relaxes. Kept high, it thickens and stiffens those walls, raising the risk of stroke, heart attack and kidney failure, while most people feel nothing at all for years. That is why it has to be measured rather than waited for.'),
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
    riskFactors: [
      t('กินเค็ม น้ำหนักเกิน ไม่ค่อยขยับ และดื่มแอลกอฮอล์เป็นประจำ', 'A salty diet, extra weight, little movement, and regular alcohol'),
      t('อายุที่มากขึ้น และประวัติความดันสูงในครอบครัว', 'Rising age, and high blood pressure in the family'),
      t('ภาวะหยุดหายใจขณะหลับ — สังเกตจากกรนเสียงดังและง่วงมากตอนกลางวัน', 'Sleep apnoea — loud snoring and heavy daytime sleepiness are the clues'),
      t('ยาบางชนิด เช่น สเตียรอยด์ ยาคุมกำเนิด และยาแก้หวัดที่มีตัวหดหลอดเลือด', 'Some medicines: steroids, contraceptive pills, and cold remedies containing decongestants'),
    ],
    keyFacts: [
      TopicFact('< 120/80', t('ระดับที่ถือว่าเหมาะสม', 'The optimal range')),
      TopicFact('≥ 140/90', t('เข้าเกณฑ์ความดันโลหิตสูง เมื่อวัดซ้ำได้ค่านี้หลายครั้ง', 'Meets the definition of hypertension when repeated readings agree')),
      TopicFact('≥ 180/110', t('สูงมาก ควรพบแพทย์โดยเร็ว', 'Very high — see a doctor promptly')),
      TopicFact(t('นั่งพัก 5 นาที', 'Sit for 5 minutes'), t('ก่อนวัดทุกครั้ง เท้าวางราบ ไม่พูดคุยขณะวัด', 'Before every reading — feet flat, no talking while it runs')),
    ],
    myths: [
      TopicMyth(
        t('ไม่ปวดหัว ไม่เวียนหัว แปลว่าความดันปกติ', 'No headache or dizziness means my blood pressure is fine'),
        t('ความดันสูงส่วนใหญ่ไม่มีอาการใดๆ อาการปวดหัวไม่ใช่ตัวชี้วัดความดัน การวัดเท่านั้นที่บอกได้', 'High blood pressure usually produces no symptoms at all. A headache is not an indicator — only a reading is.'),
      ),
      TopicMyth(
        t('ความดันลงเป็นปกติแล้ว หยุดยาได้', 'My reading is normal now, so I can stop the tablets'),
        t('ค่าที่ลงมาคือผลของยาที่กำลังทำงานอยู่ การหยุดเองมักทำให้ความดันดีดกลับขึ้นสูงภายในไม่กี่สัปดาห์ การลดหรือหยุดยาต้องให้แพทย์เป็นผู้ตัดสิน', 'The reading is normal because the medicine is working. Stopping on your own usually sends it back up within weeks — only a doctor should reduce or stop it.'),
      ),
    ],
    specialtyKeywords: ['หัวใจ', 'อายุรกรรม'],
  ),
  HealthTopic(
    key: 'elderly',
    label: t('สูงอายุ', 'Older age'),
    icon: Icons.elderly_outlined,
    summary: t('ดูแลผู้สูงวัย — เรื่องล้ม ยาหลายชนิด และความจำ', 'Caring for older people — falls, multiple medicines, and memory'),
    overview: t('ร่างกายผู้สูงวัยตอบสนองต่อยาและความเจ็บป่วยต่างจากวัยหนุ่มสาว ไตขับยาช้าลงทำให้ยาสะสมได้ง่าย การทรงตัวถดถอย และอาการของโรคมักไม่ตรงไปตรงมา เช่น การติดเชื้อในผู้สูงอายุอาจแสดงออกเป็นความสับสนเฉียบพลันแทนที่จะมีไข้ สามเรื่องที่กระทบคุณภาพชีวิตมากที่สุดคือ การล้ม ยาหลายชนิดที่ตีกัน และความจำที่เปลี่ยนไป', 'Older bodies handle medicines and illness differently: the kidneys clear drugs more slowly so they accumulate, balance declines, and illness often presents indirectly — an infection may show up as sudden confusion rather than fever. The three things that affect daily life most are falls, interacting medicines, and changes in memory.'),
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
    riskTitle: t('อะไรทำให้เสี่ยง', 'What raises the risk'),
    riskFactors: [
      t('กล้ามเนื้อและการทรงตัวถดถอย ร่วมกับสายตาที่แย่ลง ทำให้ล้มง่ายขึ้นมาก', 'Weakening muscles and balance, together with failing eyesight, make falls much more likely'),
      t('ยานอนหลับ ยาคลายกังวล และยาลดความดันบางชนิด เพิ่มโอกาสล้มโดยตรง', 'Sleeping tablets, anti-anxiety drugs and some blood-pressure medicines directly increase falls'),
      t('กินยาตั้งแต่ 5 ชนิดขึ้นไป เพิ่มโอกาสที่ยาจะตีกันอย่างมีนัยสำคัญ', 'Taking five or more medicines markedly raises the chance of interactions'),
      t('หูตึงและสายตาไม่ดี ทำให้ดูเหมือนความจำเสื่อม ทั้งที่แก้ไขได้ด้วยแว่นและเครื่องช่วยฟัง', 'Poor hearing and vision can look like memory loss, when glasses and a hearing aid would fix it'),
    ],
    keyFacts: [
      TopicFact(t('5 ชนิดขึ้นไป', 'Five or more'), t('จำนวนยาที่ควรให้เภสัชกรทบทวนทั้งหมดพร้อมกัน', 'The number of medicines at which a full pharmacist review is worthwhile')),
      TopicFact(t('ปีละ 1 ครั้ง', 'Once a year'), t('ความถี่ที่ควรตรวจสายตาและการได้ยิน', 'How often to check eyesight and hearing')),
      TopicFact(t('30 นาที/วัน', '30 minutes a day'), t('การเดินหรือออกกำลังเบาๆ ที่ช่วยลดการล้มได้จริง', 'Walking or gentle exercise that genuinely reduces falls')),
      TopicFact('1669', t('โทรทันทีเมื่อล้มศีรษะกระแทก หรือสับสนเฉียบพลัน', 'Call at once after a fall hitting the head, or for sudden confusion')),
    ],
    myths: [
      TopicMyth(
        t('หลงลืมเป็นเรื่องธรรมดาของคนแก่ ไม่ต้องไปตรวจ', 'Forgetfulness is just old age, no need to have it checked'),
        t('ลืมชื่อแล้วนึกออกทีหลังเป็นเรื่องปกติ แต่ลืมจนหลงทางในที่คุ้นเคยหรือทำกิจวัตรเองไม่ได้ ไม่ปกติ และบางสาเหตุ เช่น ไทรอยด์ต่ำ ขาดวิตามิน B12 หรือผลจากยา รักษาให้กลับมาดีได้', 'Forgetting a name and recalling it later is normal. Getting lost somewhere familiar, or being unable to manage daily routines, is not — and some causes, such as low thyroid, B12 deficiency or a medication effect, are fully reversible.'),
      ),
      TopicMyth(
        t('ผู้สูงอายุควรพักมากๆ อย่าให้เหนื่อย', 'Older people should rest as much as possible'),
        t('การไม่ขยับทำให้กล้ามเนื้อลีบเร็วและยิ่งล้มง่ายขึ้น การเคลื่อนไหวสม่ำเสมอในระดับที่พอดีปลอดภัยกว่าการนอนอยู่เฉยๆ', 'Not moving wastes muscle quickly and makes falls more likely. Regular movement at a sensible level is safer than sitting still.'),
      ),
    ],
    specialtyKeywords: ['ผู้สูงอายุ', 'เวชศาสตร์ครอบครัว', 'อายุรกรรม'],
  ),
  HealthTopic(
    key: 'diabetes',
    label: t('เบาหวาน', 'Diabetes'),
    icon: Icons.bloodtype_outlined,
    summary: t('ระดับน้ำตาลในเลือดสูงเรื้อรัง คุมได้ด้วยอาหาร ยา และการติดตาม', 'Persistently high blood sugar, managed with diet, medication and monitoring'),
    overview: t('เบาหวานคือภาวะที่น้ำตาลในเลือดสูงเรื้อรัง เพราะอินซูลินไม่พอหรือร่างกายตอบสนองต่ออินซูลินได้ไม่ดี ชนิดที่ 2 พบมากที่สุดและสัมพันธ์กับน้ำหนักและพันธุกรรม น้ำตาลที่สูงต่อเนื่องจะทำลายหลอดเลือดขนาดเล็กที่จอตา ไต และปลายประสาท มาหลายปีก่อนที่จะมีอาการให้รู้สึก การคุมน้ำตาลจึงเป็นการป้องกันภาวะแทรกซ้อนในอนาคต ไม่ใช่แค่ทำให้วันนี้สบายขึ้น', 'Diabetes means blood sugar stays high because there is too little insulin, or the body responds poorly to it. Type 2 is by far the most common and is tied to weight and family history. Sustained high sugar damages the small vessels of the retina, kidneys and nerves for years before producing any symptom. Controlling it is about preventing future complications, not just feeling better today.'),
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
    riskFactors: [
      t('น้ำหนักเกิน โดยเฉพาะอ้วนลงพุง และการนั่งนานโดยไม่ค่อยขยับ', 'Extra weight, especially around the waist, and long hours sitting still'),
      t('พ่อแม่พี่น้องเป็นเบาหวาน ทำให้ความเสี่ยงสูงขึ้นชัดเจน', 'A parent or sibling with diabetes raises the risk substantially'),
      t('เคยเป็นเบาหวานขณะตั้งครรภ์ หรือคลอดบุตรน้ำหนักเกิน 4 กิโลกรัม', 'Past gestational diabetes, or having had a baby over 4 kg'),
      t('เครื่องดื่มหวานและข้าวขาวปริมาณมากในแต่ละมื้อ', 'Sweet drinks and large portions of white rice at every meal'),
    ],
    keyFacts: [
      TopicFact(t('น้ำตาลอดอาหาร', 'Fasting glucose'), t('< 100 ปกติ · 100–125 เสี่ยง · ≥ 126 เข้าเกณฑ์เบาหวาน (มก./ดล.)', '< 100 normal · 100–125 at risk · ≥ 126 meets the diabetes threshold (mg/dL)')),
      TopicFact('HbA1c < 7%', t('เป้าหมายทั่วไป แพทย์อาจตั้งต่างจากนี้ตามอายุและโรคร่วม', 'The usual target — your doctor may set a different one for your age and other conditions')),
      TopicFact(t('< 70 มก./ดล.', '< 70 mg/dL'), t('ถือว่าน้ำตาลต่ำ ให้กินน้ำหวานหรือลูกอม 15 กรัมทันที', 'Counts as hypoglycaemia — take 15 g of something sweet at once')),
      TopicFact(t('ปีละ 1 ครั้ง', 'Once a year'), t('ตรวจจอตา การทำงานของไต และตรวจเท้าอย่างละเอียด', 'Retinal screening, kidney function, and a thorough foot check')),
    ],
    myths: [
      TopicMyth(
        t('เป็นเบาหวานเพราะกินหวานมากเพียงอย่างเดียว', 'Diabetes comes only from eating too much sugar'),
        t('ความหวานเป็นปัจจัยหนึ่ง แต่พันธุกรรม น้ำหนัก และการไม่ออกกำลังกายมีน้ำหนักพอกัน คนผอมที่ไม่กินหวานก็เป็นเบาหวานได้', 'Sugar is one factor, but genetics, weight and inactivity matter just as much. Thin people who avoid sweets still develop it.'),
      ),
      TopicMyth(
        t('ผลไม้เป็นน้ำตาลธรรมชาติ กินเท่าไหร่ก็ได้', 'Fruit is natural sugar, so any amount is fine'),
        t('น้ำตาลจากผลไม้ก็ทำให้น้ำตาลในเลือดขึ้นเช่นกัน ควรกินเป็นส่วนๆ พร้อมกากใย และเลี่ยงน้ำผลไม้คั้นที่ไม่มีกาก', 'Fruit sugar raises blood glucose too. Eat it in portions with the fibre intact, and avoid strained fruit juice.'),
      ),
      TopicMyth(
        t('น้ำตาลลงเป็นปกติแล้ว หยุดยาได้', 'My sugar is normal now, so I can stop the medicine'),
        t('ค่าที่ดีคือผลของยาและอาหารที่ทำอยู่ การหยุดเองทำให้น้ำตาลดีดกลับ การลดยาต้องให้แพทย์ปรับตามผลเลือด', 'The good number is the result of the medicine and diet you are on. Stopping sends it back up — only a doctor should reduce it, guided by your test results.'),
      ),
    ],
    specialtyKeywords: [t('เบาหวาน', 'Diabetes'), 'ต่อมไร้ท่อ', 'อายุรกรรม'],
  ),
  HealthTopic(
    key: 'epilepsy',
    label: t('ลมชัก', 'Epilepsy'),
    icon: Icons.bolt_outlined,
    summary: t('ภาวะที่สมองปล่อยคลื่นไฟฟ้าผิดปกติเป็นครั้งคราว', 'A condition where the brain occasionally fires abnormal electrical activity'),
    overview: t('ลมชักเกิดจากเซลล์สมองกลุ่มหนึ่งปล่อยสัญญาณไฟฟ้าพร้อมกันผิดจังหวะ อาการที่เห็นจึงขึ้นกับว่าเกิดที่สมองส่วนใด มีตั้งแต่เหม่อนิ่งไปไม่กี่วินาทีจนคนรอบข้างไม่ทันสังเกต ไปจนถึงเกร็งกระตุกทั้งตัว ลมชักไม่ใช่โรคติดต่อและไม่เกี่ยวกับเรื่องเหนือธรรมชาติ คนส่วนใหญ่คุมอาการได้ดีด้วยยาและใช้ชีวิต เรียน และทำงานได้ตามปกติ', 'A seizure happens when a group of brain cells fires electrically all at once, out of rhythm. What it looks like depends on where in the brain it starts — from a few seconds of blank staring that nobody notices, to whole-body convulsions. Epilepsy is not contagious and has nothing to do with the supernatural. Most people control it well on medication and study, work and live normally.'),
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
    riskTitle: t('สิ่งที่กระตุ้นให้ชัก', 'What sets off a seizure'),
    riskFactors: [
      t('อดนอน ลืมกินยา และดื่มแอลกอฮอล์ เป็นตัวกระตุ้นที่พบบ่อยที่สุด', 'Missed sleep, missed doses and alcohol are the commonest triggers'),
      t('ไข้สูงในเด็กเล็ก การบาดเจ็บที่ศีรษะ และการติดเชื้อในสมอง', 'High fever in small children, head injury, and brain infections'),
      t('แสงกะพริบถี่ในบางราย เช่น จอเกมหรือไฟตามสถานบันเทิง', 'Rapidly flashing light in some people — game screens, club lighting'),
      t('หลายรายตรวจไม่พบสาเหตุชัดเจน ซึ่งไม่ได้แปลว่ารักษาไม่ได้', 'In many people no clear cause is found, which does not mean it cannot be treated'),
    ],
    keyFacts: [
      TopicFact(t('5 นาที', '5 minutes'), t('ชักนานกว่านี้ถือเป็นภาวะฉุกเฉิน โทร 1669 ทันที', 'A seizure longer than this is an emergency — call 1669')),
      TopicFact(t('ห้ามงัดปาก', 'Never force the mouth'), t('คนชักไม่กลืนลิ้นตัวเอง การงัดปากทำให้ฟันหักและสำลัก', 'Nobody swallows their tongue — forcing the mouth breaks teeth and causes choking')),
      TopicFact(t('จับนอนตะแคง', 'Roll them on their side'), t('ช่วยให้น้ำลายไหลออกและไม่สำลัก', 'Lets saliva drain out and prevents choking')),
      TopicFact(t('2–5 ปี', '2–5 years'), t('ระยะที่ต้องปลอดชักก่อนแพทย์จะพิจารณาลดยา', 'How long seizure-free before a doctor considers reducing medication')),
    ],
    myths: [
      TopicMyth(
        t('คนชักต้องเอาช้อนงัดปากกันกัดลิ้น', 'You must put a spoon in the mouth to stop them biting their tongue'),
        t('อันตรายมากและทำให้ฟันหัก ขากรรไกรบาดเจ็บ และสำลักได้ ไม่มีใครกลืนลิ้นตัวเองขณะชัก สิ่งที่ถูกต้องคือจับนอนตะแคง เอาของแข็งออก และจับเวลา', 'This is dangerous — it breaks teeth, injures the jaw and causes choking. Nobody swallows their tongue during a seizure. Roll them on their side, clear hard objects away, and time it.'),
      ),
      TopicMyth(
        t('คนเป็นลมชักเรียนหรือทำงานไม่ได้', 'People with epilepsy cannot study or hold a job'),
        t('เมื่อคุมอาการได้ ส่วนใหญ่เรียนและทำงานได้ตามปกติ เพียงเลี่ยงงานที่เสี่ยงหากชักกะทันหัน เช่น ทำงานบนที่สูงหรือขับรถในช่วงที่ยังคุมไม่ได้', 'Once seizures are controlled, most people study and work normally. They only need to avoid tasks that would be dangerous during a seizure — working at height, or driving while control is not yet established.'),
      ),
    ],
    specialtyKeywords: ['ระบบประสาท', 'สมอง'],
  ),
  HealthTopic(
    key: 'mental_health',
    label: t('สุขภาพจิต', 'Mental health'),
    icon: Icons.self_improvement_outlined,
    summary: t('ความเครียด ซึมเศร้า วิตกกังวล — รักษาได้เหมือนโรคทางกาย', 'Stress, depression, anxiety — treatable like any physical illness'),
    overview: t('โรคซึมเศร้าและวิตกกังวลเกิดจากหลายปัจจัยประกอบกัน ทั้งสารสื่อประสาทในสมอง พันธุกรรม และเหตุการณ์ในชีวิต จึงไม่ใช่เรื่องของการคิดมากหรือจิตใจอ่อนแอ และไม่ใช่สิ่งที่สั่งให้หายได้ด้วยกำลังใจ โรคกลุ่มนี้ตอบสนองต่อการรักษาด้วยจิตบำบัดและยาได้ดีพอๆ กับที่โรคทางกายตอบสนองต่อการรักษา ยิ่งเริ่มเร็วยิ่งใช้เวลาน้อย', 'Depression and anxiety arise from several things at once — brain chemistry, genetics and life events. They are not overthinking or weakness of character, and they cannot be willed away. They respond to talking therapy and medication as well as physical illnesses respond to treatment, and the earlier treatment starts, the less of it is needed.'),
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
    riskFactors: [
      t('การสูญเสีย ความเครียดเรื้อรัง ปัญหาการเงิน และความสัมพันธ์ที่กดดัน', 'Bereavement, chronic stress, money troubles and strained relationships'),
      t('ประวัติซึมเศร้าหรือโรคทางจิตเวชในครอบครัว', 'A family history of depression or other psychiatric illness'),
      t('โรคทางกายบางอย่าง เช่น ไทรอยด์ผิดปกติ และยาบางชนิด ทำให้อารมณ์เปลี่ยนได้จริง', 'Some physical illnesses such as thyroid disorders, and some medicines, genuinely alter mood'),
      t('การอดนอนเรื้อรัง แอลกอฮอล์ และสารเสพติด ทำให้อาการแย่ลงเสมอ', 'Chronic sleep loss, alcohol and drugs always make it worse'),
    ],
    keyFacts: [
      TopicFact('1323', t('สายด่วนสุขภาพจิต ฟรี ตลอด 24 ชั่วโมง', 'Mental health helpline, free, 24 hours')),
      TopicFact(t('2 สัปดาห์', '2 weeks'), t('อาการต่อเนื่องนานกว่านี้ ควรปรึกษาผู้เชี่ยวชาญ', 'Symptoms lasting longer than this are worth professional advice')),
      TopicFact(t('2–4 สัปดาห์', '2–4 weeks'), t('ยาต้านซึมเศร้ามักเริ่มเห็นผลหลังจากนี้ ไม่ใช่ทันทีที่กิน', 'Antidepressants usually begin working after this, not straight away')),
      TopicFact(t('7–9 ชั่วโมง', '7–9 hours'), t('การนอนที่ช่วยให้อารมณ์คงที่ที่สุด', 'The amount of sleep that keeps mood most stable')),
    ],
    myths: [
      TopicMyth(
        t('ซึมเศร้าคือคิดมาก ทำใจเองได้ถ้าเข้มแข็งพอ', 'Depression is overthinking — you can snap out of it if you are strong enough'),
        t('เป็นภาวะทางการแพทย์ที่มีการเปลี่ยนแปลงของสารสื่อประสาทในสมองจริง การบอกให้สู้ๆ ไม่ได้ช่วย แต่จิตบำบัดและยาช่วยได้ชัดเจน', 'It is a medical condition with real changes in brain neurotransmitters. Telling someone to cheer up does not help; therapy and medication clearly do.'),
      ),
      TopicMyth(
        t('กินยาต้านซึมเศร้าแล้วจะติดยา', 'Antidepressants are addictive'),
        t('ยากลุ่มนี้ไม่ทำให้เสพติดแบบสารเสพติด ไม่ต้องเพิ่มขนาดเพื่อให้ได้ผลเท่าเดิม แต่ต้องค่อยๆ ลดตามที่แพทย์สั่ง ไม่หยุดกะทันหัน', 'They are not addictive in the way drugs of abuse are — the dose does not have to keep rising. They do need tapering under a doctor rather than stopping abruptly.'),
      ),
    ],
    specialtyKeywords: ['จิตเวช', t('สุขภาพจิต', 'Mental health')],
  ),
  HealthTopic(
    key: 'herbal',
    label: t('สมุนไพร', 'Herbal remedies'),
    icon: Icons.eco_outlined,
    summary: t('สมุนไพรก็มีฤทธิ์ยา จึงตีกับยาแผนปัจจุบันได้', 'Herbs act like drugs, so they can interact with prescribed medicine'),
    overview: t('สมุนไพรออกฤทธิ์ผ่านสารเคมีเช่นเดียวกับยาแผนปัจจุบัน และยาหลายตัวที่ใช้อยู่ทุกวันนี้ก็พัฒนามาจากพืช ข้อควรระวังจึงเหมือนกับยาทุกประการ คือ ขนาดที่ใช้ ผลข้างเคียง และการตีกับยาอื่น คำว่าธรรมชาติไม่ได้แปลว่าปลอดภัยโดยอัตโนมัติ ปัญหาที่พบบ่อยที่สุดในไทยคือผู้ป่วยกินสมุนไพรคู่กับยาประจำตัวโดยไม่ได้บอกแพทย์', 'Herbs work through chemicals in exactly the way pharmaceutical drugs do — many medicines in use today were developed from plants. The same cautions apply: dose, side effects and interactions. Natural does not automatically mean safe. The commonest problem seen in Thailand is a patient taking herbs alongside their regular medicine without telling the doctor.'),
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
    riskTitle: t('ความเสี่ยงที่พบบ่อย', 'Where the risk lies'),
    riskFactors: [
      t('ขมิ้นชัน กระเทียมสกัด และแปะก๊วย เพิ่มความเสี่ยงเลือดออกเมื่อกินคู่กับยาละลายลิ่มเลือด', 'Turmeric, garlic extract and ginkgo raise bleeding risk when combined with blood thinners'),
      t('ผู้ป่วยโรคตับและโรคไต ขับสารออกจากร่างกายได้ช้ากว่าคนทั่วไป จึงสะสมจนเป็นพิษง่ายกว่า', 'People with liver or kidney disease clear these substances more slowly, so they build up to harmful levels sooner'),
      t('ผลิตภัณฑ์ที่ไม่มีเลขทะเบียน เคยตรวจพบการปนเปื้อนสเตียรอยด์และโลหะหนัก', 'Unregistered products have been found contaminated with steroids and heavy metals'),
      t('ใช้ขนาดสูงกว่าฉลากระบุ หรือใช้ติดต่อกันนานกว่าที่แนะนำ', 'Taking more than the label states, or for longer than recommended'),
    ],
    keyFacts: [
      TopicFact(t('เลข อย.', 'FDA number'), t('ต้องมีบนฉลากทุกผลิตภัณฑ์ ตรวจสอบเลขได้ที่เว็บไซต์ อย.', 'Must appear on every product label — the number can be checked on the Thai FDA website')),
      TopicFact(t('ฟ้าทะลายโจร ไม่เกิน 5 วัน', 'Andrographis, max 5 days'), t('ไม่ควรใช้ต่อเนื่องนานกว่านี้โดยไม่ปรึกษา', 'Should not be taken longer without advice')),
      TopicFact('1556', t('สายด่วน อย. แจ้งหรือสอบถามผลิตภัณฑ์ที่สงสัย', 'Thai FDA hotline for checking or reporting a suspect product')),
      TopicFact(t('ตัวเหลือง ตาเหลือง', 'Yellow skin or eyes'), t('สัญญาณตับอักเสบ ให้หยุดสมุนไพรทันทีและพบแพทย์', 'A sign of liver injury — stop the herb at once and see a doctor')),
    ],
    myths: [
      TopicMyth(
        t('สมุนไพรเป็นของธรรมชาติ กินเท่าไหร่ก็ไม่อันตราย', 'Herbs are natural, so no amount can hurt you'),
        t('สมุนไพรหลายชนิดเป็นพิษต่อตับและไตเมื่อใช้ขนาดสูงหรือใช้ติดต่อกันนาน พิษเห็ดและพืชมีพิษก็เป็นของธรรมชาติเช่นกัน', 'Many herbs are toxic to the liver and kidneys at high doses or over long periods. Poisonous mushrooms and plants are natural too.'),
      ),
      TopicMyth(
        t('กินสมุนไพรควบคู่กับยาที่หมอสั่งได้ ไม่ต้องบอกหมอ', 'I can take herbs alongside my prescription without mentioning it'),
        t('สมุนไพรหลายชนิดเสริมหรือลดฤทธิ์ยา ทำให้เลือดออกง่าย น้ำตาลต่ำเกินไป หรือคุมโรคไม่ได้ ต้องแจ้งแพทย์และเภสัชกรทุกครั้ง', 'Many herbs strengthen or weaken prescribed drugs, causing bleeding, dangerously low blood sugar, or loss of disease control. Always tell your doctor and pharmacist.'),
      ),
    ],
    specialtyKeywords: ['เภสัช', 'แพทย์แผนไทย'],
  ),
  HealthTopic(
    key: 'vitamin',
    label: t('วิตามิน', 'Vitamins'),
    icon: Icons.medication_outlined,
    summary: t('คนที่กินอาหารครบหมู่ส่วนใหญ่ไม่จำเป็นต้องเสริมวิตามิน', 'Most people eating a balanced diet do not need supplements'),
    overview: t('วิตามินคือสารที่ร่างกายต้องการในปริมาณน้อยแต่ขาดไม่ได้ และคนที่กินอาหารหลากหลายส่วนใหญ่ได้ครบอยู่แล้ว วิตามินแบ่งเป็นสองกลุ่มที่ต่างกันมาก คือ ชนิดละลายในน้ำ (B และ C) ที่ส่วนเกินถูกขับออกทางปัสสาวะ กับชนิดละลายในไขมัน (A, D, E, K) ที่สะสมอยู่ในตับและไขมันของร่างกาย จึงเป็นกลุ่มที่กินเกินขนาดแล้วเป็นพิษได้จริง', 'Vitamins are needed in small amounts but cannot be done without, and most people eating varied food already get enough. They fall into two very different groups: water-soluble ones (B and C), whose excess is passed out in urine, and fat-soluble ones (A, D, E, K), which accumulate in the liver and body fat — and these are the ones that genuinely become toxic in overdose.'),
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
    riskTitle: t('ใครเสี่ยงขาดวิตามินจริง', 'Who genuinely risks a deficiency'),
    riskFactors: [
      t('กินมังสวิรัติหรือวีแกนเคร่งครัดโดยไม่เสริมวิตามิน B12', 'Strict vegetarians and vegans who do not supplement B12'),
      t('ผู้สูงอายุ คนที่อยู่แต่ในร่ม และผู้ที่ปกปิดผิวมิดชิด เสี่ยงขาดวิตามิน D', 'Older people, those who stay indoors, and anyone who keeps their skin covered risk low vitamin D'),
      t('ดื่มแอลกอฮอล์หนักเป็นประจำ ทำให้ขาดวิตามินบีหลายตัว', 'Heavy regular drinking causes several B-vitamin deficiencies'),
      t('เคยผ่าตัดลดขนาดกระเพาะ หรือมีโรคลำไส้ที่ทำให้ดูดซึมได้น้อยลง', 'Past bariatric surgery, or bowel disease that reduces absorption'),
    ],
    keyFacts: [
      TopicFact(t('10–15 นาที/วัน', '10–15 minutes a day'), t('แดดช่วงเช้าที่เพียงพอให้ผิวสังเคราะห์วิตามิน D', 'Enough morning sun for the skin to make vitamin D')),
      TopicFact(t('400 ไมโครกรัม/วัน', '400 micrograms a day'), t('โฟลิกที่แนะนำก่อนตั้งครรภ์และช่วงไตรมาสแรก', 'The folic acid advised before pregnancy and through the first trimester')),
      TopicFact(t('วิตามิน A เกิน 10,000 IU/วัน', 'Vitamin A above 10,000 IU a day'), t('ขนาดสูงต่อเนื่องเสี่ยงเป็นพิษ อันตรายเป็นพิเศษในหญิงตั้งครรภ์', 'Sustained high doses risk toxicity, and are especially dangerous in pregnancy')),
      TopicFact('1367', t('สายด่วนศูนย์พิษวิทยา เมื่อเด็กกินวิตามินหรือยาเกินขนาด', 'Poison centre hotline if a child swallows too many vitamins or pills')),
    ],
    myths: [
      TopicMyth(
        t('วิตามินซีขนาดสูงป้องกันหวัดได้', 'High-dose vitamin C prevents colds'),
        t('งานวิจัยพบว่าลดระยะเวลาที่เป็นหวัดลงได้เล็กน้อยเท่านั้น และไม่ได้ป้องกันการติดเชื้อ ส่วนที่เกินความต้องการถูกขับทิ้งทางปัสสาวะ', 'Studies show it shortens a cold slightly at best and does not prevent infection. What the body does not need is passed out in urine.'),
      ),
      TopicMyth(
        t('กินวิตามินเยอะๆ ไม่เสียหาย เกินแล้วร่างกายก็ขับออกเอง', 'Extra vitamins do no harm — the body just gets rid of the surplus'),
        t('จริงเฉพาะวิตามินที่ละลายในน้ำ ส่วน A, D, E และ K สะสมในร่างกายและเป็นพิษต่อตับและกระดูกได้เมื่อได้รับมากเกินไปนานๆ', 'True only for the water-soluble ones. A, D, E and K accumulate and can poison the liver and bones when taken in excess over time.'),
      ),
    ],
    specialtyKeywords: ['เภสัช', 'โภชนาการ'],
  ),
  HealthTopic(
    key: 'genetics',
    label: t('พันธุศาสตร์', 'Genetics'),
    icon: Icons.biotech_outlined,
    summary: t('โรคที่ถ่ายทอดในครอบครัว และการวางแผนตรวจคัดกรอง', 'Conditions that run in families, and planning screening'),
    overview: t('ยีนที่ได้รับจากพ่อแม่กำหนดความเสี่ยงต่อโรคบางอย่าง แต่ไม่ได้กำหนดว่าจะเป็นแน่นอน โรคส่วนใหญ่เกิดจากยีนทำงานร่วมกับพฤติกรรมและสิ่งแวดล้อม ประโยชน์ที่แท้จริงของการรู้ประวัติครอบครัวจึงไม่ใช่การทำนายอนาคต แต่คือการรู้ว่าควรเริ่มตรวจคัดกรองเมื่อไหร่และบ่อยแค่ไหน ซึ่งเป็นสิ่งที่เปลี่ยนผลลัพธ์ได้จริง', 'The genes you inherit set your risk for certain conditions but do not decide the outcome — most diseases arise from genes acting together with behaviour and environment. The real value of knowing your family history is not prediction but timing: it tells you when to start screening and how often, and that is what actually changes outcomes.'),
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
    riskTitle: t('สัญญาณว่าควรปรึกษาเรื่องพันธุกรรม', 'Signs it is worth asking about genetics'),
    riskFactors: [
      t('ธาลัสซีเมียพบพาหะได้ราว 1 ใน 3 ของคนไทย จึงควรตรวจก่อนแต่งงานหรือวางแผนมีบุตร', 'About one in three Thais carries a thalassaemia gene, so testing before marriage or pregnancy is worthwhile'),
      t('ญาติสายตรงเป็นมะเร็งเต้านมหรือมะเร็งลำไส้ก่อนอายุ 50 ปี', 'A close relative with breast or bowel cancer before the age of 50'),
      t('ญาติสายตรงเป็นโรคหัวใจ ผู้ชายก่อนอายุ 55 ปี หรือผู้หญิงก่อน 65 ปี', 'A close relative with heart disease — a man before 55, or a woman before 65'),
      t('มีสมาชิกหลายคนในครอบครัวเป็นโรคเดียวกันข้ามรุ่น', 'Several family members across generations with the same condition'),
    ],
    keyFacts: [
      TopicFact(t('3 รุ่น', '3 generations'), t('จำนวนรุ่นที่ควรบันทึกในผังประวัติสุขภาพครอบครัว', 'How far back a family health history should reach')),
      TopicFact(t('1 ใน 4', '1 in 4'), t('โอกาสที่ลูกจะเป็นโรค เมื่อพ่อและแม่เป็นพาหะธาลัสซีเมียชนิดเดียวกัน', 'The chance a child is affected when both parents carry the same thalassaemia gene')),
      TopicFact(t('เร็วกว่า 10 ปี', '10 years earlier'), t('หลักคร่าวๆ ในการเริ่มคัดกรอง เทียบกับอายุที่ญาติเริ่มเป็น', 'A rough rule for when to start screening, relative to the age a relative was diagnosed')),
      TopicFact(t('ก่อนตั้งครรภ์', 'Before pregnancy'), t('ช่วงที่ปรึกษาพันธุศาสตร์ได้ประโยชน์มากที่สุด เพราะยังมีทางเลือกครบ', 'When genetic counselling helps most, because every option is still open')),
    ],
    myths: [
      TopicMyth(
        t('ครอบครัวเป็นโรคนี้กันหมด ยังไงเราก็ต้องเป็น', 'It runs in my family, so I am bound to get it'),
        t('ยีนบอกความเสี่ยง ไม่ใช่คำตัดสิน การคัดกรองตั้งแต่เนิ่นๆ ร่วมกับการปรับพฤติกรรม เปลี่ยนผลลัพธ์ได้มากในโรคส่วนใหญ่', 'Genes describe risk, not destiny. Early screening plus changes in how you live alter the outcome substantially for most conditions.'),
      ),
      TopicMyth(
        t('ตรวจพันธุกรรมออนไลน์ครั้งเดียวก็รู้ทุกอย่าง', 'One online genetic test tells you everything'),
        t('ชุดตรวจทั่วไปดูยีนได้จำกัดมากและแปลผลยาก ผลที่ออกมาว่าไม่พบความผิดปกติไม่ได้แปลว่าปลอดภัย ควรให้แพทย์เป็นผู้แปลผลเสมอ', 'Consumer kits look at a very limited set of genes and are hard to interpret. A negative result does not mean you are in the clear — always have a doctor read it.'),
      ),
    ],
    specialtyKeywords: [t('พันธุศาสตร์', 'Genetics'), 'สูตินรีเวช'],
  ),
  HealthTopic(
    key: 'checkup',
    label: t('ตรวจสุขภาพ', 'Health checks'),
    icon: Icons.monitor_heart_outlined,
    summary: t('ตรวจอะไร เมื่อไหร่ ตามอายุและความเสี่ยงของแต่ละคน', 'What to check and when, based on your age and risks'),
    overview: t('การตรวจสุขภาพที่ดีไม่ใช่การตรวจให้มากที่สุด แต่คือการตรวจให้ตรงกับอายุ เพศ และความเสี่ยงของแต่ละคน การตรวจที่ไม่จำเป็นมักเจอสิ่งผิดปกติเล็กๆ ที่ไม่มีความหมายทางการแพทย์ แล้วนำไปสู่การตรวจเพิ่มที่มีความเสี่ยงและค่าใช้จ่ายโดยไม่ได้ประโยชน์ สิ่งที่คุ้มค่าที่สุดสำหรับคนทั่วไปคือ ความดัน น้ำตาล ไขมัน น้ำหนัก และการคัดกรองมะเร็งตามช่วงอายุ', 'A good health check is not the one with the most tests, but the one matched to your age, sex and risks. Unnecessary tests often turn up small findings of no medical meaning, which then lead to further tests carrying real risk and cost for no benefit. For most people the worthwhile ones are blood pressure, blood sugar, cholesterol, weight, and the cancer screening appropriate to their age.'),
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
    riskTitle: t('ใครควรตรวจถี่กว่าคนทั่วไป', 'Who should be checked more often'),
    riskFactors: [
      t('สูบบุหรี่ หรือดื่มแอลกอฮอล์เป็นประจำ', 'Smokers, and regular drinkers'),
      t('น้ำหนักเกินหรือรอบเอวเกินเกณฑ์', 'Anyone overweight or above the waist threshold'),
      t('มีพ่อแม่พี่น้องเป็นเบาหวาน ความดันสูง หรือมะเร็ง', 'A parent or sibling with diabetes, high blood pressure or cancer'),
      t('เคยมีผลตรวจผิดปกติมาก่อน หรืออยู่ระหว่างติดตามอาการ', 'A previous abnormal result, or an ongoing issue being followed'),
    ],
    keyFacts: [
      TopicFact(t('อายุ 35 ปี', 'Age 35'), t('ช่วงที่ควรเริ่มตรวจความดัน น้ำตาล และไขมันเป็นระยะ', 'When to start periodic blood pressure, sugar and cholesterol checks')),
      TopicFact(t('อายุ 45–50 ปี', 'Age 45–50'), t('ช่วงที่แนะนำให้เริ่มคัดกรองมะเร็งลำไส้ใหญ่', 'When bowel-cancer screening is usually advised to begin')),
      TopicFact(t('รอบเอว', 'Waist'), t('ผู้ชายไม่เกิน 90 ซม. ผู้หญิงไม่เกิน 80 ซม.', 'Men under 90 cm, women under 80 cm')),
      TopicFact(t('8–12 ชั่วโมง', '8–12 hours'), t('งดอาหารก่อนเจาะเลือดตรวจน้ำตาลและไขมัน ดื่มน้ำเปล่าได้', 'Fast before blood sugar and cholesterol tests — plain water is fine')),
    ],
    myths: [
      TopicMyth(
        t('ตรวจสุขภาพยิ่งแพงยิ่งละเอียด ยิ่งดี', 'The more expensive and extensive the package, the better'),
        t('แพ็กเกจราคาสูงมักพ่วงรายการที่ไม่จำเป็นสำหรับคนทั่วไป และการตรวจเกินจำเป็นนำไปสู่การตรวจซ้ำที่เสี่ยงและสิ้นเปลือง การตรวจให้ตรงกับความเสี่ยงของตัวเองได้ประโยชน์กว่ามาก', 'Expensive packages bundle tests most people do not need, and over-testing leads to further investigations that carry risk and cost. Testing matched to your own risk is far more useful.'),
      ),
      TopicMyth(
        t('ผลตรวจปกติแปลว่าปลอดภัยไปทั้งปี', 'A normal result means I am safe for the whole year'),
        t('ผลตรวจบอกสภาพร่างกาย ณ วันที่ตรวจเท่านั้น หากมีอาการผิดปกติระหว่างปี ต้องพบแพทย์ทันที ไม่ต้องรอรอบตรวจถัดไป', 'A result describes your body on the day of the test. If something changes during the year, see a doctor then — do not wait for the next round.'),
      ),
    ],
    specialtyKeywords: [t('ตรวจสุขภาพ', 'Health checks'), 'เวชศาสตร์ครอบครัว', 'อายุรกรรม'],
  ),
  HealthTopic(
    key: 'dental',
    label: t('ทันตกรรม', 'Dental'),
    icon: Icons.medical_information_outlined,
    summary: t('สุขภาพช่องปากเชื่อมโยงกับเบาหวานและโรคหัวใจมากกว่าที่คิด', 'Oral health is linked to diabetes and heart disease more than people expect'),
    overview: t('ฟันผุและโรคเหงือกเริ่มจากคราบจุลินทรีย์ที่เกาะบนผิวฟัน แบคทีเรียในคราบนี้ย่อยน้ำตาลแล้วปล่อยกรดออกมากัดเคลือบฟัน และทำให้เหงือกอักเสบจนเลือดออก เมื่อคราบแข็งตัวเป็นหินปูนแล้ว การแปรงฟันเอาออกไม่ได้อีก ต้องให้ทันตแพทย์ขูด โรคเหงือกเรื้อรังยังสัมพันธ์กับการคุมเบาหวานที่แย่ลงและความเสี่ยงโรคหัวใจ จึงไม่ใช่เรื่องของช่องปากอย่างเดียว', 'Tooth decay and gum disease begin with plaque clinging to the tooth surface. Bacteria in it turn sugar into acid that eats the enamel and inflames the gums until they bleed. Once plaque hardens into tartar, brushing can no longer remove it and a dentist has to scale it off. Long-standing gum disease is also linked to worse diabetes control and higher heart-disease risk, so it is not only a mouth problem.'),
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
    riskFactors: [
      t('จิบเครื่องดื่มหวานหรือกินขนมบ่อยๆ ระหว่างวัน อันตรายกว่ากินหวานทีเดียวแล้วจบ', 'Sipping sweet drinks or snacking through the day is worse for teeth than eating something sweet in one sitting'),
      t('แปรงฟันไม่ทั่วถึง โดยเฉพาะซอกฟันที่ขนแปรงเข้าไม่ถึง จึงต้องใช้ไหมขัดฟัน', 'Missing spots when brushing, especially between the teeth where bristles cannot reach — which is what floss is for'),
      t('สูบบุหรี่ ทำให้เหงือกอักเสบเรื้อรังและแผลในปากหายช้า', 'Smoking drives chronic gum inflammation and slows healing in the mouth'),
      t('ปากแห้งจากยาบางชนิดหรือจากอายุ ทำให้ฟันผุง่ายขึ้นมาก', 'A dry mouth from medication or age makes decay much more likely'),
    ],
    keyFacts: [
      TopicFact(t('2 ครั้ง × 2 นาที', 'Twice × 2 minutes'), t('การแปรงฟันต่อวัน โดยครั้งสำคัญที่สุดคือก่อนนอน', 'Brushing per day — the one before bed matters most')),
      TopicFact('1,000–1,500 ppm', t('ปริมาณฟลูออไรด์ในยาสีฟันสำหรับผู้ใหญ่', 'The fluoride level to look for in adult toothpaste')),
      TopicFact(t('ทุก 6 เดือน', 'Every 6 months'), t('ความถี่ในการตรวจฟันและขูดหินปูน', 'How often to have a check-up and scale')),
      TopicFact(t('2 สัปดาห์', '2 weeks'), t('แผลในปากที่ไม่หายเกินนี้ ต้องให้ทันตแพทย์ตรวจ', 'A mouth ulcer lasting longer than this needs a dentist to look at it')),
    ],
    myths: [
      TopicMyth(
        t('เลือดออกตอนแปรงฟันเป็นเรื่องปกติ แปรงเบาลงก็หาย', 'Bleeding when brushing is normal — just brush more gently'),
        t('เลือดออกคือสัญญาณของเหงือกอักเสบ ไม่ใช่เรื่องปกติ และการเลี่ยงไม่แปรงบริเวณนั้นยิ่งทำให้แย่ลง ควรแปรงให้ถูกวิธีร่วมกับใช้ไหมขัดฟัน และพบทันตแพทย์', 'Bleeding is a sign of inflamed gums, not something normal — and avoiding the area makes it worse. Brush properly, floss, and see a dentist.'),
      ),
      TopicMyth(
        t('ไม่ปวดฟันก็ไม่ต้องไปหาหมอฟัน', 'No toothache means no need to see a dentist'),
        t('ฟันผุระยะแรกและหินปูนไม่ทำให้ปวดเลย กว่าจะปวดมักลามถึงโพรงประสาทแล้ว ซึ่งรักษายากกว่าและแพงกว่าหลายเท่า', 'Early decay and tartar cause no pain at all. By the time it hurts it has usually reached the nerve, which is far harder and several times more expensive to treat.'),
      ),
    ],
    specialtyKeywords: [t('ทันตกรรม', 'Dental'), 'ทันตแพทย์'],
  ),
  HealthTopic(
    key: 'anti_aging',
    label: t('ชะลอวัย', 'Ageing well'),
    icon: Icons.spa_outlined,
    summary: t('สิ่งที่มีหลักฐานรองรับจริง คือ นอน อาหาร ออกกำลังกาย และกันแดด', 'What actually has evidence behind it: sleep, diet, exercise and sun protection'),
    overview: t('ความชราคือการที่เซลล์เสื่อมสภาพลงตามเวลา ซึ่งเร่งให้เร็วขึ้นได้ด้วยแสงแดด บุหรี่ การอดนอน และการอักเสบเรื้อรัง ปัจจุบันยังไม่มีอาหารเสริมหรือฮอร์โมนชนิดใดที่พิสูจน์ได้ว่าทำให้มนุษย์อายุยืนขึ้น สิ่งที่มีหลักฐานหนักแน่นที่สุดยังคงเป็นเรื่องพื้นฐานและราคาถูก คือ การนอน อาหาร การออกกำลังกาย และการกันแดด ซึ่งได้ผลทั้งกับผิวและกับอายุขัย', 'Ageing is cells wearing down over time, sped up by sun, smoking, lost sleep and chronic inflammation. No supplement or hormone has been shown to extend human lifespan. What has the strongest evidence remains basic and cheap — sleep, diet, exercise and sun protection — and it works on both the skin and the years.'),
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
      t('ระวังคำโฆษณาที่อ้างว่าคืนความอ่อนเยาว์ โดยไม่มีงานวิจัยรองรับ', 'Be wary of advertising that promises to restore youth without research behind it'),
    ],
    riskTitle: t('อะไรเร่งให้แก่เร็วขึ้น', 'What speeds ageing up'),
    riskFactors: [
      t('แสงแดดสะสมเป็นสาเหตุของริ้วรอยและจุดด่างดำบนใบหน้าถึงราว 80%', 'Cumulative sun exposure accounts for around 80% of facial wrinkles and dark spots'),
      t('บุหรี่ทำลายคอลลาเจนและทำให้ผิวเหี่ยวเร็วขึ้นอย่างเห็นได้ชัด', 'Smoking destroys collagen and visibly accelerates skin ageing'),
      t('นอนน้อยกว่า 6 ชั่วโมงเป็นประจำ กระทบทั้งผิว ความจำ และภูมิคุ้มกัน', 'Habitually sleeping under 6 hours affects skin, memory and immunity alike'),
      t('อาหารแปรรูปและน้ำตาลสูง ทำให้เกิดการอักเสบเรื้อรังทั่วร่างกาย', 'Processed food and high sugar drive chronic inflammation throughout the body'),
    ],
    keyFacts: [
      TopicFact(t('SPF 30 ขึ้นไป', 'SPF 30 or above'), t('ครีมกันแดดที่แนะนำ ทาซ้ำทุก 2–3 ชั่วโมงเมื่ออยู่กลางแจ้ง', 'The sunscreen to use, reapplied every 2–3 hours outdoors')),
      TopicFact(t('2 ครั้ง/สัปดาห์', 'Twice a week'), t('การออกกำลังแบบมีแรงต้าน เพื่อรักษามวลกล้ามเนื้อไว้', 'Resistance training, to hold on to muscle mass')),
      TopicFact(t('7–9 ชั่วโมง', '7–9 hours'), t('การนอนต่อคืนที่ร่างกายซ่อมแซมตัวเองได้เต็มที่', 'Sleep per night, which is when the body does its repair')),
      TopicFact('ABCDE', t('หลักสังเกตไฝผิดปกติ: ไม่สมมาตร ขอบไม่เรียบ สีไม่สม่ำเสมอ ใหญ่กว่า 6 มม. และเปลี่ยนแปลง', 'Checking a mole: Asymmetry, irregular Border, uneven Colour, Diameter over 6 mm, and Evolving')),
    ],
    myths: [
      TopicMyth(
        t('คอลลาเจนแบบกินช่วยให้ผิวเต่งตึงแน่นอน', 'Drinking collagen definitely firms the skin'),
        t('หลักฐานยังจำกัดและผลไม่ชัดเจน คอลลาเจนที่กินเข้าไปถูกย่อยเป็นกรดอะมิโนเหมือนโปรตีนทั่วไป ร่างกายไม่ได้ส่งกลับไปที่ผิวโดยตรง การกันแดดให้ผลชัดกว่ามากในราคาที่ถูกกว่า', 'The evidence is thin and inconsistent. Swallowed collagen is broken down into amino acids like any protein; the body does not route it back to the skin. Sun protection does far more, for far less.'),
      ),
      TopicMyth(
        t('ครีมกันแดดใช้เฉพาะวันที่แดดจัด', 'Sunscreen is only for bright sunny days'),
        t('รังสี UVA ซึ่งเป็นตัวหลักที่ทำให้ผิวแก่ ทะลุเมฆและกระจกหน้าต่างได้ จึงควรทาทุกวันแม้อยู่ในร่มหรือวันที่ฟ้าครึ้ม', 'UVA — the wavelength mainly responsible for skin ageing — passes through cloud and window glass, so it is worth applying every day, indoors or overcast.'),
      ),
    ],
    specialtyKeywords: ['ผิวหนัง', 'เวชศาสตร์ชะลอวัย'],
  ),
  HealthTopic(
    key: 'general',
    label: t('ทั่วไป', 'General'),
    icon: Icons.local_hospital_outlined,
    summary: t('ไม่แน่ใจว่าอาการเข้าหมวดไหน ถามรวมได้ที่นี่', 'Not sure which topic fits? Ask here.'),
    overview: t('อาการอย่างไข้ ไอ หรือปวดเมื่อยตามตัว เกิดได้จากโรคที่ต่างกันมาก สิ่งที่ช่วยแยกได้ดีที่สุดมีสี่อย่าง คือ อาการเริ่มเมื่อไหร่ กำลังดีขึ้นหรือแย่ลง มีอาการอะไรร่วมด้วย และมีโรคประจำตัวหรือยาที่กินอยู่หรือไม่ สี่ข้อนี้คือสิ่งที่แพทย์ถามเป็นอันดับแรกเสมอ การเตรียมคำตอบไว้ล่วงหน้าทำให้ได้คำแนะนำที่ตรงกว่ามาก ทั้งในแอปและเมื่อไปพบแพทย์จริง', 'Symptoms like fever, cough or aching can come from very different illnesses. Four things separate them best: when it started, whether it is improving or worsening, what else came with it, and what conditions or medicines you already have. These are what a doctor asks first, every time — having the answers ready gets you far more useful advice, here and in the clinic.'),
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
    riskTitle: t('เตรียมตัวก่อนถามหรือไปพบแพทย์', 'Getting ready to ask, or to go in'),
    riskFactors: [
      t('จดวันที่เริ่มมีอาการ และอาการเปลี่ยนไปอย่างไรในแต่ละวัน', 'Note the day symptoms started, and how they have changed since'),
      t('วัดไข้แล้วจดค่าไว้ ถ้ามีเครื่องวัดความดันหรือน้ำตาลก็จดด้วย', 'Take your temperature and write it down — plus blood pressure or sugar if you have a monitor'),
      t('ถ่ายรูปผื่นหรือแผลเก็บไว้ เพราะอาจจางลงก่อนได้พบแพทย์', 'Photograph a rash or wound — it may fade before anyone can look at it'),
      t('เตรียมรายชื่อยา อาหารเสริม และสมุนไพรที่กินอยู่ทั้งหมด', 'Have a full list ready of every medicine, supplement and herb you take'),
    ],
    keyFacts: [
      TopicFact('1669', t('สายด่วนฉุกเฉิน เจ็บหน้าอก หายใจไม่ออก หรืออ่อนแรงครึ่งซีก', 'Emergency line — chest pain, breathing trouble, or weakness down one side')),
      TopicFact('1330', t('สายด่วน สปสช. เรื่องสิทธิบัตรทองและการรักษา', 'National Health Security hotline for coverage and treatment rights')),
      TopicFact('38 °C', t('อุณหภูมิที่ถือว่ามีไข้', 'The temperature at which it counts as a fever')),
      TopicFact(t('3 วัน', '3 days'), t('ไข้สูงต่อเนื่องเกินนี้ ควรพบแพทย์', 'A high fever lasting longer than this should be seen')),
    ],
    myths: [
      TopicMyth(
        t('เป็นหวัดต้องกินยาปฏิชีวนะให้หายเร็ว', 'A cold needs antibiotics to clear up faster'),
        t('หวัดส่วนใหญ่เกิดจากไวรัส ซึ่งยาปฏิชีวนะไม่มีผลเลย การใช้พร่ำเพรื่อทำให้เชื้อดื้อยาและเสี่ยงผลข้างเคียงโดยไม่ได้ประโยชน์', 'Most colds are viral, and antibiotics do nothing to viruses. Using them anyway breeds resistant bacteria and risks side effects for no gain.'),
      ),
      TopicMyth(
        t('ไข้สูงต้องเช็ดตัวด้วยน้ำเย็นหรือแอลกอฮอล์', 'A high fever should be sponged with cold water or alcohol'),
        t('ให้ใช้น้ำอุ่นเช็ดตัว น้ำเย็นทำให้หนาวสั่นและอุณหภูมิร่างกายสูงขึ้นกว่าเดิม ส่วนแอลกอฮอล์ดูดซึมผ่านผิวหนังได้และเป็นอันตราย โดยเฉพาะในเด็ก', 'Use lukewarm water. Cold water causes shivering, which drives the temperature higher, and alcohol is absorbed through the skin and is dangerous, especially in children.'),
      ),
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
