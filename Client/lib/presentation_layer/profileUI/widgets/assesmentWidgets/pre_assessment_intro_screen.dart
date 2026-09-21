import 'package:flutter/material.dart';
import 'pre_assessment_questions_screen.dart';
class PreAssessmentIntroScreen extends StatelessWidget {
 const PreAssessmentIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFCFAF6),
      body: Directionality(
        textDirection: TextDirection.rtl,
      child:SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
            child: IconButton(
              onPressed: (){
                      },
              icon: const Icon (Icons.arrow_back,),
            ),
            ),
            const SizedBox(height: 60.0,),
            Container(
              
              width: 74, 
              height:74 ,
              decoration: BoxDecoration(
                color: const Color(0xFFCFE4E1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.description_outlined, size: 40.0, color: Color.fromARGB(255, 81, 82, 82),),
            ),

          const SizedBox(height: 28.0,),

            Container(
              width: double.infinity,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF7EAD7),
                borderRadius: BorderRadius.circular(18),
              ),
              child :Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text ("الخطوة ١ من ٢ : التقييم المسبق", style: const TextStyle(color: const Color(0xFF6FA7A3), fontWeight: FontWeight.bold),),
              ),
            ),

            const SizedBox(height: 35.0,),

            const Text(
              "دعنا نتعرف على تجربتك في الكلام",
              textAlign: TextAlign.right,
               style: TextStyle(
                fontSize: 24.0, 
                fontWeight: FontWeight.bold, 
                color: Color.fromARGB(255, 1, 1, 1), )),
            const Text("اجاباتك تساعد طليق على تخصيص التقييم و التدريب لك", style: TextStyle(fontSize:14.0, fontWeight: FontWeight.normal, color: Color.fromARGB(255, 138, 138, 138), ) ,),


            const SizedBox(height: 32.0,),
            Container(
              width: double.infinity,
              height: 230,
              padding: const EdgeInsets.all(20.0),

              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 1), // changes position of shadow
                  ),
                ],
                
              ),
            child: Column(
                  children: [
                    Row(
                      children: [
                      const Icon(
                        Icons.check_circle,
                        size: 25.0,
                        color: Color.fromARGB(255, 182, 201, 197),),
                        
                      const SizedBox(width: 12.0,),

                      const Text(
                        "يستغرق حوالي ٣ دقائق",
                         style: TextStyle(fontSize: 15.0, color: Color.fromARGB(255, 101, 101, 101), fontWeight: FontWeight.bold),
                        
                  ),
                  ],
                ),
                const SizedBox(height: 18.0,),
                Row(
                      children: [
                      const Icon(
                        Icons.check_circle,
                        size: 25.0,
                        color: Color.fromARGB(255, 182, 201, 197),),
                        
                      const SizedBox(width: 12.0,),

                      const Text(
                        "بضعة اسئلة قصيرة ",
                         style: TextStyle(fontSize: 15.0, color: Color.fromARGB(255, 101, 101, 101), fontWeight: FontWeight.bold),
                        
                  ),
                  ],
                ),
                const SizedBox(height: 18.0,),
                Row(
                      children: [
                      const Icon(
                        Icons.check_circle,
                        size: 25.0,
                        color: Color.fromARGB(255, 182, 201, 197),),
                        
                      const SizedBox(width: 12.0,),

                      const Text(
                        "لا توجد اجابات صحيحة او خاطئة",
                         style: TextStyle(fontSize: 15.0, color: Color.fromARGB(255, 101, 101, 101), fontWeight: FontWeight.bold),
                        
                  ),
                  ],
                ),
                const SizedBox(height: 18.0,),
                Row(
                      children: [
                      const Icon(
                        Icons.check_circle,
                        size: 25.0,
                        color: Color.fromARGB(255, 182, 201, 197),),
                        
                      const SizedBox(width: 12.0,),

                      const Text(
                        "سري تماما",
                         style: TextStyle(fontSize: 15.0, color: Color.fromARGB(255, 101, 101, 101), fontWeight: FontWeight.bold),
                        
                  ),
                  ],
                ),
                ],

            ),
            ),

            const SizedBox(height: 70.0,),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PreAssessmentQuestionsScreen()),
                );
                // Handle button press
              },
              style: ElevatedButton.styleFrom(

                backgroundColor: const Color(0xFF6FA7A3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                
              ),
              child: const Text(
                "ابدأ التقييم المسبق",
                style: TextStyle(fontSize: 16.0, color: Colors.white),
              ),
            ),
          ],
          
        ),
        ),
      ),
      ),
    );
  }

}