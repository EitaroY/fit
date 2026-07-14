# 配布と販売

## 販売モデル（2026-07-14 決定）

- **¥350 買い切り、ライセンスキーなし（性善説）**
- 対価は「公証済みの公式ビルド」——ダウンロードして開くだけで動く（Xcode 不要・Gatekeeper 警告なし）——と開発支援
- **ネットワークコードゼロは不変**: ライセンス認証・試用期限・アップデートチェックの類は実装しない
- ソースは GPL-3.0 で公開のまま。自分でビルドすれば無料（会社 Mac ユースケースはこちら）
- GPL の性質上、購入者がバイナリを再配布することも法的には可能。それも織り込んだ上での性善説

## なぜ Mac App Store ではないか（2026-07-14 実機検証で確定）

- Mac App Store は App Sandbox が必須だが、**App Sandbox は TCC のアクセシビリティ許可があっても他アプリへの AX 書き込み（ウィンドウの移動・リサイズ）を遮断する**。サンドボックス化した Fit は全機能が停止した
- ストアに現存するウィンドウマネージャ（Magnet 等）は 2012 年のサンドボックス義務化**以前**からあるアプリへの例外措置で、非サンドボックスのまま更新を続けている（Magnet のエンタイトルメントに `app-sandbox` が無いことを実機確認）。新規アプリはこの枠に入れない
- Rectangle・AltTab・BetterTouchTool が App Store 外で配布されているのも同じ理由

## 初回セットアップ（1 回だけ）

1. **Developer ID Application 証明書**を作成:
   Xcode → Settings… → Accounts → 自分の Apple ID を選択 → **Manage Certificates…** → 左下の「+」→ **Developer ID Application**
2. https://account.apple.com → サインインとセキュリティ → **アプリ用パスワード**を 1 つ発行
3. 公証の資格情報をキーチェーンに保存:

```sh
xcrun notarytool store-credentials fit-notary \
  --apple-id "<Apple ID のメール>" \
  --team-id 94HLRRY93H \
  --password "<アプリ用パスワード>"
```

## リリース手順

```sh
./scripts/release.sh
```

これ 1 コマンドで: Release ビルド → Developer ID + Hardened Runtime で署名 → dmg 作成 → Apple の公証サービスに提出（1〜5 分）→ チケットをステープル、まで完了し、`dist/Fit-<version>.dmg` ができる。

検証: 別の Mac（または新規ユーザー）で dmg を開いて警告が出ないこと。コマンドなら:

```sh
spctl -a -t open --context context:primary-signature -v dist/Fit-*.dmg
```

### アップロード先

- **販売ページ**: BOOTH または Lemon Squeezy に商品（¥350）を作成し dmg を添付。**アップデートはファイル差し替え**——購入者は再ダウンロードで最新版を入手できる
- **リポジトリ**: 同じ内容にタグを打つ（`git tag v1.0 && git push --tags`）。販売中のバイナリに対応するソースが常に公開されている状態を保つ（GPL 的な誠実さの担保）

## 更新の運用

1. `MARKETING_VERSION` を上げて main にマージ
2. `./scripts/release.sh` → 新しい dmg
3. 販売ページのファイル差し替え + git タグ
4. 大きな変更は BOOTH / Lemon Squeezy の購入者向けメッセージ機能で告知（アプリ内に通知機構は無い設計のため）

## 商品ページの文言ドラフト

### 日本語

> Fit はウィンドウ整理をキーボードで完結させる、メニューバー常駐の軽量ユーティリティです。
>
> ⌃⌥ と矢印キーでウィンドウを左右上下の半分へ。同じキーを連打すれば 1/2 → 2/3 → 1/3 とサイズが切り替わり、続けて直交方向のキーを押せば四隅にぴったり収まります。ドラッグ派には画面端スナップ（プレビュー付き）も。
>
> ・半分・4分の1・3分の1・3分の2・最大化・中央寄せ・元に戻す
> ・連打でサイズサイクル、連続押しで四隅へ
> ・マルチディスプレイ対応、ギャップ調整、ショートカットカスタマイズ、ログイン時起動
>
> ネットワークに一切アクセスせず、解析・トラッキングもありません。要求する権限はウィンドウ操作に必要なアクセシビリティのみ。ソースコードは GitHub で公開しています（GPL-3.0）。この商品は「ビルド不要・公証済みの公式ビルド」です。ソースから自分でビルドすることもできます。

### English

> Fit is a lightweight menu bar utility that keeps your windows organized without leaving the keyboard.
>
> Snap the frontmost window to any half with ⌃⌥ + arrows. Press again to cycle 1/2 → 2/3 → 1/3, or press a perpendicular arrow to tuck it into a corner. Prefer the mouse? Drag to a screen edge and release on the preview.
>
> • Halves, quarters, thirds, two-thirds, maximize, center, restore
> • Size cycling and corner combining, multi-display support, adjustable gaps, custom shortcuts, launch at login
>
> No network access, no analytics. The only permission required is Accessibility. Source code is on GitHub (GPL-3.0) — this purchase is the pre-built, notarized official binary, ready to run.
