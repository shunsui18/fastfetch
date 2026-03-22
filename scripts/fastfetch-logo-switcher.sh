#!/bin/env bash

# --- Configuration ---
LOGO_DIR="$HOME/.config/fastfetch/logos"
CONFIG_FILE="$HOME/.config/fastfetch/config.jsonc"
BACKUP_FILE="$HOME/.config/fastfetch/config.jsonc.bak"
TEMP_FILE="$HOME/.config/fastfetch/config.jsonc.tmp"
STATE_FILE="$HOME/.config/fastfetch/.current_logo_index"

# 1. Image Discovery
shopt -s nullglob
IMAGES=("$LOGO_DIR"/*.{png,jpg,jpeg,gif,webp})

if [ ${#IMAGES[@]} -eq 0 ]; then
    echo "Error: No images found in $LOGO_DIR"
    exit 1
fi

# 2. Logic to handle corrupted/missing config
if [ ! -f "$CONFIG_FILE" ]; then
    if [ -f "$BACKUP_FILE" ]; then
        echo "Main config missing! Restoring from backup..."
        cp "$BACKUP_FILE" "$CONFIG_FILE"
    else
        echo "Error: config.jsonc not found and no backup exists."
        exit 1
    fi
fi

# 3. Determine the next index
if [ -f "$STATE_FILE" ]; then
    INDEX=$(cat "$STATE_FILE")
    INDEX=$(( (INDEX + 1) % ${#IMAGES[@]} ))
else
    INDEX=0
fi
echo "$INDEX" > "$STATE_FILE"

SELECTED_PATH="${IMAGES[$INDEX]}"
FILE_NAME=$(basename "$SELECTED_PATH")
EXTENSION="${FILE_NAME##*.}"

# 4. Generate the new Logo Module based on file type
if [[ "$EXTENSION" == "gif" ]]; then
    # GIF: kitty-icat, absolute path, left padding 3
    NEW_LOGO='"logo": {
		"type": "kitty-icat",
		"source": "/home/anustup_dutta/.config/fastfetch/logos/'"$FILE_NAME"'",
		"width": 20,
		"padding": {
			"top": 8,
			"left": 3
		}
	},'
else
    # Others: auto, tilde path, left padding 2
    NEW_LOGO='"logo": {
		"type": "auto",
		"source": "~/.config/fastfetch/logos/'"$FILE_NAME"'",
		"width": 20,
		"padding": {
			"top": 8,
			"left": 2
		}
	},'
fi

# 5. ATOMIC WRITE OPERATION
# Create a backup of the current state before we try anything
cp "$CONFIG_FILE" "$BACKUP_FILE"

# Export logo block for Perl environment
export NEW_LOGO_BLOCK="$NEW_LOGO"

# Perform replacement into a TEMPORARY file first
if perl -0777 -pe 's/"logo": \{.*?\s*\},/$ENV{NEW_LOGO_BLOCK}/s' "$CONFIG_FILE" > "$TEMP_FILE"; then
    # Check if the temporary file is valid (not empty and contains the new path)
    if [[ -s "$TEMP_FILE" && $(grep -c "$FILE_NAME" "$TEMP_FILE") -gt 0 ]]; then
        # Use move (mv) - this is an atomic operation in Linux
        mv "$TEMP_FILE" "$CONFIG_FILE"
        echo "Successfully updated to: $FILE_NAME"
    else
        echo "Error: Generated file was invalid. Aborting update."
        rm -f "$TEMP_FILE"
        exit 1
    fi
else
    echo "Error: Perl processing failed."
    rm -f "$TEMP_FILE"
    exit 1
fi