# os-tues: the machine TUES' operating systems class works on, one account per
# student, reached over SSH as <student>@vm.os.tues.qo.ax (docs/os-tues.md).
# Installed and deployed by tofu/os_tues.tf like an organisation's plane; the
# VM's hardware and disk layout come from infrastructure-reusables.
#
# What the class needs is what its notes use (os-tues on GitHub): nasm and
# binutils for x86-64 assembly, gcc and make, gdb, valgrind, strace and
# ltrace, the Linux and POSIX man pages, ncurses, and editors from nano to
# gedit over `ssh -X`. Students install anything else into their own profile
# with `nix profile install nixpkgs#<name>`; none of them has root.
#
# The students' accounts are not in this repository, which is public: they are
# made from a sigma export by os-tues-students (students.nix).
{ lib, pkgs, ... }:
let
  # Public Servers, VLAN 4 (tofu/unifi/networks.tf), in the Dmz zone: the
  # internet reaches it through the port forward and Internal can reach it,
  # but it cannot reach Internal. Id rule: 4 + 031 = VM 4031.
  address = "192.168.4.31";
  prefixLength = 24;
  gateway = "192.168.4.1";

  # The notes link with -lcurses and include <curses.h>, as Debian's
  # libncurses-dev allows. NixOS's ncurses has no libcurses.so and its gcc
  # sees no library it isn't told about, so this gcc is told about ncurses,
  # with the libcurses.so Debian has; the store path it links from becomes
  # the program's rpath.
  cLibraries = pkgs.runCommand "os-tues-c-libraries" { } ''
    mkdir -p $out/lib
    ln -s ${lib.getLib pkgs.ncurses}/lib/* $out/lib/
    ln -s libncursesw.so $out/lib/libcurses.so
  '';
  gcc = pkgs.gcc.override (old: {
    extraBuildCommands = (old.extraBuildCommands or "") + ''
      echo "-isystem ${lib.getDev pkgs.ncurses}/include" >> $out/nix-support/cc-cflags
      echo "-L${cLibraries}/lib" >> $out/nix-support/cc-ldflags
    '';
  });

  # The notes send students to /usr/include (asm/unistd_64.h for the syscall
  # numbers), which NixOS doesn't have. For reading only: gcc finds its
  # headers on its own.
  usrInclude = pkgs.symlinkJoin {
    name = "os-tues-usr-include";
    paths = [
      (lib.getDev pkgs.glibc)
      pkgs.linuxHeaders
      (lib.getDev pkgs.ncurses)
    ];
  };

  installHint = ''
    This machine runs NixOS: there is no apt, and no sudo for students.
    Install a program into your own account with

      nix profile install nixpkgs#<name>

    find its name with `nix search nixpkgs <name>`, or try it without
    installing with `nix shell nixpkgs#<name>`.
  '';
  aptHint =
    name:
    pkgs.writeShellScriptBin name ''
      cat >&2 <<'EOF'
      ${installHint}
      EOF
      exit 1
    '';

in
{
  imports = [
    ./students.nix
    ./lazyvim.nix
    ./teachers.nix
  ];

  networking.hostName = "os-tues";
  networking.useDHCP = false;
  systemd.network = {
    enable = true;
    networks."10-lan" = {
      matchConfig.Type = "ether";
      address = [ "${address}/${toString prefixLength}" ];
      gateway = [ gateway ];
      dns = [
        "1.1.1.1"
        "1.0.0.1"
      ];
    };
  };

  # Data disk one (tofu/os_tues.tf): a student filling it cannot fill the
  # system or the Nix store.
  servacho.proxmoxGuest.dataDisks = [ "/home" ];

  # The students' clocks, for `date` and file times.
  time.timeZone = lib.mkForce "Europe/Sofia";

  environment.systemPackages =
    (with pkgs; [
      # Assembly and C, as the notes check for them.
      nasm
      binutils
      gnumake
      gdb
      valgrind
      strace
      ltrace
      pkg-config
      ncurses
      clang-tools

      # Editors. gedit needs `ssh -X`.
      nano
      neovim
      gedit

      # What the notes and homework use around the code.
      man-pages
      man-pages-posix
      file
      tinyxxd
      tree
      lsof
      psmisc
      iotop
      sysstat
      traceroute
      dnsutils
      netcat-openbsd
      socat
      wget
      zip
      unzip
      bc
      tmux
      python3
      cowsay
    ])
    ++ [
      gcc
      (aptHint "apt")
      (aptHint "apt-get")
    ];

  users.motd = ''

    os-tues, the TUES operating systems class machine.

    gcc, nasm, ld, objdump, gdb, make, valgrind, strace and ltrace are here;
    so are nano, vim, nvim (as LazyVim) and gedit (`ssh -X` for gedit).
    ${installHint}
  '';

  systemd.tmpfiles.rules = [ "L+ /usr/include - - - - ${usrInclude}/include" ];

  # The base module leaves the manuals out of a headless VM; here they are
  # the point: sections 2 and 3 and POSIX's, and `man -k`.
  documentation = {
    enable = lib.mkForce true;
    man.enable = true;
    dev.enable = true;
  };

  programs.fish.enable = true;
  programs.zsh.enable = true;
  programs.dconf.enable = true;
  fonts.enableDefaultPackages = true;
  # VS Code's Remote-SSH server and other binaries built for other
  # distributions, which look for /lib64/ld-linux-x86-64.so.2.
  programs.nix-ld.enable = true;

  # Students' `nix profile install` builds run under the daemon, outside
  # their limits below; they wait for the students' own work.
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";

  # Every login's share of the machine: a fork bomb from the processes class
  # stops at TasksMax, a leak at MemoryMax. root (user-0) is not limited.
  systemd.slices = {
    "user-" = {
      overrideStrategy = "asDropin";
      sliceConfig = {
        CPUQuota = "200%";
        MemoryHigh = "1536M";
        MemoryMax = "2G";
        TasksMax = 512;
      };
    };
    "user-0" = {
      overrideStrategy = "asDropin";
      sliceConfig = {
        CPUQuota = "";
        MemoryHigh = "infinity";
        MemoryMax = "infinity";
        TasksMax = "infinity";
      };
    };
  };
  zramSwap.enable = true;

  # Students log in with passwords (students.nix). root takes the deploy key
  # and the administrators' keys from the home networks (and its WireGuard)
  # only: this machine is on the internet.
  services.openssh = {
    settings = {
      PermitRootLogin = lib.mkForce "no";
      X11Forwarding = true;
      # A classroom behind one address: up to 64 logins at a password prompt
      # before sshd starts dropping new ones, and penalties that a guessing
      # bot runs into but a class mistyping passwords doesn't.
      MaxStartups = "64:30:256";
      PerSourcePenalties = "authfail:1s noauth:1s min:60s max:600s";
      PerSourcePenaltyExemptList = "192.168.0.0/16";
      ClientAliveInterval = 300;
    };
    extraConfig = ''
      Match Address 192.168.0.0/16
        PermitRootLogin prohibit-password
    '';
  };
  users.users.root.openssh.authorizedKeys.keyFiles = [
    ../servacho-managment-plane/deploy-key.pub
    ../../keys/yogacho-v2.pub
  ];

  system.stateVersion = "26.05";
}
