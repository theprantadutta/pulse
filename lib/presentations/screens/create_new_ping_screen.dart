import 'package:flutter/material.dart';

import '../../core/widgets/main_layout.dart';

class CreateNewPingScreen extends StatelessWidget {
  static const String kRouteName = '/create-new-ping';
  const CreateNewPingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Create New Ping',
      body: Center(child: Text('Create New Ping')),
    );
  }
}
