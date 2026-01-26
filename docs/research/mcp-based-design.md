# CVI MCP サーバー設計案

## 背景・課題

### 現在のhooksベース実装の問題点

1. **設定の不安定さ**
   - セッションごとに設定が忘れられる
   - 言語設定が勝手にリセットされる
   - コンテキスト依存で予測不能な動作

2. **複雑なセットアップ**
   - hooks設定、スクリプト配置、権限設定が必要
   - トラブルシューティングが困難

3. **プラットフォーム依存**
   - シェルスクリプトベースでmacOS固有コマンドに依存
   - クロスプラットフォーム対応が大変

---

## 提案: MCP サーバーとして再実装

### MCPサーバーのメリット

| 観点 | hooks方式 | MCP方式 |
|------|-----------|---------|
| 設定管理 | ファイル + コンテキスト依存 | サーバー側で永続管理 |
| 安定性 | セッションで不安定 | 常駐プロセスで安定 |
| セットアップ | 複雑（hooks + scripts） | `npx cvi-mcp` で起動 |
| クロスプラットフォーム | シェルスクリプト依存 | Node.js/Rustで統一 |
| 拡張性 | 限定的 | ツール追加が容易 |

---

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────┐
│                    Claude Code                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │  MCP Client                                       │  │
│  │  - ツール呼び出し: cvi_speak, cvi_listen         │  │
│  │  - リソース参照: cvi://settings                  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                           │
                           │ stdio / HTTP
                           ▼
┌─────────────────────────────────────────────────────────┐
│                  CVI MCP Server                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Settings Manager (永続化)                        │  │
│  │  - voice, language, rate, enabled                │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │  TTS Engine                                       │  │
│  │  - macOS: say                                    │  │
│  │  - Linux/Windows: Piper TTS                      │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │  STT Engine (Whisper.cpp)                         │  │
│  │  - 音声入力 → テキスト変換                       │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## MCP ツール定義

### 1. cvi_speak - テキスト読み上げ

```typescript
{
  name: "cvi_speak",
  description: "テキストを音声で読み上げる",
  inputSchema: {
    type: "object",
    properties: {
      text: {
        type: "string",
        description: "読み上げるテキスト"
      },
      voice: {
        type: "string",
        description: "音声名（省略時はデフォルト）"
      },
      rate: {
        type: "number",
        description: "読み上げ速度（0.5-2.0）"
      },
      wait: {
        type: "boolean",
        description: "読み上げ完了を待つか（デフォルト: false）"
      }
    },
    required: ["text"]
  }
}
```

### 2. cvi_listen - 音声入力（Whisper.cpp）

```typescript
{
  name: "cvi_listen",
  description: "マイクから音声を録音し、テキストに変換する",
  inputSchema: {
    type: "object",
    properties: {
      duration: {
        type: "number",
        description: "録音時間（秒）。省略時はVADで自動検出"
      },
      language: {
        type: "string",
        description: "言語コード（ja, en等）"
      }
    }
  }
}
```

### 3. cvi_stop - 読み上げ停止

```typescript
{
  name: "cvi_stop",
  description: "現在の読み上げを停止する",
  inputSchema: {
    type: "object",
    properties: {}
  }
}
```

### 4. cvi_configure - 設定変更

```typescript
{
  name: "cvi_configure",
  description: "CVIの設定を変更する",
  inputSchema: {
    type: "object",
    properties: {
      enabled: { type: "boolean" },
      voice_ja: { type: "string" },
      voice_en: { type: "string" },
      rate: { type: "number" },
      auto_detect_language: { type: "boolean" },
      notification_sound: { type: "boolean" }
    }
  }
}
```

### 5. cvi_list_voices - 利用可能な音声一覧

```typescript
{
  name: "cvi_list_voices",
  description: "利用可能な音声の一覧を取得する",
  inputSchema: {
    type: "object",
    properties: {
      language: {
        type: "string",
        description: "フィルタする言語（ja, en等）"
      }
    }
  }
}
```

---

## MCP リソース定義

### cvi://settings - 現在の設定

```typescript
{
  uri: "cvi://settings",
  name: "CVI Settings",
  mimeType: "application/json",
  description: "現在のCVI設定"
}

// 返却例
{
  "enabled": true,
  "voice_ja": "ja_JP-takumi-medium",
  "voice_en": "en_US-lessac-medium",
  "rate": 1.0,
  "auto_detect_language": true,
  "notification_sound": true,
  "platform": "linux",
  "tts_engine": "piper"
}
```

### cvi://voices - 利用可能な音声

```typescript
{
  uri: "cvi://voices",
  name: "Available Voices",
  mimeType: "application/json"
}
```

---

## 技術スタック選択

### Option A: Node.js + TypeScript

