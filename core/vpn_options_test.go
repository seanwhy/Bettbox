package main

import (
	"core/state"
	"encoding/json"
	"net/netip"
	"slices"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/config"
)

func TestBuildAndroidVpnOptions(t *testing.T) {
	appState := &state.State{
		VpnProps: state.AndroidVpnRawOptions{
			Enable:      true,
			AllowBypass: false,
			SystemProxy: true,
			RouteMode:   "config",
			DozeSuspend: true,
		},
		BypassDomain: []string{"localhost"},
	}
	cfg := &config.Config{
		General: &config.General{
			IPv6: true,
		},
	}
	cfg.General.MixedPort = 7890
	cfg.General.AllowLan = true
	cfg.General.Tun.RouteAddress = []netip.Prefix{netip.MustParsePrefix("1.0.0.0/8")}
	cfg.General.Tun.RouteExcludeAddress = []netip.Prefix{
		netip.MustParsePrefix("10.0.0.0/8"),
		netip.MustParsePrefix("fe80::/10"),
	}
	cfg.General.Tun.MTU = 9000

	opts := buildAndroidVpnOptions(appState, cfg)
	if !opts.AllowBypass {
		t.Fatalf("expected AllowBypass=true when AllowLan=true")
	}
	if opts.Port != 7890 {
		t.Fatalf("expected Port=7890, got %d", opts.Port)
	}
	if opts.Ipv6Address != state.DefaultIpv6Address {
		t.Fatalf("expected Ipv6Address=%q, got %q", state.DefaultIpv6Address, opts.Ipv6Address)
	}
	wantExcludes := []netip.Prefix{
		netip.MustParsePrefix("10.0.0.0/8"),
		netip.MustParsePrefix("fe80::/10"),
	}
	if !slices.Equal(opts.RouteExcludeAddress, wantExcludes) {
		t.Fatalf("expected RouteExcludeAddress=%v, got %v", wantExcludes, opts.RouteExcludeAddress)
	}

	raw, err := json.Marshal(opts)
	if err != nil {
		t.Fatalf("json.Marshal failed: %v", err)
	}
	if !strings.Contains(string(raw), `"routeExcludeAddress":["10.0.0.0/8","fe80::/10"]`) {
		t.Fatalf("unexpected JSON serialization: %s", raw)
	}
}

func TestBuildAndroidVpnOptionsNilSlicesAndAllowBypassFalse(t *testing.T) {
	appState := &state.State{
		VpnProps: state.AndroidVpnRawOptions{
			Enable:      true,
			AllowBypass: false,
		},
	}
	cfg := &config.Config{
		General: &config.General{
			IPv6: false,
		},
	}
	cfg.General.MixedPort = 7890
	cfg.General.AllowLan = false

	opts := buildAndroidVpnOptions(appState, cfg)
	if opts.AllowBypass {
		t.Fatalf("expected AllowBypass=false when both VpnProps.AllowBypass and AllowLan are false")
	}
	if opts.Ipv6Address != "" {
		t.Fatalf("expected empty Ipv6Address when IPv6=false, got %q", opts.Ipv6Address)
	}
	raw, err := json.Marshal(opts)
	if err != nil {
		t.Fatalf("json.Marshal failed: %v", err)
	}
	for _, field := range []string{
		`"bypassDomain":[]`,
		`"routeAddress":[]`,
		`"routeExcludeAddress":[]`,
	} {
		if !strings.Contains(string(raw), field) {
			t.Fatalf("expected non-nil empty array %s in %s", field, raw)
		}
	}
}
