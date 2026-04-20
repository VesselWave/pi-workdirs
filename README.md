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
- splits helper logic into small Fish source files under `fish/functions/pi-lib/`

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

Copy bundled Fish files into config:

```fish
cp -R fish/. ~/.config/fish/
source ~/.config/fish/functions/pi.fish
```

This installs:

- `functions/pi.fish`
- `functions/pi-lib/common.fish`
- `functions/pi-lib/listing.fish`
- `functions/pi-lib/runtime.fish`

## Notes

- `live` = tmux session exists
- `used` = dir has non-metadata files
- `meta` = only `.pi-session` and `SESSION.md`
- `empty` = legacy empty dir

## License

MIT
