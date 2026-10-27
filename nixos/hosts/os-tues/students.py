"""os-tues-students: the students' accounts on os-tues (docs/os-tues.md).

    os-tues-students import CLASS [--grade GRADE] [--max N] < sigma-export
    os-tues-students retire CLASS
    os-tues-students restore CLASS

import reads a students export from sigma (.xlsx or .csv) on stdin and gives
every student in it an account in the class's group, class-CLASS:

- the user name is the student's ELSYS address without @elsys-bg.org;
- the initial password is the middle name, transliterated (Bulgaria's
  Streamlined System) with a capital first letter, followed by the last four
  digits of the phone number, and must be changed at the first login.

An account that exists keeps its password and joins the class. retire locks
a class's accounts out (they expire; the homes stay) and restore lets them in
again.

Run by root, over SSH from .github/workflows/os-tues-students.yaml, whose log
is public: what this prints is counts and column titles only. The students'
names go to the journal (journalctl -t os-tues-students).
"""

import argparse
import csv
import io
import os
import re
import subprocess
import sys
import syslog

import openpyxl

os.environ["PATH"] = "@path@:" + os.environ.get("PATH", "")

# Every student's group, which sshd lets in with a password.
STUDENTS = "students"
# The teachers' class, whose group has sudo (teachers.nix).
TEACHERS = "teachers"
ELSYS = "@elsys-bg.org"
SHELL = "/run/current-system/sw/bin/bash"
USER = re.compile(r"[a-z][a-z0-9._-]{0,31}")
CLASS = re.compile(r"[a-z0-9][a-z0-9-]{0,22}")

LATIN = dict(
    zip(
        "абвгдежзийклмнопрстуфхцчшщъьюя",
        "a b v g d e zh z i y k l m n o p r s t u f h ts ch sh sht a y yu ya".split(),
    )
)


def fail(message):
    print(f"os-tues-students: {message}", file=sys.stderr)
    sys.exit(1)


def log(message):
    syslog.syslog(message)


def run(*command, stdin=None):
    return subprocess.run(
        command, input=stdin, text=True, check=True, capture_output=True
    ).stdout


def exists(database, key):
    found = subprocess.run(["getent", database, key], capture_output=True)
    return found.returncode == 0


def entry(database, key):
    return run("getent", database, key).rstrip("\n").split(":")


def members(group):
    return [user for user in entry("group", group)[3].split(",") if user]


def ensure_group(group):
    if not exists("group", group):
        run("groupadd", group)


def latin(text):
    """Bulgaria's Streamlined System; -ия at the end of a word is -ia."""
    words = []
    for word in text.lower().split():
        if word.endswith("ия"):
            word = word[:-2] + "ia"
        words.append("".join(LATIN.get(c, c) for c in word))
    return " ".join(words)


def cell(value):
    if value is None:
        return ""
    if isinstance(value, float) and value.is_integer():
        value = int(value)
    return str(value).strip()


def read_rows(data):
    if data[:2] == b"PK":
        book = openpyxl.load_workbook(io.BytesIO(data), read_only=True, data_only=True)
        return [[cell(v) for v in row] for row in book.active.iter_rows(values_only=True)]
    text = data.decode("utf-8-sig")
    try:
        dialect = csv.Sniffer().sniff(text[:4096], delimiters=",;\t")
    except csv.Error:
        dialect = csv.excel
    return [[cell(v) for v in row] for row in csv.reader(io.StringIO(text), dialect)]


def digits(value):
    return re.sub(r"\D", "", value)


def is_email(value):
    return value.lower().endswith(ELSYS)


def is_phone(value):
    return bool(re.fullmatch(r"[\d\s+()./-]+", value)) and 9 <= len(digits(value)) <= 13


def is_word(value):
    return len(value.split()) == 1 and value.replace("-", "").isalpha()


def is_full_name(value):
    words = value.split()
    return len(words) >= 3 and all(w.replace("-", "").isalpha() for w in words)


def is_grade(value):
    return bool(re.fullmatch(r"\d{1,2}\s*[^\W\d_]", value))


def passes(values, test):
    """At least four in five of the column's filled cells pass test."""
    filled = [v for v in values if v]
    return bool(filled) and sum(map(test, filled)) >= 0.8 * len(filled)


def titled(header, columns, titles, test):
    """The first column titled like titles whose values pass test."""
    return next((i for i, t in enumerate(header) if re.search(titles, t) and passes(columns[i], test)), None)


def find(header, columns, titles, test):
    """The column titled like titles, or else the first whose values pass test."""
    found = titled(header, columns, titles, test)
    if found is None:
        found = next((i for i, values in enumerate(columns) if passes(values, test)), None)
    return found


