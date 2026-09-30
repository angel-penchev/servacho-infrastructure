# One k3s node: a server (the Kubernetes control plane, "master") or an agent
# (a worker, "runner"). On top of services.k3s it adds what every servacho node
# needs around it: the firewall shape the qoaxhack operations spec asks for, a
# bootstrap that lets a clone of a generic image join a cluster without the
# cluster's identity being baked into the image, and the host side of Longhorn.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.servacho.k3s;
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    types
    ;

  # https://docs.k3s.io/installation/requirements#inbound-rules-for-k3s-nodes
  # 10250 kubelet metrics (every node); 6443 API and supervisor, 2379-2380
  # etcd (servers); 8472/udp flannel VXLAN (every node).
  clusterTcpPorts = [
    10250
  ]
  ++ lib.optionals (cfg.role == "server") [
    6443
    2379
    2380
  ];
  clusterUdpPorts = [ 8472 ];

  nftSet = xs: "{ ${lib.concatStringsSep ", " (map toString xs)} }";
in
{
  options.servacho.k3s = {
    enable = mkEnableOption "a servacho k3s node";

    role = mkOption {
      type = types.enum [
        "server"
        "agent"
      ];
      description = ''
        `server`: control plane with embedded etcd that also runs workloads.
        `agent`: worker that joins an existing server.
      '';
    };

    package = lib.mkPackageOption pkgs "k3s" { };

    clusterNetworks = mkOption {
      type = types.listOf types.str;
      example = [ "192.168.10.0/23" ];
      description = ''
        Source CIDRs allowed to reach the node's cluster ports (API, etcd,
        kubelet, flannel): normally the VLAN the cluster's nodes sit on. Pod
        and service traffic arrives on the CNI interfaces, which are trusted
        regardless.
      '';
    };

    configFile = mkOption {
      type = types.nullOr types.str;
      default = "/etc/rancher/k3s/config.yaml";
      description = ''
        A k3s configuration file the node waits for before it starts. This is
        how a clone of a generic image learns what no image may contain: the
        cluster token and, depending on the node, `cluster-init: true` or the
        `server:` to join. Until the file exists the unit stays inactive
        (a systemd condition, not a failure), so a template that boots before
        it is configured never initialises a stray single-node cluster.
        cloud-init's `write_files` or a colmena key can place it; k3s reads it
        on every start. Set to null to configure k3s through the NixOS options
        alone and start it unconditionally.
      '';
    };

    exposeIngress = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Open 80 and 443 to any source. k3s's ServiceLB publishes the
        in-cluster Traefik on every node, and the router in front of the
        cluster forwards to whichever node it likes; Traefik's client
        certificate requirement is what keeps strangers out, not the firewall.
      '';
    };

    longhorn.enable = mkEnableOption ''
      the host-side prerequisites for Longhorn: the iSCSI initiator, the NFS
      client, the kernel modules, and the tool paths Longhorn expects to find
      on a node
    '';
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.networking.nftables.enable;
        message = "servacho.k3s writes nftables rules; enable networking.nftables.";
      }
      {
        assertion = cfg.clusterNetworks != [ ];
        message = "servacho.k3s.clusterNetworks must list at least one CIDR.";
      }
    ];

    services.k3s = {
      enable = true;
      inherit (cfg) role package;
      configPath = cfg.configFile;
      # Drain pods before a reboot (PBS snapshots, kernel updates) instead of
      # letting containerd kill them.
      gracefulNodeShutdown.enable = true;
    };

    # The kubelet holds a logind inhibitor for the grace period; logind caps
    # that at InhibitDelayMaxSec (5s by default), which must cover it.
    services.logind.settings.Login.InhibitDelayMaxSec = "45s";

    systemd.services.k3s = {
      unitConfig.ConditionPathExists = mkIf (cfg.configFile != null) cfg.configFile;
      # On a fresh clone cloud-init writes the config file and sets the host
      # name k3s registers under; the condition is checked at start, so
      # ordering k3s after cloud-init's last stage is enough.
      after = mkIf config.services.cloud-init.enable [ "cloud-final.service" ];
    };

    networking.firewall = {
      trustedInterfaces = [
        "cni0"
        "flannel.1"
      ];
      allowedTCPPorts = mkIf cfg.exposeIngress [
        80
        443
      ];
      extraInputRules = ''
        ip saddr ${nftSet cfg.clusterNetworks} tcp dport ${nftSet clusterTcpPorts} accept
        ip saddr ${nftSet cfg.clusterNetworks} udp dport ${nftSet clusterUdpPorts} accept
      '';
      # kube-proxy's NAT and the overlay make strict reverse-path filtering
      # drop legitimate cross-node traffic; loose still rejects spoofed sources.
      checkReversePath = "loose";
    };

    # Container-heavy nodes exhaust the kernel defaults quickly.
    boot.kernel.sysctl = {
      "fs.inotify.max_user_instances" = 8192;
      "fs.inotify.max_user_watches" = 1048576;
    };

    # --- Longhorn -----------------------------------------------------------

    services.openiscsi = mkIf cfg.longhorn.enable {
      enable = true;
      # Longhorn's engine exposes each volume over iSCSI on the node that
      # runs it and logs in from that same node, so the initiator name only
      # has to be well-formed, not unique across nodes.
      name = "iqn.2016-04.com.open-iscsi:servacho-k3s-node";
    };

    environment.systemPackages = mkIf cfg.longhorn.enable (
      with pkgs;
      [
        openiscsi
        nfs-utils
        util-linux
        cryptsetup
      ]
    );

    boot.kernelModules = mkIf cfg.longhorn.enable [
      "iscsi_tcp"
      "dm_crypt"
    ];
    boot.supportedFilesystems = mkIf cfg.longhorn.enable [ "nfs" ];

    # Longhorn runs iscsiadm, mount and friends on the host through nsenter
    # with a conventional PATH; NixOS keeps them under /run/current-system.
    systemd.tmpfiles.rules = mkIf cfg.longhorn.enable [
      "L+ /usr/local/bin - - - - /run/current-system/sw/bin/"
    ];
  };
}
