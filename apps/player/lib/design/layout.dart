import 'package:flutter/widgets.dart';

/// Below this width (phones, tablets held upright) screens show one pane at
/// a time and the sidebar becomes a bottom bar. The desktop layout needs
/// about 1100 px (the window's minimum), so desktop never goes compact.
const compactWidth = 1000.0;

bool isCompact(BuildContext context) => MediaQuery.sizeOf(context).width < compactWidth;
