import 'package:flutter/material.dart';

import 'sales_screen.dart';

class LivestreamingScreen extends StatelessWidget {
  const LivestreamingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SalesScreen(
      initialView: 'Live Streams',
      lockedView: true,
      titleOverride: 'Livestreaming',
    );
  }
}
