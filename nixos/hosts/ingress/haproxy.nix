# HAProxy on ingress, built from tenants.json (docs/ingress.md says how to add
# a tenant).
#
# 443 is routed by the TLS server name and passed on unopened, so the VM
# ends no TLS and holds no tenant's keys; 80 is routed by the Host header. A
# connection with no name, or with a name no tenant claims, is closed on 443
# and gets a 404 on 80: there is no default backend.
#
# tenants.json maps each tenant, named with lower-case letters, digits and
# dashes, to:
#
#   names           exact names, and suffixes with a leading dot, each of
#                   which covers every name under it: ".example.org" covers
#                   "www.example.org", but not "example.org" or
#                   "badexample.org". An exact name wins over a suffix.
#   https           its servers for 443, as "address:port"
#   http            its servers for 80, which answer ACME HTTP-01 challenges
#                   and redirect to HTTPS; left out, HAProxy redirects itself
#   proxy_protocol  true when its servers take a PROXY v2 header with the
#                   visitor's address, on both ports; false when left out
#
# A file that claims a name twice, in which a tenant's suffix covers another
# tenant's name, or that makes the VM or its gateway (vm.json) a server, does
# not evaluate, and the system's build runs haproxy -c on the result: a bad
# entry fails the pull request's plan, not the VM. Which networks a server
# may be on is tofu/unifi/ingress.tf's to check, in the same plan.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  tenants = lib.importJSON ./tenants.json;
  # The VM's address and gateway, as configuration.nix sets them.
  vm = lib.importJSON ./vm.json;

  label = "[a-z0-9]([a-z0-9-]*[a-z0-9])?";
  octet = "(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])";
  matches = pattern: s: builtins.isString s && builtins.match pattern s != null;
  isListOf = check: v: builtins.isList v && lib.all check v;
  isName = matches "\\.?${label}(\\.${label})+";
  # On the home's networks, and neither the VM itself nor its gateway. The VM
  # trusts lo, so a server at its own address would hand each connection of a
  # tenant without proxy_protocol back to HAProxy, until it ran out of
  # connections; the gateway's 80 and 443 are the UniFi console. Which
  # networks a server may be on, and which hosts on them it may not be, is
  # tofu/unifi/ingress.tf's to check: it knows them, and fails the plan.
  isServer =
    s:
    matches "192\\.168\\.${octet}\\.${octet}:[1-9][0-9]{0,4}" s
    && lib.toInt (lib.last (lib.splitString ":" s)) <= 65535
    && !builtins.elem (lib.head (lib.splitString ":" s)) [
      vm.address
      vm.gateway
    ];
  # isServer in words, for the problems below.
  serverRule = "address:port, the addresses in 192.168.0.0/16 and neither the VM's ${vm.address} nor its gateway ${vm.gateway}";

  tenantProblems =
    id: t:
    if !builtins.isAttrs t then
      [ "${id}: not an object" ]
    else
      lib.optional (
        !matches label id
      ) "${id}: a tenant is named with lower-case letters, digits and dashes"
      ++ map (field: "${id}: unknown field ${field}") (
        lib.subtractLists [ "names" "https" "http" "proxy_protocol" ] (builtins.attrNames t)
      )
      ++ lib.optional (
        !(t ? names && t.names != [ ] && isListOf isName t.names)
      ) "${id}: names is a list of lower-case names, exact or with a leading dot"
      ++ lib.optional (
        !(t ? https && t.https != [ ] && isListOf isServer t.https)
      ) "${id}: https is a list of ${serverRule}"
      ++ lib.optional (t ? http && !isListOf isServer t.http) "${id}: http is a list of ${serverRule}"
      ++ lib.optional (
        t ? proxy_protocol && !builtins.isBool t.proxy_protocol
      ) "${id}: proxy_protocol is true or false";

  # Every name, with the tenant that claims it.
  claimsOf =
    ts:
    lib.concatLists (
      lib.mapAttrsToList (tenant: t: map (name: { inherit tenant name; }) (lib.unique t.names)) ts
    );

  # Whether a covers b: the same name, or a suffix that b ends with.
  covers = a: b: a == b || (lib.hasPrefix "." a && lib.hasSuffix a b);

  conflicts =
    claims:
    lib.concatMap (
      a:
      lib.concatMap (
        b:
        if a.name == b.name then
          lib.optional (a.tenant < b.tenant) "${a.name} is claimed by both ${a.tenant} and ${b.tenant}"
        else
          lib.optional (
            a.tenant != b.tenant && covers a.name b.name
          ) "${b.name} (${b.tenant}) is covered by ${a.name} (${a.tenant})"
      ) claims
    ) claims;

  problems =
    if !builtins.isAttrs tenants then
      [ "the file is one JSON object, of tenants" ]
    else
      let
        shapes = lib.concatLists (lib.mapAttrsToList tenantProblems tenants);
      in
      if shapes != [ ] then shapes else conflicts (claimsOf tenants);

  checked =
    if problems == [ ] then
      tenants
    else
      throw ''
        nixos/hosts/ingress/tenants.json (docs/ingress.md):
        ${lib.concatMapStrings (problem: "  - ${problem}\n") problems}'';

  # One pair of maps serves both ports, from each name to its tenant: exact
  # names, and the suffixes map_end matches. Each port makes the tenant its
  # own backend's name, https-<tenant> or http-<tenant>, prefixes no other
  # backend has.
  mapFile =
    kind: suffixes:
    pkgs.writeText "ingress-${kind}.map" (
      lib.concatMapStrings (claim: "${claim.name} ${claim.tenant}\n") (
        lib.filter (claim: lib.hasPrefix "." claim.name == suffixes) (claimsOf checked)
      )
    );
  exactMap = mapFile "exact" false;
  suffixMap = mapFile "suffix" true;

  # A server is named after its address, which is what the log shows, so a
  # server listed twice is listed once.
  servers =
    t: addresses:
    map (
      address:
      "  server ${address} ${address} check"
      + lib.optionalString (t.proxy_protocol or false) " send-proxy-v2"
    ) (lib.unique addresses);

  backends = lib.concatLines (
    lib.concatLists (
      lib.mapAttrsToList (
        id: t:
        [
          ""
          "backend https-${id}"
          "  mode tcp"
        ]
        ++ servers t t.https
        ++ [
          ""
          "backend http-${id}"
          "  mode http"
          "  timeout server 30s"
        ]
        ++ (
          if (t.http or [ ]) != [ ] then
            servers t t.http
          else
            [ "  http-request redirect scheme https code 301" ]
        )
      ) checked
    )
  );
