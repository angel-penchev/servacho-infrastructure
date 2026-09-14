# Runbook: import the live UniFi controller into OpenTofu state

**Written:** 2026-09-14 · **Status:** ✅ **done 2026-09-14** — 46 resources imported (apply run 34843335300), one re-imported (run 34876118372), `tofu/imports_unifi.tf` deleted, plan clean. Kept as the record of how it was done and for the next import (a new device, a resource created by hand).
**Where:** the management plane (`servacho-managment-plane`, `192.168.5.11`), the only host with the state file (`/var/lib/opentofu/servacho-infrastructure.tfstate`, local backend in `tofu/providers.tf`) and OpenBao.
**What:** `tofu/imports_unifi.tf` (deleted after the run, see git history at 28664fc) — 46 `import` blocks, one per resource in `tofu/unifi`, with the live ids read from the controller on 2026-09-14. Nothing had been applied since the factory reset of 2026-09-05; the tree was written to mirror live, and the imports landed with a 4-change diff that §14.12 of the drift report walks through.

## Why import blocks

The five aspirational blocks in the module (`unifi_setting_switch`, `unifi_setting_security`, `unifi_setting_ether_lighting`, `unifi_setting_mdns`, `unifi_wan_sla`) are commented out, so 46 real resources remain and every one of them exists live. Importing (rather than letting `apply` create) matters because:

- a duplicate create is rejected (`unifi_radius_user` has no `allow_existing`; a second network/profile/WLAN/zone with the same name errors or, for policies, silently duplicates);
- `unifi_device` cannot be created at all, only adopted; import is the documented way in;
- `unifi_client` with `allow_existing = true` would take over on create, but only import gives a clean `plan` first.

`import` blocks give one `tofu plan` that shows the 46 imports **and** every diff at once, without touching the controller. The `tofu import` CLI loop at the end does the same one resource at a time and never applies anything — use it if the plan shows drift you do not want to apply yet.

## Id formats (provider v0.55.0, from its `ImportState` code)

| Type | Import id | Note |
|---|---|---|
| `unifi_network`, `unifi_port_profile`, `unifi_wlan`, `unifi_port_forward`, `unifi_firewall_zone`, `unifi_firewall_policy`, `unifi_vpn_server`, `unifi_radius_user` | controller `_id` (optionally `default:<_id>`) | radius user = account `_id` |
| `unifi_wan` | `_id` if 24 hex, otherwise the WAN **name** | `networkgroup` is read from the controller on import |
| `unifi_device` | **MAC** or `_id` | site is the provider's; a `site:` prefix is not parsed |
| `unifi_client` | **MAC only** | anything without colons is rejected |
| `unifi_setting` | `default` (the site name) | populates nothing until the first refresh — expect a full diff on this one resource |

## Procedure

Everything below runs on the management plane in the repo's `tofu/` directory with OpenBao unsealed and `BAO_ADDR=http://127.0.0.1:8200` (the root module reads the provider credentials and the module secrets from it).

### 1. Bring the tree over and initialise

```sh
git pull                      # the branch that carries the import blocks
tofu init                     # provider ~> 0.55.0 is pinned; -upgrade not needed
```

### 2. Clear the pre-reset entries from state

State still holds the ids of the controller that was factory-reset on 2026-09-05, under the old submodule addresses (`module.unifi.module.core.*`, `module.unifi.module.devices.*`, …). A refresh would 404 on each and drop them, but do it explicitly so the plan is readable:

```sh
tofu state list | grep '^module.unifi\.'
tofu state list | grep '^module.unifi\.' | xargs -r -n1 tofu state rm
```

Nothing outside `module.unifi` (Proxmox, Vault) is touched.

### 3. Plan

```sh
tofu plan -out=unifi-import.plan 2>&1 | tee unifi-import.plan.txt
```

Expected: `46 to import`. Then read the diff line by line against this list:

