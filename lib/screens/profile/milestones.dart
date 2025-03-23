import 'package:flutter/material.dart';

class MilestonesPage extends StatefulWidget {
  final int currentCount;
  final String type; // 'likes', 'comments', 'shares', 'bookmarks', 'all'

  const MilestonesPage({
    Key? key,
    required this.currentCount,
    required this.type,
  }) : super(key: key);

  @override
  _MilestonesPageState createState() => _MilestonesPageState();
}

class _MilestonesPageState extends State<MilestonesPage> {
  late List<Milestone> milestones;

  @override
  void initState() {
    super.initState();
    _initMilestones();
  }

  void _initMilestones() {
    final String title = _getTitle();

    milestones = [
      Milestone(
        level: 1,
        count: 1,
        description: 'First $title!',
        badge: '🔥',
        rewardName: 'Beginner Badge',
      ),
      Milestone(
        level: 2,
        count: 10,
        description: 'Keep going!',
        badge: '🌟',
        rewardName: 'Bronze Badge',
      ),
      Milestone(
        level: 3,
        count: 25,
        description: 'You\'re on fire!',
        badge: '💫',
        rewardName: 'Silver Badge',
      ),
      Milestone(
        level: 4,
        count: 50,
        description: 'Halfway to 100!',
        badge: '🏆',
        rewardName: 'Gold Badge',
      ),
      Milestone(
        level: 5,
        count: 75,
        description: 'Almost at 100!',
        badge: '⚡',
        rewardName: 'Platinum Badge',
      ),
      Milestone(
        level: 6,
        count: 100,
        description: 'Century achievement!',
        badge: '💯',
        rewardName: 'Diamond Badge',
      ),
      Milestone(
        level: 7,
        count: 150,
        description: 'Beyond expectations!',
        badge: '🎖️',
        rewardName: 'Elite Badge',
      ),
      Milestone(
        level: 8,
        count: 250,
        description: 'Unstoppable!',
        badge: '👑',
        rewardName: 'Royal Badge',
      ),
      Milestone(
        level: 9,
        count: 500,
        description: 'Legendary status!',
        badge: '🌈',
        rewardName: 'Legendary Badge',
      ),
      Milestone(
        level: 10,
        count: 1000,
        description: 'Master level!',
        badge: '🔱',
        rewardName: 'Master Badge',
      ),
    ];
  }

  String _getTitle() {
    switch (widget.type) {
      case 'likes':
        return 'Like';
      case 'comments':
        return 'Comment';
      case 'shares':
        return 'Share';
      case 'bookmarks':
        return 'Bookmark';
      case 'all':
        return 'Interaction';
      default:
        return 'Achievement';
    }
  }

  String _getTypeDisplayName() {
    switch (widget.type) {
      case 'likes':
        return 'Likes';
      case 'comments':
        return 'Comments';
      case 'shares':
        return 'Shares';
      case 'bookmarks':
        return 'Bookmarks';
      case 'all':
        return 'Total Interactions';
      default:
        return 'Achievements';
    }
  }

  Color _getTypeColor() {
    switch (widget.type) {
      case 'likes':
        return Colors.red;
      case 'comments':
        return Colors.amber;
      case 'shares':
        return Colors.green;
      case 'bookmarks':
        return Colors.blue;
      case 'all':
        return Colors.purple;
      default:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final typeColor = _getTypeColor();
    final currentLevel = _getCurrentLevel();
    final nextMilestone = _getNextMilestone();

    return Scaffold(
      appBar: AppBar(
        title: Text('${_getTypeDisplayName()} Milestones'),
        elevation: theme.appBarTheme.elevation,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Stats summary
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  typeColor.withOpacity(isDarkMode ? 0.8 : 0.7),
                  typeColor.withOpacity(isDarkMode ? 0.6 : 0.5),
                ],
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_getIconForType(), color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      '${widget.currentCount}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  _getTypeDisplayName(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: 16),

                // Current level display
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Level ${currentLevel.level}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(currentLevel.badge, style: TextStyle(fontSize: 18)),
                    ],
                  ),
                ),

