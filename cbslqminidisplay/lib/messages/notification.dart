import 'package:flutter/material.dart';

class MessageUtils {
  static void showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        duration: const Duration(seconds: 5),
        content: SizedBox(
          width: 200, // Adjust the width to your desired value
          child: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        behavior: SnackBarBehavior.floating, // Makes the SnackBar smaller
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // New method for showing API response messages
  static void showErrorMessage(BuildContext context, String message) {
    showSnackBar(context, message, Colors.red);
  }

  static void showSuccessMessage(BuildContext context, String message) {
    showSnackBar(context, message, Colors.green);
  }
}
