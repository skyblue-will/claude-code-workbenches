# Reference

*The fine detail behind the [README](README.md) recipe: every flag, the safe
way to feed a first prompt, the ways back in, and how this relates to what
Remote Control does natively. You don't need this page to get started.*

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

## The spawn script

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

## How this relates to Remote Control's native modes

Remote Control has grown several modes of its own. As of mid-2026:

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

Side by side:

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

It's not the features, it's a way of using them: an always-on machine, tmux
holding the terminals, Remote Control reaching them, and the working
conventions in [WIRING.md](WIRING.md).

## Requirements and notes

- tmux and the `claude` CLI on `PATH`.
- Run it on an always-on machine, such as a cheap VPS, so the terminals stay
  reachable any time, even when your own computer is off.
- `--dangerously-skip-permissions` lets the agent run tools without asking. Only
  use it where you trust the environment.
- A blank `tmux capture-pane` from a running Claude session is normal; the
  full-screen UI doesn't render into the captured buffer. The boot URL still shows
  in the early scrollback, which is why the script polls right after launch.
