# Fit 詳細設計書

対象バージョン: v0.1（初回リリース）
最終更新: 2026-07-12

## 1. 目的・背景

Magnet 相当のウィンドウスナップ機能を、**App Store・Homebrew が使えない環境でも Xcode だけでビルドして使える** OSS として提供する。

設計上の最優先事項（優先順）:

1. **ビルドの容易さ** — Xcode を開いて ⌘R だけで動く。アカウント不要、外部依存ゼロ、ネットワーク不要。
2. **監査の容易さ** — コード量を最小限に保ち、ネットワーク・ファイル書き込み等の副作用を持たない。
3. **Magnet からの移行コストゼロ** — デフォルトショートカットとドラッグ挙動を Magnet 互換にする。

## 2. 要求仕様

### 2.1 機能要件

| ID | 要件 |
|---|---|
| F1 | ショートカットでフォーカス中のウィンドウを、半分（左右上下）・1/4（四隅）・1/3（左中右）・2/3（左右）・最大化・中央寄せに配置できる |
| F2 | スナップ前のウィンドウ位置・サイズを記憶し、ショートカットで復元できる |
| F3 | ウィンドウを隣のディスプレイ（前/次）へ移動できる（相対位置・サイズを維持） |
| F4 | ウィンドウをドラッグして画面端に触れると配置プレビューを表示し、離すとスナップする |
| F5 | ショートカットは GUI で変更・削除・初期化できる |
| F6 | スナップ後のウィンドウ間に任意のギャップ（0〜32px）を設定できる |
| F7 | メニューバーからすべてのスナップ操作・設定・終了ができる |
| F8 | ログイン時の自動起動を設定できる |
| F9 | アクセシビリティ権限が未許可のとき、許可手順を案内するオンボーディングを表示する |
| F10 | 半分のショートカットを連打するとサイズを ½ → ⅔ → ⅓ で循環できる（左右・上下すべて対応、設定でオフ可） |
| F11 | 指定修飾キー（既定 ⇧、変更/オフ可）を押しながらのドラッグ中はエッジスナップを無効化する |
| F12 | 直前が半分スナップだったとき、直交する半分のショートカットで対応する角の 1/4 にスナップする（設定でオフ可） |

### 2.2 非機能要件

| ID | 要件 |
|---|---|
| N1 | 外部依存ライブラリなし（Apple のシステムフレームワークのみ） |
| N2 | ネットワークアクセスを行うコードを含まない |
| N3 | 要求する TCC 権限はアクセシビリティのみ（画面収録・入力監視は不要） |
| N4 | macOS 13 Ventura 以降、Xcode 16 以降でビルド可能 |
| N5 | 署名は「Sign to Run Locally」（アドホック）で完結する |
| N6 | 座標計算・ゾーン判定は AppKit 非依存の純粋関数とし、`swift test` で検証できる |

### 2.3 非目標（v0.1 ではやらない）

- タイル型 WM（yabai 的な自動レイアウト）
- 6分割
- スナップゾーンのカスタマイズ、アプリごとの除外リスト
- 自動アップデート（配布は git pull + 再ビルド）

## 3. 全体アーキテクチャ

```
                        ┌───────────────────────────┐
                        │        AppDelegate         │  起動・配線・権限ゲート
                        └─┬─────┬─────────┬─────┬───┘
              ┌───────────┘     │         │     └────────────┐
              ▼                 ▼         ▼                  ▼
   StatusItemController   HotkeyCenter  DragSnapMonitor   Permission
   （メニューバー）        （Carbon）    （NSEventモニタ）   Onboarding
              │                 │         │  └─ SnapOverlay │
              │                 │         │     （プレビュー）│
              └────────┬────────┴────┬────┘                 │
                       ▼             │                      │
                  SnapExecutor ◀─────┘        SettingsWindow(SwiftUI)
                  （実行の中枢）                     │
                       │                            ▼
        ┌──────────────┼──────────────┐       SettingsStore ──▶ UserDefaults
        ▼              ▼              ▼          （全コンポーネントが購読）
   WindowFinder    AXWindow      ScreenGeometry
   （対象特定）   （AXラッパー）  （座標変換）
                       │
                       ▼
              ┌─────────────────┐
              │  Core（純粋層）   │  LayoutCalculator / EdgeZone /
              │  AppKit 非依存    │  SnapAction / Shortcut
              └─────────────────┘
```

