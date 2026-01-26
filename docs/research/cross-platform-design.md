# CVI クロスプラットフォーム設計案

## 概要

現在のCVIはmacOS専用（`say`, `afplay`, `osascript`依存）ですが、
**Whisper.cpp + Piper TTS** を活用してクロスプラットフォーム対応を実現する設計案です。

---

## 技術スタック

### 音声認識（STT）: Whisper.cpp

- **用途**: 音声入力でClaudeに指示を出す（新機能）
- **特徴**:
  - C/C++実装、高速・軽量
  - オフライン動作（プライバシー重視）
  - GPU加速対応（CUDA, Metal, Vulkan, OpenVINO）
  - WebAssemblyでブラウザ動作も可能
- **対応OS**: macOS, Linux, Windows, Raspberry Pi
- **リポジトリ**: https://github.com/ggml-org/whisper.cpp

### 音声合成（TTS）: Piper TTS

- **用途**: 現在の`say`コマンドの代替
- **特徴**:
  - ニューラルTTS（VITS + ONNX）
  - 高品質な音声出力
  - オフライン動作
  - 軽量（Raspberry Pi 4でも動作）
  - 多言語対応（日本語含む）
- **対応OS**: macOS, Linux, Windows (WSL)
- **リポジトリ**: https://github.com/rhasspy/piper

### 音声再生: mpv / ffplay

- **用途**: 現在の`afplay`コマンドの代替
- **候補**:
  | ツール | メリット | デメリット |
  |--------|----------|------------|
  | mpv | 軽量、クロスプラットフォーム | インストール必要 |
  | ffplay | FFmpegに付属 | UIが出る |
  | paplay | PulseAudio標準 | Linux限定 |
  | aplay | ALSA標準 | Linux限定 |

### 通知システム

| OS | ツール | コマンド例 |
|----|--------|-----------|
| macOS | osascript | `osascript -e 'display notification...'` |
| Linux | notify-send | `notify-send "CVI" "タスク完了"` |
| Windows | PowerShell | `[Windows.UI.Notifications.ToastNotificationManager]...` |

---

## アーキテクチャ設計

### 現在のアーキテクチャ（macOS固定）

```
┌─────────────────────────────────────┐
│     Claude Code Hooks               │
├─────────────────────────────────────┤
│     notify-end.sh / notify-input.sh │
├─────────────────────────────────────┤
│     macOS: say + afplay + osascript │
└─────────────────────────────────────┘
```

### 提案アーキテクチャ（クロスプラットフォーム）

```
┌─────────────────────────────────────────────────────┐
│           Claude Code Hooks                          │
├─────────────────────────────────────────────────────┤
│           notify-end.sh / notify-input.sh            │
├─────────────────────────────────────────────────────┤
│           Abstraction Layer (cvi-engine)             │
│  ┌─────────────────────────────────────────────────┐ │
│  │  cvi_speak()  │  cvi_play()  │  cvi_notify()    │ │
│  └─────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────┤
│  macOS Backend    │  Linux Backend  │  Win Backend  │
│  ┌─────────────┐  │  ┌───────────┐  │  ┌─────────┐  │
│  │ say/afplay  │  │  │ piper/mpv │  │  │ piper   │  │
│  │ osascript   │  │  │ notify-   │  │  │ mpv     │  │
│  │             │  │  │ send      │  │  │ toast   │  │
│  └─────────────┘  │  └───────────┘  │  └─────────┘  │
└─────────────────────────────────────────────────────┘
```

---

## ディレクトリ構造（提案）

```
CVI/
├── scripts/
│   ├── engine/                    # NEW: 抽象化レイヤー
│   │   ├── cvi-engine.sh          # メインエントリポイント
│   │   ├── backend-macos.sh       # macOSバックエンド
│   │   ├── backend-linux.sh       # Linuxバックエンド
│   │   └── backend-windows.sh     # Windowsバックエンド（WSL）
│   ├── voice-input/               # NEW: Whisper.cpp統合
│   │   ├── listen.sh              # 音声入力開始
│   │   └── transcribe.sh          # 文字起こし
│   ├── notify-end.sh              # 既存（エンジン経由に変更）
│   ├── notify-input.sh            # 既存（エンジン経由に変更）
│   └── kill-voice.sh              # 既存（エンジン経由に変更）
├── bin/                           # NEW: バイナリ配置
│   ├── whisper-cpp/               # Whisper.cppバイナリ
│   └── piper/                     # Piperバイナリ
├── models/                        # NEW: モデルファイル
│   ├── whisper/                   # Whisperモデル
│   │   └── ggml-base.bin
│   └── piper/                     # Piper音声モデル
│       ├── ja_JP-takumi-medium.onnx
│       └── en_US-lessac-medium.onnx
└── ...
```

