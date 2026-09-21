import 'package:flutter/material.dart';
import 'pre_assesment_success_screen.dart';
import 'speech_assesment_questions_screen.dart';

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
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
            child: IconButton(
              onPressed: (){
                 Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PreAssessmentSuccessScreen()), );

                      },
              icon: const Icon (Icons.arrow_back,),
            ),
            ),
            const SizedBox(height: 30.0,),

            Align(
            alignment: AlignmentDirectional.centerStart,
            child:Container(
              width: MediaQuery.of(context).size.width/2.4,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF7EAD7),
                borderRadius: BorderRadius.circular(18),
              ),
              child :Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text ("الخطوة ٢ من ٢ : تقييم الكلام" ,style: const TextStyle(color: const Color(0xFF6FA7A3), fontWeight: FontWeight.bold , fontSize: 13) , ),
                )
              ),
            ),
            const SizedBox(height: 10.0,),
            Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text  ("قبل أن تبدأ" , style: const TextStyle(color: Color.fromARGB(255, 11, 11, 11), fontWeight: FontWeight.bold , fontSize: 30) ),
            ),
            const SizedBox(height: 10.0,),
            Text( 'ستكمل ٣ مهام قصيرة في الكلام، تسجل كل منهم للتحليل.',textAlign : TextAlign.center ,style: TextStyle(color: const Color.fromARGB(255, 158, 158, 158) , fontWeight : FontWeight.w100 , fontSize : 17 ,  ), ),
            const SizedBox(height: 10.0,),

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

            const SizedBox(height: 20),
            
            
            Container(
              width: double.infinity,
              height: 60,
              padding: const EdgeInsets.all(20.0),
              margin: const EdgeInsets.symmetric(vertical : 3),

              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 1), // changes position of shadow
                  ),
                ],
                
              ),
    
                    child: Row(
                      children: [
                      const Icon(
                        Icons.volume_off_outlined,
                        size: 25.0,
                        color: Color.fromARGB(255, 182, 201, 197),),
                        
                      const SizedBox(width: 12.0,),

                      const Text(
                        "ابحث عن مكان هادئ ومريح",
                         style: TextStyle(fontSize: 15.0, color: Color.fromARGB(255, 101, 101, 101), fontWeight: FontWeight.bold),
                        
                  ),
                  ],
                ),
          
            ),


          

             Container(
              width: double.infinity,
              height: 60,
              padding: const EdgeInsets.all(20.0),
              margin: const EdgeInsets.symmetric(vertical : 3),

              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 1), // changes position of shadow
                  ),
                ],
                
              ),
    
                    child: Row(
                      children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 25.0,
                        color: Color.fromARGB(255, 182, 201, 197),),
                        
                      const SizedBox(width: 12.0,),

                      const Text(
                        "اقرأ كل مهمة بعناية قبل التسجيل",
                         style: TextStyle(fontSize: 15.0, color: Color.fromARGB(255, 101, 101, 101), fontWeight: FontWeight.bold),
                        
                  ),
                  ],
                ),
            ),


             Container(
              width: double.infinity,
              height: 60,
              padding: const EdgeInsets.all(20.0),
              margin: const EdgeInsets.symmetric(vertical : 3),

              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 1), // changes position of shadow
                  ),
                ],
                
              ),
    
                    child: Row(
                      children: [
                      const Icon(
                        Icons.replay,
                        size: 25.0,
                        color: Color.fromARGB(255, 182, 201, 197),),
                        
                      const SizedBox(width: 12.0,),

                      const Text(
                        "يمكنك الاستماع واعادة التسجيل",
                         style: TextStyle(fontSize: 15.0, color: Color.fromARGB(255, 101, 101, 101), fontWeight: FontWeight.bold),
                        
                  ),
                  ],
                ),
            ),
             Container(
              width: double.infinity,
              height: 60,
              padding: const EdgeInsets.all(20.0),
              margin: const EdgeInsets.symmetric(vertical : 3),

              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 1), // changes position of shadow
                  ),
                ],
                
              ),
    
                    child: Row(
                      children: [
                      const Icon(
                        Icons.phone_iphone,
                        size: 25.0,
                        color: Color.fromARGB(255, 182, 201, 197),),
                        
                      const SizedBox(width: 12.0,),

                      const Text(
                        "ابق جهازك قريبا لصوت واضح",
                         style: TextStyle(fontSize: 15.0, color: Color.fromARGB(255, 101, 101, 101), fontWeight: FontWeight.bold),
                        
                  ),
                  ],
                ),
            ),




                  






      ]),
        )
      )
        )
    ,bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20.0),
 
                  child: SizedBox(
                    height: 60.0,
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
                      borderRadius: BorderRadius.circular(12.0),
                      
                    ),
                  ), child: Text( "المتابعة إلى تقييم الكلام", style: TextStyle(fontSize: 20.0, color: Colors.white),),
                  ),
                  ),
    ));

}


}