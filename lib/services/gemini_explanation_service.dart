import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tik_tok_wikipidiea/services/gemini_api_client.dart';
import 'package:tik_tok_wikipidiea/widgets/gemini_explanation_sheet.dart';

class GeminiExplanationService {
  // Show the explanation bottom sheet
  static void showExplanation(BuildContext context, String selectedText) {
    // Provide haptic feedback
    HapticFeedback.selectionClick();

    // Initial state - loading with empty explanation
    String explanation = "";
    bool isLoading = true;

    // Show bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Get explanation only once when sheet opens
            if (isLoading) {
              _getExplanation(selectedText).then((result) {
                // Update sheet with the explanation
                setState(() {
                  explanation = result;
                  isLoading = false;
                });
              });
            }

            return GeminiExplanationSheet(
              selectedText: selectedText,
              explanation: explanation,
              isLoading: isLoading,
            );
          },
        );
      },
    );
  }

  // Get explanation from Gemini API
  static Future<String> _getExplanation(String text) async {
    try {
      // Use the existing API client with a specialized prompt
      return await GeminiApiClient.getDefinitionOrExplanation(text);
    } catch (e) {
      return "Sorry, I couldn't get an explanation for this text. Please try again later.";
    }
  }
}