| Diff | Verdict |
|---|---|
| `module.unifi.unifi_setting.default` shows every block as an add | **Expected.** Import stores only the id; the first refresh/apply fills it. The values are the live ones, so the apply POSTs what is already there. |
| Nothing else | The goal. |
| `unifi_client.*` shows `last_ip` or similar computed noise | Known #428 — an in-place update **fails** on apply. Do not apply; add the attribute to `ignore_changes` in `clients.tf` and re-plan. |
| `unifi_device.*` shows `port_override` changes | Should not happen (`ignore_changes = [port_override]` is on all three switches/gateway). If it does, stop — see drift report §14.3. |
| `unifi_device.*` shows `config_network` / `disabled` / STP changes | Known #463 / #476: those fields are dropped from the update PUT, apply would fail with "inconsistent result". Do not apply; mirror the live value in code and re-plan. |
| `unifi_wlan.*` passphrase / bands | Should not happen (`ignore_changes` in `wlans.tf`). |
| `unifi_firewall_policy.*` `index` | Read-only, #348. Should not appear because `index` is not declared. |
| `unifi_wan.*` `provider_capabilities` on the secondary | Not declared in code because live stores none; if the plan wants to remove something, mirror live. |
| Anything else | A doc bug: the code is meant to mirror live. Fix the code to match live, re-plan, and record the finding in `unifi-manual-vs-tofu.md`. |

### 4. Apply

Only when the plan is imports + the `unifi_setting` fill-in and nothing else:

```sh
tofu apply unifi-import.plan
tofu plan                     # must now be "No changes."
```

If the plan is not clean and you still want the imports in state, do **not** apply the saved plan. Use the CLI loop below (state only), then work the diffs down one by one.

### 5. Clean up

- Delete `tofu/imports_unifi.tf` (or comment it out like `tofu/vms.tf` does) — a second plan with the blocks present is harmless but noisy. Commit. *(Done 2026-09-14.)*
- Update `docs/unifi-manual-vs-tofu.md` §0.6 A1 → done, and note the first clean plan's date. *(Done; first clean plan 2026-09-14.)*
- From here on the loop is: change in UI or API → read back → mirror → `tofu plan` must be clean. The `ignore_changes` blocks listed under §0.6 B stay until the provider ships the fixes.

## CLI fallback (state only, nothing applied)

Same 46 objects as the blocks. Run from `tofu/`:

