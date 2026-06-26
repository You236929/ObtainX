import 'package:flutter/material.dart';
import 'package:obtainium/components/bulk_add_widget.dart';

/// Standalone page wrapper around [BulkAddWidget].
///
/// Kept as a separate route so that any existing [Navigator.push] to this
/// page continues to work unchanged. All logic lives in [BulkAddWidget].
class BulkAddAppsPage extends StatelessWidget {
  const BulkAddAppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth >= 720 ||
        (screenWidth >= 600 &&
            MediaQuery.of(context).orientation == Orientation.landscape);
    return BulkAddWidget(standalone: true, isLargeScreen: isLargeScreen);
  }
}
