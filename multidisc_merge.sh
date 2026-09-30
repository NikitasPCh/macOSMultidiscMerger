#!/usr/bin/env bash
#
# merge_multidisc.sh
#
# Scans a directory for multi-disc game folders following the naming
# convention "Game Title (Disc N)" and merges each matching group into
# a single folder containing all disc files, plus a generated .m3u
# playlist that auto-detects each disc's .cue/.chd file.
#
# At the end, optionally hides each game's disc files: the .m3u ends up
# directly in the scanned directory and the raw disc files move into a
# dot-prefixed hidden folder next to it, so frontends (e.g. ES-DE) show
# exactly one entry per game instead of a folder to navigate into.
#
# Compatible with bash 3.2+ (the version macOS ships by default) -
# no minimum bash version, Homebrew, or extra install required.
#
# Usage:
#   ./merge_multidisc.sh <target_directory>

set -uo pipefail

if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0 <target_directory>"
    echo ""
    echo "Scans <target_directory>'s top-level folders for the naming convention"
    echo "\"Game Title (Disc N)\", merges each matching group into one folder,"
    echo "and generates a .m3u playlist referencing each disc's .cue/.chd file."
    exit 0
fi

TARGET_DIR="$1"

if ! cd "$TARGET_DIR" 2>/dev/null; then
    echo "Error: cannot access directory: $TARGET_DIR"
    exit 1
fi

echo "Scanning directory: $(pwd)"
echo ""
echo "Select mode:"
echo "  1) Dry run  - ask (y/n) before merging each game"
echo "  2) Fast run - no confirmation, merge everything automatically"
read -rp "Enter 1 or 2: " MODE_CHOICE
echo ""

case "$MODE_CHOICE" in
    1) CONFIRM_MODE=true ;;
    2) CONFIRM_MODE=false ;;
    *) echo "Invalid choice. Exiting."; exit 1 ;;
esac

DISC_REGEX='\(Disc ([0-9]+)\)'

# Bash 3.2 has no associative arrays, so grouping is done via a plain
# temp file instead: one line per disc folder found, formatted as
#   base_name|disc_num|folder_name
SCAN_FILE=$(mktemp)
trap 'rm -f "$SCAN_FILE"' EXIT

MERGED_GAMES=()
SKIPPED_SINGLETONS=()

shopt -s nullglob

# --- Step 1: scan top-level folders and record matches to the temp file ---
for entry in */; do
    dir="${entry%/}"
    if [[ "$dir" =~ $DISC_REGEX ]]; then
        disc_num="${BASH_REMATCH[1]}"
        # Everything from "(Disc N)" onward is disc-specific and gets dropped
        # for grouping purposes - some ROM sets add a differing descriptor
        # after the disc marker per disc (e.g. "(Disc 1) (Allies)" /
        # "(Disc 2) (Soviet)", or "(Disc 2) (Evolution Disc)"), which would
        # otherwise produce a different "base name" per disc and prevent
        # them from being grouped as the same game.
        base_name=$(echo "$dir" \
            | sed -E 's/ ?\(Disc [0-9]+\).*$//' \
            | sed -E 's/ +/ /g' \
            | sed -E 's/^ //; s/ $//')
        printf '%s|%s|%s\n' "$base_name" "$disc_num" "$dir" >> "$SCAN_FILE"
    fi
done