### 3.1 レイヤ構成と依存方向

| レイヤ | ディレクトリ | 依存 | 役割 |
|---|---|---|---|
| Core | `Fit/Core/` | Foundation, CoreGraphics のみ | スナップ矩形計算、ドラッグゾーン判定、モデル型。**AppKit 禁止** |
| Windowing | `Fit/Windowing/` | AppKit, ApplicationServices | AX API ラッパー、座標系変換、スナップ実行 |
| Input | `Fit/Input/` | AppKit, Carbon | グローバルホットキー、ドラッグ監視 |
| UI | `Fit/UI/` | AppKit, SwiftUI | 設定画面、オンボーディング、プレビューオーバーレイ |
| Support | `Fit/Support/` | Foundation, ServiceManagement | 設定永続化、ログイン項目 |
| App | `Fit/App/` | 全部 | エントリポイント、配線 |

依存は上から下への一方向。Core は他レイヤに依存しない。

Core は Xcode ターゲットに直接コンパイルされると同時に、リポジトリ直下の `Package.swift` から `FitCore` モジュールとしても参照される。これにより `swift test` だけでコアロジックのユニットテストが回る（Xcode プロジェクトのテストターゲント不要）。

### 3.2 技術選定の根拠

| 選定 | 代替案 | 理由 |
|---|---|---|
| ウィンドウ操作: **Accessibility API**（`AXUIElement`） | CGWindow（読み取り専用）、Apple Event | 他アプリのウィンドウを move/resize できる唯一の公開 API。Magnet / Rectangle と同方式 |
| ホットキー: **Carbon `RegisterEventHotKey`** | `NSEvent.addGlobalMonitor`（イベントを消費できない）、CGEventTap（過剰） | キーイベントを消費でき、数十年安定して動作。MASShortcut 等の外部ライブラリを使わず自前 100 行で済む |
| ドラッグ検知: **`NSEvent.addGlobalMonitorForEvents`** | CGEventTap | 監視だけでよい（消費不要）ので軽量な方を選択。アクセシビリティ権限で動作 |
| UI: **AppKit 骨格 + SwiftUI 設定画面** | 全 SwiftUI（MenuBarExtra） | NSStatusItem・オーバーレイ NSWindow の細かい制御は AppKit が確実。フォーム系 UI だけ SwiftUI の生産性を取る |
| プロジェクト形式: **Xcode 16 synchronized folders**（objectVersion 77） | 旧形式 pbxproj | ファイル追加時に pbxproj 編集不要 → OSS のコンフリクト源を排除 |
| 署名: **アドホック（CODE_SIGN_IDENTITY = "-"）** | Developer ID | アカウント不要でビルド可能にする（N5）。TCC 再許可の注意点は §10 |

## 4. モジュール詳細設計

### 4.1 Core（純粋層）

#### `SnapAction`

全スナップ操作を表す enum。`String` の rawValue を持ち、設定の永続化キーとメニュー構築に使う。

```swift
public enum SnapAction: String, CaseIterable, Codable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeftQuarter, topRightQuarter, bottomLeftQuarter, bottomRightQuarter
    case leftThird, centerThird, rightThird, leftTwoThirds, rightTwoThirds
    case maximize, center, restore
    case previousDisplay, nextDisplay
}
```

`title`（メニュー表示名）と `menuGroups`（メニュー/設定画面での並び）を提供する。

`cycleChain` は連打サイクル（F10）の遷移列を定義する: `leftHalf → leftTwoThirds → leftThird`（右も同様）。先頭は必ず自分自身で、対象外の action は nil。上下半分をサイクルさせたくなったら、縦 1/3 系の action を追加して chain を定義するだけでよい。

#### `LayoutCalculator`

スナップ先矩形の計算。**すべて CG 座標系（左上原点・y は下向き）** で行う。