```
cvi-mcp/
├── src/
│   ├── index.ts          # MCPサーバーエントリポイント
│   ├── tools/
│   │   ├── speak.ts      # TTS実装
│   │   ├── listen.ts     # STT実装（Whisper.cpp bindings）
│   │   └── configure.ts  # 設定管理
│   ├── engines/
│   │   ├── tts/
│   │   │   ├── macos.ts  # say コマンド
│   │   │   ├── piper.ts  # Piper TTS
│   │   │   └── index.ts  # 自動選択
│   │   └── stt/
│   │       └── whisper.ts # Whisper.cpp
│   └── config/
│       └── settings.ts   # 永続化設定
├── package.json
└── tsconfig.json
```

**メリット**: MCP SDKが公式、開発が速い
**デメリット**: Whisper.cppのbindingsが必要

### Option B: Rust

```
cvi-mcp/
├── src/
│   ├── main.rs
│   ├── tools/
│   ├── engines/
│   └── config/
├── Cargo.toml
└── whisper-rs (依存)
```

**メリット**: Whisper.cppと相性良好、高速、シングルバイナリ
**デメリット**: 開発コストが高い

### 推奨: Node.js + whisper-node

Node.jsで開発し、Whisper.cppはネイティブbindingsを使用。

---

## 実装詳細

### TTS エンジン抽象化

```typescript
// src/engines/tts/index.ts
interface TTSEngine {
  speak(text: string, options: SpeakOptions): Promise<void>;
  stop(): Promise<void>;
  listVoices(): Promise<Voice[]>;
}

// OS自動検出
function createTTSEngine(): TTSEngine {
  switch (process.platform) {
    case 'darwin':
      return new MacOSTTS();
    case 'linux':
    case 'win32':
      return new PiperTTS();
    default:
      throw new Error(`Unsupported platform: ${process.platform}`);
  }
}
```

### macOS TTS実装

```typescript
// src/engines/tts/macos.ts
import { exec } from 'child_process';

class MacOSTTS implements TTSEngine {
  private currentProcess: ChildProcess | null = null;

  async speak(text: string, options: SpeakOptions): Promise<void> {
    const args = ['-r', String(options.rate * 200)];
    if (options.voice) {
      args.push('-v', options.voice);
    }

    return new Promise((resolve, reject) => {
      this.currentProcess = exec(
        `say ${args.join(' ')} "${text.replace(/"/g, '\\"')}"`,
        (error) => {
          this.currentProcess = null;
          if (error) reject(error);
          else resolve();
        }
      );
    });
  }

  async stop(): Promise<void> {
    if (this.currentProcess) {
      this.currentProcess.kill();
    }
    exec('killall say 2>/dev/null');
  }

  async listVoices(): Promise<Voice[]> {
    return new Promise((resolve, reject) => {
      exec('say -v "?"', (error, stdout) => {
        if (error) reject(error);
        const voices = stdout.split('\n')
          .filter(line => line.trim())
          .map(line => {
            const [name, locale] = line.split(/\s+/);
            return { name, locale };
          });
        resolve(voices);
      });
    });
  }
}
```

### Piper TTS実装

```typescript
// src/engines/tts/piper.ts
import { spawn } from 'child_process';
import path from 'path';

class PiperTTS implements TTSEngine {
  private piperPath: string;
  private modelsPath: string;

  async speak(text: string, options: SpeakOptions): Promise<void> {
    const model = options.voice || 'ja_JP-takumi-medium';
    const modelPath = path.join(this.modelsPath, `${model}.onnx`);

    return new Promise((resolve, reject) => {
      const piper = spawn(this.piperPath, [
        '--model', modelPath,
        '--output-raw'
      ]);

      const aplay = spawn('aplay', ['-r', '22050', '-f', 'S16_LE', '-t', 'raw']);

      piper.stdout.pipe(aplay.stdin);
      piper.stdin.write(text);
      piper.stdin.end();

      aplay.on('close', () => resolve());
      aplay.on('error', reject);
    });
  }
}
```

### Whisper.cpp STT実装

```typescript
// src/engines/stt/whisper.ts
import { Whisper } from 'whisper-node';  // or custom bindings

class WhisperSTT {
  private whisper: Whisper;

  constructor(modelPath: string) {
    this.whisper = new Whisper(modelPath);
  }

  async listen(options: ListenOptions): Promise<string> {
    // 1. 録音
    const audioBuffer = await this.record(options.duration);

    // 2. 文字起こし
    const result = await this.whisper.transcribe(audioBuffer, {
      language: options.language || 'ja'
    });

    return result.text;
  }

  private async record(duration?: number): Promise<Buffer> {
    // sox または node-record-lpcm16 を使用
    // VADを使う場合はduration省略
  }
}
```

### 設定の永続化

```typescript
// src/config/settings.ts
import fs from 'fs';
import path from 'path';
import os from 'os';

const CONFIG_PATH = path.join(os.homedir(), '.cvi', 'mcp-settings.json');

