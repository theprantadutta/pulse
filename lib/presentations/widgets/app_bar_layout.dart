import 'package:flutter/material.dart';

class AppBarLayout extends StatelessWidget {
  final List<Widget> appBarActions;
  final String title;

  const AppBarLayout({
    super.key,
    required this.title,
    this.appBarActions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        return Container(
          padding: EdgeInsets.symmetric(vertical: 10),
          margin: EdgeInsets.only(bottom: 10),
          height: MediaQuery.sizeOf(context).height * (isDesktop ? 0.08 : 0.06),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Row(children: appBarActions),
              ],
            ),
          ),
        );
      },
    );
  }
}

// return AppBar(
//       title: Text(title),
//       elevation: 0,
//       backgroundColor: kPrimaryColor.withValues(alpha: 0.1),
//       actions: appBarActions,
//     );
