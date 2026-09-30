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
chmod +x multidisc_merge.sh
```

### 2. Run it

```
./multidisc_merge.sh "/path/to/your/roms"
```

Replace the path with the folder you want scanned.

You'll be asked to choose a mode:

- **Dry run** — asks for confirmation (y/n) before merging each game it finds, so you can review everything first
- **Fast run** — merges every matching group automatically, no prompts

When it finishes, it prints a summary of every game it merged and every singleton `(Disc 1)` folder it skipped.

## Test example

The `test/` folder in this repository contains a small set of placeholder folders you can use to see the script in action before running it on your real library:

```
test/
├── Multidisc Quest (Disc 1)/
│   ├── Multidisc Quest (Disc 1).bin
│   └── Multidisc Quest (Disc 1).cue
├── Multidisc Quest (Disc 2)/
│   ├── Multidisc Quest (Disc 2).bin
│   └── Multidisc Quest (Disc 2).cue
├── Singleton Quest (Disc 1)/
│   ├── Singleton Quest (Disc 1).bin
│   └── Singleton Quest (Disc 1).cue
└── Singleton Quest 2 (Disc 2)/
    ├── Singleton Quest 2 (Disc 2).bin
    └── Singleton Quest 2 (Disc 2).cue
```

All `.bin` files are empty placeholders (0 bytes) — no real game data is included, since sharing actual disc images isn't legal. Each `.cue` file is a minimal, valid-looking sheet referencing its matching `.bin`, just enough for the script to detect and process.

This set demonstrates both code paths:

- **`Multidisc Quest`** has two disc folders sharing the same base title — the script will merge them into a single `Multidisc Quest/` folder and generate `Multidisc Quest.m3u`.
- **`Singleton Quest`** and **`Singleton Quest 2`** each have only one disc folder with no matching sibling — the script will leave both untouched and list them separately in the summary as skipped singletons.

To try it yourself:

```
chmod +x multidisc_merge.sh
./multidisc_merge.sh "test"
```

Pick **Dry run** mode when prompted so you can see exactly what it plans to do to `Multidisc Quest` before confirming. Afterward, `test/` will contain a merged `Multidisc Quest/` folder with its `.m3u` playlist, while both `Singleton Quest` folders remain exactly as they were.

## Technical notes

macOS ships bash 3.2 by default, and associative arrays weren't introduced until bash 4.0. Rather than require anyone to install a newer bash through Homebrew, this script uses a plain temp file (created with `mktemp`, cleaned up automatically on exit) to group discs by game title instead — keeping it compatible with the stock bash on any Mac, no dependencies required.

## License

MIT
