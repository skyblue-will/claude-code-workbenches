# Managing multiple terminals remotely with Claude Code

Run as many Claude Code terminals as you want on a machine, and reach each one
from anywhere, including your phone: the Claude.ai web app, the desktop app, SSH,
or a local terminal. They keep running when you disconnect.

## Workbenches

A workbench is just a terminal. It's the name I give them, because that's how one
feels to use: a single space where you bring together agents, tools, and context
to do a piece of work. That's why I use this. You build your own architecture on
top of it.

Each one is a remote-controlled session you spawn on demand, and any terminal can
spawn more from inside itself. The only limit is RAM. The rest of this is how to
build one. **[WIRING.md](WIRING.md) is how many of them become a working system**:
the front door, repos as memory, seed prompts, skills, fan-out, gates, and picking
work back up.

## What's actually running where

Three ingredients, and it helps to be plain about each:

- **An always-on machine.** Yes, a computer is left on somewhere: deliberately not
  the one on your desk. A cheap VPS is plenty. Your laptop can sleep; the
  terminals don't.
- **tmux.** tmux runs terminal sessions on a machine that keep running after
  you disconnect. You attach to a session to see it, detach, and it carries on.
  That's the whole trick this recipe borrows: the terminal belongs to the box,
  not to your screen.
- **Remote Control.** Claude Code's own feature that puts a running session in
  your claude.ai session list, so you can drive it from the web app, the desktop
  app, or your phone. It looks like any other Claude Code session in the app; the
  difference is where it's running.

### How this relates to what Remote Control does natively

Remote Control has grown several modes of its own, so it is worth being exact
about what this recipe adds. As of mid-2026:

- An interactive session (`claude --remote-control`) lives and dies with the
  local process: close the terminal and the session ends. Sleep is handled
  gracefully, the session reconnects when the machine wakes, but a sleeping
  machine does no work in the meantime.
- **Server mode** (`claude remote-control`) is a native front door: one
  process that waits for connections and spawns sessions on demand from the
  app, up to a set capacity, each in the server's directory or its own git
  worktree of that repo.
- **Background sessions** (`claude --bg`, agent view) keep running with no
  terminal attached, hosted by a per-user supervisor, and survive sleep. They
  cover "keep working after I close the shell" without tmux.

Against the questions that actually matter, side by side:

| You want | RC session | RC server mode | Background (`--bg`) | Wired together (this recipe) |
|---|---|---|---|---|
| Drive a session from your phone | yes | yes | no, local only | yes, every bench |
| Start a fresh session from your phone | no | yes, in the server's repo | no | yes, any repo, via the front door |
| Survive the terminal closing | no | no | yes | yes |
| Work continues while your own computer is off | no* | no* | no* | yes |
| Arrive pre-briefed: a work order, not a blank prompt | no, you type it | no, you type it | yes, from that machine's shell | yes, composed and fed at spawn |
| Sessions spawn sessions | no | no | no | yes |
| Come back up after a reboot | no | no | no | yes, one cron line |
| Attach as a real terminal over SSH | no | no | yes, `claude attach` | yes, `tmux attach` |
| Isolation between parallel sessions | n/a | yes, git worktrees | yes, git worktrees | no, deliberate: the repo is the memory |

\* They run wherever you start them. Put them on an always-on box and you have
started building this recipe.

Read the right-hand column carefully: it isn't a feature, and this repo isn't
a product competing with the other three columns. The native modes are
ingredients. The value is the wiring: an always-on machine, tmux holding the
terminals, Remote Control reaching them, and the working conventions in
[WIRING.md](WIRING.md), seeds as work orders, repos as memory, gates, a front
door that is an agent. That page is where this stops being a features list
and becomes a way of working.

## The whole thing in one command

```bash
tmux new-session -d -s myagent -c ~/myproject
tmux send-keys -t myagent \
  'claude --remote-control "myagent" --dangerously-skip-permissions' Enter
```

A detached tmux session named `myagent`, running Claude Code with Remote Control
on. The rest of this README covers the flags, how to hand it a first prompt
safely, and how to get back in.

## The flags

| Flag | What it does |
|---|---|
| `--remote-control [name]` | Turn on Remote Control and optionally name the session. A named session maps the app and URL to a name you chose. |
| `--remote-control-session-name-prefix <prefix>` | Auto-generate the name from a prefix instead (Claude appends a unique suffix). The default prefix is the hostname. |
| `--dangerously-skip-permissions` | Run tool calls without prompting, so the session works unattended. Use it only in a trusted or sandboxed environment. |
| `--allow-dangerously-skip-permissions` | A softer form that makes the skip available without turning it on by default. |
| `--plugin-dir <path>` | Load a plugin (custom skills, persona, commands) from a directory or `.zip` for this session. Repeatable. Optional. |

Two ways to name the Remote Control session:

- **Named**: `--remote-control "myagent"` gives the session exactly that name. Map
  it one-to-one to your tmux session.
- **Prefix**: `--remote-control-session-name-prefix myagent` produces
  `myagent-<suffix>`. Useful when a script starts several at once and you want
  unique names.

## tmux: the detached session

```bash
tmux new-session -d -s <name> -c <dir>
```

- `-d` starts the session detached, in the background, so it keeps running with
  nothing attached.
- `-s <name>` sets the session name you attach by.
- `-c <dir>` sets the directory Claude starts in.

