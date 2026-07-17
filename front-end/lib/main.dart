import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';


void main(){

  runApp(
      MyApp()
  );

}


class MyApp extends StatelessWidget{

  @override
  Widget build(BuildContext context){

    return MaterialApp(
      title: 'docsigne',
      theme: AppTheme.light,
      debugShowCheckedModeBanner:false,

      home: LoginPage(),

    );

  }

}