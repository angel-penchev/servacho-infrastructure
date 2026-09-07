### Description
The UDM and the switches ended up on different VLANs and could no longer talk to each other. After several hours of troubleshooting, the whole estate was factory reset and rebuilt by hand, one documented step at a time. This PR is the first pass at bringing that rebuilt reality back into OpenTofu, and at working out which of the remaining gaps can be closed in code at all.

**Networks**
- The untagged LAN is now `UniFi Devices`.
- Qoax is a single `/23` spanning `192.168.10.0-192.168.11.255`; the separate VLAN 11 network and its output are removed.

**Port profiles**
- Only two profiles survived the reset. `unifi_devices` takes its real name, `UniFi Device`, and remains the VLAN 1 profile for infrastructure uplinks.
- `unifi_port_profile.main` becomes `host_device`. The old name was actively misleading: the profile governs host access ports, not the Main VLAN. The rename is plumbed through outputs, module variables and the device files.

**802.1X — unauthenticated clients were getting no DHCP at all**

Host ports run `dot1x_ctrl = "auto"`, which leaves an unauthenticated client *unauthorized* and drops everything it sends, its DHCP handshake included. The intended "if they don't authenticate, put them on Guest" behaviour is not a port-profile property at all — it is the site-wide **802.1X fallback VLAN**, and it was unset. It has been set to Guest on the controller. It is not expressible in code (`unifi_setting` exposes no switch/dot1x block at v0.55.0), so the profile documents the dependency instead, and now takes Main as its native VLAN — that being what an authenticated client with no RADIUS-assigned VLAN should receive.

Verified against a real client: a wired host on a `dot1x_ctrl = "auto"` port now holds a Guest lease, which was impossible before.

**Devices**
- UDM renamed to `UDM StKr`; static management addresses declared; AP LEDs switched off.

**Also**
- WANs match the controller; the `Hotspot` zone is managed so the Guest network keeps `purpose = "guest"`; the DMZ zone uses the controller's `Dmz` casing; the previously unused `radius_profile_secret` now feeds `unifi_setting.radius`; both IoT SSIDs are hidden.

**Documentation**
- `docs/unifi-manual-vs-tofu.md` — three-way comparison of the rebuild checklist, the live controller and the tofu config, plus a survey of the provider's bug surface.
- `docs/unifi-browser-changes.md` — every change made to the live controller outside of tofu, with before/after values.

### Referenced Issue
Refs #27.

Deliberately **not** `Resolves`. Issue #27 asks for three things; this PR delivers the first two (edge mode on the profiles, a dedicated UniFi device profile on VLAN 1) but not the third — enabling/disabling ports on the 10G switch — which is blocked upstream, see below. #27 should stay open.

### Type of Change
- [x] Bug fix
- [x] New feature / Infrastructure addition
- [x] Documentation update

### Breaking Changes
- [ ] **No**, this change is fully backwards-compatible and safe to deploy independently.
- [x] **Yes**, this change requires downstream updates, manual intervention, or downtime (explain below).

1. **Both IoT SSIDs are now hidden** (`StKr_IoT`, `StKr_IoT_2.4GHz`). Already-associated devices keep working — only the beacon changes — but any IoT device that joined by picking the SSID from a scan list will need it entered manually if it is ever re-provisioned.
2. **The 802.1X fallback VLAN is a manual, site-wide setting.** It is not in this PR's code and will not be recreated by `tofu apply`. If the controller is ever rebuilt, it must be set by hand or host ports silently stop handing out addresses.
3. **The `Host Device` native VLAN moves from Guest to Main.** Reachable only after successful 802.1X, so this is not a widened boundary, but it does change where an authenticated client with no RADIUS VLAN lands.

### Validation
`tofu fmt -check` clean and `tofu validate` passing throughout.

`tofu plan` was **not** run: state lives on the management plane, not on the workstation. Live state was instead read directly from the controller's Network REST API through an authenticated browser session, and every controller-side change was verified by reading the object back afterwards. The end state is recorded in `docs/unifi-browser-changes.md`.

### Additional Context / Visuals

**This PR is a checkpoint, not the finished job.** Still outstanding, all marked `TODO(...)` in the files and tracked in `docs/unifi-manual-vs-tofu.md`:

- Port overrides on all three switches — no custom port names survive on the controller.
- The three per-VLAN port profiles destroyed by the reset (`IoT`, `Public Servers`, `Private Servers`).
- mDNS policy.
- Two RADIUS users not yet created.
- Port forwards, fixed-IP clients, VPN, site settings.
- Pro Max ports 6 and 18 are known bad (no DHCP lease) and deliberately left alone.

**Much of the remainder is blocked on the provider, not on us.** `ubiquiti-community/unifi` v0.55.0 is still the latest release while `main` carries 13 unreleased fixes. Two consequences matter here:

- `buildMinimalUpdateDevice` silently drops most device fields from the update `PUT`, so the static management IPs in this PR are declared but **inert** until [#463](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/463) ships. They are annotated as such.
- The `ignore_changes = [port_override]` blocks must stay. [#430](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/430) (merged, unreleased) shows a single declared `port_override` silently strips settings from *every* port on the device — the most likely explanation for why no port names survived in the first place.

Also worth recording: `forward = "disabled"` never disabled a port. Port State is `port_security_enabled` with an empty MAC allowlist ([#470](https://github.com/ubiquiti-community/terraform-provider-unifi/pull/470), still open), which is why the earlier commits on this branch cycling through disable strategies could not have worked.
