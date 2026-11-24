import 'package:flutter/painting.dart';

/// Maps coordinates from a fixed design canvas onto a concrete viewport.
///
/// The design width always fills the viewport, and the same scale is applied to
/// both axes so text, icons and rounded corners retain the design proportions.
/// Devices with a different aspect ratio receive additional or reduced canvas
/// height through [canvasHeight], which can be used by stretchable regions.
final class DesignMetrics {
  const DesignMetrics({
    required this.referenceSize,
    required this.viewportSize,
  });

  final Size referenceSize;
  final Size viewportSize;

  bool get isUsable =>
      referenceSize.width.isFinite &&
      referenceSize.height.isFinite &&
      viewportSize.width.isFinite &&
      viewportSize.height.isFinite &&
      referenceSize.width > 0 &&
      referenceSize.height > 0 &&
      viewportSize.width > 0 &&
      viewportSize.height > 0;

  double get scale {
    if (!isUsable) return 0;
    return viewportSize.width / referenceSize.width;
  }

  double get canvasHeight => scale == 0 ? 0 : viewportSize.height / scale;

  Offset mapOffset(Offset designOffset) =>
      Offset(designOffset.dx * scale, designOffset.dy * scale);

  Size mapSize(Size designSize) =>
      Size(designSize.width * scale, designSize.height * scale);

  Rect mapRect(Rect designRect) => Rect.fromLTRB(
    designRect.left * scale,
    designRect.top * scale,
    designRect.right * scale,
    designRect.bottom * scale,
  );

  EdgeInsets mapInsets(EdgeInsets designInsets) => EdgeInsets.fromLTRB(
    designInsets.left * scale,
    designInsets.top * scale,
    designInsets.right * scale,
    designInsets.bottom * scale,
  );

  double bottomAnchoredY({
    required double designHeight,
    required double itemHeight,
  }) => canvasHeight - itemHeight - designHeight;
}
