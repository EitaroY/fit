# Mac App Store リリース手順

Fit を App Store で ¥350 買い切りとして公開するためのランブック。技術面（サンドボックス・プライバシーマニフェスト・バージョン設定）はリポジトリ側で対応済みなので、この文書は App Store Connect まわりの手作業をまとめる。

## 0. 前提（済んでいること）

- Apple Developer Program 加入済み（Team ID: `94HLRRY93H`）
- プロジェクトは App Sandbox 有効・`PrivacyInfo.xcprivacy` 同梱・`MARKETING_VERSION = 1.0`
- `ITSAppUsesNonExemptEncryption = NO` 設定済み（アップロード毎の輸出コンプライアンス質問がスキップされる）
- App アイコン全サイズ（16〜1024px）同梱済み

## 1. App Store Connect の初期設定（初回のみ）

1. [App Store Connect](https://appstoreconnect.apple.com) → **契約 / Business** → **Paid Applications 契約**に同意
2. 銀行口座・税務情報（日本の口座 + 税務フォーム）を登録。承認まで数時間〜数日
3. **App Store Small Business Program** に申請（https://developer.apple.com/jp/app-store/small-business-program/）
   - 年間売上 100 万 US ドル以下なら手数料が 30% → **15%**。¥350 の手取りが約 245 円 → **約 297 円**になる。やらない理由がない

## 2. App の登録

1. My Apps → **+** → New App
   - プラットフォーム: **macOS**
   - 名前: **「Fit」単体はほぼ確実に取得済み**なので、候補: `Fit — Window Snapping` / `Fit: Snap Windows` / `Fit Window Manager`（Connect 上で重複エラーが出なくなるまで試す）
   - プライマリ言語: 日本語 or 英語（後から各言語のローカライズ追加可）
   - Bundle ID: `dev.temma.fit`（一覧に出ない場合は Xcode で Team を選択して一度 Archive すると自動登録される。または developer.apple.com → Identifiers で手動登録）
   - SKU: `fit-macos`（自由入力・ユーザーには見えない）
2. **価格および配信状況**: 価格ポイントから **¥350**（無ければ最寄り）を選択
3. **配信地域**: 全地域 or 選択制。**EU で販売する場合は DSA のトレーダー要件で住所・連絡先の公開が必要**。面倒なら初回は EU を外すのが楽（後から追加可能）

## 3. Xcode からのアップロード

1. `Fit.xcodeproj` を開く → TARGETS Fit → **Signing & Capabilities** → Team に自分のチームを選択（App Sandbox は設定済みなので追加操作なし）
2. スキームの実行先が **My Mac** になっていることを確認 → **Product → Archive**
3. Organizer が開いたら **Distribute App → App Store Connect → Upload**（署名は Automatic でよい）
4. 数分〜30 分ほどで Connect の **TestFlight / ビルド**欄に現れる
5. 以後アップデートするたびに `CURRENT_PROJECT_VERSION`（ビルド番号）を +1。ユーザー向けバージョンを上げるときは `MARKETING_VERSION` も上げる

## 4. ストア情報

### 名前・サブタイトル案

| 項目 | 案 |
|---|---|
| 名前 | Fit — Window Snapping |
| サブタイトル (JA) | キーボードでウィンドウを整列 |
| サブタイトル (EN) | Snap windows with your keyboard |

### 説明文ドラフト（日本語）

> Fit はウィンドウ整理をキーボードで完結させる、メニューバー常駐の軽量ユーティリティです。
>
> ⌃⌥ と矢印キーでウィンドウを左右上下の半分へ。同じキーを連打すれば 1/2 → 2/3 → 1/3 とサイズが切り替わり、続けて直交方向のキーを押せば四隅にぴったり収まります。マウス派にはドラッグスナップも。ウィンドウを画面の端に引き寄せるだけで、プレビューを確認してから配置できます。
>
> 特徴:
> ・半分・4分の1・3分の1・3分の2・最大化・中央寄せ・元に戻す
> ・同じショートカットの連打でサイズをサイクル
> ・ドラッグで画面端にスナップ（プレビュー付き）
> ・マルチディスプレイ対応、ディスプレイ間の移動もショートカットで
> ・ウィンドウ間の隙間（ギャップ）を調整可能
> ・ショートカットは自由にカスタマイズ
> ・ログイン時に自動起動
>
> Fit はネットワークに一切アクセスせず、解析・トラッキングも行いません。要求する権限はウィンドウ操作に必要なアクセシビリティのみです。ソースコードは GitHub で公開しています。

### 説明文ドラフト（英語）

> Fit is a lightweight menu bar utility that keeps your windows organized without leaving the keyboard.
>
> Snap the frontmost window to any half of the screen with ⌃⌥ and the arrow keys. Press the same shortcut again to cycle the size through 1/2 → 2/3 → 1/3, or press a perpendicular arrow to tuck the window into a corner. Prefer the mouse? Drag a window to a screen edge and release when the preview shows where it will land.
>
> Features:
> • Halves, quarters, thirds, two-thirds, maximize, center, and restore
> • Repeat a shortcut to cycle window sizes
> • Drag-to-edge snapping with a live preview
> • Multi-display support, including move-to-next-display shortcuts
> • Adjustable gap between snapped windows
> • Fully customizable shortcuts
> • Launch at login
>
> Fit never accesses the network and contains no analytics or tracking. The only permission it requests is Accessibility, which macOS requires for moving other apps' windows. The source code is available on GitHub.

### キーワード（100 文字以内 / **競合アプリ名は入れない** — ガイドライン 2.3.7 で却下リスク）

```
window,snap,tiling,resize,split,layout,shortcut,keyboard,organize,productivity,display
```

### その他

- カテゴリ: 仕事効率化（Productivity）— ビルドに設定済み
- スクリーンショット: **1280×800 / 1440×900 / 2560×1600 / 2880×1800 のいずれか**で最低 1 枚（最大 10 枚）。おすすめ構成: ①2 分割で並んだデスクトップ ②ドラッグスナップのプレビュー表示中 ③Settings の Shortcuts タブ ④メニューバーのメニュー。⌘⇧5 で撮影し、必要ならプレビュー.app でサイズ調整
- プライバシー: 「データを収集しない」を選択（ネットワークコードなしなので正直にこれで通る）
- 年齢制限: 質問すべて「いいえ」→ 4+

## 5. 審査メモ（App Review 向け・英語のまま貼る）

App Review Information の Notes 欄に:

> Fit is a window-management utility for macOS (menu bar app; its icon appears on the right side of the menu bar, and it intentionally has no Dock icon — LSUIElement).
>
> It moves and resizes other applications' windows using the public macOS Accessibility API. This requires the user to grant permission under System Settings → Privacy & Security → Accessibility. On first launch, the app shows an onboarding window that explains this and links to the setting.
>
> To test: launch the app, click "Request Accessibility Access" in the onboarding window and grant permission, then focus any window (e.g. Finder) and press Control+Option+LeftArrow — the window snaps to the left half of the screen. Dragging a window to a screen edge shows a snap preview.
>
> The app uses no private APIs, has no network access, and collects no data. Source code: https://github.com/EitaroY/fit

デモ動画（画面収録 1 分程度）を添付するとさらにスムーズ。

## 6. 提出前チェックリスト

- [ ] `./scripts/install.sh` でローカルにインストールし、docs/BUILDING.md の手動チェックリストを全部通す（**サンドボックス化後の実機確認** — 特にスナップ・ドラッグ・ログイン項目）
- [ ] Settings → About のバージョン表示が 1.0 になっている
- [ ] Paid Apps 契約が「有効」になっている（これが未了だと有料アプリを提出できない）
- [ ] スクリーンショット撮影・アップロード済み
- [ ] 審査メモ貼り付け済み
- [ ] 価格 ¥350・配信地域設定済み

## 7. リリース後の運用

- **アップデート**: main にタグ（例: `v1.1`）→ `CURRENT_PROJECT_VERSION` +1 → Archive → Upload → Connect で新バージョン作成・What's New 記入 → 審査へ
- **GPL との両立**: ストア版のソースは常にこのリポジトリと同一に保つ（リリースごとにタグを打つ）。README に明記済みのデュアルライセンス構成が根拠になる
- **サポート URL**: リポジトリの Issues（https://github.com/EitaroY/fit/issues）を App の サポート URL に設定
- 審査で「なぜアクセシビリティが必要か」と質問が来たら、審査メモの文面を再掲して返信すれば通る（このカテゴリのアプリは前例多数）