in
{
  services.haproxy = {
    enable = true;
    # The module opens the global section with the stats socket that hands
    # the listeners over on a reload; this carries on from there.
    config = ''
        maxconn 4096
        # After a reload, old workers keep their connections until those
        # close, for 30 minutes at most.
        hard-stop-after 30m
        # One line per connection, to the journal.
        log stdout format short daemon

      defaults
        log global
        timeout connect 2s
        # 443's: 5 minutes of silence, so that held streams and WebSockets
        # stay open. Port 80 sets its own.
        timeout client 5m
        timeout server 5m
        # Every server is checked every 5 s and down after 2 failures, and a
        # failed connection is retried on the tenant's next server.
        default-server inter 5s fall 2 rise 2
        option redispatch 1

      frontend https
        mode tcp
        bind :443
        log-format "%ci:%cp %ft %[var(sess.name)] %b/%s %Tw/%Tc/%Tt %B %ts %ac/%fc/%bc/%sc/%rc %sq/%bq"
        # Up to 5 s for the ClientHello. Its server name picks the tenant,
        # an exact name before a suffix.
        tcp-request inspect-delay 5s
        tcp-request content set-var(sess.name) req.ssl_sni,lower if { req.ssl_hello_type 1 }
        tcp-request content set-var(sess.tenant) var(sess.name),map_str(${exactMap}) if { var(sess.name) -m found }
        tcp-request content set-var(sess.tenant) var(sess.name),map_end(${suffixMap}) if { var(sess.name) -m found } !{ var(sess.tenant) -m found }
        tcp-request content accept if { req.ssl_hello_type 1 }
        # No default backend: anything else is closed.
        use_backend https-%[var(sess.tenant)] if { var(sess.tenant) -m found }

      frontend http
        mode http
        bind :80
        log-format "%ci:%cp %ft %[var(txn.name)] %b/%s %TR/%Tw/%Tc/%Tr/%Ta %ST %B %tsc %ac/%fc/%bc/%sc/%rc %sq/%bq %{+Q}r"
        # 10 s to send the headers.
        timeout http-request 10s
        timeout client 30s
        # The Host header without its port picks the tenant, as on 443.
        http-request set-var(txn.name) req.hdr(host),host_only,lower
        http-request set-var(txn.tenant) var(txn.name),map_str(${exactMap}) if { var(txn.name) -m found }
        http-request set-var(txn.tenant) var(txn.name),map_end(${suffixMap}) if { var(txn.name) -m found } !{ var(txn.tenant) -m found }
        http-request deny deny_status 404 unless { var(txn.tenant) -m found }
        use_backend http-%[var(txn.tenant)]

      # HAProxy's Prometheus exporter, for the sources configuration.nix
      # admits.
      frontend metrics
        mode http
        bind :8405
        no log
        timeout client 30s
        http-request use-service prometheus-exporter if { path /metrics }
        http-request deny deny_status 404
    ''
    + backends;
  };

  # A changed configuration is reloaded rather than restarted, as the module
  # alone would: the new workers take the listeners over, and the old ones
  # keep their connections.
  systemd.services.haproxy.reloadIfChanged = true;

  # haproxy -c, warnings included, on the configuration the VM runs, maps and
  # all: part of the system's build, and the flake's checks.ingress-haproxy.
  system.build.haproxyCheck =
    let
      haproxy = lib.getExe config.services.haproxy.package;
      haproxyCfg = config.environment.etc."haproxy.cfg".source;
    in
    pkgs.runCommand "ingress-haproxy-check" { } ''
      ${haproxy} -c -dW -f ${haproxyCfg}
      touch $out
    '';
  system.checks = [ config.system.build.haproxyCheck ];
}
