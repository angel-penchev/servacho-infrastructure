# Keeps intercom.qo.ax on the address the network is on the internet with,
# so the intercom follows the gateway onto WAN2 when WAN1 fails, and back
# (docs/unity-intercom.md). The plane's own traffic leaves through the same
# active WAN, so its public address is the one the record needs.
#
# Every minute: ask Cloudflare which address we come from, read the record,
# and PATCH only its content when they differ. A PATCH keeps the record's
# TTL (60 s) and comment; a PUT, as cloudflare-dyndns sends, would reset
# both.
#
# The token is a Cloudflare API token with Zone -> DNS -> Edit on qo.ax
# alone, placed by hand in tokenFile (root, 0400). Until it is there the
# unit is skipped rather than failing.
{ pkgs, ... }:

let
  zoneId = "068c334673663431af83b5ee0f6f85ca"; # qo.ax
  record = "intercom.qo.ax";
  tokenFile = "/var/lib/intercom-dns/.token";

  update = pkgs.writeShellApplication {
    name = "intercom-dns-update";
    runtimeInputs = with pkgs; [
      curl
      gnused
      jq
    ];
    text = ''
      api="https://api.cloudflare.com/client/v4/zones/${zoneId}/dns_records"
      token=$(< "$CREDENTIALS_DIRECTORY/token")
      # From a file, not the command line, so the token stays out of ps.
      cf() {
        curl -fsS --max-time 15 \
          -H @<(printf 'Authorization: Bearer %s\n' "$token") \
          -H 'Content-Type: application/json' "$@"
      }

      ip=$(curl -fsS -4 --max-time 15 https://cloudflare.com/cdn-cgi/trace | sed -n 's/^ip=//p')
      if ! [[ $ip =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
        echo "no IPv4 address from the trace: '$ip'" >&2
        exit 1
      fi

      records=$(cf "$api?type=A&name=${record}")
      if [[ $(jq '.result | length' <<< "$records") != 1 ]]; then
        echo "expected exactly one A record for ${record}" >&2
        exit 1
      fi
      id=$(jq -r '.result[0].id' <<< "$records")
      current=$(jq -r '.result[0].content' <<< "$records")

      if [[ $current == "$ip" ]]; then
        exit 0
      fi

      cf -X PATCH "$api/$id" --data "{\"content\": \"$ip\"}" > /dev/null
      echo "${record}: $current -> $ip"
    '';
  };
in
{
  systemd.services.intercom-dns = {
    description = "Point ${record} at the active WAN";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig.ConditionPathExists = tokenFile;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${update}/bin/intercom-dns-update";
      DynamicUser = true;
      LoadCredential = [ "token:${tokenFile}" ];
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
    startAt = "minutely";
  };
}
