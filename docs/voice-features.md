# CVI 音声機能ガイド

## 概要

CVI (Claude Voice Integration) は、Claude Codeのタスク完了時に音声でフィードバックを行うhooksシステムです。

---

## 音声通知機能

### 特徴

- 🔊 **音声通知**: タスク完了を音声で通知
- ⏸️ **自動中断**: 読み上げ中に新しい指示を出すと自動停止
- 🌐 **多言語対応**: 日本語・英語を自動判定
- 🎯 **カスタマイズ可能**: [VOICE]タグで読み上げ内容を制御

### タスク完了通知の仕組み

タスクが完了したときに：
1. macOS通知が表示される
2. 通知音（Glass）が鳴る
3. 完了メッセージが音声で読み上げられる

### [VOICE]タグによるカスタマイズ

Claude Codeは`[VOICE]...[/VOICE]`タグを使って、読み上げ用の簡潔な要約を提供できます。

**ルール**：
- **要約は140文字以内**にまとめる
- 簡潔で分かりやすい日本語を使用
- タスクの完了内容を端的に伝える

**例**：
```markdown
詳細な作業内容の説明...

技術的な詳細が続く...

[VOICE]notify-end.shとCLAUDE.mdの編集が完了しました。フォールバック文字数を200文字に、要約上限を140文字に設定しました。[/VOICE]
```

**動作**：
- `[VOICE]タグ`がある場合：タグ内のテキスト（140文字以内）のみが読み上げられます
- タグがない場合：メッセージの**最初の200文字**が自動的に読み上げられます（フォールバック）

---

## インストール

### 必要環境

- **OS**: macOS（`say`, `afplay`コマンド使用）
- **Claude Code**: 最新版
- **権限**: スクリプト実行権限

### セットアップ手順

#### 1. スクリプトをコピー

```bash
# CVIリポジトリから
cp scripts/notify-end.sh ~/.claude/scripts/
cp scripts/kill-voice.sh ~/.claude/scripts/

# 実行権限を付与
chmod +x ~/.claude/scripts/notify-end.sh
chmod +x ~/.claude/scripts/kill-voice.sh
```

#### 2. hooks設定

`~/.claude/settings.json`を編集（または作成）：

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/scripts/kill-voice.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/scripts/notify-end.sh"
          }
        ]
      }
    ]
  }
}
```

#### 3. Claude Codeを再起動

設定を反映させるため、Claude Codeを再起動してください。

---

## 使い方

### 基本的な使い方

1. Claude Codeでタスクを実行
2. タスクが完了すると音声通知
3. 読み上げ中に新しい指示を出すと自動停止

### Claude Codeでの使用例

**ユーザー**: "README.mdを編集して、インストール手順を追加してください"

**Claude Code**:
```markdown
README.mdにインストール手順を追加しました。以下の内容を記載しました：
- 前提条件
- インストールコマンド
- 初期設定手順

[VOICE]READMEにインストール手順を追加しました[/VOICE]
```

→ 「READMEにインストール手順を追加しました」と読み上げられます

---

## カスタマイズ

### 音量調整

`~/.claude/scripts/notify-end.sh`の以下の行を編集：

```bash
# 音声読み上げ音量を変更（0.0〜1.0）
afplay -v 0.6 "$TEMP_AUDIO"  # デフォルト: 0.6（60%）

# 通知音の音量を変更（0.0〜1.0）
afplay -v 1.0 /System/Library/Sounds/Glass.aiff  # デフォルト: 1.0（100%）
```

### 音声の変更

日本語音声を変更する場合：

```bash
# Kyoko以外の日本語音声を使用
say -v Otoya -o "$TEMP_AUDIO" "$MSG"
```

利用可能な音声を確認：
```bash
say -v '?'
```

### 通知音の変更

Glass音以外を使用する場合：

```bash
# 利用可能な音を確認
ls /System/Library/Sounds/

# 別の音に変更（notify-end.sh内で）
afplay -v 1.0 /System/Library/Sounds/Ping.aiff &
```

---

## トラブルシューティング

### 音声が再生されない

**確認事項**:
1. スクリプトに実行権限があるか確認
   ```bash
   ls -l ~/.claude/scripts/notify-end.sh
   ```
2. hooks設定が正しいか確認
   ```bash
   cat ~/.claude/settings.json
   ```
3. macOSの音量がミュートになっていないか確認

### 読み上げが中断されない

**確認事項**:
1. `UserPromptSubmit`フックが設定されているか
2. `kill-voice.sh`に実行権限があるか
3. Claude Codeを再起動したか

### エラーメッセージが表示される

**デバッグ方法**:
```bash
# スクリプトを直接実行してエラー確認
bash ~/.claude/scripts/notify-end.sh < /dev/null
```

---

## アンインストール

```bash
# スクリプトを削除
rm ~/.claude/scripts/notify-end.sh
rm ~/.claude/scripts/kill-voice.sh

# settings.jsonからhooks設定を削除
# （手動で編集が必要）
```

---

## 技術仕様

### notify-end.shの処理フロー

1. **入力データ取得**: フックからJSON形式のデータを受け取る
2. **トランスクリプト読み込み**: 会話ログから最新のアシスタントメッセージを抽出
3. **メッセージ処理**:
   - `[VOICE]タグ`がある場合：タグ内のテキストを抽出
   - タグがない場合：最初の200文字を使用
4. **通知表示**: macOS通知を表示
5. **音声生成**: `say`コマンドで音声ファイルを生成
6. **再生**: 指定した音量で音声を再生

### kill-voice.shの処理フロー

1. **プロセス検索**: `say`および`afplay`プロセスを検索
2. **プロセス終了**: 該当プロセスを終了（SIGTERM）
3. **一時ファイル削除**: 音声一時ファイルをクリーンアップ

---

## 参考資料

- [CVI README](../README.md) - プロジェクト概要
- [Claude Code公式ドキュメント](https://docs.claude.com/en/docs/claude-code)
- [Claude Code Hooks](https://docs.claude.com/en/docs/claude-code/hooks)
- [macOS `say`コマンド](https://ss64.com/mac/say.html)

---

**最終更新**: 2025-10-17
