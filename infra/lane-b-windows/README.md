# Lane B test bed — dockur/windows on th-dc

A Win 11 KVM VM running on the `th-dc` remote docker context, used to
verify the smoodle Windows installer end-to-end before any public
Lane B ship. Replaces the "need a Parallels VM" gap flagged as Open
Question 1 in `docs/LANE-B-WINDOWS.md`.

## Why a remote VM (vs Parallels on the founder's Mac)

- Free macOS RAM/CPU/disk during installer dev cycles.
- Same VM persists across machine restarts and across founder
  machines — no rebuilding the rehearsal box every time.
- `th-dc` has the headroom (64 cores, 189 GB RAM, 600 GB free disk,
  KVM enabled) to run several test VMs if Lane B grows.
- Same blueprint extends to the future MSI installer + code-signing
  rehearsal stage.

## Resource budget

| Knob       | Value | Why                                    |
|------------|-------|----------------------------------------|
| OS         | Win 11 | Phase 1 wedge baseline (most diaspora-Thai friends are on Win 11) |
| RAM        | 16 GB | Comfortable for Win 11 + IME work; th-dc has plenty |
| CPU        | 4 cores | More than enough for typing tests; th-dc has 64 |
| Disk       | 64 GB | Win 11 needs ~30 GB; leaves room for test artifacts |
| Persistent storage | named volume `windows-storage` | survives `compose down` |

## Deploy

```bash
# from smoodle repo root
docker --context th-dc compose -f infra/lane-b-windows/docker-compose.yml pull
docker --context th-dc compose -f infra/lane-b-windows/docker-compose.yml up -d
```

First run downloads the Win 11 ISO (~6 GB) and runs an unattended
install (~15-25 min). Watch progress at `http://th-dc:8006`.

## Access

The hostname `th-dc` below assumes you have an SSH `Host th-dc` block
in `~/.ssh/config` (the same alias used by the docker context). If
not, substitute the server's address — currently `10.159.0.63`.

| Path | When to use |
|------|-------------|
| Browser to `http://th-dc:8006` | watch first-boot install, occasional debug |
| Microsoft Remote Desktop (Mac) → `th-dc:3389` | day-to-day installer testing — better latency, copy-paste, file transfer |

Credentials: `smoodle / smoodle` (test bed only — rotate before any
public artifact ships).

To probe the VM is up *without* the alias on your machine, run a
container *on the th-dc context* and curl through localhost:
```bash
docker --context th-dc run --rm --network host alpine \
  sh -c 'wget -qO- http://127.0.0.1:8006 >/dev/null && echo OK'
```

## Lifecycle

| Action | Command |
|--------|---------|
| Stop the VM (preserve disk) | `docker --context th-dc compose -f infra/lane-b-windows/docker-compose.yml down` |
| Stop and **wipe** Windows install | `docker --context th-dc compose -f infra/lane-b-windows/docker-compose.yml down -v` |
| Status | `docker --context th-dc ps --filter name=smoodle-lane-b` |
| Logs | `docker --context th-dc logs -f smoodle-lane-b` |

`down -v` is the "start fresh" button — useful when the smoodle
installer leaves artifacts and you want to re-test from a clean
Windows desktop.

## Smoke checklist (after first boot)

1. Web viewer `http://th-dc:8006` shows Win 11 desktop.
2. RDP from Mac connects with `smoodle / smoodle`.
3. Inside the VM: `winget install Rime.Weasel` succeeds.
4. Weasel toolbar appears in the system tray.
5. Type a Latin character somewhere (Notepad), confirm Weasel is
   intercepting input.
6. Uninstall Weasel: leaves the VM ready for a clean
   `install-windows.ps1` smoke once that script lands.

## Trigger to retire this test bed

- Lane B ships a signed MSI installer that's been validated against
  multiple real Windows machines from the dogfood circle.
- OR: the founder ends up with a dedicated Windows laptop / Parallels
  VM and prefers local iteration.

Either way, the compose file + this README stay in repo as a
"how to bring a test Windows VM back up" reference.

## Security note

`docker-compose.yml` binds 8006 + 3389 on `0.0.0.0` of the th-dc
host. This is acceptable because th-dc is a private DC behind a
controlled network. **Do not** run this compose on a server with
public-internet exposure on those ports without changing the
credentials and binding to `127.0.0.1` + SSH-tunnel.
