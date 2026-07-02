# Wiring it together

*The README builds one remote workbench. This page is how I run many of them as one system.*

## What it is

From a phone, I can open a Claude Code workbench on any piece of my work, hand it a job,
and put the phone away, without ever logging on to the server. Each workbench starts with
a footing I choose: a directory to open in, a brief, and a reading list. Results land as
commits, so nothing important lives only in a chat window.

At the basic level, that's four abilities:

- **Open work from anywhere.** One standing session, the *front door*, is always
  running. You open it in the Claude app and ask it to spawn workbenches for you. No
  SSH, no logging on: you talk to sessions, and sessions manage the machine.
- **Every bench starts on solid ground.** It opens in a directory you chose, reads the
  `CLAUDE.md` there first, then reads whatever else its brief names. It sits down
  knowing the ground, not as a blank chat you have to brief from scratch.
- **Work runs unattended.** A complete seed prompt (the task, its definition of done,
  where the output lands) means the bench needs no supervisor. Kick it off, check in
  later.
- **Nothing is lost when a session ends.** Repos hold the memory; sessions are
  disposable. A bench that dies mid-work cost you nothing that was written down.

## How it works

```mermaid
flowchart LR
    subgraph reach [Reach it from anywhere]
        P[Phone / web app]
        D[Desktop app]
        S[SSH / local tmux]
    end
    subgraph vm [Always-on machine]
        direction TB
        F[front door
        standing bench]
        W1[workbench:
        one brief]
        W2[workbench:
        another brief]
        L[(git repos:
        context + state)]
        F -. spawns .-> W1
        F -. spawns .-> W2
        W1 -. can spawn .-> W2
        W1 --- L
        W2 --- L
    end
    P --> F
    P --> W1
    D --> W2
    S --> W1
```

Five pieces:

1. **An always-on machine.** A cheap VPS is plenty; tmux and the `claude` CLI are the
   whole stack.
2. **tmux** keeps every session alive, detached, through disconnects.
3. **Remote Control** gives each session a `https://claude.ai/code/session_…` link, so
   any of them opens on a phone, in a browser, or in the desktop app.
4. **Git repos** hold the context benches start from and the state they leave behind.
5. **The front door**: one standing bench whose job is to open the others. A phone
   can't run a shell script, so you ask the front door instead: "spawn an audit bench
   on project-a, seeded with this." It runs [`spawn-remote.sh`](spawn-remote.sh) (the
   README's recipe), hands you the new session's link, and you carry on with your
   morning. (Remote Control's own server mode also spawns sessions on demand, within
   one repo; the front door is an agent, so it opens benches anywhere and writes the
   brief. The README compares the two properly.)

### Surviving a reboot

The front door has to be running, and a rebooted machine forgets. Give it a way back up
and the system is phone-only permanently: one `@reboot` line in `crontab -e`.

```cron
@reboot sleep 30 && PATH=/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin \
  $HOME/claude-code-workbenches/spawn-remote.sh front-door $HOME/repos \
  'Read CLAUDE.md. You are the front door: you open other workbenches on request.'
```

Notes that matter: cron runs with a minimal `PATH`, so set it (or use full paths to
`tmux` and `claude`); the `sleep 30` gives the network time to come up; and `claude`
must already be logged in on the box (its credentials persist across reboots). After a
reboot, the fresh front-door link is in your session list a minute later.

## Building it well

The pieces above make the system exist. These habits are what make it work.

### Benches and repos mix and match

It is tempting to make the rule "one workbench, one repo". That is not how it plays out
in practice, and forcing it wastes the flexibility. The real relationship is
many-to-many:

- **Several benches on one repo.** A project with a lot going on gets several benches at
  once, each with its own brief: one refreshing the docs, one preparing for a meeting,
  one auditing the backlog. They share the ground; they don't share the focus. The
  brief, not the directory, is what a bench *is*.
- **One bench across several repos.** Real work ranges: a bench opens in the project
  repo, reads background from a notes repo, checks an API detail in a second codebase,
  clones a third to compare. The seed names the mix: "read X here, check Y there, write
  the result to Z."
- **Some work owns a repo; some work borrows.** A product you're building deserves its
  own repo, and benches come and go against it for months. A one-off investigation
  deserves no repo at all: it borrows its footing from wherever the evidence lives and
  leaves its findings in the most sensible place. Give durable concerns repos; don't
  invent a repo per bench.

Two things hold regardless. Whatever directory a bench opens in, the `CLAUDE.md` there
is its seat: what this place is, the rules, where outputs land. And anything worth
keeping gets written into some repo before the session ends, because the repo layer is
the memory and the bench is not.

```
~/repos/
  project-a/     CLAUDE.md + the work      <- three benches on it right now
  project-b/     CLAUDE.md + the work      <- quiet this week, no bench
  notes/         CLAUDE.md + background    <- no bench of its own; every bench reads it
```

