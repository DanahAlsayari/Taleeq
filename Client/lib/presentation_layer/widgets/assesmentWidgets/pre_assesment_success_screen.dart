import 'package:flutter/material.dart';
import 'speech_assesment_intro_screen.dart';
import '../../widgets/journey_stepper.dart';
import '../../widgets/skip_assessment_button.dart';
import '../../HomepageUI/home_screen.dart';
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
            mainAxisAlignment: MainAxisAlignment.start,
            
            
            children: [
               const SizedBox(height:110),
              JourneyStepper(currentStep: 2),
               const SizedBox(height:80),
              const Icon(Icons.check_circle, size: 80.0, color: Color(0xFF6FA7A3)),
              const SizedBox(height:17),
                Text( ' شكرا لك  ', style: TextStyle(color: Colors.black , fontWeight : FontWeight.bold , fontSize : 35),),
                Text( ' تم حفظ اجاباتك', style: TextStyle(color: const Color.fromARGB(255, 10, 10, 10) , fontWeight : FontWeight.w100 , fontSize : 17),),
                const SizedBox(height:17),
                Text( '  اتممت التقييم القبلي بنجاح ! الخطوة التالية هي تقييم صوتي للكلام يتضمن مهام لتساعدنا على تخصيص تجربتك',textAlign : TextAlign.center ,style: TextStyle(color: const Color.fromARGB(255, 158, 158, 158) , fontWeight : FontWeight.w100 , fontSize : 17 ,  ), ),
                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFE8F3EF),
                        Color(0xFFF5F9F7),
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFDCEBE5),
                    ),
                  ),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome_outlined,
                          color: Color(0xFF6FA7A3),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'مشاركة تجربتك خطوة شجاعة، ونحن هنا لنرافقك فيها.',
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            color: Color(0xFF477B75),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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

                    backgroundColor: const Color(0xFF006B63),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),

                    ),
        
                
                  ), child: Text( "المتابعة إلى تقييم الكلام", style: TextStyle(fontSize: 18.0, color: Colors.white),),
                  ),
                  ),
                    SkipAssessmentButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/home',
                        (route) => false,
                      );
                    },
                  ),

            ],
            ),
          )
        ),
        );
  }


}