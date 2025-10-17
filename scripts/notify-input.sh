#!/bin/bash

# Check if CVI is enabled
CONFIG_FILE="$HOME/.cvi/config"
if [ -f "$CONFIG_FILE" ]; then
    CVI_ENABLED=$(grep "^CVI_ENABLED=" "$CONFIG_FILE" | cut -d'=' -f2)
fi
CVI_ENABLED=${CVI_ENABLED:-on}

# Exit early if disabled
if [ "$CVI_ENABLED" = "off" ]; then
    exit 0
fi

# Play Glass notification sound
afplay -v 1.0 /System/Library/Sounds/Glass.aiff &

# Read message aloud with volume control (60% = 0.6)
TEMP_AUDIO="/tmp/claude_input_$$.aiff"

# Load configuration
CONFIG_FILE="$HOME/.cvi/config"
if [ -f "$CONFIG_FILE" ]; then
    SPEECH_RATE=$(grep "^SPEECH_RATE=" "$CONFIG_FILE" | cut -d'=' -f2)
    VOICE_LANG=$(grep "^VOICE_LANG=" "$CONFIG_FILE" | cut -d'=' -f2)
    VOICE_EN=$(grep "^VOICE_EN=" "$CONFIG_FILE" | cut -d'=' -f2)
fi
SPEECH_RATE=${SPEECH_RATE:-200}
VOICE_LANG=${VOICE_LANG:-ja}
VOICE_EN=${VOICE_EN:-Samantha}

# Set message based on language
if [ "$VOICE_LANG" = "en" ]; then
    MSG="Please confirm"
else
    MSG="確認をお願いします"
fi

# Select voice based on language setting
if [ "$VOICE_LANG" = "en" ]; then
    # Use configured English voice (default: Samantha)
    say -v "$VOICE_EN" -r "$SPEECH_RATE" -o "$TEMP_AUDIO" "$MSG"
else
    # Use system default voice (Siri Japanese if configured in System Settings)
    say -r "$SPEECH_RATE" -o "$TEMP_AUDIO" "$MSG"
fi

# Play with 60% volume and cleanup in background
(afplay -v 0.6 "$TEMP_AUDIO" && rm -f "$TEMP_AUDIO") &
