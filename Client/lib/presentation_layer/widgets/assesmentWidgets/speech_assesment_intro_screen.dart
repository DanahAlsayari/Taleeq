import 'package:flutter/material.dart';
import 'pre_assesment_success_screen.dart';
import 'speech_assesment_questions_screen.dart';
import '../../widgets/journey_stepper.dart';
class SpeechAssesmentIntroScreen extends StatelessWidget {
     const SpeechAssesmentIntroScreen({super.key});

  @override
  Widget build (BuildContext context) { 
    return Scaffold(
      backgroundColor: Color(0xFFFCFAF6),
      
   
        body: Directionality(
        textDirection: TextDirection.rtl,
      child:SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PreAssessmentSuccessScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_back),
              ),
            ),

            const JourneyStepper(currentStep:3),
            const SizedBox(height: 28.0,),
            Align(
            alignment: AlignmentDirectional.centerStart,
            
            child: Text  ("قبل أن تبدأ" , style: const TextStyle(color: Color.fromARGB(255, 11, 11, 11), fontWeight: FontWeight.bold , fontSize: 30) ),
            ),
            const SizedBox(height: 20.0,),
            Text( 'ستكمل ٣ مهام قصيرة في الكلام، تسجل كل منهم للتحليل.',textAlign : TextAlign.center ,style: TextStyle(color: const Color.fromARGB(255, 158, 158, 158) , fontWeight : FontWeight.w100 , fontSize : 17 ,  ), ),
            const SizedBox(height: 20.0,),

            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              color: Color.fromARGB(74, 111, 167, 163) ,
                ),
             
              child: Row (children: [
                
                Expanded(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center ,
                  children: [
                  const Text("٦ دقائق" , style:  TextStyle(color: Color(0xFF1F5F5A), fontWeight: FontWeight.bold , fontSize: 25) ),
                  const Text("الوقت المتوقع" , style:  TextStyle(color: Color(0xFF6FA7A3), fontWeight: FontWeight.normal , fontSize: 15) ),
              ])),

              const VerticalDivider(
                width: 1,
                thickness: 1,
                indent: 5,
                endIndent: 5,
                color: Color(0xFF6FA7A3) ,
              ),
                
                
                Expanded(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center ,
                  children: [
                  const Text("٣" , style:  TextStyle(color: Color(0xFF1F5F5A), fontWeight: FontWeight.bold , fontSize: 25) ),
                  const Text("عدد المهام" , style:  TextStyle(color: Color(0xFF6FA7A3), fontWeight: FontWeight.normal , fontSize: 15) ),

              ])),

           

              ],
              
              )

            ),

            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Align(
                alignment: Alignment.topRight,
                child: const Text(
                'نصائح قبل أن تبدأ',
                style: TextStyle(
                  color: Color.fromARGB(255, 11, 11, 11),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                ),
              ),
            ),
            const SizedBox(height: 10),
           
             Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8.0),
                    
                    child: 
                    
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow( icon: Icons.volume_off_outlined , text:"ابحث عن مكان هادئ ومريح"),Divider(height: 32.0, thickness: 1, color: Color.fromARGB(255, 223, 223, 223)),
                        _InfoRow( icon: Icons.description_outlined , text:"اقرأ كل مهمة بعناية قبل التسجيل" ),Divider(height: 32.0, thickness: 1, color: Color.fromARGB(255, 223, 223, 223)),
                        _InfoRow( icon: Icons.replay_outlined , text:"يمكنك الاستماع واعادة التسجيل"),Divider(height: 32.0, thickness: 1, color: Color.fromARGB(255, 223, 223, 223)),
                        _InfoRow( icon: Icons.phone_iphone , text:"ابق جهازك قريبا لصوت واضح")
                      ],
                    ),
                  ),


      ]),
        )
      ))
        )
    ,bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
 
                  child: SizedBox(
                    height: 56.0,
                    child: ElevatedButton(
                  onPressed: () {

                    Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SpeechAssesmentQuestionsScreen()),
                );
      
                    } ,
                  
                  style: ElevatedButton.styleFrom(

                    backgroundColor: const Color(0xFF6FA7A3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.0),
                      
                    ),
                  ), child: Text( "المتابعة إلى تقييم الكلام", style: TextStyle(fontSize: 18.0, color: Colors.white),),
                  ),
                  ),
    ));

}


}


// Reusable information row
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 25.0,
          color: const Color.fromARGB(255, 114, 183, 168),
        ),
        const SizedBox(width: 12.0),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15.0,
            ),
          ),
        ),
      ],
    );
  }
}