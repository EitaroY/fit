#!/usr/bin/env python3
"""Watch Apple's macOS releases and report newly shipped stable versions.

Stable releases only — betas and RCs are deliberately out of scope. Data comes
from the SOFA feed (macadmins.io), which tracks Apple's software update catalog
and is the same source Mac admin tooling uses.

State lives in .github/os-watch-state.json so a version is reported once. On the
first run the state file is seeded without reporting anything, otherwise every
currently-shipping macOS would be announced at once.

Writes `has_news`, `title` and `summary` to $GITHUB_OUTPUT; the issue body goes
to os-watch-issue.md in the working directory.
"""

import json
import os
import urllib.request

FEED_URL = "https://sofafeed.macadmins.io/v1/macos_data_feed.json"
STATE_PATH = ".github/os-watch-state.json"
BODY_PATH = "os-watch-issue.md"
# Anything older than the app's MACOSX_DEPLOYMENT_TARGET is not our problem.
MIN_MAJOR = 13


def fetch_feed():
    request = urllib.request.Request(FEED_URL, headers={"User-Agent": "fit-os-watch"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def latest_versions(feed):
    """{major: {name, version, build, released}} for supported majors."""
    result = {}
    for entry in feed.get("OSVersions", []):
        latest = entry.get("Latest") or {}
        version = latest.get("ProductVersion")
        if not version:
            continue
        try:
            major = int(version.split(".")[0])
        except ValueError:
            continue
        if major < MIN_MAJOR:
            continue
        result[str(major)] = {
            "name": entry.get("OSVersion", f"macOS {major}"),
            "version": version,
            "build": latest.get("Build", ""),
            "released": (latest.get("ReleaseDate") or "")[:10],
        }
    return result


def load_state():
    try:
        with open(STATE_PATH, encoding="utf-8") as file:
            return json.load(file)
    except FileNotFoundError:
        return None


def save_state(versions):
    os.makedirs(os.path.dirname(STATE_PATH), exist_ok=True)
    with open(STATE_PATH, "w", encoding="utf-8") as file:
        json.dump({"versions": versions}, file, indent=2, sort_keys=True)
        file.write("\n")


def changes(previous, current):
    """New majors and bumped versions, as (kind, info) pairs."""
    found = []
    for major, info in sorted(current.items(), key=lambda item: int(item[0])):
        known = previous.get(major)
        if known is None:
            found.append(("major", info))
        elif known.get("version") != info["version"]:
            found.append(("minor", info))
    return found


def issue_body(found, current):
    lines = ["Apple から新しい macOS の安定版が公開されました。", ""]
    for kind, info in found:
        label = "**新しいメジャーバージョン**" if kind == "major" else "アップデート"
        lines.append(
            f"- {label}: {info['name']} — `{info['version']}`"
            f" (build `{info['build']}`, {info['released']})"
        )
    lines += [
        "",
        "## 確認すること",
        "",
        "- [ ] 新しい OS でビルドが通る（`swift test` と Release ビルド）",
        "- [ ] アクセシビリティ権限でのウィンドウ操作が壊れていない"
        "（分割・エッジスナップ・ホットキー）",
        "- [ ] 権限の付与フロー（オンボーディング）が変わっていない",
        "- [ ] ログイン項目への登録（SMAppService）が従来どおり動く",
    ]
    if any(kind == "major" for kind, _ in found):
        lines += [
            "- [ ] `MACOSX_DEPLOYMENT_TARGET` / `Package.swift` の"
            "サポート範囲を見直すか判断する",
            "- [ ] CI のランナーイメージに新バージョンが追加されたか確認する",
        ]
    lines += [
        "",
        "## 現在の各メジャーの最新版",
        "",
        "| macOS | バージョン | ビルド | リリース日 |",
        "| --- | --- | --- | --- |",
    ]
    for major in sorted(current, key=int, reverse=True):
        info = current[major]
        lines.append(
            f"| {info['name']} | {info['version']} | {info['build']} | {info['released']} |"
        )
    lines += [
        "",
        f"<sub>[SOFA feed]({FEED_URL}) より自動生成。ベータ版は対象外です。</sub>",
    ]
    return "\n".join(lines) + "\n"


def set_output(**values):
    path = os.environ.get("GITHUB_OUTPUT")
    if not path:
        for key, value in values.items():
            print(f"{key}={value}")
        return
    with open(path, "a", encoding="utf-8") as file:
        for key, value in values.items():
            file.write(f"{key}={value}\n")


def main():
    current = latest_versions(fetch_feed())
    if not current:
        raise SystemExit("feed returned no supported macOS versions")

    state = load_state()
    if state is None:
        save_state(current)
        print("Seeded state file; no issue on the first run.")
        set_output(has_news="false", seeded="true")
        return

    found = changes(state.get("versions", {}), current)
    if not found:
        print("No new stable macOS releases.")
        set_output(has_news="false", seeded="false")
        return

    save_state(current)
    with open(BODY_PATH, "w", encoding="utf-8") as file:
        file.write(issue_body(found, current))

    versions = ", ".join(info["version"] for _, info in found)
    print(f"New stable release(s): {versions}")
    set_output(
        has_news="true",
        seeded="false",
        title=f"macOS {versions} がリリースされました — 動作確認",
        summary=versions,
    )


if __name__ == "__main__":
    main()
