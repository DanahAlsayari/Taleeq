import 'package:flutter/material.dart';
import 'speech_assesment_intro_screen.dart' ;

class SpeechAssesmentQuestionsScreen extends StatefulWidget {

const SpeechAssesmentQuestionsScreen({super.key});

  @override
  State<SpeechAssesmentQuestionsScreen> createState() => _SpeechAssesmentQuestionsScreen();

}

class _SpeechAssesmentQuestionsScreen extends State<SpeechAssesmentQuestionsScreen> {

int currentQuestionIndex = 0;

final Map<int, Set<String>> answers = {};

// Questions list
  final List<Map<String, dynamic>> questions = [
    
    {
      'title': 'المهمة ١ من ٣',
      'category' : 'القراءة',
      'instruction': 'اقرأ الفقرة بصوت عال بإيقاعك الطبيعي، خذ وقتك ولاتتسرع',
      'type': 'text',
      'content': 'الحديقة القريبة من منزلي مكانٌ هادئ. في الصباح، أحب أن أتمشى فيها وأستمع إلى أصوات الطيور. أحياناً أجلس على المقعد بجانب النافورة وأراقب السحب وهي تمرّ. يذكّرني ذلك بأن بعض أجمل لحظات الحياة هي تلك البسيطة',
    },
    {
      'title': 'المهمة ٢ من ٣',
      'category' : 'وصف صورة',
      'instruction': 'صف ماتراه في الصورة بكلماتك الخاصة، تحدث بشكل طبيعي ومريح',
      'type': 'image',
      'content': 'assets/images/image.png',
    },
    {
      'title': 'المهمة ٣ من ٣',
      'category' : 'الحديث الحر',
      'instruction': 'تحدث عن نفسك ، خذ وقتك وتحدث بطريقتك الطبيعية بدون تحضير مسبق',
      'type': 'self',
      'content': 'this is the text"',
    },

  ];


  @override
  Widget build(BuildContext context) {
    final currentQuestion = questions[currentQuestionIndex];

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
                  MaterialPageRoute(builder: (context) => const SpeechAssesmentIntroScreen()), );

                      
                    }
                      },
              icon: const Icon (Icons.arrow_back,),
            ),
            ),
            const SizedBox(width: 120.0,),

            Column(
              children: [

            Text ("${questions.length}/${currentQuestionIndex + 1}", style: const TextStyle(color: const Color(0xFF8FA39F), fontWeight: FontWeight.bold),),
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
            Row(
            children: [

              Align(
            alignment: AlignmentDirectional.centerStart,
            child:Container(
              width: MediaQuery.of(context).size.width/4,
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                color: const Color(0xFFCFE4E1),
                borderRadius: BorderRadius.circular(18),
              ),
              child :Align(
                alignment: AlignmentDirectional.center,
                child: Text (currentQuestion['title'] ,style: const TextStyle(color: const Color(0xFF1F5F5A), fontWeight: FontWeight.bold , fontSize: 14) , ),
                )
              ),
            ),    
            const SizedBox(width: 6.0,),
          

            Container(
              width: MediaQuery.of(context).size.width/4,
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4F2),
                borderRadius: BorderRadius.circular(18),
              ),
              child :Align(
                alignment: AlignmentDirectional.center,
                child: Text (currentQuestion['category'] ,style: const TextStyle(color: const Color(0xFF6FA7A3), fontWeight: FontWeight.bold , fontSize: 14) , ),
                )
              ),


              ]),


              const SizedBox(height: 20.0),
              
              Align(
                alignment: AlignmentDirectional.centerStart,
               child: Text (currentQuestion['instruction'] , style: const TextStyle(color:  Color.fromARGB(255, 8, 8, 8), fontWeight: FontWeight.bold , fontSize: 22) , ),  
              ),
              const SizedBox(height: 12.0),

              Container(
             
              width: double.infinity,
              height: 250,
              padding: const EdgeInsets.all(20.0),
              margin: const EdgeInsets.symmetric(vertical : 3),

              decoration: BoxDecoration(
                color: const Color(0xFFF7EAD7),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Color.fromARGB(255, 220, 197, 162)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 1), // changes position of shadow
                  ),
                ],
                
              ),

              child:
              Align(
               child: currentQuestion['type'] == 'text'
                   ? Text(currentQuestion['content'], style: const TextStyle(color:  Color(0xFF2E3A38), fontWeight: FontWeight.normal , fontSize: 18 , height: 1.8) )
                   : currentQuestion['type'] == 'image'
                   ? Image.asset(currentQuestion['content'] , width: double.infinity , height: double.infinity,fit: BoxFit.cover): 
                   currentQuestion['type'] == 'self' ? Column (
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,

                     children: const 
                     [
                      Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            color: Color(0xFF6FA7A3),
                          ),
                          SizedBox(width: 10),
                      
                       Text("يمكنك التحدث عن: "
                        , style: const TextStyle(color:  Color(0xFF1F5F5A), fontWeight: FontWeight.bold , fontSize: 18) ),
                     ]),
                    SizedBox(height: 20),
                    Text("دراستك ، عملك ، هواياتك ، اهتماماتك، او اي شيء تود مشاركته"
                    , style: const TextStyle(color:  Color(0xFF23E3A38), fontWeight: FontWeight.bold , fontSize: 17 , height: 1.7)),


                      
              ])
                   
                   
                   
                   :const SizedBox.shrink(),
              )
              ),


                const SizedBox(height: 16.0),

                     
                

              
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
                  onPressed: () {
                    if (currentQuestionIndex < questions.length - 1) {
                      setState(() {
                        currentQuestionIndex++;
                      });
                    } else {
                      // Handle submission of answers here
                     
                    } 
                  } ,
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