interface Settings {
  enabled: boolean;
  voice_ja: string;
  voice_en: string;
  rate: number;
  auto_detect_language: boolean;
  notification_sound: boolean;
}

const DEFAULT_SETTINGS: Settings = {
  enabled: true,
  voice_ja: 'Kyoko',  // macOS
  voice_en: 'Samantha',
  rate: 1.0,
  auto_detect_language: true,
  notification_sound: true
};

class SettingsManager {
  private settings: Settings;

  constructor() {
    this.settings = this.load();
  }

  private load(): Settings {
    try {
      const data = fs.readFileSync(CONFIG_PATH, 'utf-8');
      return { ...DEFAULT_SETTINGS, ...JSON.parse(data) };
    } catch {
      return DEFAULT_SETTINGS;
    }
  }

  save(): void {
    const dir = path.dirname(CONFIG_PATH);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(CONFIG_PATH, JSON.stringify(this.settings, null, 2));
  }

  get<K extends keyof Settings>(key: K): Settings[K] {
    return this.settings[key];
  }

  set<K extends keyof Settings>(key: K, value: Settings[K]): void {
    this.settings[key] = value;
    this.save();  // 自動永続化
  }
}
```

---

## Claude Code 設定

### ~/.claude/settings.json

```json
{
  "mcpServers": {
    "cvi": {
      "command": "npx",
      "args": ["-y", "cvi-mcp"],
      "env": {
        "CVI_WHISPER_MODEL": "base",
        "CVI_PIPER_VOICE": "ja_JP-takumi-medium"
      }
    }
  }
}
```

または、ローカル開発時：

```json
{
  "mcpServers": {
    "cvi": {
      "command": "node",
      "args": ["/path/to/cvi-mcp/dist/index.js"]
    }
  }
}
```

---

## 使用例（Claude Code内）

### 基本的な読み上げ

```
User: このコードをレビューして

Claude: [コードレビュー結果...]

// Claudeが自動的にcvi_speakを呼び出し
// または明示的に: 「レビュー完了しました」を読み上げて
```

### 音声入力

```
User: 音声で指示を出したい

Claude: cvi_listenを呼び出します...

[ユーザーが話す]

Claude: 「〇〇を実装して」と聞こえました。実装を開始します。
```

### 設定変更

```
User: 読み上げ速度を速くして

Claude: cvi_configureで速度を1.5に設定しました。
        この設定は永続化されます。
```

---

## hooksとの比較

| 機能 | hooks方式 | MCP方式 |
|------|-----------|---------|
| Stop時の読み上げ | 自動 | Claudeが判断して呼び出し |
| 設定変更 | /cvi:speedなど | cvi_configureツール |
| 音声入力 | 未対応 | cvi_listenツール |
| 設定永続化 | ~/.cvi/config（不安定） | MCPサーバー管理（安定） |

### 補足: 自動読み上げ

MCPでは「タスク完了時に自動で読み上げ」は直接サポートされません。
しかし、以下の方法で対応可能：

1. **Claudeへの指示**: System promptで「タスク完了時はcvi_speakを呼び出す」と指示
2. **hooks併用**: Stop hookでMCPツールを呼び出す（ハイブリッド）

```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "curl -X POST http://localhost:3000/speak -d '{\"text\":\"完了\"}'"
      }]
    }]
  }
}
```

---

## 実装フェーズ

### Phase 1: 基本MCPサーバー

- [ ] プロジェクトセットアップ（Node.js + TypeScript）
- [ ] cvi_speak ツール（macOS対応）
- [ ] cvi_stop ツール
- [ ] cvi_configure ツール
- [ ] 設定永続化

### Phase 2: クロスプラットフォームTTS

- [ ] Piper TTS統合
- [ ] OS自動検出
- [ ] モデル自動ダウンロード

### Phase 3: Whisper.cpp統合

- [ ] whisper-node または独自bindings
- [ ] cvi_listen ツール
- [ ] VAD（Voice Activity Detection）

### Phase 4: 配布

- [ ] npm publish
- [ ] GitHub Releases（バイナリ）
- [ ] ドキュメント整備

---

## まとめ

### MCP方式のメリット

1. **設定が安定** - サーバー側で永続管理
2. **クロスプラットフォーム** - Node.js/Rustで統一実装
3. **拡張性** - 新しいツールを簡単に追加
4. **音声入力対応** - Whisper.cppを自然に統合
5. **セットアップ簡単** - `npx cvi-mcp` で起動

### 考慮点

1. **自動読み上げ** - hooksとの併用またはClaude指示が必要
2. **初期開発コスト** - 新規実装が必要
3. **依存関係** - Whisper.cpp、Piperのバイナリ管理

### 結論

MCPベースの実装は、現在のhooks方式の問題（設定忘れ、不安定さ）を根本的に解決できます。
特にWhisper.cppによる音声入力は、MCPツールとして自然にフィットします。
