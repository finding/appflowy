import 'package:appflowy/user/application/user_listener.dart';
import 'package:appflowy/workspace/application/edit_panel/edit_context.dart';
import 'package:appflowy/workspace/application/settings/appearance/appearance_cubit.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/workspace.pb.dart'
    show WorkspaceLatestPB;
import 'package:flowy_infra/size.dart';
import 'package:flowy_infra/time/duration.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_setting_bloc.freezed.dart';

class HomeSettingBloc extends Bloc<HomeSettingEvent, HomeSettingState> {
  HomeSettingBloc(
    WorkspaceLatestPB workspaceSetting,
    AppearanceSettingsCubit appearanceSettingsCubit,
    double screenWidthPx,
  )   : _listener = FolderListener(),
        _appearanceSettingsCubit = appearanceSettingsCubit,
        super(
          HomeSettingState.initial(
            workspaceSetting,
            appearanceSettingsCubit.state,
            screenWidthPx,
          ),
        ) {
    _dispatch();
  }

  final FolderListener _listener;
  final AppearanceSettingsCubit _appearanceSettingsCubit;

  @override
  Future<void> close() async {
    await _listener.stop();
    return super.close();
  }

  void _dispatch() {
    on<HomeSettingEvent>(
      (event, emit) async {
        await event.map(
          initial: (_Initial value) {},
          setEditPanel: (e) async {
            emit(state.copyWith(panelContext: e.editContext));
          },
          dismissEditPanel: (value) async {
            emit(state.copyWith(panelContext: null));
          },
          didReceiveWorkspaceSetting: (_DidReceiveWorkspaceSetting value) {
            emit(state.copyWith(workspaceSetting: value.setting));
          },
          changeMenuStatus: (_CollapseMenu e) {
            final status = e.status;
            if (state.menuStatus == status) return;
            if (status != MenuStatus.floating) {
              _appearanceSettingsCubit.saveIsMenuCollapsed(
                status == MenuStatus.expanded ? false : true,
              );
            }
            emit(
              state.copyWith(menuStatus: status),
            );
          },
          collapseNotificationPanel: (_) {
            final isNotificationPanelCollapsed =
                !state.isNotificationPanelCollapsed;
            emit(
              state.copyWith(
                isNotificationPanelCollapsed: isNotificationPanelCollapsed,
              ),
            );
          },
          checkScreenSize: (_CheckScreenSize e) {
            final bool isScreenSmall =
                e.screenWidthPx < PageBreaks.tabletLandscape;
            if (state.isScreenSmall == isScreenSmall) return;
            if (state.hasColappsedMenuManually) {
              emit(state.copyWith(isScreenSmall: isScreenSmall));
            } else {
              MenuStatus menuStatus = state.menuStatus;
              if (isScreenSmall && menuStatus == MenuStatus.expanded) {
                menuStatus = MenuStatus.hidden;
              } else if (!isScreenSmall && menuStatus == MenuStatus.hidden) {
                menuStatus = MenuStatus.expanded;
              }
              emit(
                state.copyWith(
                  menuStatus: menuStatus,
                  isScreenSmall: isScreenSmall,
                ),
              );
            }
          },
          editPanelResizeStart: (_EditPanelResizeStart e) {
            emit(
              state.copyWith(
                resizeType: MenuResizeType.drag,
                resizeStart: state.resizeOffset,
              ),
            );
          },
          editPanelResized: (_EditPanelResized e) {
            final newPosition =
                (state.resizeStart + e.offset).clamp(0, 200).toDouble();
            if (state.resizeOffset != newPosition) {
              emit(state.copyWith(resizeOffset: newPosition));
            }
          },
          editPanelResizeEnd: (_EditPanelResizeEnd e) {
            _appearanceSettingsCubit.saveMenuOffset(state.resizeOffset);
            emit(state.copyWith(resizeType: MenuResizeType.slide));
          },
        );
      },
    );
  }

  bool get isMenuHidden => state.menuStatus == MenuStatus.hidden;

  bool get isMenuExpanded => state.menuStatus == MenuStatus.expanded;

  void collapseMenu() {
    if (isMenuExpanded) {
      add(HomeSettingEvent.changeMenuStatus(MenuStatus.hidden));
    } else if (isMenuHidden) {
      add(HomeSettingEvent.changeMenuStatus(MenuStatus.expanded));
    }
  }
}

enum MenuResizeType {
  slide,
  drag,
}

extension MenuResizeTypeExtension on MenuResizeType {
  Duration duration() {
    switch (this) {
      case MenuResizeType.drag:
        return 30.milliseconds;
      case MenuResizeType.slide:
        return 350.milliseconds;
    }
  }
}

@freezed
class HomeSettingEvent with _$HomeSettingEvent {
  const factory HomeSettingEvent.initial() = _Initial;

  const factory HomeSettingEvent.setEditPanel(EditPanelContext editContext) =
      _ShowEditPanel;

  const factory HomeSettingEvent.dismissEditPanel() = _DismissEditPanel;

  const factory HomeSettingEvent.didReceiveWorkspaceSetting(
    WorkspaceLatestPB setting,
  ) = _DidReceiveWorkspaceSetting;

  const factory HomeSettingEvent.changeMenuStatus(MenuStatus status) =
      _CollapseMenu;

  const factory HomeSettingEvent.collapseNotificationPanel() =
      _CollapseNotificationPanel;

  const factory HomeSettingEvent.checkScreenSize(double screenWidthPx) =
      _CheckScreenSize;

  const factory HomeSettingEvent.editPanelResized(double offset) =
      _EditPanelResized;

  const factory HomeSettingEvent.editPanelResizeStart() = _EditPanelResizeStart;

  const factory HomeSettingEvent.editPanelResizeEnd() = _EditPanelResizeEnd;
}

@freezed
class HomeSettingState with _$HomeSettingState {
  const factory HomeSettingState({
    required EditPanelContext? panelContext,
    required WorkspaceLatestPB workspaceSetting,
    required bool unauthorized,
    required MenuStatus menuStatus,
    required bool isNotificationPanelCollapsed,
    required bool isScreenSmall,
    required bool hasColappsedMenuManually,
    required double resizeOffset,
    required double resizeStart,
    required MenuResizeType resizeType,
  }) = _HomeSettingState;

  factory HomeSettingState.initial(
    WorkspaceLatestPB workspaceSetting,
    AppearanceSettingsState appearanceSettingsState,
    double screenWidthPx,
  ) {
    return HomeSettingState(
      panelContext: null,
      workspaceSetting: workspaceSetting,
      unauthorized: false,
      menuStatus: appearanceSettingsState.isMenuCollapsed
          ? MenuStatus.hidden
          : MenuStatus.expanded,
      isNotificationPanelCollapsed: true,
      isScreenSmall: screenWidthPx < PageBreaks.tabletLandscape,
      hasColappsedMenuManually: false,
      resizeOffset: appearanceSettingsState.menuOffset,
      resizeStart: 0,
      resizeType: MenuResizeType.slide,
    );
  }
}

enum MenuStatus { hidden, expanded, floating }
