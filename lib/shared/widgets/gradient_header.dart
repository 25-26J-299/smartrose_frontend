import 'package:flutter/material.dart';

/// Shared header widget with standard white AppBar style
/// Features:
/// - White background AppBar
/// - Black text and icons
/// - Back button on the left
/// - Centered title
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    required this.title,
    this.onBackPressed,
    this.showBackButton = true,
    super.key,
  });

  final String title;
  final VoidCallback? onBackPressed;
  final bool showBackButton;

  /// Builds an AppBar that matches the page's background color
  static PreferredSizeWidget buildAppBar({
    required BuildContext context,
    required String title,
    VoidCallback? onBackPressed,
    bool showBackButton = true,
    Color? backgroundColor,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color appBarColor = backgroundColor ?? scheme.surfaceContainerHighest;
    
    // Determine text/icon color based on background brightness
    final bool isDark = appBarColor.computeLuminance() < 0.5;
    final Color textColor = isDark ? Colors.white : Colors.black;
    
    return AppBar(
      backgroundColor: appBarColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: showBackButton
          ? IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: textColor,
              ),
              onPressed: onBackPressed,
              padding: EdgeInsets.zero,
            )
          : const SizedBox.shrink(),
      leadingWidth: showBackButton ? 56 : 0,
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    // This widget is just for backward compatibility
    // The actual header should be used via buildAppBar in Scaffold's appBar
    return const SizedBox.shrink();
  }
}