```swift
public struct LayoutCalculator {
    public let gap: CGFloat
    /// restore / display 移動 / center 以外の action の矩形。対象外は nil
    public func frame(for action: SnapAction, in visibleFrame: CGRect) -> CGRect?
    /// サイズ維持で中央配置（visibleFrame に収まるようクランプ）
    public func centered(size: CGSize, in visibleFrame: CGRect) -> CGRect
    /// ディスプレイ間移動: 相対位置・相対サイズを維持して写像し、収まるようクランプ
    public static func proportionallyMapped(_ frame: CGRect, from: CGRect, to: CGRect) -> CGRect
}
```

**ギャップの数式**: 画面端に `gap`、ウィンドウ間にも `gap` を置く。n 分割の 1 カラム幅は

```
unit = (W - (n+1)·gap) / n
x(i) = minX + gap + i·(unit + gap)
幅(span k) = k·unit + (k-1)·gap
```

行方向（半分上下）も同式。1/4 は列×行の交差で合成する。`gap = 0` のとき Magnet と完全一致。

| action | 列 (count, index, span) | 行 (count, index, span) |
|---|---|---|
| leftHalf | (2, 0, 1) | (1, 0, 1) |
| rightHalf | (2, 1, 1) | (1, 0, 1) |
| topHalf / bottomHalf | (1, 0, 1) | (2, 0/1, 1) |
| 四隅 quarter | (2, 0 or 1, 1) | (2, 0 or 1, 1) |
| left/center/rightThird | (3, 0/1/2, 1) | (1, 0, 1) |
| leftTwoThirds | (3, 0, 2) | (1, 0, 1) |
| rightTwoThirds | (3, 1, 2) | (1, 0, 1) |
| maximize | visibleFrame を gap だけ内側に |  |

#### `EdgeZone`

ドラッグスナップのゾーン判定（純粋関数）。

```swift
public enum EdgeZone {
    /// p: ポインタ位置（CG座標）, vf: 対象スクリーンの visibleFrame（CG座標）
    public static func action(
        for p: CGPoint, inVisibleFrame vf: CGRect,
        edgeThreshold t: CGFloat = 12, cornerFraction cf: CGFloat = 0.25
    ) -> SnapAction?
}
```

判定順序（先勝ち）:

1. `p.x ≤ vf.minX + t`（左端）: 縦位置が上 cf → `topLeftQuarter` / 下 cf → `bottomLeftQuarter` / 中央 → `leftHalf`
2. 右端: 同様に右系
3. `p.y ≤ vf.minY + t`（上端）: `maximize`
4. `p.y ≥ vf.maxY − t`（下端）: 横位置 3 等分で `leftThird` / `centerThird` / `rightThird`
5. どれでもない → `nil`（プレビュー消去）

メニューバー・Dock 上にポインタがある場合も、visibleFrame の外側は各辺のしきい値帯に含まれる（`≤`/`≥` 比較なので自然に成立）。

#### `Shortcut`

```swift
public struct Shortcut: Codable, Hashable {
    public var keyCode: UInt32          // Carbon 仮想キーコード
    public var carbonModifiers: UInt32  // Carbon 修飾キービット
    public var keyLabel: String         // 表示用（"←", "U", "↩" など。記録時に確定）
    public var display: String          // "⌃⌥←" のような表示文字列
    public func matches(_ other: Shortcut) -> Bool  // keyCode+modifiers で比較
}
```

Carbon の修飾キービット（`cmdKey = 0x100, shiftKey = 0x200, optionKey = 0x800, controlKey = 0x1000`）は Core を Carbon 非依存に保つため定数として自前定義する。表示ラベルは**記録時**に NSEvent から確定して保存する（キーボードレイアウト変換を実行時に持たないため）。

デフォルトバインディング（Magnet 互換）も `Shortcut.defaultBindings: [SnapAction: Shortcut]` としてここに定義する。

### 4.2 Windowing

#### `ScreenGeometry` — 座標系設計（最重要）

macOS には 2 つの座標系が混在する:

