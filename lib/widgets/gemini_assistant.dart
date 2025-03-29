import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tik_tok_wikipidiea/models/post_content.dart';
import 'package:tik_tok_wikipidiea/services/gemini_service.dart';
import 'package:tik_tok_wikipidiea/services/gemini_api_client.dart';

class GeminiAssistant extends StatefulWidget {
  final Post post;

  const GeminiAssistant({Key? key, required this.post}) : super(key: key);

  @override
  _GeminiAssistantState createState() => _GeminiAssistantState();
}

class _GeminiAssistantState extends State<GeminiAssistant> {
  // State variables
  bool isLoading = true;
  List<ChatMessage> messages = [];
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isSendingQuestion = false;

  @override
  void initState() {
    super.initState();

    // Load existing conversation or start a new one
    _loadConversation();
  }

  void _loadConversation() {
    // Check if we have an existing conversation
    final existingMessages = GeminiService.getConversation(widget.post.id);
    final existingLoadingState = GeminiService.isLoading(widget.post.id);

    if (existingMessages.isNotEmpty) {
      // Restore existing conversation
      setState(() {
        messages = existingMessages;
        isLoading = existingLoadingState;
      });

      // Scroll to bottom after restoring messages
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } else {
      // Start a new conversation
      _loadInitialExplanation();
    }
  }

  Future<void> _loadInitialExplanation() async {
    // Set loading state
    setState(() {
      isLoading = true;
    });

    // Save initial loading state
    GeminiService.saveConversation(widget.post.id, [], isLoading);

    try {
      // Prepare content for Gemini
      final String articleContent = _prepareContentForGemini();

      // Get real Gemini analysis using the API
      final explanation = await GeminiApiClient.analyzeArticle(articleContent);

      if (mounted) {
        final newMessages = [ChatMessage(text: explanation, isUser: false)];

        setState(() {
          messages = newMessages;
          isLoading = false;
        });

        // Save conversation state
        GeminiService.saveConversation(widget.post.id, newMessages, false);
      }
    } catch (e) {
      if (mounted) {
        print("=========================$e");
        final errorMessage = ChatMessage(
          text:
              "Sorry, I couldn't analyze this article right now. Please try again.",
          isUser: false,
        );

        setState(() {
          messages = [errorMessage];
          isLoading = false;
        });

        // Save conversation state
        GeminiService.saveConversation(widget.post.id, [errorMessage], false);
      }
    }
  }

  String _prepareContentForGemini() {
    // Combine article content for Gemini to analyze
    String content = "Title: ${widget.post.title}\n\n";
    content += "Summary: ${widget.post.summary}\n\n";

    for (var section in widget.post.sections) {
      content += "Section: ${section.title}\n${section.content}\n\n";
    }

    return content;
  }

  Future<void> _sendQuestion(String question) async {
    if (question.trim().isEmpty) return;

    final userMessage = ChatMessage(text: question, isUser: true);

    setState(() {
      isSendingQuestion = true;
      messages.add(userMessage);
      _questionController.clear();
    });

    // Update persistent state
    GeminiService.saveConversation(widget.post.id, messages, isLoading);

    // Scroll to bottom after adding user message
    _scrollToBottom();

    try {
      // Format conversation history for API
      final conversationHistory =
          messages
              .map((msg) => {'text': msg.text, 'isUser': msg.isUser})
              .toList();

      // Add article context to ensure the model has context
      final articleContext = _prepareContentForGemini();

      // Get real response from Gemini API
      final answer = await GeminiApiClient.askQuestion([
        {'text': 'Article context: $articleContext', 'isUser': true},
        ...conversationHistory,
      ], question);

      final aiMessage = ChatMessage(text: answer, isUser: false);

      if (mounted) {
        setState(() {
          messages.add(aiMessage);
          isSendingQuestion = false;
        });

        // Update persistent state
        GeminiService.saveConversation(widget.post.id, messages, isLoading);

        // Scroll to bottom after response
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = ChatMessage(
          text: "Sorry, I couldn't process your question. Please try again.",
          isUser: false,
        );

        setState(() {
          messages.add(errorMessage);
          isSendingQuestion = false;
        });

        // Update persistent state
        GeminiService.saveConversation(widget.post.id, messages, isLoading);

        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    // Adjust height based on keyboard visibility
    final sheetHeight =
        keyboardHeight > 0
            ? MediaQuery.of(context).size.height * 0.85
            : MediaQuery.of(context).size.height * 0.7;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black26 : Colors.black12,
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.primaryColor,
                        theme.primaryColor.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.support_agent, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "AI Assistant",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Ask me about this article (Gemini)",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(color: theme.dividerColor),

          // Chat messages
          Expanded(
            child:
                isLoading
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Analyzing article...",
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(
                          messages[index],
                          theme,
                          isDarkMode,
                        );
                      },
                    ),
          ),

          // Input area - Always visible above keyboard
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade50,
              border: Border(
                top: BorderSide(color: theme.dividerColor, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _questionController,
                    decoration: InputDecoration(
                      hintText: 'Ask about this article...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      fillColor:
                          isDarkMode
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                      filled: true,
                      prefixIcon: Icon(
                        Icons.chat_bubble_outline,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        size: 20,
                      ),
                    ),
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    onSubmitted: (value) {
                      if (!isSendingQuestion) {
                        _sendQuestion(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.primaryColor,
                        Color.fromARGB(
                          255,
                          theme.primaryColor.red - 40,
                          theme.primaryColor.green - 20,
                          theme.primaryColor.blue + 20,
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon:
                        isSendingQuestion
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Icon(Icons.send),
                    color: Colors.white,
                    onPressed:
                        isSendingQuestion
                            ? null
                            : () => _sendQuestion(_questionController.text),
                  ),
                ),
              ],
            ),
          ),
          // Safe area at the bottom
          SizedBox(height: keyboardHeight > 0 ? 0 : 8),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessage message,
    ThemeData theme,
    bool isDarkMode,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            // AI avatar for non-user messages
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor,
                    theme.primaryColor.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],

          // Message bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color:
                    message.isUser
                        ? theme.primaryColor
                        : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomRight: message.isUser ? const Radius.circular(4) : null,
                  bottomLeft: message.isUser ? null : const Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        isDarkMode
                            ? Colors.black12
                            : Colors.black.withOpacity(0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: message.isUser ? Colors.white : null,
                    height: 1.4,
                  ),
                  children: _processTextWithBulletPoints(
                    message.text,
                    message.isUser
                        ? Colors.white
                        : (isDarkMode ? Colors.white : Colors.black87),
                    theme,
                  ),
                ),
              ),
            ),
          ),

          if (message.isUser) ...[
            // User avatar for user messages
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8, top: 4),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  List<TextSpan> _processTextWithBulletPoints(
    String text,
    Color textColor,
    ThemeData theme,
  ) {
    List<TextSpan> spans = [];

    // Split the text by lines
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];

      // Check if line starts with a bullet point
      if (line.startsWith('• ')) {
        spans.add(
          TextSpan(
            text: '• ',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
        );
        // Add the rest of the bullet point text
        spans.add(TextSpan(text: line.substring(2)));
      } else {
        spans.add(TextSpan(text: line));
      }

      // Add a newline for all but the last line
      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n'));
      }
    }

    return spans;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}
