# Claude Code workbenches: agents on a machine that never closes

People are carrying open laptops around the house because closing the lid
would kill the agent. That's the tell. The work is right; the machine is
wrong.

The fix: run your Claude Code sessions on a cheap always-on box instead.
Every session keeps working while your laptop is shut and your phone is in
your pocket, and every one is reachable from anywhere: the Claude app, a
browser, SSH. You open work from wherever you are, hand it a job, and walk
away. Results land as git commits, not scrollback.

Day to day: from your phone, ask a standing session to open a new one on any
project, seeded with the task. Check in at lunch. Let it finish, or kill it;
the repos hold the memory, so nothing you care about dies with a session.

## A workbench

A workbench is just a terminal on that box: one space where an agent, its
tools, and its context do a piece of work. Spawn as many as you want. Any of
them can spawn more. The only limit is RAM.

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
  cuts. 4 GB of RAM runs several benches.
- **A Mac Mini in a cupboard**: same recipe, `brew install tmux`. You own the
  hardware and the files stay home; you also own the uptime.
- **An old laptop, lid shut, sleep disabled**: the free trial.

[`bootstrap-vps.sh`](bootstrap-vps.sh) takes a fresh Ubuntu VPS to a working
host in one run. Logging in and trusting your directories stay manual,
because credentials should never be scripted.

## The security model, plainly

- **These are not sandboxes.** Every bench is a full process on the same box,
  as the same user. For real isolation between pieces of work: separate Unix
  users, containers, or separate machines.
- **A dedicated box is itself a boundary.** Unattended agents on your own
  laptop put your SSH keys and browser sessions in the blast radius. On a box
  that holds only the work, the worst case is the box.
- **Your claude.ai account becomes a control surface for the machine.**
  Strong auth, and don't share it.
- **Keep a human on anything that leaves the machine.** Speed inside the box
  is the agent's; sending, publishing, and spending stay behind your yes.
  How to write the gates down is in WIRING.md.

## Where next

- **[WIRING.md](WIRING.md)**: how many benches become one working system: the
  front door, seeds as work orders, repos as memory, gates, put-down and
  pick-up.
- **[REFERENCE.md](REFERENCE.md)**: flags, scripts, quoting, and how this
  relates to Remote Control's own server mode and background sessions.
