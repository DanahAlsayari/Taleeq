import 'package:flutter/material.dart';
import 'pre_assessment_intro_screen.dart';
import 'pre_assesment_success_screen.dart';

class PreAssessmentQuestionsScreen extends StatefulWidget {

const PreAssessmentQuestionsScreen({super.key});

  @override
  State<PreAssessmentQuestionsScreen> createState() => _PreAssessmentQuestionsScreenState();

}

class _PreAssessmentQuestionsScreenState extends State<PreAssessmentQuestionsScreen> {

int currentQuestionIndex = 0;

final Map<int, Set<String>> answers = {};

// Questions list
  final List<Map<String, dynamic>> questions = [
    
    {
      'question': 'متى بدأت التأتأة لديك ؟',
      'subtitle': 'اختر إجابة واحدة',
      'multiple': false,
      'options': [
        'منذ الطفولة',
        'في مرحلة المراهقة',
        'في مرحلة البلوغ',
        'لست متأكدًا',
       ],
    },
    {
      'question': 'كيف تصف بدايةالتأتأة لديك ؟',
      'subtitle': 'اختر إجابة واحدة',
      'multiple': false,
      'options': [
        'بدأت في الطفولج بشكل تدريجي',
         'يوجد تاريخ عائلي للتأتأة',
         'بدأت بشكل مفاجئ',
         'بدأت بعد ضغط او تجربة نفسية صعبة',
         'بدأت بعد إصابة أو حادث',
         'بدأت بعد مشكلة صحية أو عصبية',
         'بدأت بعد دواء أو علاج',
         'لا أعرف أو لا أتذكر',],
    },
    {
      'question': 'هل سبق أن تلقيت جلسات علاج نطق/تخاطب للتأتأة ؟',
      'subtitle': 'اختر إجابة واحدة',
      'multiple': false,
      'options': ['نعم', 'لا'],
    },

    {
      'question': 'هل تتجنب أو تستبدل كلمات لأنك تتوقع انك ستتأتئ فيها ؟',
      'subtitle': 'اختر إجابة واحدة',
      'multiple': false,
      'options': ['غالبا','أحيانا', 'أبدا'],
    },

      {
      'question': 'في أي مواقف تزداد التأتأة لديك ؟',
      'subtitle': 'اختر جميع الإجابات التي تنطبق عليك',
      'multiple': true,
      'options': ['التحدث مع اشخاص جدد','المكالمات الهاتفية', 'العروض والتحدث أمام مجموعة', 'القراءة بصوت مرتفع', 'المحادثات اليومية','مواقف أخرى'],
    },

    {
      'question': 'ماذا تريد ان تحسن ؟',
      'subtitle': 'اختر جميع الإجابات التي تنطبق عليك',
      'multiple': true,
      'options': ['التحدث براحة أكبر','المحادثات اليومية', 'التقديم والعروض', 'المكالمات الهاتفية', 'مقابلات العمل','تقليل التوقف أثناء الكلام', 'تقليل الشد والتوتر أثناء الكلام',],
    },
  ];


  @override
  Widget build(BuildContext context) {
    final currentQuestion = questions[currentQuestionIndex];
    final hasAnswer = answers[currentQuestionIndex]?.isNotEmpty ?? false;

    return Scaffold(
      backgroundColor: Color(0xFFFCFAF6),
      body: Directionality(
        textDirection: TextDirection.rtl,
      child:SafeArea(
        child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children:  [
                Stack(children: [Align(
              alignment: AlignmentDirectional.centerStart,
            child: IconButton(
              onPressed: (){
                if (currentQuestionIndex > 0) {
                      setState(() {
                        currentQuestionIndex--;
                      });
                    } else {
                      Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PreAssessmentIntroScreen()), );

                    }
                      },
              icon: const Icon (Icons.arrow_back,),
            ),
            ),
            const SizedBox(width: 120.0,),

            Column(
              children: [

            Text ("6/${currentQuestionIndex + 1}", style: const TextStyle(color: const Color(0xFF8FA39F), fontWeight: FontWeight.bold),),
            const SizedBox(height: 12.0,),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(questions.length, (index) {
                return Container(
                  width: 20.0,
                  height: 8.0,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  decoration: BoxDecoration(
                    color: index <= currentQuestionIndex ? const Color(0xFF6FA7A3) : const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                );
              }),
            )


            ],),

                ]),
                const SizedBox(height: 20.0,),

                Text(
                  currentQuestion['question'],
                  style: const TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
                ),
                                const SizedBox(height: 12.0),
                Text(
                  currentQuestion['subtitle'],
                  style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.normal, color: Color.fromARGB(255, 138, 138, 138)),
                ),
                const SizedBox(height: 16.0),

                ...currentQuestion['options'].map<Widget>((option){
                  final isSelected = answers[currentQuestionIndex]?.contains(option) ?? false;

                  return GestureDetector(
                    onTap: (){


                      
                      setState(() {
                        if (currentQuestion['multiple'] == true) {

                          answers.putIfAbsent(currentQuestionIndex,() => {}) ;
                          if (isSelected) {
                            answers[currentQuestionIndex]?.remove(option);
                          } else {
                            answers[currentQuestionIndex]?.add(option);
                          }
                        }


                        else{
                        answers[currentQuestionIndex] = {option}; }
                      });
                    },
                  


                  child:  Container(
                    width: double.infinity,
                    height: 60,
                    margin: const EdgeInsets.all(7.0),
                    padding: const EdgeInsets.all(13.0),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color.fromARGB(255, 240, 255, 251): const Color.fromARGB(255, 255, 255, 255),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: isSelected ? const Color.fromARGB(255, 182, 202, 205) : const Color.fromARGB(255, 219, 230, 229), width: 1.0),
                    ),
                    child : Row(
                    
                    children: [
                      isSelected ? const Icon (Icons.check_circle, size: 20.0, color: Color(0xFF6FA7A3),) : const Icon (Icons.circle_outlined, size: 20.0, color: Color.fromARGB(255, 219, 230, 229),),
                      const SizedBox(width: 8.0),
                      Text (option, 
                      style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.normal, color: Color.fromARGB(255, 0, 0, 0),) ),
                    ],

                    )
                  )

       


                  );

                }).toList(),

                
                
                

              
              ],
            ),
          ),
        ),
        
      ),
      )
      ,bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20.0),
 
                  child: SizedBox(
                    height: 60.0,
                    child: ElevatedButton(
                  onPressed: hasAnswer ? () {
                    if (currentQuestionIndex < questions.length - 1) {
                      setState(() {
                        currentQuestionIndex++;
                      });
                    } else {
                      // Handle submission of answers here
                      Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PreAssessmentSuccessScreen()), );

                      print('Answers: $answers');
                    } 
                  } :  null ,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6FA7A3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ), child: Text( ( currentQuestionIndex == questions.length - 1 ? "إرسال" : "التالي"), style: TextStyle(fontSize: 16.0, color: Colors.white),),
                  ),
                  ),
                  
              
      ),
    );

    
  }

}