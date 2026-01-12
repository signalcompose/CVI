# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## プロジェクト概要

**CVI (Claude Voice Integration)** は、Claude Codeのタスク完了時に音声通知を行うmacOS向けシステム。

- タスク完了を音声で通知（Stop Hook）
- 読み上げ中に新しい指示を出すと自動中断（UserPromptSubmit Hook）
- `[VOICE]...[/VOICE]`タグで読み上げ内容をカスタマイズ
- 日本語・英語の自動判定と音声選択

---

## アーキテクチャ

### Hooks連携フロー

```
┌─────────────────────────────────────────────────────────────┐
│                    Claude Code                               │
└─────────────────────────────────────────────────────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
   UserPromptSubmit      Stop           Notification
         │                 │                 │
         ▼                 ▼                 ▼
   kill-voice.sh    notify-end.sh    notify-input.sh
         │                 │                 │
         ▼                 ▼                 ▼
   killall afplay    say + afplay      say + afplay
```

### 主要スクリプト

| スクリプト | トリガー | 役割 |
|-----------|---------|------|
| `notify-end.sh` | Stop Hook | タスク完了時の音声通知 |
| `notify-input.sh` | Notification Hook | 入力待ち通知 |
| `kill-voice.sh` | UserPromptSubmit Hook | 音声再生の中断 |

### 制御コマンド（`scripts/cvi*`）

| コマンド | 機能 |
|---------|------|
| `cvi` | 音声通知の有効/無効切り替え |
| `cvi-speed` | 読み上げ速度の調整（wpm） |
| `cvi-lang` | 言語切り替え（ja/en） |
| `cvi-voice` | 音声の選択（言語別設定） |
| `cvi-auto` | 言語自動検出の切り替え |
| `cvi-check` | セットアップ診断 |
| `cvi-setup` | 自動セットアップ |

---

## 設定ファイル

### `~/.cvi/config`

```bash
CVI_ENABLED=on          # on/off
SPEECH_RATE=200         # 読み上げ速度（wpm）
VOICE_LANG=ja           # デフォルト言語
VOICE_EN=Samantha       # 英語音声
VOICE_JA=system         # 日本語音声（system=Siri）
AUTO_DETECT_LANG=false  # 言語自動検出
VOICE_MODE=auto         # auto/fixed
```

---

## 開発原則

### Documentation Driven Development (DDD)

1. 仕様書を最初に書く → `docs/`配下
2. 実装
3. テスト（動作確認）
4. ドキュメント更新

---

## Git Workflow

### ブランチ戦略（Git Flow）

- **main**: リリースブランチ
- **develop**: 開発ブランチ（デフォルト）
- **feature/xxx**: 機能ブランチ
- **bugfix/xxx**: バグ修正ブランチ

### 禁止事項

- ❌ main/developへの直接コミット
- ❌ main → developへの逆流マージ
- ❌ Squashマージ

### Commit言語ルール

- **タイトル**: 英語（Conventional Commits）
- **本文**: 日本語

```bash
feat(voice): add volume control

音量調整機能を追加

Closes #123
```

---

## 参考ドキュメント

- **[README.md](README.md)** - インストール・使い方
- **[docs/INDEX.md](docs/INDEX.md)** - ドキュメント索引
- **[docs/voice-features.md](docs/voice-features.md)** - 音声機能の詳細