| 座標系 | 原点 | y の向き | 使用箇所 |
|---|---|---|---|
| Cocoa (AppKit) | プライマリ画面の**左下** | 上向き | `NSScreen.frame/visibleFrame`, `NSWindow.setFrame`, `NSEvent.mouseLocation` |
| CG / AX | プライマリ画面の**左上** | 下向き | `AXUIElement` の position, `CGWindow` 系 |

**方針: アプリ内部の計算はすべて CG 座標系に統一する。** Cocoa 座標は入口（NSScreen, NSEvent）で変換し、出口（オーバーレイ NSWindow）で逆変換する。変換は 1 箇所に集約:

```
flip(rect) : y' = primaryScreenHeight − rect.maxY   （幅・高さ・x は不変）
flip(point): y' = primaryScreenHeight − point.y
```

`primaryScreenHeight` は `frame.origin == (0,0)` のスクリーン（プライマリ）の高さ。flip は対合（2 回适用で元に戻る）なので同一関数を双方向に使う。

```swift
enum ScreenGeometry {
    static func cgFrame(of: NSScreen) -> CGRect
    static func cgVisibleFrame(of: NSScreen) -> CGRect
    static func toCocoa(_ cgRect: CGRect) -> CGRect
    static func cgMouseLocation() -> CGPoint
    static func screen(containingCG point: CGPoint) -> NSScreen?
    static func screen(for windowFrame: CGRect) -> NSScreen   // 交差面積最大
    static func adjacentScreen(of: NSScreen, next: Bool) -> NSScreen?  // CG minX,minY 順で循環
}
```

#### `AXWindow`

`AXUIElement`（ウィンドウ要素）の薄いラッパー。

```swift
struct AXWindow {
    let element: AXUIElement
    var frame: CGRect? { get }          // kAXPosition + kAXSize
    func set(frame: CGRect)             // ★ size → position → size の順で設定
    var isStandard: Bool                // subrole == AXStandardWindow
    var isFullscreen: Bool              // "AXFullScreen" 属性
    var isMovable: Bool / var isResizable: Bool   // AXUIElementIsAttributeSettable
    var pid: pid_t?
    var appElement: AXUIElement?        // pid から生成
}
```

**size→position→size の理由**: アプリは自身の最小サイズやリサイズ増分で要求値をクランプする。先に position だけ設定すると、画面右端で「移動したがサイズが縮まず画面外にはみ出す」等が起きる。size を先に当ててから position、最後に size を再適用すると収束する（Rectangle も同じ手法）。

**AXEnhancedUserInterface ワークアラウンド**: 一部アプリ（Chrome / Electron 系）はアプリ要素の `AXEnhancedUserInterface` が true のとき move がアニメーション干渉で失敗することがある。スナップ実行の間だけ false にして、元の値へ戻す。

#### `WindowFinder`

```swift
enum WindowFinder {
    /// フォーカス中ウィンドウ。自アプリが前面のときは tracker の「直前の外部アプリ」を使う
    static func focusedWindow(preferringPid: pid_t?) -> AXWindow?
    /// ドラッグスナップ用: 指定 CG 座標直下のウィンドウ
    static func window(atCG point: CGPoint) -> AXWindow?
}
```

- focusedWindow: `NSWorkspace.frontmostApplication` の pid → `AXUIElementCreateApplication` → `kAXFocusedWindowAttribute`（無ければ `kAXMainWindowAttribute` にフォールバック）
- window(atCG:): `AXUIElementCopyElementAtPosition`（system-wide 要素）→ その要素の `kAXWindowAttribute`、無ければ `kAXParentAttribute` を最大 20 段さかのぼって `AXWindow` ロールを探す

#### `FrontmostAppTracker`

設定画面やメニュー操作で自アプリが前面化した直後でも正しい対象を掴むため、`NSWorkspace.didActivateApplicationNotification` を購読して**自分以外で最後にアクティブだったアプリの pid** を保持する。

#### `FrameHistory`

restore（F2）用の元位置記憶。

- キー: `AXUIElement` を `CFHash`/`CFEqual` でラップした `AXWindowKey`
- 値: スナップ**初回**時点の CG frame（2 回目以降のスナップでは上書きしない）
- restore 実行でエントリを消費（削除）→ 次のスナップで再記録
- 容量 64 件の挿入順 LRU。プロセス終了で消える（永続化しない）

