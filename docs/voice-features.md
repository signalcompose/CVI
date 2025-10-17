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

#### 簡単セットアップ（推奨）

```bash
# CVIリポジトリから
cd /path/to/CVI

# グローバルインストール（全プロジェクトで有効）
scripts/cvi-setup global

# または、プロジェクトローカル（現在のプロジェクトのみ）
scripts/cvi-setup project
```

これで以下が自動的に実行されます：
- スクリプトのコピーと権限設定
- hooks設定の追加
- 初期設定（速度、言語）
- Siri音声設定の確認

#### 手動セットアップ

詳細は[README.md](../README.md#手動インストール)を参照してください。

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

### 読み上げ速度の変更

**`cvi-speed`コマンド**で簡単に速度を変更できます：

```bash
# 現在の速度を確認
scripts/cvi-speed

# 速度を変更（90-350 wpm）
scripts/cvi-speed 220    # 速め
scripts/cvi-speed 200    # 標準（デフォルト）
scripts/cvi-speed 180    # ゆっくり

# デフォルトに戻す
scripts/cvi-speed reset
```

**推奨速度**:
- **180 wpm**: ゆっくり、聞き取りやすい
- **200 wpm**: 標準速度（デフォルト）
- **220 wpm**: やや速め、効率的

設定は`~/.cvi/config`に保存され、次回のタスク完了時から適用されます。

---

### 音声の変更（Siri音声の使用）

**システム設定でSiri音声を選択**すると、より自然で流暢な読み上げになります：

1. **システム設定** > **アクセシビリティ** > **読み上げコンテンツ**
2. **システムの声**で「Siri (声2)」または「Eloquence」を選択
3. CVIは自動的にシステムデフォルト音声を使用

**確認方法**：
```bash
# システムデフォルト音声でテスト
say "これはテストメッセージです"
```

Siri音声で読み上げられれば、CVIでも同じ音声が使われます。

---

### 言語切り替え

**`cvi-lang`コマンド**で読み上げ言語を切り替えできます：

```bash
# 現在の言語を確認
scripts/cvi-lang

# 言語を変更
scripts/cvi-lang ja    # 日本語
scripts/cvi-lang en    # English

# デフォルトに戻す
scripts/cvi-lang reset
```

**サポート言語**:
- **ja**: 日本語（デフォルト）
- **en**: English

**音声選択**:

言語設定に応じて、自動的に適切な音声が選択されます：

- **日本語（ja）**: システムデフォルト音声（Siri日本語を推奨）
- **英語（en）**: Samantha（macOS標準英語音声）

これにより、システム設定を変更することなく、言語ごとに自然な発音で読み上げられます。

**注意**: [VOICE]タグ内のテキストは言語設定に関わらずそのまま読み上げられます。

---

### セットアップ診断

**`cvi-check`コマンド**でセットアップ状態を診断できます：

```bash
scripts/cvi-check
```

以下の項目をチェック：
- ✅ Siri音声設定
- ✅ スクリプト実行権限
- ✅ hooks設定
- ✅ 読み上げ速度
- ✅ 言語設定

問題が見つかった場合、解決方法を案内します。

---

### 音量調整

`~/.claude/scripts/notify-end.sh`の以下の行を編集：

```bash
# 音声読み上げ音量を変更（0.0〜1.0）
afplay -v 0.6 "$TEMP_AUDIO"  # デフォルト: 0.6（60%）

# 通知音の音量を変更（0.0〜1.0）
afplay -v 1.0 /System/Library/Sounds/Glass.aiff  # デフォルト: 1.0（100%）
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
