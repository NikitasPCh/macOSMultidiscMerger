# macOS Multidisc Merger

A macOS bash script that merges multi-disc ROM folders (PS1, PS2, Sega Saturn, and any other CUE/CHD-based system) into a single folder per game, and generates a `.m3u` playlist for emulators and frontends that support disc-swapping.

## What it does

Given a directory containing folders like:

```
Final Fantasy VII (Disc 1)
Final Fantasy VII (Disc 2)
Final Fantasy VII (Disc 3)
```

the script merges them into:

```
Final Fantasy VII/
├── Final Fantasy VII (Disc 1).bin
├── Final Fantasy VII (Disc 1).cue
├── Final Fantasy VII (Disc 2).bin
├── Final Fantasy VII (Disc 2).cue
├── Final Fantasy VII (Disc 3).bin
├── Final Fantasy VII (Disc 3).cue
└── Final Fantasy VII.m3u
```

No files are renamed in the process — everything keeps its original filename, just moved into the new shared folder. The original per-disc folders are deleted once they're empty.

Folders with only a single `(Disc 1)` and no matching siblings are left untouched, since they aren't actually part of a multi-disc set.

At the end, it can also optionally hide the raw disc files for frontend compatibility — see below.

## Requirements

- macOS (uses whatever bash macOS ships by default — no Homebrew or extra install needed)
- Folder names must follow this exact convention: `<Game Title> (Disc 1)`, `(Disc 2)`, etc. — parentheses, capital "D", and a number.

## Before you run it on your real library

**This script moves files and deletes folders.** Back up your ROMs first. It's also worth running Dry run mode (see below) on a small test folder before pointing it at your whole collection, just to see how it behaves.

## Usage

### 1. Give the script permission to run

Open Terminal (⌘ + Space, type "Terminal", press Return) and navigate to the folder containing the script.

If you're not sure of the folder's path: locate the script in Finder, hold the Option key, then right-click (or two-finger tap on a trackpad) on it. Choose **Copy "filename" as Pathname** from the menu. Back in Terminal, type `cd ` (with a trailing space), then paste the path (⌘ + V) and press Return.

Then make the script executable:

```
chmod +x merge_multidisc.sh
```

### 2. Run it

```
./merge_multidisc.sh "/path/to/your/roms"
```

Replace the path with the folder you want scanned.

You'll be asked to choose a mode:

- **Dry run** — asks for confirmation (y/n) before merging each game it finds, so you can review everything first
- **Fast run** — merges every matching group automatically, no prompts

When it finishes, it prints a summary of every game it merged and every singleton `(Disc 1)` folder it skipped.

## Hiding disc files for frontends (e.g. ES-DE)

Some frontends — ES-DE among them — list every file inside a game's folder as its own entry, rather than treating the folder as a single game. Even after merging, a game folder still contains the raw `.bin`/`.cue`/`.chd` files alongside the `.m3u`, so the frontend sees several confusing entries instead of one.

At the end of a run, the script asks:

```
Hide the individual disc files in a .hidden subfolder for frontend compatibility? (y/n):
```

Answering `y` scans every top-level folder in the target directory — multi-disc games merged just now, single-disc "(Disc 1)" games left untouched, and anything left over from a previous run — and for each one that still has its disc files sitting loose, it:

- moves the `.bin`/`.cue`/`.chd` files into a `.hidden` subfolder (the leading dot makes it invisible to most frontends and to Finder by default)
- rewrites the game's `.m3u` to point at the hidden copies (`.hidden/<filename>`)

The result is a folder containing only a `.m3u` file (plus the invisible `.hidden` subfolder), which frontends like ES-DE will show as a single, clean entry per game — including for single-disc games, not just multi-disc ones.

A folder that already has a `.hidden` subfolder is skipped on future runs, so it's safe to answer `y` every time, even on a library that's a mix of already-hidden and not-yet-hidden games.

**Note:** after this step, disc-swapping in your emulator (e.g. DuckStation) still works exactly the same, since it's the `.m3u` — not the raw files — that gets loaded, and the `.m3u` still resolves correctly via its relative path into `.hidden/`.

## Technical notes

macOS ships bash 3.2 by default, and associative arrays weren't introduced until bash 4.0. Rather than require anyone to install a newer bash through Homebrew, this script uses a plain temp file (created with `mktemp`, cleaned up automatically on exit) to group discs by game title instead — keeping it compatible with the stock bash on any Mac, no dependencies required.

## License

MIT
</content>