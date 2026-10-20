# os-tues: the machine TUES' operating systems class works on, one account per
# student, reached from anywhere as <student>@os-tues.qo.ax (docs/os-tues.md).
# Installed and deployed by tofu/os_tues.tf like an organisation's plane; the
# VM's hardware and disk layout come from infrastructure-reusables.
#
# What the class needs is what its notes use (os-tues on GitHub): nasm and
# binutils for x86-64 assembly, gcc and make, gdb, valgrind, strace and
# ltrace, the Linux and POSIX man pages, ncurses, and editors from nano to
# gedit over `ssh -X`. Students install anything else into their own profile
# with `nix profile install nixpkgs#<name>`; none of them has root.
#
# The accounts are not in this file: the repository is public. Their names and
# initial password hashes are in the root OpenBao, and tofu/os_tues.tf hands
# them to the os-tues-students service below as a roster file.
{ lib, pkgs, ... }:
let
  # Public Servers, VLAN 4 (tofu/unifi/networks.tf), in the Dmz zone: the
  # internet reaches it through the port forward and Internal can reach it,
  # but it cannot reach Internal. Id rule: 4 + 031 = VM 4031.
  address = "192.168.4.31";
  prefixLength = 24;
  gateway = "192.168.4.1";

  # Every student's supplementary group; sshd lets only its members in with a
  # password.
  studentsGroup = "students";
  roster = "/var/lib/os-tues/students.json";

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

  # Creates the account of every student on the roster, a JSON object of user
  # name to initial password hash: a home only its owner can enter, and a
  # password that must be changed at the first login. It never touches the
  # password of an account that exists, so a password a student has set
  # survives every run. A student taken off the roster is locked out (the
  # account expires) with the home kept; put back, they can log in again.
  syncStudents = pkgs.writeShellApplication {
    name = "os-tues-students";
    runtimeInputs = with pkgs; [
      coreutils
      getent
      gnugrep
      jq
      shadow
      systemd
    ];
    text = ''
      group=${studentsGroup}
      roster=${roster}

      # Made here, not declared: NixOS leaves the members of a group it
      # doesn't manage alone.
      getent group "$group" > /dev/null || groupadd "$group"

      if [[ ! -s $roster ]]; then
        echo "No roster at $roster; nothing to do"
        exit 0
      fi
      jq -e 'type == "object" and all(.[]; type == "string")' "$roster" > /dev/null

      declare -A listed=()
      while IFS= read -r user; do
        if ! [[ $user =~ ^[a-z][a-z0-9._-]{0,31}$ ]]; then
          echo "Skipped '$user': not a user name" >&2
          continue
        fi
        listed[$user]=1

        if id -u "$user" > /dev/null 2>&1; then
          if ! id -nG "$user" | grep -qw "$group"; then
            echo "Skipped $user: an account that isn't a student's exists" >&2
            continue
          fi
          # Back on the roster after being taken off.
          if [[ $(getent shadow "$user" | cut -d: -f8) == 1 ]]; then
            usermod --expiredate "" "$user"
            echo "Unlocked $user"
          fi
          continue
        fi

        useradd --create-home --user-group --groups "$group" \
          --shell /run/current-system/sw/bin/bash "$user"
        chmod 0700 "/home/$user"
        # The hash through stdin, so no other student sees it in ps.
        jq -r --arg user "$user" '"\($user):\(.[$user])"' "$roster" | chpasswd --encrypted
        chage --lastday 0 "$user"
        echo "Created $user"
      done < <(jq -r 'keys[]' "$roster")

      IFS=, read -ra members <<< "$(getent group "$group" | cut -d: -f4)"
      for user in "''${members[@]}"; do
        if [[ -z ''${listed[$user]:-} && $(getent shadow "$user" | cut -d: -f8) != 1 ]]; then
          usermod --expiredate 1 "$user"
          loginctl terminate-user "$user" 2> /dev/null || true
          echo "Locked $user: no longer on the roster"
        fi
      done
    '';
  };
in
{
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
    so are nano, vim, nvim and gedit (connect with `ssh -X` for gedit).
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

  # The base module allows keys only. Students log in with their password,
  # and must replace the initial one on the first login, which sshd asks for
  # through keyboard-interactive PAM. root takes the deploy key and the
  # administrators' keys from the home networks (and its WireGuard) only:
  # this machine is on the internet.
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
      Match Group ${studentsGroup}
        PasswordAuthentication yes
        KbdInteractiveAuthentication yes
      Match Address 192.168.0.0/16
        PermitRootLogin prohibit-password
    '';
  };
  # NixOS gives sshd's PAM service pam_unix only when PasswordAuthentication
  # is on globally; here it is on in the Match above.
  security.pam.services.sshd.unixAuth = lib.mkForce true;

  users.users.root.openssh.authorizedKeys.keyFiles = [
    ./servacho-managment-plane/deploy-key.pub
    ../keys/yogacho-v2.pub
  ];

  # Accounts are made at run time (os-tues-students), so NixOS must keep the
  # users and groups it doesn't declare.
  users.mutableUsers = true;

  systemd.services.os-tues-students = {
    description = "Create the accounts of the students on the roster";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe syncStudents;
      StateDirectory = "os-tues";
      StateDirectoryMode = "0700";
    };
  };

  system.stateVersion = "26.05";
}
