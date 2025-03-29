import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class GeminiApiClient {
  static const String _apiKey = "AIzaSyDryFrbIvNNGOwCEc8gv7MVDqN_t9b7QEw";
  static const String _baseUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey";

  // Initialize a conversation with article content
  static Future<String> analyzeArticle(String articleContent) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "role": "user",
              "parts": [
                {
                  "text":
                      "Analyze this article and provide a short summary of the main points. Keep your response concise and informative: $articleContent",
                },
              ],
            },
          ],
          "generationConfig": {
            "temperature": 0.7,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 800,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] ??
            "I've analyzed this article and found its key points. What would you like to know about it?";
      } else {
        debugPrint('Error response: ${response.body}');
        return "I couldn't analyze this article right now. Please try again later.";
      }
    } catch (e) {
      debugPrint('Error in analyzeArticle: $e');
      return "Sorry, I encountered an error while analyzing this article.";
    }
  }

  // Continue conversation with a user question
  static Future<String> askQuestion(
    List<Map<String, dynamic>> conversation,
    String question,
  ) async {
    try {
      // Format conversation history for the API
      final formattedConversation =
          conversation.map((message) {
            return {
              "role": message["isUser"] ? "user" : "model",
              "parts": [
                {"text": message["text"]},
              ],
            };
          }).toList();

      // Add the new user question
      formattedConversation.add({
        "role": "user",
        "parts": [
          {"text": question},
        ],
      });

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": formattedConversation,
          "generationConfig": {
            "temperature": 0.7,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 1000,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] ??
            "I'm not sure how to answer that question. Could you rephrase?";
      } else {
        debugPrint('Error response: ${response.body}');
        return "I'm having trouble processing your question right now. Please try again.";
      }
    } catch (e) {
      debugPrint('Error in askQuestion: $e');
      return "Sorry, I encountered an error while processing your question.";
    }
  }

  // Get definition or explanation of selected text
  static Future<String> getDefinitionOrExplanation(String selectedText) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "role": "user",
              "parts": [
                {
                  "text":
                      "Give a brief explanation or definition of the following text: \"$selectedText\". Keep your response concise and under 150 words. If it's a term, explain what it means. If it's a phrase or statement, explain its significance or meaning.",
                },
              ],
            },
          ],
          "generationConfig": {
            "temperature": 0.1,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 200,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] ??
            "I couldn't find an explanation for this text.";
      } else {
        debugPrint('Error response: ${response.body}');
        return "I couldn't find an explanation for this text right now.";
      }
    } catch (e) {
      debugPrint('Error in getDefinitionOrExplanation: $e');
      return "Sorry, I encountered an error while getting the explanation.";
    }
  }
}
