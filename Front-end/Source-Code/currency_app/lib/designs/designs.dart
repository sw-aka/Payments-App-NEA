import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../pages/homePage.dart';

/// Creates a back button with a specified [context].
///
/// The back button is a [SvgPicture] that navigates back to the [HomePage]
/// when tapped.
///
/// Args:
///   context: The [BuildContext] used for navigation.
///
/// Returns:
///   A [Container] containing the back button.
Container backButton(BuildContext context) {
  // Aligns the container to the top-left corner.
  return Container(
    alignment: Alignment.topLeft,
    // Utilizes LayoutBuilder for responsive margins.
    child: LayoutBuilder(builder: (context, constraints) {
      // Container for the back button.
      return Container(
        // Sets margin based on a percentage of the maximum width and height.
        margin: EdgeInsets.only(
          left: constraints.maxWidth * 0.03,
          top: constraints.maxWidth * 0.03,
        ),
        // GestureDetector for handling taps on the back button.
        child: GestureDetector(
          // Navigates to the HomePage when the back button is tapped.
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          },
          // Displays the back button as an SvgPicture.
          child: SvgPicture.asset(
            'assets/angle-circle-left-icon.svg',
            height: constraints.maxHeight * 0.7,
          ),
        ),
      );
    }),
  );
}
