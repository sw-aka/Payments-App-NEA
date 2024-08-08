import 'package:flutter/material.dart'; // Importing the Flutter material library for UI components.

late BuildContext toastContext; // Defining a late variable to hold the BuildContext for displaying toasts.

/// Function to display a toast message.
///
/// Args:
///   - message: The message to be displayed in the toast.
///   - duration: The duration for which the toast should be visible (default is 1 second).
///
/// Returns: None.
void sendToast(String message, {int duration = 1}) {
  // Showing a Snackbar with the provided message and duration.
  ScaffoldMessenger.of(toastContext).showSnackBar(
    SnackBar(
      content: Text(message), // Setting the content of the Snackbar to the provided message.
      duration: Duration(seconds: duration), // Setting the duration for which the Snackbar should be visible.
    ),
  );
}