You can pass the command as a final argument to `new-session`
(`tmux new-session -d -s n -c d "claude ..."`). That works with no opening prompt,
but it makes feeding a first prompt awkward. See below.

## Feeding the first prompt

To start Claude and hand it an opening message, start a shell in the tmux session
and type the command into it with `send-keys`:

```bash
SEED='Audit this repo for TODOs and summarise what you find.'
SEED_ESC=$(printf '%q' "$SEED")
tmux send-keys -t myagent \
  "claude --remote-control \"myagent\" --dangerously-skip-permissions $SEED_ESC" Enter
```

`send-keys` sends its argument to the shell as literal keystrokes, and the shell
parses that line. A seed prompt is arbitrary text: spaces, quotes, `$`, backticks,
newlines. Without quoting, spaces split it into separate arguments, and `$(...)`
or backticks run as command substitution before Claude sees them.

`printf '%q'` produces a shell-safe version of the string that parses back to the
original as a single argument, with no splitting and no substitution. Quote the
seed; don't drop it in raw.

With no seed prompt, the simpler form is fine and Claude just starts interactive:
`tmux new-session -d -s myagent -c ~/myproject "claude --remote-control myagent --dangerously-skip-permissions"`.

## Getting back in

### Browser or app

At boot, Claude prints a Remote Control link:

```
https://claude.ai/code/session_XXXXXXXX
```

Open it in the web app or on your phone to drive the session. To read it from a
script, poll the pane until it appears:

```bash
for _ in $(seq 1 15); do
  sleep 1
  URL=$(tmux capture-pane -t myagent -p -S -200 \
        | grep -oE 'https://claude\.ai/code/session_[a-zA-Z0-9_-]+' | tail -1)
  [[ -n "$URL" ]] && break
done
echo "$URL"
```

`capture-pane -p` prints the pane text; `-S -200` includes the last 200 scrollback
lines, in case the link scrolled off. Give it a few seconds to register.

### Local tmux

```bash
tmux attach -t myagent
```

### SSH

```bash
ssh <user>@<host> -t tmux attach -t myagent
```

`-t` forces a TTY so tmux has a real terminal to attach to. Detach with `Ctrl-b d`
and the session keeps running. All three routes reach the same live session.

## Reference script

[`spawn-remote.sh`](spawn-remote.sh) is the recipe as one runnable script. It
checks prereqs, refuses to clobber an existing session, starts the detached tmux
session, feeds an optional seed prompt with the quoting above, captures the URL,
and prints the three ways to attach.

```bash
chmod +x spawn-remote.sh

./spawn-remote.sh <name> [dir] [seed-prompt]

# examples
./spawn-remote.sh myagent
./spawn-remote.sh myagent ~/myproject
./spawn-remote.sh myagent ~/myproject 'Find and fix the failing test.'
```

An agent can run it too, which is how one session starts the others.

## Getting a box

The crux of this recipe is the always-on machine, and it's the part people
stall on. Any of these works:

- **A cheap VPS** is the lowest-friction answer: a few pounds a month, nothing
  on your desk, survives power cuts, and providers give you snapshots. 4 GB of
  RAM runs several benches comfortably.
- **A Mac Mini in a cupboard** works the same way: install tmux with brew and
  the recipe is identical. You own the hardware and the files stay home; you
  also own the uptime, the backups, and the electricity.
- **An old laptop with the lid shut** is the free trial. Disable
  sleep-on-lid-close and you have a host to learn on before spending anything.

[`bootstrap-vps.sh`](bootstrap-vps.sh) takes a fresh Ubuntu VPS to a working
host in one run: tmux and Claude Code installed, this repo cloned, the reboot
cron from WIRING.md in place. Two one-time steps stay manual, logging in and
trusting your directories, because credentials should never be scripted.

## The security model, plainly

Questions worth answering before you run this:

- **These are not sandboxes.** Every workbench is a full process on the same
  machine, as the same user. A bench can read another bench's files. Claude
  Code itself offers some isolation if you want it: a `--sandbox` flag for
  filesystem and network isolation (off by default), and background sessions
  isolate their file edits in git worktrees. For real isolation between
  pieces of work, that's separate Unix users, containers, or separate
  machines; this recipe adds none of its own.
- **A dedicated box is itself a boundary.** Running unattended agents with
  permissions skipped on your own laptop puts your SSH keys, browser sessions,
  and everything else you care about in the blast radius. Running them on a VPS
  that holds only the work confines the worst case to the box. That isn't
  sandboxing in the strict sense, but it is most of what people want from it.
- **Your claude.ai account becomes a control surface for the machine.** Anyone
  who can open your session list can drive terminals on the box. Treat the
  account accordingly: strong auth, and don't share it.
- **Keep a human on anything that leaves the machine.** Skipped permissions
  should mean the agent acts freely inside the box, not outside it. The gates,
  and how to write them down, are in [WIRING.md](WIRING.md).

## Requirements and notes

- tmux and the `claude` CLI on `PATH`.
- Run it on an always-on machine, such as a cheap VPS, so the terminals stay
  reachable any time, even when your own computer is off.
- `--dangerously-skip-permissions` lets the agent run tools without asking. Only
  use it where you trust the environment.
- A blank `tmux capture-pane` from a running Claude session is normal; the
  full-screen UI doesn't render into the captured buffer. The boot URL still shows
  in the early scrollback, which is why the script polls right after launch.