                if (nextMilestone != null) ...[
                  SizedBox(height: 16),

                  // Progress to next milestone
                  Column(
                    children: [
                      Text(
                        'Next milestone: ${nextMilestone.count} ${_getTypeDisplayName()}',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: widget.currentCount / nextMilestone.count,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                          minHeight: 10,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '${nextMilestone.count - widget.currentCount} more to go!',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Milestones timeline - custom implementation
          Expanded(
            child: Container(
              color: isDarkMode ? Color(0xFF1E1E1E) : Color(0xFFF8F8F8),
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                itemCount: milestones.length,
                itemBuilder: (context, index) {
                  final milestone = milestones[index];
                  final isCompleted = widget.currentCount >= milestone.count;
                  final isNext =
                      nextMilestone != null &&
                      milestone.count == nextMilestone.count;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timeline indicator and connector
                        Column(
                          children: [
                            // Dot indicator
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    isCompleted
                                        ? typeColor
                                        : (isNext
                                            ? typeColor.withOpacity(0.5)
                                            : Colors.grey.withOpacity(0.3)),
                              ),
                              child: Center(
                                child:
                                    isCompleted
                                        ? Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 18,
                                        )
                                        : Text(
                                          '${milestone.level}',
                                          style: TextStyle(
                                            color:
                                                isNext
                                                    ? Colors.white
                                                    : Colors.grey[600],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                              ),
                            ),

                            // Connector line (if not last item)
                            if (index < milestones.length - 1)
                              _buildConnector(
                                isCompleted,
                                index < milestones.length - 1
                                    ? widget.currentCount >=
                                        milestones[index + 1].count
                                    : false,
                                typeColor,
                                widget.currentCount,
                                milestone.count,
                                index < milestones.length - 1
                                    ? milestones[index + 1].count
                                    : milestone.count * 2, // fallback
                              ),
                          ],
                        ),

                        SizedBox(width: 16),

                        // Content card - take remaining width
                        Expanded(
                          child: Container(
                            margin: EdgeInsets.only(bottom: 16),
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color:
                                    isCompleted
                                        ? typeColor
                                        : (isNext
                                            ? typeColor.withOpacity(0.3)
                                            : Colors.transparent),
                                width: isCompleted || isNext ? 2 : 0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${milestone.count} ${_getTypeDisplayName()}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isCompleted
                                                ? typeColor
                                                : theme
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.color,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      milestone.badge,
                                      style: TextStyle(fontSize: 20),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  milestone.description,
                                  style: TextStyle(
                                    color: theme.textTheme.bodySmall?.color,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.card_giftcard,
                                      size: 16,
                                      color:
                                          isCompleted ? typeColor : Colors.grey,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Reward: ${milestone.rewardName}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color:
                                            isCompleted
                                                ? typeColor
                                                : Colors.grey,
                                        fontWeight:
                                            isCompleted
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                                if (isCompleted) ...[
                                  SizedBox(height: 12),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: typeColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          size: 14,
                                          color: typeColor,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Achieved',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: typeColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Keep interacting to unlock more milestones!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: typeColor,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.emoji_events, color: typeColor, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildConnector(
    bool isCurrentCompleted,
    bool isNextCompleted,
    Color typeColor,
    int currentCount,
    int currentMilestone,
    int nextMilestone,
  ) {
    // For completed sections
    if (isCurrentCompleted && isNextCompleted) {
      return Container(width: 3, height: 50, color: typeColor);
    }

    // For in-progress sections
    if (isCurrentCompleted && !isNextCompleted) {
      final progress =
          (currentCount - currentMilestone) /
          (nextMilestone - currentMilestone);

      return Container(
        width: 3,
        height: 50,
        child: Stack(
          children: [
            Container(
              width: 3,
              height: 50,
              color: Colors.grey.withOpacity(0.3),
            ),
            Container(width: 3, height: 50 * progress, color: typeColor),
          ],
        ),
      );
    }

    // For future sections
    return Container(width: 3, height: 50, color: Colors.grey.withOpacity(0.3));
  }

  IconData _getIconForType() {
    switch (widget.type) {
      case 'likes':
        return Icons.favorite;
      case 'comments':
        return Icons.comment;
      case 'shares':
        return Icons.share;
      case 'bookmarks':
        return Icons.bookmark;
      case 'all':
        return Icons.analytics;
      default:
        return Icons.emoji_events;
    }
  }

  Milestone _getCurrentLevel() {
    // Find the highest milestone the user has achieved
    Milestone currentLevel = milestones.first;

    for (var milestone in milestones) {
      if (widget.currentCount >= milestone.count) {
        currentLevel = milestone;
      } else {
        break;
      }
    }

    return currentLevel;
  }

  Milestone? _getNextMilestone() {
    // Find the next milestone to achieve
    for (var milestone in milestones) {
      if (widget.currentCount < milestone.count) {
        return milestone;
      }
    }

    // If all milestones are completed
    return null;
  }
}

class Milestone {
  final int level;
  final int count;
  final String description;
  final String badge;
  final String rewardName;

  Milestone({
    required this.level,
    required this.count,
    required this.description,
    required this.badge,
    required this.rewardName,
  });
}
