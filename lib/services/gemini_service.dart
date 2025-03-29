import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tik_tok_wikipidiea/models/post_content.dart';
import 'package:tik_tok_wikipidiea/widgets/gemini_assistant.dart';

class GeminiService {
  // Store conversations by post ID
  static final Map<int, List<ChatMessage>> _conversations = {};
  static final Map<int, bool> _loadingStates = {};

  // Get conversation for a post
  static List<ChatMessage> getConversation(int postId) {
    return _conversations[postId] ?? [];
  }

  // Get loading state for a post
  static bool isLoading(int postId) {
    return _loadingStates[postId] ?? true;
  }

  // Save conversation for a post
  static void saveConversation(
    int postId,
    List<ChatMessage> messages,
    bool isLoading,
  ) {
    _conversations[postId] = List.from(messages);
    _loadingStates[postId] = isLoading;
  }

  // Clear conversation when moving to a new article (call this when article changes)
  static void clearOldConversations(int currentPostId) {
    final keysToRemove =
        _conversations.keys.where((id) => id != currentPostId).toList();
    for (var id in keysToRemove) {
      _conversations.remove(id);
      _loadingStates.remove(id);
    }
  }

  static void showGeminiAssistant(BuildContext context, Post post) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      // Enable resizing when keyboard appears
      useSafeArea: true,
      builder:
          (context) => Padding(
            // Add padding to avoid keyboard overlap
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: GestureDetector(
              // Prevent closing when tapping inside the sheet
              onTap: () {},
              // Allow taps outside to close
              behavior: HitTestBehavior.opaque,
              child: GeminiAssistant(post: post),
            ),
          ),
    );
  }
}
