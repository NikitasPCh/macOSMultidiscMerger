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

No disc files are renamed in the process — everything keeps its original filename, just moved into the new shared folder. The original per-disc folders are deleted once they're empty.

Anything after `(Disc N)` in a folder name is treated as disc-specific and dropped when grouping and naming — this handles ROM sets where each disc folder carries its own extra descriptor, e.g. `Command & Conquer - Red Alert (USA) (Disc 1) (Allies)` and `(Disc 2) (Soviet)`, or `Rival Schools - United by Fate (USA) (Disc 1)` and `(Disc 2) (Evolution Disc)`. Both pairs above are still recognized as the same game and merge into `Command & Conquer - Red Alert (USA)/` and `Rival Schools - United by Fate (USA)/` respectively.

Folders with only a single `(Disc 1)` and no matching siblings are left untouched, since they aren't actually part of a multi-disc set.

The layout above is the intermediate result of the merge step. At the end, the script can also optionally hide the raw disc files for frontend compatibility, which changes this layout further — see below.

## Requirements

- macOS (uses whatever bash macOS ships by default — no Homebrew or extra install needed)
- Folder names must follow this exact convention: `<Game Title> (Disc 1)`, `(Disc 2)`, etc. — parentheses, capital "D", and a number. Anything after the disc number (like a region/side/bonus-disc descriptor) is fine and gets handled as described above.

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

Frontends like ES-DE always show a folder as a folder you have to navigate into — they don't collapse a folder down to a single entry just because it only contains one game. So even after merging, a per-game folder (holding the `.bin`/`.cue`/`.chd` files and the `.m3u`) still shows up as an extra click before the actual game appears, and worse, ES-DE also lists each loose file inside it as its own entry.

The fix is to not have a per-game folder at all: the `.m3u` needs to sit directly in the directory ES-DE scans, with the raw disc files tucked into a dot-prefixed hidden folder right alongside it (dot-prefixed names are invisible to most frontends, and to Finder by default).

At the end of a run, the script asks:

```
Hide the individual disc files for frontend compatibility (as described above)? (y/n):
```

Answering `y` scans every top-level folder in the target directory and handles two cases:

- **Loose disc files** — multi-disc games merged just now, single-disc "(Disc 1)" games left untouched, or anything else left over with its `.bin`/`.cue`/`.chd` files sitting directly inside a folder. For each of these, the script:
  - moves the disc files into a hidden folder named after the game (e.g. `.Multidisc Quest`)
  - writes (or rewrites) the game's `.m3u` directly in the scanned directory, pointing at the hidden copies (e.g. `.Multidisc Quest/Multidisc Quest (Disc 1).cue`)
  - removes the now-empty visible per-game folder entirely
- **Already hidden by an older version of this script** — an earlier version of this tool nested the hidden folder *inside* the game folder (`Game/.hidden/...` with `Game/Game.m3u` next to it), which still left `Game/` itself as a visible folder for frontends to navigate into. If the script finds one of these, it migrates it to the current layout automatically: the disc files move out to the new top-level hidden folder, the `.m3u` is rewritten and moved to the top level, and the old nested folder plus the now-empty game folder are both removed.

So a merged game like `Multidisc Quest` ends up as:

```
Multidisc Quest.m3u
.Multidisc Quest/
├── Multidisc Quest (Disc 1).bin
├── Multidisc Quest (Disc 1).cue
├── Multidisc Quest (Disc 2).bin
└── Multidisc Quest (Disc 2).cue
```

with `Multidisc Quest.m3u` sitting right next to your other games — exactly one entry, no folder to click through — and the same applies to a single-disc "(Disc 1)" game, and to a game migrated from the older nested-hidden layout.

Once a game has been hidden this way there's no visible top-level folder left for it, so re-running the script and answering `y` again is safe — already fully-hidden games are simply skipped, since only un-hidden or old-layout folders still have something for the script to find.

**Note:** disc-swapping in a desktop emulator (e.g. DuckStation on macOS/Windows/Linux) still works exactly the same, since it's the `.m3u` — not the raw files — that gets loaded, and the `.m3u`'s relative paths still resolve correctly into the hidden folder next to it.

### Known issue: DuckStation standalone on Android

**This hidden-folder layout does not work with DuckStation's standalone Android app**, including when launched through ES-DE on Android (e.g. on a Retroid Pocket). DuckStation on Android can only resolve a `.m3u`'s entries when the disc files sit in the *same* folder as the `.m3u` itself — once they're tucked into a sibling hidden folder (which is exactly what this script does), it fails with an error like `Failed to open CD image`. This is a limitation of DuckStation's Android build itself, not something this script can work around from macOS.

What works instead:

- **Use SwanStation (the RetroArch core) instead of DuckStation standalone** for PS1 games in ES-DE on Android. It handles this exact folder layout correctly, including BIOS and RetroAchievements — this is the recommended setup if you're on Android/ES-DE.
- DuckStation standalone still works fine if launched **directly** (not through ES-DE), since its own file browser can resolve the hidden folder using its own storage access.
- If you specifically need DuckStation-via-ES-DE to work, the disc files would need to live as individually hidden (dot-prefixed) *files* directly alongside the `.m3u`, with no wrapping folder at all, rather than this script's dot-prefixed-subfolder scheme. This script does not currently support generating that layout.

## Technical notes

macOS ships bash 3.2 by default, and associative arrays weren't introduced until bash 4.0. Rather than require anyone to install a newer bash through Homebrew, this script uses a plain temp file (created with `mktemp`, cleaned up automatically on exit) to group discs by game title instead — keeping it compatible with the stock bash on any Mac, no dependencies required.

## License

MIT
</content>