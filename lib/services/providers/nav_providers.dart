import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which bottom-nav tab is active in [MainScaffold] (0=Home, 1=Search,
/// 2=Sell, 3=Chats, 4=Profile). Exposed as a provider (rather than local
/// State) so other screens — like the Home search bar — can switch tabs
/// programmatically instead of only the bottom nav bar itself being able to.
final mainTabIndexProvider = StateProvider<int>((ref) => 0);
