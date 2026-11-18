# HAProxy on ingress, built from tenants.json (docs/ingress.md).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  tenants = lib.importJSON ./tenants.json;
  vm = lib.importJSON ./vm.json;

  label = "[a-z0-9]([a-z0-9-]*[a-z0-9])?";
  octet = "(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])";
  matches = pattern: s: builtins.isString s && builtins.match pattern s != null;
  isListOf = check: v: builtins.isList v && lib.all check v;
  isName = matches "\\.?${label}(\\.${label})+";
  # Not the VM, which would loop back into HAProxy, nor its gateway, whose 80
  # and 443 are the UniFi console. tofu/unifi/ingress.tf checks the rest.
  isServer =
    s:
    matches "192\\.168\\.${octet}\\.${octet}:[1-9][0-9]{0,4}" s
    && lib.toInt (lib.last (lib.splitString ":" s)) <= 65535
    && !builtins.elem (lib.head (lib.splitString ":" s)) [
      vm.address
      vm.gateway
    ];
  # isServer in words: change the two together.
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

  claimsOf =
    ts:
    lib.concatLists (
      lib.mapAttrsToList (tenant: t: map (name: { inherit tenant name; }) (lib.unique t.names)) ts
    );

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

  problemsOf =
    file:
    if !builtins.isAttrs file then
      [ "the file is one JSON object, of tenants" ]
    else
      let
        shapes = lib.concatLists (lib.mapAttrsToList tenantProblems file);
      in
      if shapes != [ ] then shapes else conflicts (claimsOf file);

  problems = problemsOf tenants;

  # Tried by the assertions below. Each is otherwise good and must report
  # its own problem: one refused for its shape never reaches the name checks.
  rejectedFiles =
    let
      tenant = names: {
        inherit names;
        https = [ "192.168.10.40:443" ];
      };
      serverProblem =
        field:
        "a: ${field} is a list of address:port, the addresses in 192.168.0.0/16 and neither the VM's ${vm.address} nor its gateway ${vm.gateway}";
    in
    {
      "a name claimed twice" = {
        file = {
          a = tenant [ "a.example" ];
          b = tenant [ "a.example" ];
        };
        problem = "a.example is claimed by both a and b";
      };
      "a suffix over another tenant's name" = {
        file = {
          a = tenant [ "www.a.example" ];
          b = tenant [ ".a.example" ];
        };
        problem = "www.a.example (a) is covered by .a.example (b)";
      };
      "a misspelt field" = {
        file.a = tenant [ "a.example" ] // {
          proxy-protocol = true;
        };
        problem = "a: unknown field proxy-protocol";
      };
      "a server off 192.168.0.0/16" = {
        file.a = tenant [ "a.example" ] // {
          https = [ "10.0.0.1:443" ];
        };
        problem = serverProblem "https";
      };
      "the VM's own address as a server" = {
        file.a = tenant [ "a.example" ] // {
          https = [ "${vm.address}:443" ];
        };
        problem = serverProblem "https";
      };
      "the VM's gateway as a server" = {
        file.a = tenant [ "a.example" ] // {
          http = [ "${vm.gateway}:80" ];
        };
        problem = serverProblem "http";
      };
    };

  checked =
    if problems == [ ] then
      tenants
    else
      throw ''
        nixos/hosts/ingress/tenants.json (docs/ingress.md):
        ${lib.concatMapStrings (problem: "  - ${problem}\n") problems}'';

  mapFile =
    kind: suffixes:
    pkgs.writeText "ingress-${kind}.map" (
      lib.concatMapStrings (claim: "${claim.name} ${claim.tenant}\n") (
        lib.filter (claim: lib.hasPrefix "." claim.name == suffixes) (claimsOf checked)
      )
    );
  exactMap = mapFile "exact" false;
  suffixMap = mapFile "suffix" true;

  # Named after its address, so that the log shows it.
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

  # In both frontends, so that 80 and 443 count together (docs/ingress.md).
  # These lines must come before any tcp-request content, http-request or
  # use_backend line, or haproxy -c -dW fails the build.
  perAddressLimits = lib.concatStringsSep "\n  " [
    "acl shared-address src ${vm.gateway}"
    "acl shared-address src -f ${./cloudflare-ipv4.txt}"
    "tcp-request connection track-sc0 src table per-address"
    "tcp-request connection reject if { sc0_conn_cur gt 1024 }"
    "tcp-request connection reject if !shared-address { sc0_conn_cur gt 256 }"
    "tcp-request connection reject if !shared-address { sc0_conn_rate gt 1000 }"
  ];
