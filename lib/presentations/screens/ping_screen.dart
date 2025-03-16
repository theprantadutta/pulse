import 'package:flutter/material.dart';

class PingScreen extends StatelessWidget {
  static const kRouteName = '/ping';
  const PingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Ping Screen'));
  }
}