### The seed prompt carries the work

The seed you pass at spawn is not a greeting; it is the work order. A good one names:

- **the task and its definition of done**: what exists in the world when this is finished;
- **what to read first**: the files that give the session its footing, wherever they live;
- **where the output lands**: a path in a repo, so the result survives the session;
- **what not to do without asking**: the gates (below).

```bash
./spawn-remote.sh audit ~/repos/project-a \
  'Read CLAUDE.md and docs/spec.md first, and ~/repos/notes/decisions.md for
   background. Audit src/ against the spec and write the findings to
   docs/audit-2026-07.md: one section per gap, worst first.
   Do not change any source files. Commit the report when done.'
```

A bench seeded like that runs to completion without you. A bench seeded with "have a
look at the project" cannot. The seed carries the DNA of the work, and the bench grows
it.

### Skills make it repeatable

The second time you type the same seed, stop and make it a skill. `--plugin-dir` loads a
directory of skills, commands, and persona at spawn, so a bench starts with your
repeatable moves installed:

```bash
tmux send-keys -t myagent \
  'claude --remote-control "myagent" --plugin-dir ~/repos/my-plugin --dangerously-skip-permissions' Enter
```

Keep the plugin in a repo like everything else. Mine accreted one skill at a time, each
born the second or third time I caught myself re-explaining the same job.

### Fan out, and let benches open benches

One bench per brief means parallel work is just more benches:

```bash
./spawn-remote.sh triage  ~/repos/project-a 'Read CLAUDE.md. Triage the open issues into docs/triage.md.'
./spawn-remote.sh docs    ~/repos/project-a 'Read CLAUDE.md. Bring README.md up to date with src/.'
./spawn-remote.sh sweep   ~/repos/notes     'Read CLAUDE.md. Sweep for TODOs older than a month; list them in review.md.'
```

And because `spawn-remote.sh` is just a command, a bench can run it: the front door is
only the standing case of a general move. An agent that hits a sub-task deserving its
own desk spawns a sibling, seeds it, and carries on. You come back to find the work
split sensibly across sessions you didn't open yourself. The only limit is RAM.

### Keep a human on the gates

`--dangerously-skip-permissions` is what makes unattended work possible, and it should
mean exactly this: the agent acts freely *inside* the machine. Anything that *leaves*
the machine stays behind a human yes: sending, publishing, spending, deleting things
that live remotely. Write the gates into each repo's `CLAUDE.md` in plain words, and
mean them:

```
Never send email, post, publish, or push to public remotes without my explicit go.
Draft it, stage it, and stop.
```

The speed is the agent's; the responsibility stays with you. On a trusted, always-on box
with the gates written down, this arrangement has held for me across months of daily
unattended runs. Without the gates written down, don't run unattended.

### Put work down; pick it back up

Sessions end: the box reboots, you kill one to free RAM, or the work pauses for a week.
Make putting-down explicit. Before a bench closes, have it write a short state note into
a repo and commit:

```
Ask the bench: 'Write where we got to into docs/state.md: what's done, what's next,
what's blocked and on whom. Commit it. Then exit.'
```

Then end the session, and check what else is running while you're at it:

```bash
tmux ls                          # every bench on the box, at a glance
tmux kill-session -t project-a   # end one; the repo keeps everything that matters
```

Re-opening is a fresh spawn whose seed points at the note:

```bash
./spawn-remote.sh project-a ~/repos/project-a \
  'Read CLAUDE.md, then docs/state.md. Continue from "what is next".'
```

Nothing is lost when a session dies, because nothing durable lived only in the session.

## A worked hour

What it feels like, end to end:

1. Morning, phone: open the front door in the Claude app and ask it to spawn `audit` on
   project-a, seeded with the report it should produce and where to commit it. The seed
   is complete, so the bench needs no supervisor: put the phone away.
2. Midday, laptop: open the audit bench (its link, or `tmux attach -t audit`), read the
   report it committed, leave two corrections in the chat, detach.
3. It finishes. The report is a commit in the repo, not a scrollback memory. Ask it to
   write `docs/state.md` and exit, or just kill the session; the repo already holds
   everything.
4. Evening: spawn a fresh bench seeded with the report to do the fixes. It opens a
   sibling for a sub-task it judged separable. Both leave commits.

At no point did the system depend on a session surviving. The repos are the memory;
benches are how the work moves.

## Where this goes

What you have once this is running is remote, durable, parallel: benches you can open
from anywhere, that survive you leaving, with memory in repos and a human on the gates.
The seed carries the intent, the bench grows the work, and you stay exactly where you
must: the go and the sign-off.

Build your own architecture from here. How you organise it, what you name, where you
draw the lines is yours to decide, and the right answers depend on your work. I have my
own ideas running on this foundation and will publish them in due course.
