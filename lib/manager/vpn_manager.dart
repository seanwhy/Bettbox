import 'dart:async';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/providers/app.dart';
import 'package:bett_box/providers/config.dart';
import 'package:bett_box/providers/state.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef VpnRuntimeConfig = ({bool allowLan, int mixedPort, bool ipv6});

/// Whether a Clash config change requires prompting the user to restart Android VPN.
@visibleForTesting
bool shouldNotifyVpnConfigRestart({
  required bool isAndroid,
  required bool vpnEnabled,
  required VpnRuntimeConfig? prev,
  required VpnRuntimeConfig next,
}) {
  if (!isAndroid || !vpnEnabled || prev == null || prev == next) return false;
  return true;
}

class VpnManager extends ConsumerStatefulWidget {
  final Widget child;

  const VpnManager({super.key, required this.child});

  @override
  ConsumerState<VpnManager> createState() => _VpnContainerState();
}

class _VpnContainerState extends ConsumerState<VpnManager> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(vpnStateProvider, (prev, next) {
      // Skip tip
      if (prev == null || prev == next) return;

      final prevProps = prev.vpnProps;
      final nextProps = next.vpnProps;

      // Check
      final onlySmartAutoStopChanged =
          prevProps.copyWith(
            smartAutoStop: nextProps.smartAutoStop,
            smartAutoStopNetworks: nextProps.smartAutoStopNetworks,
          ) ==
          nextProps;

      final onlyQuickResponseChanged =
          prevProps.copyWith(quickResponse: nextProps.quickResponse) ==
          nextProps;

      final onlyNetworkSpeedChanged =
          prevProps.copyWith(
            networkSpeedNotification: nextProps.networkSpeedNotification,
          ) ==
          nextProps;

      final onlyHighPriorityNotificationChanged =
          prevProps.copyWith(
            highPriorityNotification: nextProps.highPriorityNotification,
          ) ==
          nextProps;

      if (onlySmartAutoStopChanged ||
          onlyQuickResponseChanged ||
          onlyNetworkSpeedChanged ||
          onlyHighPriorityNotificationChanged) {
        return; // No tip needed
      }

      showTip();
    });
    ref.listenManual(
      patchClashConfigProvider.select(
        (state) => (
          allowLan: state.allowLan,
          mixedPort: state.mixedPort,
          ipv6: state.ipv6,
        ),
      ),
      (prev, next) {
        if (shouldNotifyVpnConfigRestart(
          isAndroid: system.isAndroid,
          vpnEnabled: ref.read(vpnSettingProvider).enable,
          prev: prev,
          next: next,
        )) {
          showTip();
        }
      },
    );
    ref.listenManual(currentProfileProvider.select((state) => state?.label), (
      prev,
      next,
    ) {
      if (prev == next || !globalState.isStart) return;
      unawaited(globalState.appController.updateTraffic());
    });
  }

  void showTip() {
    debouncer.call(FunctionTag.vpnTip, () {
      if (ref.read(runTimeProvider.notifier).isStart) {
        globalState.showNotifier(
          appLocalizations.vpnTip,
          onAction: () async {
            await globalState.appController.restartCore();
            globalState.showNotifier(appLocalizations.success);
          },
          actionLabel: appLocalizations.restart,
          showCountdown: true,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