def students(rows, grade):
    """(user name, initial password) for each student in the export, and how
    many rows had to be skipped."""
    start = next((i for i, row in enumerate(rows) if any(map(is_email, row))), None)
    if start is None:
        fail(f"no {ELSYS} address in the export")
    # The column titles are on the last filled row above the first student.
    header = next((rows[i] for i in range(start - 1, -1, -1) if sum(map(bool, rows[i])) >= 2), [])
    body = [row for row in rows[start:] if any(row)]
    width = max(len(row) for row in body + [header])
    header = [title.lower() for title in header] + [""] * (width - len(header))
    body = [row + [""] * (width - len(row)) for row in body]
    columns = [list(column) for column in zip(*body)]

    def title(i):
        return header[i] or f"column {i + 1}"

    email = find(header, columns, "elsys|mail|имейл", is_email)
    if email is None:
        fail(f"no column of {ELSYS} addresses in the export")
    body = [row for row in body if is_email(row[email])]
    phone = find(header, columns, "телефон|phone", is_phone)
    # A middle name column only by its title: by content, a first name or a
    # surname column looks the same. Without one, the middle of three names.
    middle = titled(header, columns, "презиме|бащино|middle", is_word)
    name = None if middle is not None else find(header, columns, "име|name|ученик|student", is_full_name)
    print(
        f"Columns: ELSYS address {title(email)}; "
        + (f"phone {title(phone)}; " if phone is not None else "no phone; ")
        + (f"middle name {title(middle)}" if middle is not None else f"full name {title(name)}" if name is not None else "no middle or full name")
    )
    if phone is None or (middle is None and name is None):
        fail("the export needs each student's phone number and middle or full name; its column titles are: " + ", ".join(t for t in header if t))

    if grade:
        column = find(header, columns, "клас|паралелка|grade|class", is_grade)
        if column is None:
            fail(f"--grade {grade}, but the export has no class column")
        wanted = latin(grade).replace(" ", "")
        body = [row for row in body if latin(row[column]).replace(" ", "") == wanted]

    accounts, skipped = [], 0
    for row in body:
        user = row[email].lower().removesuffix(ELSYS)
        number = digits(row[phone])
        names = [row[middle]] if middle is not None else row[name].split()[1:-1]
        if not USER.fullmatch(user):
            log(f"skipped {user!r}: not a user name")
        elif len(number) < 4:
            log(f"skipped {user}: no phone number")
        elif len(names) != 1 or not names[0]:
            log(f"skipped {user}: no single middle name")
        else:
            middle_name = latin(names[0])
            accounts.append((user, middle_name[:1].upper() + middle_name[1:] + number[-4:]))
            continue
        skipped += 1
    return accounts, skipped


def import_class(group, data, grade, most):
    accounts, skipped = students(read_rows(data), grade)
    if not accounts:
        fail("no students to import")
    if len(accounts) > most:
        fail(f"{len(accounts)} students in the export, more than --max {most}; is it the whole school?")

    ensure_group(STUDENTS)
    ensure_group(group)
    created = joined = unlocked = 0
    for user, password in accounts:
        if exists("passwd", user):
            groups = run("id", "-nG", user).split()
            if STUDENTS not in groups:
                log(f"skipped {user}: an account that isn't a student's has that name")
                skipped += 1
                continue
            if group not in groups:
                run("usermod", "--append", "--groups", group, user)
                log(f"{user}: joined {group}")
                joined += 1
            if entry("shadow", user)[7] == "1":
                run("usermod", "--expiredate", "", user)
                log(f"{user}: unlocked")
                unlocked += 1
            continue
        run("useradd", "--create-home", "--user-group", "--groups", f"{STUDENTS},{group}", "--shell", SHELL, user)
        os.chmod(f"/home/{user}", 0o700)
        # Through stdin, so no other student sees the password in ps.
        run("chpasswd", stdin=f"{user}:{password}\n")
        run("chage", "--lastday", "0", user)
        log(f"{user}: created in {group}")
        created += 1

    print(
        f"{group}: {len(accounts)} in the export; {created} created, "
        f"{len(accounts) - created} already had an account ({joined} joined the class, {unlocked} unlocked); "
        f"{skipped} skipped (journalctl -t os-tues-students on os-tues says why)"
    )


def set_expiry(group, expiry, done):
    if not exists("group", group):
        fail(f"no class {group} on os-tues")
    accounts = members(group)
    for user in accounts:
        run("usermod", "--expiredate", expiry, user)
        if expiry:
            subprocess.run(["loginctl", "terminate-user", user], capture_output=True)
        log(f"{user}: {done} with {group}")
    print(f"{group}: {len(accounts)} accounts {done}")


def main():
    parser = argparse.ArgumentParser(prog="os-tues-students", description=__doc__.split("\n")[0])
    actions = parser.add_subparsers(dest="action", required=True)
    importing = actions.add_parser("import", help="give the students in a sigma export (stdin) accounts in a class")
    importing.add_argument("klass", metavar="CLASS", help="the class, as 11a-2026; its group is class-CLASS")
    importing.add_argument("--grade", default="", help="only the export's rows of this class, as 11А")
    importing.add_argument("--max", type=int, default=40, help="refuse an export of more students than this")
    for action, text in (("retire", "lock a class's accounts out"), ("restore", "let a retired class in again")):
        actions.add_parser(action, help=text).add_argument("klass", metavar="CLASS")
    args = parser.parse_args()

    if os.geteuid() != 0:
        fail("must be run as root")
    if not CLASS.fullmatch(args.klass):
        fail(f"a class is lower-case letters, digits and dashes, as 11a-2026; not {args.klass!r}")
    group = f"class-{args.klass}"
    syslog.openlog("os-tues-students")

    if args.action == "import" and args.klass == TEACHERS:
        fail("teachers have sudo, so a password from sigma would be root's; add a teacher by hand (docs/os-tues.md)")
    if args.action == "import":
        import_class(group, sys.stdin.buffer.read(), args.grade, args.max)
    elif args.action == "retire":
        set_expiry(group, "1", "locked out")
    else:
        set_expiry(group, "", "let back in")


if __name__ == "__main__":
    main()
