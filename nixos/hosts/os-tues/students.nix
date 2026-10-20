# The students' accounts on os-tues. None of them is in this repository, which
# is public and they are minors': os-tues-students (students.py) makes them
# from a sigma export, which .github/workflows/os-tues-students.yaml hands it
# over SSH (docs/os-tues.md). This module is what the accounts need from the
# host: the tool, users NixOS leaves alone, and password logins over SSH.
{ lib, pkgs, ... }:
let
  # Must match STUDENTS in students.py.
  studentsGroup = "students";

  tool =
    pkgs.writers.writePython3Bin "os-tues-students"
      {
        libraries = [ pkgs.python3Packages.openpyxl ];
        flakeIgnore = [
          "E501"
          "W503"
        ];
      }
      (
        builtins.replaceStrings
          [ "@path@" ]
          [
            (lib.makeBinPath (
              with pkgs;
              [
                coreutils
                getent
                shadow
                systemd
              ]
            ))
          ]
          (builtins.readFile ./students.py)
      );
in
{
  environment.systemPackages = [ tool ];

  # The accounts and the groups (students, class-<class>) are made at run
  # time, so NixOS must keep the users and groups it doesn't declare.
  users.mutableUsers = true;

  # The base module allows keys only. Students log in with their password and
  # replace the initial one on the first login, which sshd asks for through
  # keyboard-interactive PAM.
  services.openssh.extraConfig = ''
    Match Group ${studentsGroup}
      PasswordAuthentication yes
      KbdInteractiveAuthentication yes
  '';
  # NixOS gives sshd's PAM service pam_unix only when PasswordAuthentication
  # is on globally; here it is on in the Match above.
  security.pam.services.sshd.unixAuth = lib.mkForce true;
}