# --- Step 2: process each distinct game title (skipped entirely if nothing matched) ---
if [[ -s "$SCAN_FILE" ]]; then
    while IFS= read -r base_name <&3; do
        disc_count=$(awk -F'|' -v name="$base_name" '$1 == name' "$SCAN_FILE" | wc -l | tr -d ' ')

        if [[ "$disc_count" -le 1 ]]; then
            singleton_folder=$(awk -F'|' -v name="$base_name" '$1 == name {print $3}' "$SCAN_FILE" | head -n 1)
            SKIPPED_SINGLETONS+=("$singleton_folder")
            continue
        fi

        echo "Found multi-disc group: \"$base_name\" ($disc_count discs)"
        sorted_entries=$(awk -F'|' -v name="$base_name" '$1 == name {print $2":"$3}' "$SCAN_FILE" | sort -t: -k1,1n)

        printf '%s\n' "$sorted_entries" | while IFS=: read -r num folder; do
            [[ -n "$folder" ]] && echo "  Disc $num: $folder"
        done

        if $CONFIRM_MODE; then
            read -rp "Proceed with merging \"$base_name\"? (y/n): " ans
            if [[ ! "$ans" =~ ^[Yy]$ ]]; then
                echo "  Skipped by user request."
                echo ""
                continue
            fi
        fi

        mkdir -p "$base_name"

        m3u_lines=()

        # Move each disc's contents into the merged folder, recording its
        # .cue/.chd filename (detected BEFORE moving, so it works whether
        # or not the filename itself contains "Disc N")
        while IFS=: read -r num folder; do
            [[ -z "$folder" ]] && continue

            cue_file=$(find "$folder" -maxdepth 1 -type f \( -iname "*.cue" -o -iname "*.chd" \) | head -n 1)
            cue_basename=""
            if [[ -n "$cue_file" ]]; then
                cue_basename="$(basename "$cue_file")"
            fi

            find "$folder" -mindepth 1 -maxdepth 1 -exec mv -n {} "$base_name"/ \;

            if [[ -n "$cue_basename" ]]; then
                m3u_lines+=("$cue_basename")
            else
                echo "  Warning: no .cue/.chd file found for Disc $num (in \"$folder\") - it will be missing from the .m3u"
            fi
        done <<< "$sorted_entries"

        m3u_path="${base_name}/${base_name}.m3u"
        printf "%s\n" "${m3u_lines[@]}" > "$m3u_path"
        echo "  Created: $m3u_path"

        # Delete original disc folders only if now empty (a leftover file
        # means a name collision happened during the move - left in place
        # rather than risk losing data)
        while IFS=: read -r num folder; do
            [[ -z "$folder" ]] && continue
            if [[ -d "$folder" ]]; then
                if [[ -z "$(ls -A "$folder" 2>/dev/null)" ]]; then
                    rmdir "$folder"
                else
                    echo "  Warning: \"$folder\" is not empty after merging (likely a filename collision) - left in place, not deleted."
                fi
            fi
        done <<< "$sorted_entries"

        MERGED_GAMES+=("$base_name ($disc_count discs)")
        echo ""
    done 3< <(cut -d'|' -f1 "$SCAN_FILE" | sort -u)
else
    echo "No folders matching the \"(Disc N)\" naming convention were found in this directory."
fi