in
{
  services.haproxy = {
    enable = true;
    # Carries on the module's global section, whose stats socket hands the
    # listeners over on a reload.
    config = ''
        # About 135 MB (docs/ingress.md). The frontends' maxconn add up to
        # less, so that a flood on one leaves the others answering. A
        # connection over a frontend's maxconn waits in the kernel's listen
        # queue rather than being refused.
        maxconn 4096
        hard-stop-after 30m
        # To HAProxy's own journal (LogNamespace, below).
        log stdout format short daemon

      defaults
        log global
        option dontlognull
        timeout connect 2s
        # 443's, long for WebSockets; port 80 sets its own. client-fin:
        # 30 s of the visitor's silence once the server has closed its side.
        # No server-fin, so the server keeps its 5m after the visitor closes.
        timeout client 5m
        timeout server 5m
        timeout client-fin 30s
        default-server inter 5s fall 2 rise 2
        option redispatch 1

      frontend https
        mode tcp
        bind :443
        maxconn 3500
        log-format "%ci:%cp %ft %[var(sess.name)] %b/%s %Tw/%Tc/%Tt %B %ts %ac/%fc/%bc/%sc/%rc %sq/%bq"
        ${perAddressLimits}
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
        maxconn 500
        log-format "%ci:%cp %ft %[var(txn.name)] %b/%s %TR/%Tw/%Tc/%Tr/%Ta %ST %B %tsc %ac/%fc/%bc/%sc/%rc %sq/%bq %{+Q}r"
        ${perAddressLimits}
        # So that a few addresses can't fill 80 and stop every ACME challenge.
        tcp-request connection track-sc1 src table per-address-80
        tcp-request connection reject if !shared-address { sc1_conn_cur gt 64 }
        timeout http-request 10s
        timeout client 30s
        http-request set-var(txn.name) req.hdr(host),host_only,lower
        http-request set-var(txn.tenant) var(txn.name),map_str(${exactMap}) if { var(txn.name) -m found }
        http-request set-var(txn.tenant) var(txn.name),map_end(${suffixMap}) if { var(txn.name) -m found } !{ var(txn.tenant) -m found }
        http-request deny deny_status 404 unless { var(txn.tenant) -m found }
        use_backend http-%[var(txn.tenant)]

      # Who may reach the exporter is configuration.nix's firewall.
      frontend metrics
        mode http
        bind :8405
        maxconn 16
        no log
        timeout client 30s
        http-request use-service prometheus-exporter if { path /metrics }
        http-request deny deny_status 404

      # Up to 13 MB a table; a full one drops its oldest unused entries.
      # Tenants' backends are https-<tenant> and http-<tenant>, never these.
      backend per-address
        stick-table type ipv4 size 64k expire 1m store conn_cur,conn_rate(10s)

      backend per-address-80
        stick-table type ipv4 size 64k expire 1m store conn_cur
    ''
    + backends;
  };

  # Reload, not restart, so that the old workers keep their connections.
  systemd.services.haproxy.reloadIfChanged = true;

  # A journal of its own, so that a flood rotates out none of the system's.
  # A reload keeps the old stdout: a change to LogNamespace needs a restart.
  systemd.services.haproxy.serviceConfig.LogNamespace = "haproxy";
  environment.etc."systemd/journald@haproxy.conf".text = ''
    [Journal]
    SystemMaxUse=256M
  '';
  # As NixOS's journald module does for journald.conf.
  systemd.services."systemd-journald@".restartTriggers = [
    config.environment.etc."systemd/journald@haproxy.conf".source
  ];

  # Also the flake's checks.ingress-haproxy.
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

  assertions = lib.mapAttrsToList (name: c: {
    assertion = lib.elem c.problem (problemsOf c.file);
    message = "haproxy.nix lets a tenant file with ${name} through: it should report \"${c.problem}\", and reports ${builtins.toJSON (problemsOf c.file)}.";
  }) rejectedFiles;
}
