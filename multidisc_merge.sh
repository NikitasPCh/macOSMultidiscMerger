#!/usr/bin/env bash
#
# merge_multidisc.sh
#
# Scans a directory for multi-disc game folders following the naming
# convention "Game Title (Disc N)" and merges each matching group into
# a single folder containing all disc files, plus a generated .m3u
# playlist that auto-detects each disc's .cue/.chd file.
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
        base_name=$(echo "$dir" \
            | sed -E 's/ ?\(Disc [0-9]+\) ?/ /' \
            | sed -E 's/ +/ /g' \
            | sed -E 's/^ //; s/ $//')
        printf '%s|%s|%s\n' "$base_name" "$disc_num" "$dir" >> "$SCAN_FILE"
    fi
done

if [[ ! -s "$SCAN_FILE" ]]; then
    echo "No folders matching the \"(Disc N)\" naming convention were found in this directory."
    exit 0
fi

# --- Step 2: process each distinct game title ---
while IFS= read -r base_name; do
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
done < <(cut -d'|' -f1 "$SCAN_FILE" | sort -u)

# --- Step 3: summary ---
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