---

## 抽象化レイヤー実装案

### cvi-engine.sh

```bash
#!/bin/bash
# CVI Engine - Cross-platform abstraction layer

CVI_ROOT="$(dirname "$(realpath "$0")")/.."

# OS検出
detect_os() {
    case "$OSTYPE" in
        darwin*)  echo "macos" ;;
        linux*)   echo "linux" ;;
        msys*|cygwin*|mingw*) echo "windows" ;;
        *)        echo "unknown" ;;
    esac
}

# バックエンド読み込み
OS_TYPE=$(detect_os)
source "$CVI_ROOT/scripts/engine/backend-${OS_TYPE}.sh" 2>/dev/null || {
    echo "Unsupported OS: $OSTYPE"
    exit 1
}

# 共通インターフェース
# - cvi_speak "text" [voice] [rate]
# - cvi_play "audio_file" [volume]
# - cvi_notify "title" "message"
# - cvi_kill_audio
# - cvi_list_voices
```

### backend-macos.sh

```bash
#!/bin/bash
# macOS Backend - 既存の実装を維持

cvi_speak() {
    local text="$1"
    local voice="${2:-}"
    local rate="${3:-200}"

    if [[ -n "$voice" ]]; then
        say -v "$voice" -r "$rate" "$text"
    else
        say -r "$rate" "$text"
    fi
}

cvi_play() {
    local file="$1"
    local volume="${2:-0.6}"
    afplay -v "$volume" "$file"
}

cvi_notify() {
    local title="$1"
    local message="$2"
    osascript -e "display notification \"$message\" with title \"$title\""
}

cvi_kill_audio() {
    killall afplay 2>/dev/null
    killall say 2>/dev/null
}

cvi_list_voices() {
    say -v '?' | awk '{print $1}'
}
```

### backend-linux.sh

```bash
#!/bin/bash
# Linux Backend - Piper TTS + mpv

PIPER_BIN="${CVI_ROOT}/bin/piper/piper"
PIPER_MODELS="${CVI_ROOT}/models/piper"

cvi_speak() {
    local text="$1"
    local voice="${2:-ja_JP-takumi-medium}"
    local rate="${3:-1.0}"  # Piperは倍率

    local model="${PIPER_MODELS}/${voice}.onnx"
    local json="${PIPER_MODELS}/${voice}.onnx.json"

    if [[ -f "$model" ]]; then
        echo "$text" | "$PIPER_BIN" \
            --model "$model" \
            --config "$json" \
            --length_scale "$rate" \
            --output-raw | \
            aplay -r 22050 -f S16_LE -t raw -
    else
        # フォールバック: espeak-ng
        espeak-ng -v ja "$text"
    fi
}

cvi_play() {
    local file="$1"
    local volume="${2:-60}"  # 0-100

    if command -v mpv &>/dev/null; then
        mpv --no-video --volume="$volume" "$file"
    elif command -v paplay &>/dev/null; then
        paplay "$file"
    elif command -v aplay &>/dev/null; then
        aplay "$file"
    fi
}

cvi_notify() {
    local title="$1"
    local message="$2"

    if command -v notify-send &>/dev/null; then
        notify-send "$title" "$message"
    fi
}

cvi_kill_audio() {
    pkill -f piper 2>/dev/null
    pkill -f mpv 2>/dev/null
    pkill -f aplay 2>/dev/null
    pkill -f espeak 2>/dev/null
}

cvi_list_voices() {
    ls -1 "${PIPER_MODELS}"/*.onnx 2>/dev/null | \
        xargs -I{} basename {} .onnx
}
```

---

## Whisper.cpp統合（音声入力機能）

### 新機能: 音声でClaudeに指示