# --- Step 3: summary ---
echo ""
echo "===== Summary ====="
echo ""
if [[ ${#MERGED_GAMES[@]} -gt 0 ]]; then
    echo "Merged multi-disc games:"
    for g in "${MERGED_GAMES[@]}"; do
        echo "  - $g"
    done
else
    echo "No multi-disc games were merged."
fi

echo ""
if [[ ${#SKIPPED_SINGLETONS[@]} -gt 0 ]]; then
    echo "Skipped (only a single \"(Disc 1)\" found, no matching siblings):"
    for s in "${SKIPPED_SINGLETONS[@]}"; do
        echo "  - $s"
    done
else
    echo "No singleton \"(Disc 1)\" folders were found."
fi

# --- Step 4: optional ES-DE / EmulationStation compatibility fixup ---
# Frontends like ES-DE always show a folder as a folder to navigate into -
# they don't collapse a folder containing a single game down to one entry.
# So a per-game folder (even one containing only a .m3u plus a hidden
# subfolder) still shows up as an extra folder to click through. The fix
# is to not have a per-game folder at all: the .m3u goes directly in the
# scanned directory (right where ES-DE expects to find a game), and the
# raw disc files move into a dot-prefixed hidden folder alongside it,
# which ES-DE's scanner skips entirely.
echo ""
echo "Some frontends (e.g. ES-DE) always show a folder as a folder to navigate"
echo "into, even one that only contains a single game - so a separate folder"
echo "per game still means an extra click before the game itself appears."
echo "This step removes that folder: it places each game's .m3u directly in"
echo "this directory, and moves its raw disc files into a hidden folder"
echo "(name starts with a dot) right alongside it, which frontends skip over."
read -rp "Hide the individual disc files for frontend compatibility (as described above)? (y/n): " hide_ans

if [[ "$hide_ans" =~ ^[Yy]$ ]]; then

    hide_disc_files() {
        # $1 = folder name (currently visible, top-level)
        # $2 = directory the disc files currently live in - either "$1"
        #      itself (a freshly merged/singleton game with loose disc
        #      files), or "$1/.hidden" (a game already hidden by an OLDER
        #      version of this script, which nested a ".hidden" subfolder
        #      INSIDE the game folder and left the game folder itself
        #      visible - still a folder for frontends to navigate into,
        #      so it needs migrating to the current scheme too)
        #
        # Ends with:
        #   <folder>.m3u        (top-level, next to this folder - what ES-DE sees)
        #   .<folder>/          (hidden, holds the actual disc files)
        # and the original visible "<folder>" directory (and any old nested
        # ".hidden" inside it) removed.
        local folder="$1"
        local source_dir="$2"
        local hidden_dir=".${folder}"
        local m3u_path="${folder}.m3u"
        local tmp_list fname n sorted_names

        # Drop any .m3u already sitting directly inside the folder (from the
        # merge step, or from an older version of this script) - the
        # definitive one is about to be (re)created at the top level instead.
        find "$folder" -maxdepth 1 -type f -name "*.m3u" -delete

        # Sort disc files by the disc number in their filename (falls back
        # to the end of the list if no number is found)
        tmp_list=$(mktemp)
        while IFS= read -r f; do
            fname=$(basename "$f")
            if [[ "$fname" =~ $DISC_REGEX ]]; then
                n="${BASH_REMATCH[1]}"
            else
                n="9999"
            fi
            printf '%s|%s\n' "$n" "$fname" >> "$tmp_list"
        done < <(find "$source_dir" -maxdepth 1 -type f \( -iname "*.cue" -o -iname "*.chd" \))
        sorted_names=$(sort -t'|' -k1,1n "$tmp_list" | cut -d'|' -f2)
        rm -f "$tmp_list"

        mkdir -p "$hidden_dir"
        find "$source_dir" -mindepth 1 -maxdepth 1 -type f -exec mv -n {} "$hidden_dir"/ \;

        : > "$m3u_path"
        while IFS= read -r fname; do
            [[ -n "$fname" ]] && printf '%s/%s\n' "$hidden_dir" "$fname" >> "$m3u_path"
        done <<< "$sorted_names"

        # If the disc files came from an old nested ".hidden" dir, remove it
        # now that it's empty
        if [[ "$source_dir" != "$folder" && -d "$source_dir" && -z "$(ls -A "$source_dir" 2>/dev/null)" ]]; then
            rmdir "$source_dir"
        fi

        if [[ -z "$(ls -A "$folder" 2>/dev/null)" ]]; then
            rmdir "$folder"
        else
            echo "  Warning: \"$folder\" is not empty after hiding - left in place alongside $m3u_path."
        fi

        echo "  Hidden disc files for \"$folder\" -> ${hidden_dir}/ (created $m3u_path)"
    }

    # Scan every top-level folder - covers games merged just now, singleton
    # "(Disc 1)" games left untouched above, folders left over from a
    # previous run or manual setup with loose disc files, AND folders
    # already hidden by an older version of this script (nested
    # "<folder>/.hidden", still visible as a folder) that need migrating.
    # Once a folder is fully processed it becomes a dot-prefixed hidden
    # folder, so plain "*/" globbing naturally skips it on any later run -
    # no extra bookkeeping needed.
    echo ""
    FOUND_ANY=false

    for entry in */; do
        folder="${entry%/}"

        # Case A: loose disc files sitting directly inside the folder.
        disc_file_count=$(find "$folder" -maxdepth 1 -type f \( -iname "*.cue" -o -iname "*.chd" \) | wc -l | tr -d ' ')
        if [[ "$disc_file_count" -ge 1 ]]; then
            FOUND_ANY=true
            echo "Found: \"$folder\" ($disc_file_count disc file(s))"
            hide_disc_files "$folder" "$folder"
            continue
        fi

        # Case B: already hidden by an older version of this script (a
        # nested "<folder>/.hidden" subfolder, with "<folder>" itself still
        # visible) - migrate it to the current top-level scheme.
        if [[ -d "${folder}/.hidden" ]]; then
            old_disc_count=$(find "${folder}/.hidden" -maxdepth 1 -type f \( -iname "*.cue" -o -iname "*.chd" \) | wc -l | tr -d ' ')
            if [[ "$old_disc_count" -ge 1 ]]; then
                FOUND_ANY=true
                echo "Migrating already-hidden folder from an older run: \"$folder\" ($old_disc_count disc file(s))"
                hide_disc_files "$folder" "${folder}/.hidden"
            fi
        fi
    done

    echo ""
    if $FOUND_ANY; then
        echo "Done. Re-scan your library in ES-DE (or your frontend of choice) to see one entry per game."
    else
        echo "No folders with disc files found to update."
    fi
else
    echo "Skipped - disc files left as-is."
fi