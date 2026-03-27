class NavState {
  final bool isCollapsed;
  final Set<String> openItems;
  final String activeRoute;

  const NavState({
    this.isCollapsed = false,
    this.openItems = const {'inventory'},
    this.activeRoute = '/inventory/search',
  });

  NavState copyWith({
    bool? isCollapsed,
    Set<String>? openItems,
    String? activeRoute,
  }) {
    return NavState(
      isCollapsed: isCollapsed ?? this.isCollapsed,
      openItems: openItems ?? this.openItems,
      activeRoute: activeRoute ?? this.activeRoute,
    );
  }
}
