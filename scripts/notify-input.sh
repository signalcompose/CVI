#!/bin/bash

# Play Glass notification sound
afplay -v 1.0 /System/Library/Sounds/Glass.aiff &

# Read message aloud with volume control (60% = 0.6)
TEMP_AUDIO="/tmp/claude_input_$$.aiff"

# Japanese message
MSG="確認をお願いします"
say -v Kyoko -o "$TEMP_AUDIO" "$MSG"

# Play with 60% volume and cleanup in background
(afplay -v 0.6 "$TEMP_AUDIO" && rm -f "$TEMP_AUDIO") &
