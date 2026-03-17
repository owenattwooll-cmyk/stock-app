import 'package:flutter/material.dart';

class ScrollableDataTable extends StatefulWidget {
  const ScrollableDataTable({
    super.key,
    required this.table,
    this.minWidth,
  });

  final DataTable table;
  final double? minWidth;

  @override
  State<ScrollableDataTable> createState() => _ScrollableDataTableState();
}

class _ScrollableDataTableState extends State<ScrollableDataTable> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            controller: _verticalController,
            child: Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final targetWidth = widget.minWidth == null
                      ? constraints.maxWidth
                      : (constraints.maxWidth > widget.minWidth!
                          ? constraints.maxWidth
                          : widget.minWidth!);
                  return SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: targetWidth,
                      child: widget.table,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
