# CVI (Claude Voice Integration)

Claude Codeのタスク完了時に音声通知を行うシステム

---

## 概要

**CVI**は、Claude Codeの作業を音声でフィードバックするhooksシステムです。

### 特徴

- 🔊 **音声通知**: タスク完了を音声で通知
- ⏸️ **自動中断**: 読み上げ中に新しい指示を出すと自動停止
- 🌐 **多言語対応**: 日本語・英語を自動判定
- 🎯 **カスタマイズ可能**: [VOICE]タグで読み上げ内容を制御

---

## 必要環境

- **OS**: macOS（`say`, `afplay`コマンド使用）
- **Claude Code**: 最新版
- **権限**: スクリプト実行権限

---

## インストール

### 1. スクリプトをコピー

```bash
# スクリプトを配置
cp scripts/notify-end.sh ~/.claude/scripts/
cp scripts/kill-voice.sh ~/.claude/scripts/

# 実行権限を付与
chmod +x ~/.claude/scripts/notify-end.sh
chmod +x ~/.claude/scripts/kill-voice.sh
```

### 2. hooks設定

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

### 3. Claude Codeを再起動

設定を反映させるため、Claude Codeを再起動してください。

---

## 使い方

### 基本的な使い方

1. Claude Codeでタスクを実行
2. タスクが完了すると音声通知
3. 読み上げ中に新しい指示を出すと自動停止

### [VOICE]タグの使用

Claude Codeのレスポンスに`[VOICE]...[/VOICE]`タグを含めると、その部分が読み上げられます：

```markdown
詳細な技術的説明が続く...

[VOICE]ファイルの編集が完了しました。3つのファイルを更新しました。[/VOICE]
```

タグがない場合は、メッセージの最初の200文字が自動的に読み上げられます。

---

## 設定のカスタマイズ

### 音量調整

`notify-end.sh`の以下の行を編集：

```bash
# 音量を変更（0.0〜1.0）
afplay -v 0.6 "$TEMP_AUDIO"  # デフォルト: 0.6（60%）
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

# 別の音に変更
afplay -v 1.0 /System/Library/Sounds/Ping.aiff &
```

---

## トラブルシューティング

### Q: 音声が再生されない

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

### Q: 読み上げが中断されない

**確認事項**:
1. `UserPromptSubmit`フックが設定されているか
2. `kill-voice.sh`に実行権限があるか
3. Claude Codeを再起動したか

### Q: エラーメッセージが表示される

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

## 貢献方法

バグ報告や機能要望は、GitHubのIssuesでお知らせください。

プルリクエストも歓迎します！

---

## ライセンスと免責事項

このソフトウェアは**MITライセンス**の下で提供されています。詳細は[LICENSE](LICENSE)ファイルをご覧ください。

### 免責事項（Disclaimer）

**日本語:**

本ソフトウェアは「現状のまま」で提供され、明示的または黙示的を問わず、いかなる保証もありません。本ソフトウェアの使用によって生じたいかなる損害についても、作者または著作権者は一切の責任を負いません。

**English:**

This software is provided "as is", without warranty of any kind, express or implied. In no event shall the authors or copyright holders be liable for any claim, damages or other liability arising from the use of this software.

---

## 参考

- [Claude Code公式ドキュメント](https://docs.claude.com/en/docs/claude-code)
- [macOS `say`コマンド](https://ss64.com/mac/say.html)
- [Claude Code Hooks](https://docs.claude.com/en/docs/claude-code/hooks)

---

**快適なClaude Codeライフを！** 🚀
