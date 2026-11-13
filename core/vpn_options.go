package main

import (
	"core/state"
	"net/netip"

	"github.com/metacubex/mihomo/config"
)

func nonNilPrefixes(prefixes []netip.Prefix) []netip.Prefix {
	if len(prefixes) == 0 {
		return []netip.Prefix{}
	}
	out := make([]netip.Prefix, len(prefixes))
	copy(out, prefixes)
	return out
}

func nonNilStrings(items []string) []string {
	if len(items) == 0 {
		return []string{}
	}
	out := make([]string, len(items))
	copy(out, items)
	return out
}

// buildAndroidVpnOptions constructs the VpnService configuration passed to Android.
func buildAndroidVpnOptions(appState *state.State, cfg *config.Config) state.AndroidVpnOptions {
	if appState == nil {
		appState = &state.State{}
	}
	if cfg == nil {
		cfg = &config.Config{General: &config.General{}}
	} else if cfg.General == nil {
		cfgCopy := *cfg
		cfgCopy.General = &config.General{}
		cfg = &cfgCopy
	}
	ipv6Address := ""
	if cfg.General.IPv6 {
		ipv6Address = state.DefaultIpv6Address
	}
	return state.AndroidVpnOptions{
		Enable:                appState.VpnProps.Enable,
		Port:                  cfg.General.MixedPort,
		Ipv4Address:           state.DefaultIpv4Address,
		Ipv6Address:           ipv6Address,
		AccessControl:         appState.VpnProps.AccessControl,
		SystemProxy:           appState.VpnProps.SystemProxy,
		AllowBypass:           appState.VpnProps.AllowBypass || cfg.General.AllowLan,
		RouteAddress:          nonNilPrefixes(cfg.General.Tun.RouteAddress),
		RouteExcludeAddress:   nonNilPrefixes(cfg.General.Tun.RouteExcludeAddress),
		RouteMode:             appState.VpnProps.RouteMode,
		BypassDomain:          nonNilStrings(appState.BypassDomain),
		DnsServerAddress:      state.GetDnsServerAddress(),
		DozeSuspend:           appState.VpnProps.DozeSuspend,
		DisableIcmpForwarding: cfg.General.Tun.DisableICMPForwarding,
		Mtu:                   uint32(cfg.General.Tun.MTU),
	}
}
