import 'package:flutter_bloc/flutter_bloc.dart';
import 'nav_state.dart';

export 'nav_state.dart';

class NavCubit extends Cubit<NavState> {
  NavCubit() : super(const NavState());

  void toggleCollapse() =>
      emit(state.copyWith(isCollapsed: !state.isCollapsed));

  void toggleItem(String itemId) {
    final open = {...state.openItems};
    if (open.contains(itemId)) {
      open.remove(itemId);
    } else {
      open.add(itemId);
    }
    emit(state.copyWith(openItems: open));
  }

  void setActiveRoute(String route) =>
      emit(state.copyWith(activeRoute: route));
}
