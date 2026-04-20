# pi-workdirs

Fish wrapper for `pi` that turns throwaway `work-*` dirs into named, resumable sessions.

## What it does

- creates labeled work dirs under `~/repos/test`
- writes session metadata to `.pi-session`
- writes human summary to `SESSION.md`
- lists sessions with `pi sessions` / `pi ls`
- resumes by id or query with `pi resume`
- jumps to last session with `pi last`
- prunes stale empty dirs with `pi clean`

## Commands

```fish
pi "debug auth redirect loop"
pi new billing -- "investigate invoice retry bug"
pi sessions
pi resume 3
pi resume auth
pi cd 2
pi last
pi clean 14
pi clean 14 --yes
```

## Install

Copy function into Fish config:

```fish
mkdir -p ~/.config/fish/functions
cp fish/functions/pi.fish ~/.config/fish/functions/pi.fish
source ~/.config/fish/functions/pi.fish
```

## Notes

- `live` = tmux session exists
- `used` = dir has non-metadata files
- `meta` = only `.pi-session` and `SESSION.md`
- `empty` = legacy empty dir
