# Keeps the DNS records that point at the home on the home's active WAN, so
# they follow the gateway onto WAN2 when WAN1 fails, and back
# (docs/wan-dns.md). The plane's own traffic leaves through that same WAN, so
# its public address is the one the records need.
#
# Which records is qoax-infrastructure's to say, not this file's: every A
# record, in the zones it lists in this plane's OpenBao, whose comment carries
# the marker (its docs/dns.md). Every minute: read the Cloudflare token and
# the zones from OpenBao, ask Cloudflare which address we come from, and
# PATCH the address of each marked record that differs. A PATCH keeps a
# record's TTL and comment; a PUT, as cloudflare-dyndns sends, would reset
# both.
#
# OpenBao is reached with a periodic token of the wan-dns policy, placed by
# hand in tokenFile (root, 0400) and renewed every run. Until it is there the
# unit is skipped, and while OpenBao is sealed a run does nothing.
{ pkgs, ... }:

let
  tokenFile = "/var/lib/wan-dns/.bao-token";
  marker = "[follows-wan]";

  update = pkgs.writeShellApplication {
    name = "wan-dns-update";
    runtimeInputs = with pkgs; [
      curl
      gnused
      jq
    ];
    text = ''
      bao_api=http://127.0.0.1:8200/v1
      cf_api=https://api.cloudflare.com/client/v4
      bao_token=$(< "$CREDENTIALS_DIRECTORY/bao-token")
      # Tokens from files, not the command line, so they stay out of ps.
      bao() {
        curl -fsS --max-time 10 \
          -H @<(printf 'X-Vault-Token: %s\n' "$bao_token") "$@"
      }
      cf() {
        curl -fsS --max-time 15 \
          -H @<(printf 'Authorization: Bearer %s\n' "$cf_token") \
          -H 'Content-Type: application/json' "$@"
      }

      # Sealed after a reboot until servacho's unseal job; the next run retries.
      if ! curl -fsS --max-time 10 "$bao_api/sys/health" > /dev/null; then
        echo "OpenBao is sealed or down; nothing done"
        exit 0
      fi
      bao -X POST "$bao_api/auth/token/renew-self" > /dev/null
      cf_token=$(bao "$bao_api/secret/data/cloudflare" | jq -er '.data.data.api_token')
      zones=$(bao "$bao_api/secret/data/cloudflare-zones" | jq -er '.data.data[]')

      ip=$(curl -fsS -4 --max-time 15 https://cloudflare.com/cdn-cgi/trace | sed -n 's/^ip=//p')
      if ! [[ $ip =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
        echo "no IPv4 address from the trace: '$ip'" >&2
        exit 1
      fi

      while read -r zone; do
        # shellcheck disable=SC2016 # jq's variables, not the shell's
        cf "$cf_api/zones/$zone/dns_records?type=A&per_page=500" |
          jq -r --arg marker '${marker}' --arg ip "$ip" '.result[]
            | select((.comment // "") | contains($marker)) | select(.content != $ip)
            | "\(.id) \(.name) \(.content)"' |
          while read -r id name current; do
            cf -X PATCH "$cf_api/zones/$zone/dns_records/$id" --data "{\"content\": \"$ip\"}" > /dev/null
            echo "$name: $current -> $ip"
          done
      done <<< "$zones"
    '';
  };
in
{
  systemd.services.wan-dns = {
    description = "Point the home's DNS records at the active WAN";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig.ConditionPathExists = tokenFile;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${update}/bin/wan-dns-update";
      DynamicUser = true;
      LoadCredential = [ "bao-token:${tokenFile}" ];
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
    startAt = "minutely";
  };
}