#### `SnapExecutor` — 実行の中枢

```swift
@MainActor final class SnapExecutor {
    func perform(_ action: SnapAction)                          // ホットキー・メニュー経路
    func perform(_ action: SnapAction, on window: AXWindow,
                 preferredScreen: NSScreen?)                    // ドラッグ経路
}
```

シーケンス（ホットキー経路）:

```
HotkeyCenter ──action──▶ SnapExecutor
  1. AXIsProcessTrusted? ─ No → beep + オンボーディング表示
  2. WindowFinder.focusedWindow() ─ nil → beep
  3. window.isFullscreen? ─ Yes → beep
  4. screen = 引数 or ウィンドウ中心を含むスクリーン
  5. action 分岐:
       restore        → FrameHistory から取り出し
       center         → LayoutCalculator.centered
       next/prevDisplay → 隣接スクリーンへ proportionallyMapped
       それ以外        → LayoutCalculator.frame(for:in:)
  6. restore 以外なら FrameHistory.rememberOriginal（初回のみ記録）
  7. AXEnhancedUserInterface を退避 → AXWindow.set(frame:) → 復元
```

**連打サイクル（F10）と隅コンボ（F12）**: 前回のスナップを 1 スロットだけ記憶する `SnapMemory(windowKey, resolvedAction, appliedFrame)` を持つ。ホットキー/メニュー経路（`usesMemory: true`）では入り口で `resolve(pressed:on:currentFrame:)` を通し、以下の優先順で「本当に実行する action」を決める:

1. **コンボ**（`combineHalvesToQuarters` がオン）: `SnapAction.combinedQuarter(base: memory.resolvedAction, add: pressed)` が nil でない、つまり *前回が半分 かつ 今回が直交する半分* なら、対応する quarter へ解決する。
2. **サイクル**（`cycleSizesEnabled` がオン）: pressed の cycleChain を引き、chain 内で memory.resolvedAction の位置 i を見つけたら chain[(i+1) % count] へ解決する。
3. どちらも該当しなければ pressed をそのまま実行する。

いずれの経路でも「windowKey が同じ」「現在 frame が memory.appliedFrame と誤差 10pt 以内で一致」の 2 条件が前提。手動移動、別ウィンドウ、別 action、ドラッグ経路（`usesMemory: false`）ではメモリを参照しない。`appliedFrame` は要求値ではなく set 直後の読み戻し値を記録する。move を非同期にしか反映しないアプリでは読み戻しが古く、次回の照合が外れて「サイクル/コンボしない普通のスナップ」に退行する（安全側の縮退）。実行後は resolvedAction を含めて memory を更新する。

### 4.3 Input

#### `HotkeyCenter`

- `InstallEventHandler(GetEventDispatcherTarget(), …, kEventHotKeyPressed)` を 1 回だけ設置
- `register(bindings: [SnapAction: Shortcut])`: 既存をすべて `UnregisterEventHotKey` してから登録し直す（設定変更時は全再登録 — 件数が高々 18 なので単純さ優先）
- `EventHotKeyID.signature = 'FITK'`、`id` は登録順のインデックス → action の対応表を保持
- `pause()/resume()`: ショートカット録音中は既存ホットキーが横取りしないよう一時解除（`.fitShortcutRecordingBegan/Ended` 通知で駆動）
- コールバックは C 関数ポインタのため、`Unmanaged.passUnretained(self)` を userData として渡す

#### `DragSnapMonitor`

状態機械:

```
idle ──leftMouseDown──▶ armed（ヒットテストは初回ドラッグまで遅延）
armed ──leftMouseDragged──▶
    直下のウィンドウを AX ヒットテスト（標準ウィンドウのみ）
      取れない → rejected（このドラッグ中は再判定しない）
      取れた   → tracking(window, 初期origin)
tracking ──leftMouseDragged（33ms スロットル）──▶
    ウィンドウ origin が初期位置から 4px 超移動 → confirmed = true
    confirmed なら: ポインタ位置のスクリーンで EdgeZone.action() を判定
      ゾーンあり → LayoutCalculator で矩形計算 → SnapOverlay 表示/移動
      ゾーンなし → SnapOverlay 非表示
tracking ──leftMouseUp──▶
    confirmed かつゾーンあり → SnapExecutor.perform(action, on: window, screen)
    状態を idle へ、オーバーレイ非表示
```

