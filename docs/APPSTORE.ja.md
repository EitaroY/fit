# 配布と販売の選択肢

## 結論: Mac App Store では配布できない

当初 App Store での ¥350 買い切り販売を計画したが、**技術的に成立しない**ことが実機検証で確定した（2026-07-14）。

- Mac App Store のアプリは App Sandbox が必須
- **App Sandbox は、ユーザーが TCC のアクセシビリティ許可を与えていても、他アプリへの AX 書き込み（ウィンドウの移動・リサイズ）を遮断する**。サンドボックス化した Fit で全機能が停止することを実機で確認した
- ストアに存在するウィンドウマネージャ（Magnet・Moom・BetterSnapTool）は、2012 年のサンドボックス義務化**以前**からあるアプリへの例外措置で非サンドボックスのまま更新を続けている遺産的存在（Magnet のエンタイトルメントに `com.apple.security.app-sandbox` が無いことを実機で確認）。新規アプリはこの枠に入れない
- Rectangle・AltTab・BetterTouchTool などが App Store 外で配布されているのはこれが理由

## ストア外で販売する場合の構成（Rectangle Pro 方式）

App Store を使わずに配布・販売する標準構成:

| 要素 | 手段 |
|---|---|
| 署名 | Developer ID Application 証明書（加入済みの Apple Developer Program で発行可能） |
| 公証 | `notarytool` で自動化（CI に組み込み可能） |
| 配布 | GitHub Releases か自サイトから dmg/zip |
| 決済 | Lemon Squeezy / Paddle（Merchant of Record 型 — 消費税・VAT を代行、手数料 5%前後 + 固定費）、または Gumroad（〜10%）、Stripe Payment Links（税務は自前） |
| ライセンス | 買い切りキー発行（決済サービスの標準機能）。検証をアプリに組み込むかは任意 — ネットワークコードゼロの設計と両立させるなら「オフライン署名検証 or 性善説（OSS なので）」 |

注意点:

- GPL-3.0 のままでも著作権者本人の販売は自由（現在のデュアルライセンス構成のまま成立する）
- ネットワーク不要の設計思想を守るなら、ライセンス検証はオフライン（公開鍵署名の検証のみ）にするか、いっそ課金は「支援」と割り切る
- 公証には `ENABLE_HARDENED_RUNTIME = YES` のリリース構成が別途必要（現在の開発ビルドは NO のまま）

## 何もしない選択肢

OSS として GitHub で公開し続け、収益化は GitHub Sponsors 等に留める。会社 Mac ユースケース（ソースからビルド）には元々ストアも公証も不要。
