import 'package:flutter/material.dart';

class ImagesNotice extends StatefulWidget {
  const ImagesNotice({super.key});

  @override
  State<ImagesNotice> createState() => _ImagesNoticeState();
}

class _ImagesNoticeState extends State<ImagesNotice> {
  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      body: Center(child:
      Image.asset('assets/images/sentient_logo_nobg.png')),
    );
  }
}

