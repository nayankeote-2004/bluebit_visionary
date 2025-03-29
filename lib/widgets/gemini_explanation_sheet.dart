import 'package:flutter/material.dart';

class GeminiExplanationSheet extends StatefulWidget {
  final String selectedText;
  final String explanation;
  final bool isLoading;

  const GeminiExplanationSheet({
    Key? key,
    required this.selectedText,
    required this.explanation,
    required this.isLoading,
  }) : super(key: key);

  @override
  _GeminiExplanationSheetState createState() => _GeminiExplanationSheetState();
}

class _GeminiExplanationSheetState extends State<GeminiExplanationSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.25, // 1/4 of screen height
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Selected text section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
                text: '"${widget.selectedText}"',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          Divider(height: 1),

          // Explanation section
          Expanded(
            child:
                widget.isLoading
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.primaryColor,
                            ),
                            strokeWidth: 2,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Getting explanation...",
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    )
                    : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        widget.explanation,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