```sh
while IFS=$'\t' read -r type name id mac; do
  case "$type" in
    unifi_client|unifi_device) import_id="$mac" ;;
    *)                         import_id="$id" ;;
  esac
  tofu import "module.unifi.${type}.${name}" "$import_id"
done <<'TSV'
unifi_network	default	6a9c2f5583de4db1f0f1dcf6
unifi_network	unifi_devices	6aa6e779e5a2f2ebb4473ca6
unifi_network	main	6a9d34cc3346f05e9f31efd9
unifi_network	guest	6a9d34da3346f05e9f31efe6
unifi_network	public_servers	6a9d35773346f05e9f31f0ac
unifi_network	private_servers	6a9d358b3346f05e9f31f0bd
unifi_network	iot	6a9d35a43346f05e9f31f0db
unifi_network	qoax_community_vps	6a9d35e63346f05e9f31f11f
unifi_network	fmicodes_vps	6a9d360a3346f05e9f31f145
unifi_wan	vivacom_primary	6a9c2f5583de4db1f0f1dcf4
unifi_wan	vivacom_secondary	6a9c2f5583de4db1f0f1dcf5
unifi_vpn_server	openvpn	6aa6f9cae5a2f2ebb4474a26
unifi_vpn_server	wireguard	6aa70407e5a2f2ebb44756e8
unifi_port_profile	unifi_devices	6a9d116e3346f05e9f31cd55
unifi_port_profile	host_device	6a9e48d140324b44914391ab
unifi_port_profile	public_servers	6aa12b2a40324b449145290b
unifi_port_profile	private_servers	6aa12ba440324b449145295b
unifi_port_profile	iot	6aa12c4e40324b44914529f2
unifi_device	udm_pro_max	6a9c2f6f83de4db1f0f1dd0f	28:70:4e:5c:b4:b2
unifi_device	usw_pro_max_24_poe	6a9c94d33346f05e9f31829b	9c:05:d6:e2:6b:1d
unifi_device	usw_aggregation	6a9c94963346f05e9f318250	1c:6a:1b:98:38:ee
unifi_device	u7_pro_living_room	6a9d0f673346f05e9f31caed	9c:05:d6:d9:ad:79
unifi_device	u7_pro_bedroom	6a9d0f8a3346f05e9f31cb19	9c:05:d6:d9:af:65
unifi_client	servacho_gosho	6a9c96a13346f05e9f31846e	38:05:25:30:79:97
unifi_client	jetkvm_servacho_gosho	6a9c94b93346f05e9f318269	30:52:53:0a:09:87
unifi_client	jetkvm_michelangelo	6a9c94ca3346f05e9f31828b	30:52:53:0d:1a:68
unifi_client	fmicodes_master_node	6a9c94883346f05e9f318246	bc:24:11:c3:e5:f4
unifi_client	fmicodes_worker_node_1	6a9c94fb3346f05e9f3182cc	bc:24:11:23:76:b5
unifi_client	hackjamhub_intercom	6a9c94a63346f05e9f31825a	bc:24:11:8a:b7:98
unifi_client	living_room_tv	6a9c928483de4db1f0f1e2b3	b0:b3:69:41:2c:9b
unifi_client	bedroom_tv	6aa15f8b40324b4491455979	f4:4e:b4:73:bf:19
unifi_wlan	stkr	6a9d0ff73346f05e9f31cb74
unifi_wlan	stkr_guest	6a9e4cee40324b4491439ecb
unifi_wlan	stkr_iot	6a9f205b40324b44914417d1
unifi_wlan	stkr_iot_2_4ghz	6a9f207640324b44914417fa
unifi_firewall_zone	dmz	6a9d37ad3346f05e9f31f329
unifi_firewall_zone	hotspot	6a9d37ad3346f05e9f31f328
unifi_firewall_zone	iot	6aa12f7b40324b4491452cf5
unifi_firewall_policy	allow_main_to_iot	6a9f35ba40324b4491442e21
unifi_firewall_policy	allow_private_servers_to_iot	6aa130b640324b4491452eb5
unifi_port_forward	nginx_proxy	6a9d909b40324b44914265d2
unifi_radius_user	users["a.penchev"]	6a9d366c3346f05e9f31f1ba
unifi_radius_user	users["e.pencheva"]	6a9f24ec40324b4491441d6d
unifi_radius_user	users["vl.penchev"]	6aa6b995e5a2f2ebb44715bb
unifi_radius_user	users["v.todorova"]	6aa6b982e5a2f2ebb44715ab
unifi_setting	default	default
TSV
```

The `unifi_radius_user` names carry their `for_each` key, e.g. `module.unifi.unifi_radius_user.users["a.penchev"]`; the quotes must reach `tofu`, which the loop preserves.

## Re-import one resource

Done once, 2026-09-14, for `module.unifi.unifi_network.unifi_devices` (drift report §14.12 #14: the network was imported with DHCP Guarding off and the provider's Read never fills `dhcp_guarding` afterwards; apply run 34876118372, `1 imported, 0 changed`). Recipe: keep (or re-add) the resource's `import` block, drop the state entry on the management plane, and run the apply workflow once more — the import re-reads the object. `sudo` leaves the state files owned by root only if it creates them; check with `ls -ln /var/lib/opentofu/` (trailing slash, it is a symlink) that every file has the directory's uid:

```sh
cd ~/servacho-infrastructure && git pull
sudo tofu -chdir=tofu state rm module.unifi.unifi_network.unifi_devices
sudo chown --reference=/var/lib/opentofu /var/lib/opentofu/servacho-infrastructure.tfstate*
```

Then `gh workflow run tofu-apply.yaml --ref <branch> -f branch=<branch> -f auto_approve=false` (or let the PR plan show `1 to import, 0 to change` first). `state rm` never touches the controller.

## Rollback

Import changes state only. `tofu state rm <address>` undoes any single import; the controller is never written to by an import. The only write in this runbook is step 4's apply, and its plan is inspected first.
