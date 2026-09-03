### Description
Renamed the dedicated 2.4GHz IoT WLAN from `StKr_IoT2.4` to `StKr_IoT_2.4GHz`.
Also includes CI workflow fixes to prevent failures when the self-hosted runner restarts: extracted the auto-unseal logic into a reusable composite action, updated it to use the `OPENBAO_UNSEAL_KEY` repository secret, added a fail-fast health check, and ensured it can safely fallback on NixOS using `wget` or `nix run`.

### Referenced Issue
Resolves #none

### Type of Change
- [x] Bug fix
- [x] New feature / Infrastructure addition
- [ ] Documentation update

### Breaking Changes
- [ ] **No**, this change is fully backwards-compatible and safe to deploy independently.
- [x] **Yes**, this change requires downstream updates, manual intervention, or downtime (explain below).
This introduces a user-visible SSID rename (`hide_ssid=false`). Clients configured for the old SSID (`StKr_IoT2.4`) will stop connecting until reconfigured to use the new `StKr_IoT_2.4GHz` SSID.

### Validation
Ran `tofu apply` on the pull request which successfully migrated the WLAN state. The automated GitHub Actions workflow correctly bypassed the sealed state by running the auto-unseal composite action with the new repository keys.

### Additional Context / Visuals
The `moved` block used for the state migration was removed in the final commit because the pipeline successfully adopted the state during apply.
