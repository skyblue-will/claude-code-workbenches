# Managing multiple terminals remotely with Claude Code

People are carrying open laptops around the house because closing the lid
would kill the agent. The agent is fine. It's just running on the wrong
machine.

Run your Claude Code sessions on a cheap always-on box instead. They keep
working with your laptop shut and your phone in your pocket, and you can
reach any of them from the Claude app, a browser, or SSH. You hand a session
a job from wherever you are and get on with your day. Anything worth keeping
gets committed to a repo, so it survives whatever happens to the session.

Day to day that means: from your phone, ask a standing session to open a new
one on any project, with the task written in. Check on it at lunch. Let it
finish, or kill it.

## A workbench

A workbench is just a terminal on that box. It's the name I give them,
because that's how one feels to use: a single space where you bring together
an agent, tools, and context to do a piece of work. Spawn as many as you
want. Any of them can spawn more. The only limit is RAM.

## The whole thing in one command

```bash
tmux new-session -d -s myagent -c ~/myproject
tmux send-keys -t myagent \
  'claude --remote-control "myagent" --dangerously-skip-permissions' Enter
```

A detached terminal running Claude Code with Remote Control on. It prints a
link; open it on your phone. [`spawn-remote.sh`](spawn-remote.sh) is this as
one script, and [REFERENCE.md](REFERENCE.md) has every flag, the safe way to
feed an opening prompt, and the ways back in.

## Getting a box

- **A cheap VPS**: a few pounds a month, nothing on your desk, survives power
  cuts. A session is roughly 400 MB, so 4 GB runs a handful.
- **A Mac Mini in a cupboard**: same recipe, `brew install tmux`. Your
  hardware and your files stay at home, but the uptime and backups are on
  you.
- **An old laptop, lid shut, sleep disabled**: costs nothing and lets you try
  all of this before buying anything.

[`bootstrap-vps.sh`](bootstrap-vps.sh) takes a fresh Ubuntu VPS to a working
host in one run. Logging in and trusting your directories stay manual,
because credentials should never be scripted.

## Security

- **These are not sandboxes.** Every bench is a full process on the same box,
  as the same user. If you need real isolation between pieces of work, use
  separate Unix users, containers, or separate machines.
- **A dedicated box limits the damage.** Unattended agents on your own laptop
  put your SSH keys and browser sessions at risk. If the box only holds the
  work, the work is all that's at risk.
- **Your claude.ai account can now drive terminals on the box.** Use strong
  auth and don't share the account.
- **Keep a human on anything that leaves the machine.** Let the agent move
  fast inside the box. Sending, publishing, and spending wait for your
  say-so. WIRING.md shows how to write those gates down.

## Where next

- **[WIRING.md](WIRING.md)**: how many benches become one working system: the
  front door, seeds as work orders, repos as memory, gates, put-down and
  pick-up.
- **[REFERENCE.md](REFERENCE.md)**: flags, scripts, quoting, and how this
  relates to Remote Control's own server mode and background sessions.
