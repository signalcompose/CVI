#!/bin/bash

# Read hook input from stdin
INPUT=$(cat)

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

# Get current session directory name
SESSION_DIR=$(basename "$(pwd)")

# Extract transcript path
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path')

# If transcript path exists, extract latest assistant message
if [ -f "$TRANSCRIPT_PATH" ]; then
    FULL_MSG=$(tail -10 "$TRANSCRIPT_PATH" | \
               jq -r 'select(.message.role == "assistant") | .message.content[0].text' | \
               tail -1)

    # Check for [VOICE]...[/VOICE] tag
    if echo "$FULL_MSG" | grep -q '\[VOICE\]'; then
        # Extract text between [VOICE] tags
        MSG=$(echo "$FULL_MSG" | sed -n 's/.*\[VOICE\]\(.*\)\[\/VOICE\].*/\1/p' | head -1)
    else
        # Fallback to first 200 characters
        MSG=$(echo "$FULL_MSG" | tr '\n' ' ' | cut -c1-200)
    fi

    # Fallback message if no message found (language-aware)
    if [ -z "$MSG" ]; then
        # Load language setting
        VOICE_LANG=$(grep "^VOICE_LANG=" "$HOME/.cvi/config" 2>/dev/null | cut -d'=' -f2)
        VOICE_LANG=${VOICE_LANG:-ja}
        if [ "$VOICE_LANG" = "en" ]; then
            MSG="Task completed"
        else
            MSG="タスクが完了しました"
        fi
    fi
else
    # Load language setting
    VOICE_LANG=$(grep "^VOICE_LANG=" "$HOME/.cvi/config" 2>/dev/null | cut -d'=' -f2)
    VOICE_LANG=${VOICE_LANG:-ja}
    if [ "$VOICE_LANG" = "en" ]; then
        MSG="Task completed"
    else
        MSG="タスクが完了しました"
    fi
fi

# Display macOS notification
osascript -e "display notification \"$MSG\" with title \"ClaudeCode ($SESSION_DIR) Task Done\""

# Play Glass sound at full volume
afplay -v 1.0 /System/Library/Sounds/Glass.aiff &

# Read message aloud with volume control (60% = 0.6)
TEMP_AUDIO="/tmp/claude_notify_$$.aiff"

# Load speech rate from config (default: 200)
CONFIG_FILE="$HOME/.cvi/config"
if [ -f "$CONFIG_FILE" ]; then
    SPEECH_RATE=$(grep "^SPEECH_RATE=" "$CONFIG_FILE" | cut -d'=' -f2)
fi
SPEECH_RATE=${SPEECH_RATE:-200}

# Use system default voice (Siri if configured in System Settings)
say -r "$SPEECH_RATE" -o "$TEMP_AUDIO" "$MSG"

# === 完全に独立したバックグラウンド実行 ===
# 音声再生とクリーンアップを独立したプロセスとして実行
# スクリプト本体は即座に終了し、Claude Codeをブロックしない
(afplay -v 0.6 "$TEMP_AUDIO" && rm -f "$TEMP_AUDIO") &
