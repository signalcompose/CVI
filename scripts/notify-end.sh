#!/bin/bash

# Read hook input from stdin
INPUT=$(cat)

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

    # Fallback message if no message found
    MSG=${MSG:-"Task completed"}
else
    MSG="Task completed"
fi

# Display macOS notification
osascript -e "display notification \"$MSG\" with title \"ClaudeCode ($SESSION_DIR) Task Done\""

# Play Glass sound at full volume
afplay -v 1.0 /System/Library/Sounds/Glass.aiff &

# Read message aloud with volume control (60% = 0.6)
TEMP_AUDIO="/tmp/claude_notify_$$.aiff"

if echo "$MSG" | grep -q '[ぁ-んァ-ヶ一-龥]'; then
    # Japanese message - use Kyoko voice
    say -v Kyoko -o "$TEMP_AUDIO" "$MSG"
else
    # English message - use default voice
    say -o "$TEMP_AUDIO" "$MSG"
fi

# === 完全に独立したバックグラウンド実行 ===
# 音声再生とクリーンアップを独立したプロセスとして実行
# スクリプト本体は即座に終了し、Claude Codeをブロックしない
(afplay -v 0.6 "$TEMP_AUDIO" && rm -f "$TEMP_AUDIO") &