設計上の要点:

- **クリックのみでは AX 呼び出しを行わない**（ヒットテストは最初の drag イベントまで遅延）→ 通常のクリック操作に負荷ゼロ
- 「ウィンドウが実際に動いたか」で判定するため、テキスト選択などウィンドウ内ドラッグには反応しない
- 33ms スロットルで AX 読み取り頻度を約 30Hz に制限
- 設定 `edgeSnapEnabled` の変更で start/stop
- 抑止修飾キー（F11、既定 ⇧）が押されている間はゾーン判定とプレビューを止める。mouseUp 時にも最終確認するため、「離す直前に ⇧ を押す」でもスナップを回避できる。スナップ実行は `usesMemory: false` で呼び、連打サイクル/隅コンボの状態を汚さない

### 4.4 UI

#### `SnapOverlayController`

- borderless / 透明背景 / `ignoresMouseEvents = true` / `level = .floating` の NSWindow 1 枚を使い回す
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]`
- 外観: アクセントカラー 22% の塗り + 2px 枠 + 角丸 10
- `show(cgRect:)` は Cocoa 座標へ変換して `setFrame`。表示中の移動は 0.12s のアニメーション
- アプリを前面化させない（`orderFrontRegardless`）

#### `PermissionOnboardingController`

- 起動時に `AXIsProcessTrusted()` が false なら表示（`-FitSuppressOnboarding YES` 起動引数で抑制可能 — スモークテスト用）
- 「Open System Settings」ボタン: `AXIsProcessTrustedWithOptions(prompt: true)` でシステムダイアログを一度出しつつ、`x-apple.systempreferences:…Privacy_Accessibility` を開く
- 1 秒間隔で `AXIsProcessTrusted()` をポーリングし、許可されたら自動で閉じて `onGranted` → エンジン始動
- 再ビルドで許可が外れる注意書きを本文に含める（§10）

#### `SettingsWindowController` / `SettingsView`

- `NSWindow` + `NSHostingController`。ウィンドウは使い回し（`isReleasedWhenClosed = false`）
- SwiftUI `TabView` 3 タブ:
  - **General**: Launch at Login（SMAppService、失敗時アラート）/ Edge snapping トグル / Gap スライダー（0–32, 2 刻み）
  - **Shortcuts**: 全 action の一覧 + `ShortcutRecorderView` + Reset to Defaults
  - **About**: バージョン、リポジトリリンク、ライセンス
- 表示時に `NSApp.activate`（アクセサリアプリのため明示的に前面化）

#### `ShortcutRecorderView`

- クリックで録音開始 → `NSEvent.addLocalMonitorForEvents(.keyDown)` で次のキー入力を捕捉（イベントは飲み込む）
- Esc = キャンセル / 修飾なし Delete = 割り当て解除
- ⌘⌃⌥ のいずれかを含む、または F1–F12 単体のみ有効（誤爆防止）
- 録音開始/終了で通知を発行し、`HotkeyCenter` を pause/resume
- 同一コンボが他 action に割当済みの場合は**古い方を自動解除**（`SettingsStore.setShortcut` 内で実施）

#### `StatusItemController`

- `NSStatusItem`（SF Symbol `rectangle.split.2x1`、テンプレート画像）
- メニュー構成: 権限警告（未許可時のみ）/ 半分 4 種 / Quarters ▸ / Thirds ▸ / Maximize・Center・Restore / Display ▸ / Settings… / About / Quit
- `menuNeedsUpdate` で現在のバインディングから keyEquivalent 表示を再構築（カスタマイズが即反映される）
- 各項目の `tag` に `SnapAction.allCases` のインデックスを持たせ、単一セレクタで dispatch

### 4.5 Support

#### `SettingsStore`（`ObservableObject`, シングルトン）

| プロパティ | 型 | 既定値 | UserDefaults キー |
|---|---|---|---|
| `gap` | Double | 0 | `fit.gap` |
| `edgeSnapEnabled` | Bool | true | `fit.edgeSnapEnabled` |
| `shortcuts` | [SnapAction: Shortcut] | Magnet 互換 | `fit.shortcuts.v1`（JSON Data） |
| `cycleSizesEnabled` | Bool | true | `fit.cycleSizesEnabled` |
| `combineHalvesToQuarters` | Bool | true | `fit.combineHalvesToQuarters` |
| `dragSuppressModifier` | DragSuppressModifier | .shift | `fit.dragSuppressModifier`（rawValue 文字列） |

- 変更のたびに永続化し、`.fitSettingsDidChange` を通知 → AppDelegate がホットキー再登録・ドラッグ監視の start/stop を行う
- `shortcuts` に無い action は「無効化」を意味する
- スキーマ変更時はキーの `.v1` をインクリメントしてマイグレーション

#### `LoginItem`

`SMAppService.mainApp` の register/unregister。DerivedData 内のビルド産物を指すと不安定なため、UI に「/Applications へのコピー推奨」の注記を出す。

### 4.6 App

- `main.swift`: `NSApplication.shared` + `setActivationPolicy(.accessory)` + AppDelegate 設置 + `run()`（storyboard/nib なし）
- `AppDelegate`:
  1. `SettingsStore` ロード、`SnapExecutor`・`StatusItemController` 構築
  2. 権限チェック → OK ならエンジン始動 / NG ならオンボーディング → 許可検知で始動
  3. エンジン始動 = ホットキー登録 + （設定次第で）ドラッグ監視開始
  4. `.fitSettingsDidChange` 購読で再構成

## 5. エラー処理方針

| 状況 | 挙動 |
|---|---|
| 対象ウィンドウなし / フルスクリーン / AX 呼び出し失敗 | `NSSound.beep()` のみ。ダイアログは出さない（ホットキー操作の文脈を壊さない） |
| 権限未許可でスナップ操作 | beep + オンボーディングを再表示 |
| restore 対象の記録なし | beep |
| SMAppService 失敗 | 設定画面にアラート表示（唯一のモーダルエラー） |
| AX が resize をクランプ | そのまま受容（アプリの制約を尊重） |

ログは `os.Logger`（subsystem = bundle id）で debug レベルに出す。ユーザー向けログ UI は持たない。

## 6. パフォーマンス設計

- 常駐時の定常負荷ゼロ（ポーリングなし。ホットキーはイベント駆動、オンボーディングの 1Hz ポーリングのみ例外で許可後停止）
- ドラッグ中の AX 読み取りは 30Hz にスロットル。クリックだけでは AX を呼ばない
- ホットキー発火 → スナップ完了は体感即時（AX 呼び出し 3 回 + 計算のみ）

## 7. セキュリティ・プライバシー設計

- **App Sandbox 有効**（`ENABLE_APP_SANDBOX = YES`）。アクセシビリティ API はユーザーが TCC で許可すればサンドボックス内でも他アプリのウィンドウを操作できる（Mac App Store のウィンドウマネージャと同じ構成）。ローカルビルドとストアビルドの挙動を一致させるため、全ビルドでサンドボックスを有効にしている
- プライバシーマニフェスト（`PrivacyInfo.xcprivacy`）同梱: トラッキングなし・収集データなし・UserDefaults は自アプリ設定用途（CA92.1）
- 取得権限はアクセシビリティのみ。キー入力の内容は読まない（RegisterEventHotKey は登録したコンボのみ通知される）
- ネットワーク API・ファイル書き込み（UserDefaults 以外）・プロセス起動を行わない
- 依存ゼロのため、サプライチェーンリスクは Apple SDK のみ

## 8. テスト戦略

| 対象 | 方法 |
|---|---|
| LayoutCalculator（全 action × gap 0/16、端数、比例写像、クランプ） | `swift test`（FitCoreTests） |
| EdgeZone（各ゾーン代表点、角優先、メニューバー上のポインタ、しきい値外） | `swift test` |
| Shortcut（既定値の重複なし、matches、Codable 往復） | `swift test` |
| AX 実操作・ホットキー・ドラッグ | 手動スモークテスト（チェックリストを docs/BUILDING.md に記載） |
| 起動クラッシュ検知 | `-FitSuppressOnboarding YES` で起動 → 数秒後 kill する CI スモーク（ローカルのみ。CI はビルドとユニットテストまで） |

AX・Carbon 依存部は薄いラッパーに閉じ込め、ロジックを Core に寄せることでテスト可能面積を最大化する。

## 9. ディスプレイ・スペースに関する仕様

- スナップ先スクリーン: ホットキー時は**ウィンドウの中心（交差面積最大）のスクリーン**、ドラッグ時は**ポインタのあるスクリーン**
- `visibleFrame` を使うため、メニューバー・Dock・ノッチは自動で避ける
- ディスプレイ移動の順序は CG 座標の (minX, minY) 昇順で循環
- ネイティブフルスクリーンウィンドウは操作対象外（beep）
- Stage Manager 環境は動作保証外（既知の制約として README に記載）

## 10. 署名と TCC（アクセシビリティ許可）の既知の問題

アドホック署名はビルドごとに cdhash が変わる。macOS の TCC はアクセシビリティ許可を署名に紐付けるため、**再ビルド後に許可が「オンのまま効かない」状態になることがある**。

対処（docs/BUILDING.md に詳述）:

1. システム設定のアクセシビリティ一覧から Fit を − で削除して再追加（確実）
2. `tccutil reset Accessibility dev.temma.fit` で許可をリセットして再許可
3. 恒久対処: `security create-certificate`（または「キーチェーンアクセス」）で自己署名のコード署名証明書を作り、`CODE_SIGN_IDENTITY` に設定 → 署名が安定し再許可不要になる

## 11. ビルド構成

- ターゲット 1 本（Fit.app）。`GENERATE_INFOPLIST_FILE = YES` で Info.plist は生成（`INFOPLIST_KEY_LSUIElement = YES` で Dock 非表示）
- `SWIFT_VERSION = 5.0`（言語モード。Swift 6 strict concurrency は v0.1 では未採用 — 主要クラスは @MainActor で保護）
- `MACOSX_DEPLOYMENT_TARGET = 13.0`（SMAppService が下限を規定）
- `ENABLE_APP_SANDBOX = YES`（App Store 配布要件。エンタイトルメントファイルは持たず、ビルド設定から生成）
- `ENABLE_HARDENED_RUNTIME = NO`（Mac App Store はサンドボックスが要件で Hardened Runtime は不要。Developer ID で公証配布する場合のみ YES）
- 共有スキーム `Fit` を同梱（`xcodebuild -scheme Fit` を CI・CLI で安定させる）

## 12. 既知の制約・リスク

| リスク | 影響 | 緩和策 |
|---|---|---|
| TCC 再許可問題（§10） | 再ビルド後に動かず混乱 | オンボーディング・README・BUILDING.md の 3 箇所で案内 |
| アプリ独自のリサイズ制約 | 1px 単位でぴったりにならない | 仕様として受容（§5） |
| `AXUIElement` の同一性が保証されない場面 | restore が効かないことがある | 失敗時は beep のみで安全に無視 |
| Electron 系の move 失敗 | スナップが「ワンテンポ遅れる/効かない」 | AXEnhancedUserInterface ワークアラウンド（§4.2） |
| macOS メジャーアップデートでの AX 挙動変化 | 主要機能の退行 | ロジックを Core に隔離しラッパーを薄く保つ。CI でビルド検証 |

## 13. 将来拡張（設計上の考慮のみ）

- **6 分割・カスタムゾーン**: `LayoutCalculator` の列/行合成 API（count/index/span）がそのまま使える
- **同時押しキーコード検出**: Carbon の RegisterEventHotKey は 1 コンボ 1 イベントで、複数の矢印キー同時押しは原理的に検出できない。隅コンボ（F12）は「連続押し」で同等の UX を提供している
- **アプリ除外リスト**: `SnapExecutor` 入口で bundle id を照合する 1 点フック
- **ローカライズ**: 文字列は各 View に直書きせず定数化してあるため String Catalog 導入が容易
