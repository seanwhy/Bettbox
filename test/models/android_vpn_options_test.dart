import 'dart:convert';

import 'package:why_box/manager/vpn_manager.dart';
import 'package:why_box/models/clash_config.dart';
import 'package:why_box/models/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AndroidVpnOptions', () {
    test('defaults routeExcludeAddress to empty and round-trips JSON', () {
      const baseJson = {
        'enable': true,
        'port': 7890,
        'accessControl': null,
        'allowBypass': true,
        'systemProxy': true,
        'bypassDomain': ['localhost'],
        'ipv4Address': '198.51.100.1/30',
        'ipv6Address': 'fdfe:dcba:9876::1/126',
        'dnsServerAddress': '198.51.100.2',
        'routeExcludeAddress': null,
      };
      final withoutExcludes = AndroidVpnOptions.fromJson(baseJson);
      expect(withoutExcludes.routeExcludeAddress, isEmpty);

      final updated = withoutExcludes.copyWith(
        routeExcludeAddress: ['10.0.0.0/8', 'fe80::/10'],
      );
      final restored = AndroidVpnOptions.fromJson(
        jsonDecode(jsonEncode(updated.toJson())) as Map<String, dynamic>,
      );
      expect(restored.routeExcludeAddress, ['10.0.0.0/8', 'fe80::/10']);
      expect(restored.allowBypass, isTrue);
    });
  });

  group('TunExt.getRealTun', () {
    test('populates Android routeExcludeAddress when bypassing private routes', () {
      const tun = Tun(
        routeExcludeAddress: ['192.0.2.0/24', '10.0.0.0/8'],
      );

      final realTun = tun.getRealTun(
        true,
        isDesktop: false,
        isLinux: false,
      );

      expect(realTun.autoRoute, isTrue);
      expect(realTun.routeAddress, defaultBypassPrivateRouteAddress);
      expect(
        realTun.routeExcludeAddress,
        containsAll(['192.0.2.0/24', ...defaultAndroidRouteExcludeAddress]),
      );
      expect(
        realTun.routeExcludeAddress.where((e) => e == '10.0.0.0/8').length,
        1,
      );
    });

    test('preserves custom Android bypassPrivateRouteAddress without injecting default excludes', () {
      const tun = Tun(routeExcludeAddress: ['192.0.2.0/24']);
      final customRoutes = ['1.0.0.0/8', '10.10.0.0/16'];

      final realTun = tun.getRealTun(
        true,
        bypassPrivateRouteAddress: customRoutes,
        isDesktop: false,
        isLinux: false,
      );

      expect(realTun.routeAddress, customRoutes);
      expect(realTun.routeExcludeAddress, ['192.0.2.0/24']);
    });

    test('clears Android routeAddress while preserving profile routeExcludeAddress when bypass is off', () {
      const tun = Tun(routeExcludeAddress: ['10.0.0.0/8']);

      final realTun = tun.getRealTun(
        false,
        isDesktop: false,
        isLinux: false,
      );

      expect(realTun.routeAddress, isEmpty);
      expect(realTun.routeExcludeAddress, ['10.0.0.0/8']);
    });

    test('keeps desktop routeExcludeAddress behavior unchanged', () {
      const tun = Tun();

      final realTun = tun.getRealTun(
        true,
        isDesktop: true,
        isLinux: true,
      );

      expect(realTun.autoRedirect, isTrue);
      expect(realTun.routeAddress, isEmpty);
      expect(
        realTun.routeExcludeAddress,
        defaultDesktopBypassPrivateRouteAddress,
      );
    });
  });

  group('shouldNotifyVpnConfigRestart', () {
    const initial = (allowLan: false, mixedPort: 7890, ipv6: false);

    test('notifies only on Android when VPN is enabled and relevant config changed', () {
      expect(
        shouldNotifyVpnConfigRestart(
          isAndroid: true,
          vpnEnabled: true,
          prev: null,
          next: initial,
        ),
        isFalse,
      );
      expect(
        shouldNotifyVpnConfigRestart(
          isAndroid: true,
          vpnEnabled: true,
          prev: initial,
          next: initial,
        ),
        isFalse,
      );
      expect(
        shouldNotifyVpnConfigRestart(
          isAndroid: false,
          vpnEnabled: true,
          prev: initial,
          next: (allowLan: true, mixedPort: 7890, ipv6: false),
        ),
        isFalse,
      );
      expect(
        shouldNotifyVpnConfigRestart(
          isAndroid: true,
          vpnEnabled: false,
          prev: initial,
          next: (allowLan: true, mixedPort: 7890, ipv6: false),
        ),
        isFalse,
      );
      expect(
        shouldNotifyVpnConfigRestart(
          isAndroid: true,
          vpnEnabled: true,
          prev: initial,
          next: (allowLan: true, mixedPort: 7890, ipv6: false),
        ),
        isTrue,
      );
      expect(
        shouldNotifyVpnConfigRestart(
          isAndroid: true,
          vpnEnabled: true,
          prev: initial,
          next: (allowLan: false, mixedPort: 7891, ipv6: false),
        ),
        isTrue,
      );
    });
  });
}
