#!/bin/bash

# Play Glass notification sound
afplay -v 1.0 /System/Library/Sounds/Glass.aiff &

# Read message aloud with volume control (60% = 0.6)
TEMP_AUDIO="/tmp/claude_input_$$.aiff"

# Load speech rate from config (default: 200)
CONFIG_FILE="$HOME/.cvi/config"
if [ -f "$CONFIG_FILE" ]; then
    SPEECH_RATE=$(grep "^SPEECH_RATE=" "$CONFIG_FILE" | cut -d'=' -f2)
fi
SPEECH_RATE=${SPEECH_RATE:-200}

# Use system default voice (Siri if configured in System Settings)
MSG="確認をお願いします"
say -r "$SPEECH_RATE" -o "$TEMP_AUDIO" "$MSG"

# Play with 60% volume and cleanup in background
(afplay -v 0.6 "$TEMP_AUDIO" && rm -f "$TEMP_AUDIO") &
