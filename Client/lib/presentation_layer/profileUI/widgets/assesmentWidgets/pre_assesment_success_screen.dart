import 'package:flutter/material.dart';
import 'speech_assesment_intro_screen.dart';
class PreAssessmentSuccessScreen extends StatelessWidget {
 const PreAssessmentSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFCFAF6),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            
            
            children: [
              const Icon(Icons.check_circle, size: 80.0, color: Color(0xFF6FA7A3)),
              const SizedBox(height:17),
                Text( ' ! شكرا لك  ', style: TextStyle(color: Colors.black , fontWeight : FontWeight.bold , fontSize : 35),),
                Text( ' تم حفظ اجاباتك', style: TextStyle(color: const Color.fromARGB(255, 10, 10, 10) , fontWeight : FontWeight.w100 , fontSize : 17),),
                const SizedBox(height:17),
                Text( '  اتممت التقييم القبلي بنجاح ! الخطوة التالية هي تقييم صوتي للكلام يتضمن مهام لتساعدنا على تخصيص تجربتك',textAlign : TextAlign.center ,style: TextStyle(color: const Color.fromARGB(255, 158, 158, 158) , fontWeight : FontWeight.w100 , fontSize : 17 ,  ), ),

                const SizedBox(height:35),

                  SizedBox(
                    height: 60.0,
                    width: double.infinity ,
                    child: ElevatedButton(
                  onPressed: () {
 
                      Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SpeechAssesmentIntroScreen()), );

      
                    } ,
                  
                  style: ElevatedButton.styleFrom(

                    backgroundColor: const Color(0xFF6FA7A3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      
                    ),
                  ), child: Text( "المتابعة إلى تقييم الكلام", style: TextStyle(fontSize: 20.0, color: Colors.white),),
                  ),
                  ),


            ],
            ),
          )
        ),
        );
  }


}