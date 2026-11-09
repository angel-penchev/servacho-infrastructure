# Agents

The skills for this repository are in `.agents/skills`. Claude Code reads them
through `.claude/skills`. They come from
[qoax-agent-skills](https://github.com/qoax-community/qoax-agent-skills), and
`skills-lock.json` pins them. Do not edit them here. Change a skill in
qoax-agent-skills, then run
`DISABLE_TELEMETRY=1 npx skills@1.7.3 update -p -y` on a computer that has a
`~/.claude` directory.

Each `.claude/skills/<name>` is a symbolic link. On Windows, turn on Developer
Mode and clone with `git clone -c core.symlinks=true`. Without the links,
Claude Code loads none of the skills. The
[qoax-agent-skills README](https://github.com/qoax-community/qoax-agent-skills#symbolic-links)
shows how to repair a clone.

## Writing

Write prose (docs, comments, commit messages, issues, pull requests) with the
`asd-ste100` skill. Keep the British spelling this repository uses
(organisation, behaviour).
