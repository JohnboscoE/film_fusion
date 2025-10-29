import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:movie_app/splash_screen.dart';


void main(){
  runApp(
    DevicePreview(
      enabled: false,
        builder: (context) =>MaterialApp(
          useInheritedMediaQuery: true,
          debugShowCheckedModeBanner: false,
          home: SplashScreen(),
    )
  )
  );
}