import 'package:flutter/material.dart';
import 'package:tik_tok_wikipidiea/screens/profile/domain_articles_page.dart';
import 'dart:async';
import 'package:lottie/lottie.dart'; // Add this package for animations

class StreakBottomSheet {
  static void show({
    required BuildContext context,
    required int streakCount,
    required List<dynamic> interestedDomains,
    required Map<String, int> domainReadCounts,
    required int articlesPerDomainGoal,
    required Function(String) incrementDomainReadCount,
    required Function showStreakInfoDialog,
    required int todayReadCount, // Added this parameter
  }) {
    final theme = Theme.of(context);
    bool _showSplash = true;

    // Calculate total articles read across all domains
    int totalArticlesRead = 0;
    domainReadCounts.forEach((key, value) {
      totalArticlesRead += value;
    });

    // Calculate total goal
    int totalGoal = articlesPerDomainGoal * interestedDomains.length;

    // Calculate completion percentage
    double completionPercentage =
        totalGoal > 0 ? (totalArticlesRead / totalGoal) * 100 : 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              // Start timer to hide splash after 5 seconds
              if (_showSplash) {
                Timer(Duration(seconds: 5), () {
                  setState(() {
                    _showSplash = false;
                  });
                });
              }

              return Container(
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),

                    // Show splash or content based on _showSplash flag
                    _showSplash
                        ? _buildSplashScreen(
                          context,
                          streakCount,
                          todayReadCount, // Pass the todayReadCount parameter
                          completionPercentage,
                          theme,
                        )
                        : Expanded(
                          child: Column(
                            children: [
                              // Title with streak count
                              Padding(
                                padding: EdgeInsets.all(20),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.local_fire_department,
                                          color: Colors.deepOrange,
                                          size: 28,
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Current Streak: $streakCount days',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.info_outline),
                                      onPressed: () {
                                        showStreakInfoDialog();
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              Divider(),

                              // Daily goal title
                              Padding(
                                padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.emoji_events,
                                      color: Colors.amber,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Daily Reading Goals',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              // Domain progress list
                              Expanded(
                                child: GridView.builder(
                                  padding: EdgeInsets.all(16),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        childAspectRatio: 1.5,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                      ),
                                  itemCount: interestedDomains.length,
                                  itemBuilder: (context, index) {
                                    final domain = interestedDomains[index];
                                    final readCount =
                                        domainReadCounts[domain] ?? 0;
                                    final progress =
                                        readCount / articlesPerDomainGoal;
                                    final isComplete =
                                        readCount >= articlesPerDomainGoal;

                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => DomainArticlesPage(
                                                  domain: domain,
                                                  onArticleRead:
                                                      () =>
                                                          incrementDomainReadCount(
                                                            domain,
                                                          ),
                                                ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: theme.cardColor,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color:
                                                isComplete
                                                    ? Colors.green
                                                    : theme.dividerColor,
                                            width: isComplete ? 2 : 1,
                                          ),
                                        ),
                                        padding: EdgeInsets.all(12),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  _getDomainIcon(domain),
                                                  color:
                                                      isComplete
                                                          ? Colors.green
                                                          : theme.primaryColor,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    domain,
                                                    style: theme
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              isComplete
                                                                  ? Colors.green
                                                                  : null,
                                                        ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 8),
                                            Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                // Progress bar
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: LinearProgressIndicator(
                                                    value: progress,
                                                    backgroundColor: theme
                                                        .dividerColor
                                                        .withOpacity(0.3),
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(
                                                          isComplete
                                                              ? Colors.green
                                                              : theme
                                                                  .primaryColor,
                                                        ),
                                                    minHeight: 8,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              '$readCount/$articlesPerDomainGoal articles read',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        isComplete
                                                            ? Colors.green
                                                            : null,
                                                  ),
                                            ),
                                            if (isComplete)
                                              Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                                size: 16,
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              );
            },
          ),
    );
  }

  // Updated splash screen to use todayReadCount
  static Widget _buildSplashScreen(
    BuildContext context,
    int streakCount,
    int todayReadCount, // Changed parameter name
    double completionPercentage,
    ThemeData theme,
  ) {
    return Expanded(
      child: SingleChildScrollView(
        // Add ScrollView to prevent overflow
        physics: BouncingScrollPhysics(),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title with animation
              Text(
                'Daily Reading Streak',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),

              SizedBox(height: 20), // Reduced from 30
              // Animated fire streak icon
              Container(
                height: 160, // Reduced from 180
                width: 160, // Reduced from 180
                child: Image.asset('assets/trophy.gif', fit: BoxFit.cover),
              ),

              SizedBox(height: 20), // Reduced from 30
              // Streak count display with pulsing animation
              TweenAnimationBuilder(
                duration: Duration(milliseconds: 1200),
                tween: Tween<double>(begin: 0.8, end: 1.0),
                builder: (_, double value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.deepOrange.shade300,
                        Colors.deepOrange.shade700,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepOrange.withOpacity(0.4),
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: Colors.white,
                        size: 40,
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$streakCount',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Day Streak',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 30), // Reduced from 40
              // Article count display - Updated to show todayReadCount
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.menu_book, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          '$todayReadCount Articles Read Today', // Using todayReadCount
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12),

                    // Progress indicator
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Circular progress indicator
                        SizedBox(
                          height: 70, // Reduced from 80
                          width: 70, // Reduced from 80
                          child: TweenAnimationBuilder(
                            duration: Duration(seconds: 2),
                            tween: Tween<double>(
                              begin: 0,
                              end: completionPercentage / 100,
                            ),
                            builder: (context, double value, child) {
                              return CircularProgressIndicator(
                                value: value,
                                strokeWidth: 8, // Reduced from 10
                                backgroundColor: theme.dividerColor.withOpacity(
                                  0.3,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.blue,
                                ),
                              );
                            },
                          ),
                        ),

                        // Percentage text
                        Text(
                          '${completionPercentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 16, // Reduced from 18
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 8),

                    Text('of Daily Goal', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),

              SizedBox(height: 20), // Added fixed spacing instead of Spacer
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to get icon for each domain
  static IconData _getDomainIcon(String domain) {
    // Map domain names to appropriate icons
    final Map<String, IconData> domainIcons = {
      'Nature': Icons.terrain,
      'Education': Icons.school,
      'Entertainment': Icons.movie,
      'Technology': Icons.computer,
      'Science': Icons.science,
      'Political': Icons.account_balance,
      'Lifestyle': Icons.spa,
      'Social': Icons.people,
      'Space': Icons.rocket,
      'Food': Icons.restaurant,
    };

    return domainIcons[domain] ?? Icons.interests;
  }
}
