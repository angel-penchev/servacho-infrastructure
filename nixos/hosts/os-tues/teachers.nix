# The teachers on os-tues: the accounts in class-teachers (docs/os-tues.md).
#
# Teachers have sudo, with their own password. They log in with that password
# from anywhere, as students do, so it is root's in effect, and it has to be
# one no one guesses: at least 15 characters, with lower and upper case
# letters, a digit and another character. PAM holds a teacher to that
# whenever their password changes: at the forced change of their first SSH
# login, with passwd, and when root sets it. Students keep pam_unix's rules.
#
# A teacher's account is made by hand with a random first password, not from
# a sigma export (students.py refuses): a password derived from sigma would
# be root's to whoever guesses it first.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Must match TEACHERS in students.py.
  teachers = "class-teachers";

  # Ahead of pam_unix in a service's password stack. Anyone not a teacher
  # skips to pam_unix as before. A teacher's new password goes through
  # pwquality first, and a pam_unix of its own sets that one (use_authtok) or
  # fails the change, so that the plain pam_unix can't be reached.
  policy =
    service:
    let
      unix = config.security.pam.services.${service}.rules.password.unix;
    in
    {
      teachers-only = {
        order = unix.order - 30;
        control = "[success=2 default=ignore]";
        modulePath = "${config.security.pam.package}/lib/security/pam_succeed_if.so";
        args = [
          "quiet"
          "user"
          "notingroup"
          teachers
        ];
      };
      teachers-pwquality = {
        order = unix.order - 20;
        control = "requisite";
        modulePath = "${pkgs.libpwquality.lib}/lib/security/pam_pwquality.so";
        settings = {
          minlen = 15;
          # Lower case, upper case, digits and the rest: all four.
          minclass = 4;
          # No length credit for those classes: 15 means 15 characters.
          dcredit = 0;
          ucredit = 0;
          lcredit = 0;
          ocredit = 0;
          # sshd changes an expired password as root, and root setting a
          # teacher's password is held to it too.
          enforce_for_root = true;
          retry = 3;
        };
      };
      teachers-unix = {
        order = unix.order - 10;
        control = "[success=done default=die]";
        inherit (unix) modulePath;
        settings = unix.settings // {
          use_authtok = true;
        };
      };
    };
in
{
  security.sudo.extraRules = [
    {
      groups = [ teachers ];
      commands = [ "ALL" ];
    }
  ];

  security.pam.services.sshd.rules.password = policy "sshd";
  security.pam.services.passwd.rules.password = policy "passwd";
}