```bash
# 音声入力開始
cvi voice-input

# 動作フロー:
# 1. マイクから音声を録音（VAD付き）
# 2. Whisper.cppで文字起こし
# 3. Claude Codeに入力として送信
```

### voice-input/listen.sh

```bash
#!/bin/bash
# Whisper.cpp音声入力

WHISPER_BIN="${CVI_ROOT}/bin/whisper-cpp/main"
WHISPER_MODEL="${CVI_ROOT}/models/whisper/ggml-base.bin"

# 録音 + 文字起こし
record_and_transcribe() {
    local duration="${1:-5}"  # デフォルト5秒
    local temp_audio="/tmp/cvi_voice_input.wav"

    # 録音（sox使用）
    if command -v rec &>/dev/null; then
        rec -r 16000 -c 1 -b 16 "$temp_audio" trim 0 "$duration"
    elif command -v arecord &>/dev/null; then
        arecord -f S16_LE -r 16000 -c 1 -d "$duration" "$temp_audio"
    fi

    # Whisper.cppで文字起こし
    "$WHISPER_BIN" \
        -m "$WHISPER_MODEL" \
        -f "$temp_audio" \
        -l ja \
        --no-timestamps \
        2>/dev/null

    rm -f "$temp_audio"
}
```

---

## 設定ファイル拡張

### ~/.cvi/config（拡張版）

```ini
# 基本設定
CVI_ENABLED=on
SPEECH_RATE=200

# TTS設定
TTS_ENGINE=auto          # auto | macos | piper | espeak
TTS_VOICE_JA=ja_JP-takumi-medium
TTS_VOICE_EN=en_US-lessac-medium

# STT設定（Whisper.cpp）
STT_ENABLED=off
STT_MODEL=base           # tiny | base | small | medium
STT_LANGUAGE=ja

# プラットフォーム設定
AUDIO_PLAYER=auto        # auto | mpv | ffplay | afplay
NOTIFICATION_ENABLED=on
```

---

## 実装フェーズ

### Phase 1: 抽象化レイヤー

1. `cvi-engine.sh`の作成
2. macOSバックエンドの分離
3. 既存スクリプトのエンジン経由化
4. sed互換性対応

### Phase 2: Linuxサポート

1. Piper TTSの統合
2. mpv/aplayの統合
3. notify-sendの統合
4. Linuxでの動作確認

### Phase 3: Whisper.cpp統合

1. 音声入力機能の実装
2. VAD（Voice Activity Detection）統合
3. Claude Codeとの連携

### Phase 4: Windows対応（オプション）

1. WSL経由でのLinuxバックエンド利用
2. ネイティブPowerShellバックエンド（将来）

---

## 依存関係インストール

### Linux（Debian/Ubuntu）

```bash
# Piper TTS
pip install piper-tts

# 音声再生
sudo apt install mpv

# 通知
sudo apt install libnotify-bin

# 録音（Whisper用）
sudo apt install sox

# Whisper.cpp（ビルド）
git clone https://github.com/ggml-org/whisper.cpp
cd whisper.cpp && make
```

### macOS（既存環境）

```bash
# 追加インストール不要（say, afplayは標準）

# Whisper.cpp（オプション）
brew install whisper-cpp
```

---

## まとめ

| 機能 | macOS | Linux | Windows |
|------|-------|-------|---------|
| TTS（音声合成） | say | Piper TTS | Piper (WSL) |
| 音声再生 | afplay | mpv/aplay | mpv (WSL) |
| 通知 | osascript | notify-send | PowerShell |
| STT（音声認識） | Whisper.cpp | Whisper.cpp | Whisper.cpp |

**メリット**:
- オフライン動作（プライバシー重視）
- 高品質な音声（ニューラルTTS）
- 既存のmacOS動作を維持しつつ拡張

**デメリット**:
- 初期セットアップが複雑
- モデルファイルのダウンロードが必要（数百MB）

---

## 参考リンク

- [Whisper.cpp](https://github.com/ggml-org/whisper.cpp) - 音声認識
- [Piper TTS](https://github.com/rhasspy/piper) - 音声合成
- [Piper Voices](https://huggingface.co/rhasspy/piper-voices) - 音声モデル
