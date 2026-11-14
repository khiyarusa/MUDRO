# MUDRO Radio — Content Policy and Content Pack Format

**Status:** implemented in 3.0. The radio code lives in `scripts/radio/` (`radio_pack.gd`, `radio_model.gd`) and `scripts/ui/radio_screen.gd`, the screen is `scenes/menus/radio.tscn`, and the pack gates are covered by the `J. Radio content packs` section of the headless suite. This document is the rule set the implementation is built against and the contract any future pack must satisfy.
**Applies to:** every audio file that can ever play through the in-game radio, in every distribution channel (Google Play build, sideloaded APK, desktop test build).
**Related:** [`docs/ASSET_LICENSES.md`](ASSET_LICENSES.md) §6–§8 for the asset-register mechanics and the marketplace-licence analysis this policy reuses.

---

## 1. The three permitted sources

A track may enter MUDRO only if it falls into exactly one of these buckets, and the bucket is **evidenced in the pack manifest**, not merely believed by whoever assembled the pack.

| # | Bucket | What qualifies | Required evidence |
|---|---|---|---|
| **A** | **Original / procedurally generated** | Music or ambience produced inside this project: synthesised from oscillators, noise and envelopes by a script in `tools/`, or composed/recorded by the project owner | Generator path + seed/parameters, or the project owner's written statement. No third-party input at all |
| **B** | **User-supplied with written permission** | A track the user owns, or has a signed permission for, delivered as a local Content Pack | Signed permission record (see §9) naming the track, the rights granted, the term and the territory |
| **C** | **Properly licensed clip** | A track under a licence that actually covers this use: commercial, worldwide, in a mobile game, including the right to edit/loop | Licence identifier + URL + the licence text as read on the acquisition date, stored in the pack |

Anything that does not fit A, B or C is **out of policy**, regardless of how it sounds, how short the clip is, or how many people have already used it.

---

## 2. Explicitly forbidden

These are named because they are the failure modes this feature will actually attract:

1. **Ripping audio out of short-form video.** No downloading, screen-recording, stream-capturing or "audio extracting" from YouTube Shorts, Instagram Reels, TikTok, Snapchat Spotlight, Twitter/X, Telegram channels or any similar platform, and no use of the resulting file in a pack. This is prohibited **even when the clip is a few seconds long, has no visible owner, or is described as "free"** in a caption.
2. **Meme and trend audio generally.** A sound that is popular is not a sound that is licensed. "Everyone uses it" is evidence of popularity, not of permission.
3. **Stream-ripping and downloader tools/services.** Using them to obtain the file is itself a breach of the source platform's terms, independent of copyright.
4. **"No copyright infringement intended" disclaimers, credit-in-the-description, or non-commercial framing.** None of these are licences. Attribution is a condition of some licences; it is never a substitute for one.
5. **Unlicensed covers, remixes, edits, nightcore/slowed versions, mashups, or AI voice-clones of a performer.** A cover engages the composition; a remix engages the master recording; a clone engages the performer's voice. Each needs its own permission.
6. **Game, film and trailer audio.** No engine sounds, siren samples, horn recordings or soundtrack cues lifted from another game or a film.
7. **Assume-it-is-fine sourcing.** No "found on a free-sound site without reading the licence", no "the uploader said it was copyright-free", no "it was on a CC search engine" without the licence deed and the attributing page recorded.

If a pack contains any of the above, the **whole pack is rejected**, not just the track — a pack is a unit of provenance (§6.4).

---

## 3. Why the bar is this high

Three independent reasons, all of which bite on a commercially distributed mobile game:

- **Copyright.** A sound recording and the underlying composition are separately owned and separately licensed (in practice: a label/master right and a publishing right). A permission that covers one does not cover the other. A game that ships a track needs both.
- **Source-platform terms.** YouTube's Terms of Use, as served on 2026-11-14, prohibit users from, among other things, *"accéder à, reproduire, télécharger, distribuer, transmettre, diffuser, afficher, vendre, concéder sous licence, altérer, modifier ou utiliser de toute autre façon tout ou partie du Service ou du Contenu"* — access, reproduce, **download**, distribute, transmit, broadcast, display, sell, license, alter or otherwise use the Service or the Content — except where explicitly permitted by the Service, with prior written authorisation from YouTube **and the rights holders**, or as permitted by law ([youtube.com/static?template=terms](https://www.youtube.com/static?template=terms)). Downloading a Short is therefore a terms breach before it is a copyright question.
- **Store policy on downloadable content.** Google Play's developer policy on deceptive behaviour — the article that also governs how apps describe themselves — states that *"Additional app resources (for example, game assets) may only be downloaded if they are necessary for the users' use of the app. Downloaded resources must be compliant with all Google Play policies, and before beginning the download, the app should prompt users and clearly disclose the download size"* ([support.google.com/googleplay/android-developer/answer/9888077](https://support.google.com/googleplay/android-developer/answer/9888077)). A radio pack is exactly such an additional resource: it must be policy-compliant, and if it is ever downloaded rather than sideloaded, the size must be disclosed and the user prompted.

The marketplace research in [`ASSET_LICENSES.md`](ASSET_LICENSES.md) §8 shows the same shape from the other side: every commercial marketplace licence examined (Sketchfab, CGTrader, TurboSquid, Superhive) grants rights **in the asset only** and disclaims or defers responsibility for the third-party rights embedded in it. A radio track is the same problem with a shorter file.

---

## 4. Licence allowlist

For bucket **C**, only these licence families are accepted, and only with the stated conditions. "Royalty-free" is **not** a licence category — it is a pricing model, and each such EULA must be read and its identifier recorded.

| Licence | Radio-usable? | Conditions | Notes |
|---|---|---|---|
| **CC0 1.0** / public-domain dedication | **Yes** | None. Keep the source URL as evidence | Cleanest option; matches the project's own audio stance |
| **CC BY 4.0** (and 3.0) | **Yes** | Attribution to the creator, a link to the licence, and an indication that the track was edited/looped, delivered in-app. Commercial use permitted; adaptation permitted ([creativecommons.org/licenses/by/4.0](https://creativecommons.org/licenses/by/4.0/)) | Accepted only if the attribution can actually be displayed (§5) |
| **CC BY-SA** | **No, by default** | ShareAlike can reach the adapted material | Only with written sign-off that the project accepts share-alike on that element. Treat as blocked |
| **CC BY-ND** | **No** | NoDerivatives; looping, trimming, crossfading and normalising are adaptations in substance | Blocked |
| **CC BY-NC** (any NC variant) | **No** | NonCommercial conflicts with a monetised game, and the boundary of "commercial" in a free-with-IAP build is not one to litigate | Blocked |
| **"Royalty-free" stock / production music** | **Case by case** | Read the EULA: media (games vs broadcast), term, territory, monetisation, whether a separate sync licence is needed for a game, per-track vs per-project | Record the EULA clause and the date |
| **Commissioned work with a signed contract** | **Yes** | Contract must grant worldwide, perpetual, commercial, edit-and-loop rights for interactive media | Store the contract reference |
| **Commercial label releases** | **No** by default | Requires a negotiated sync licence for both master and composition | Out of scope for an indie build without a deal |
| **Platform-sourced audio (Shorts/Reels/TikTok)** | **No** | See §2 | Never |

Two rules that resolve most arguments:

1. **If the licence cannot be named, the track does not ship.** "It was free on the internet" is not a licence identifier.
2. **If the licence text cannot be produced later, the track does not ship.** A URL alone is not enough — marketplace and stock terms change; store the text as read at acquisition.

---

## 5. Track record and attribution

Every track carries a record. These fields are mandatory and map 1:1 onto the manifest (§6.2):

| Field | Required | Purpose |
|---|---|---|
| `title` | yes | Display + audit |
| `artist` / `rights_holder` | yes | Attribution + takedown contact |
| `source_bucket` | yes | `A` / `B` / `C` from §1 |
| `license_id` | yes | e.g. `CC0-1.0`, `CC-BY-4.0`, `PROPRIETARY-EULA-<vendor>`, `OWN-WORK`, `WRITTEN-PERMISSION` |
| `license_url` | for C | Where the licence was read |
| `evidence_path` | yes | Path inside the pack to the stored licence text / permission letter (`.txt` or `.pdf`) |
| `attribution_text` | for CC BY, B, C | The exact string displayed in the radio overlay and the Credits screen |
| `edited` | yes | `true` if looped/trimmed/normalised — CC BY requires indicating changes |
| `duration_s`, `sha256` | yes | Integrity + display |

**Rendering rule:** if `attribution_text` is non-empty, the radio overlay must show it (a "ⓘ" affordance on the now-playing row is sufficient) and the Credits screen must list it. A track whose required attribution cannot be displayed is not playable — the loader must skip it rather than play it unattributed.

**No implied endorsement.** The radio may not state or imply that an artist, label or vehicle manufacturer endorses MUDRO. No artist names, logos or cover art may be used in store listing material without a separate permission — a CC BY licence covers the audio, not the artist's brand.

---

## 6. Content Pack format (offline, outside the APK)

### 6.1 Storage location — and why not `res://`

Packs live **outside** the game package, in the app's user data directory:

```
user://radio_packs/<pack_id>/          # Android: internal app data, not the APK
```

This is not a stylistic choice. `export_presets.cfg:9` sets `export_filter="all_resources"`, so **anything placed under `res://` is packed into the APK**. That is not theoretical: `docs/ASSET_LICENSES.csv` sits in the project, Godot imports it as a translation table (`docs/ASSET_LICENSES.csv.import:3`, `importer="csv_translation"`), and the built `local-builds/android/MUDRO-2.0-debug.apk` contains eight `assets/docs/ASSET_LICENSES.*.translation` resources as a result. A radio pack dropped into `res://` would ride into the APK the same way — bloating the download, and putting third-party audio inside the signed package where a rights holder's first move is to pull the listing.

Rules:

- **R1** — Packs are never referenced by `res://` path. The loader reads only from `user://radio_packs/`.
- **R2** — No pack file may be added to `include_filter` in any export preset.
- **R3** — The base APK ships **zero** third-party audio. All shipped audio remains synthesised (§`ASSET_LICENSES.md` classes 9–10).
- **R4** — If packs are ever distributed by download rather than sideload, the app must prompt before downloading and disclose the size (§3, Play policy), and must not fetch anything at runtime without that prompt.

### 6.2 Directory layout

```
user://radio_packs/
  canyon_drive_v1/
    manifest.json
    LICENSE.txt                 # pack-level licence summary, human readable
    evidence/
      track-01_cc-by_deed.txt   # stored licence text / permission letter
      permission_2026-11-02.pdf
    tracks/
      01_dust_road.ogg
      02_long_climb.ogg
    CHECKSUMS.sha256            # one line per file, sha256sum format
```

### 6.3 `manifest.json` schema (v1)

```json
{
  "schema_version": 1,
  "pack_id": "canyon_drive_v1",
  "display_name": "Canyon Drive",
  "author": "…",
  "created": "2026-11-14",
  "pack_license": "mixed",
  "license_file": "LICENSE.txt",
  "tracks": [
    {
      "id": "01_dust_road",
      "file": "tracks/01_dust_road.ogg",
      "title": "Dust Road",
      "artist": "…",
      "rights_holder": "…",
      "source_bucket": "C",
      "license_id": "CC-BY-4.0",
      "license_url": "https://creativecommons.org/licenses/by/4.0/",
      "evidence_path": "evidence/track-01_cc-by_deed.txt",
      "attribution_text": "\"Dust Road\" by … — CC BY 4.0 — edited (looped, normalised)",
      "edited": true,
      "duration_s": 132.4,
      "sha256": "…",
      "loop": true,
      "loudness_lufs": -16.0
    }
  ]
}
```

Field rules: `schema_version` is mandatory and the loader rejects unknown major versions. `pack_id` must match the directory name. `file` must be a relative path inside the pack — absolute paths, `..` segments and URL schemes are rejected (§6.4, gate 6). Audio formats accepted: `.ogg`, `.wav` only; anything else is refused, which incidentally keeps executables out.

### 6.4 Load-time validation gates

A pack is usable only if **all** gates pass. Failures are reported to the user as "pack rejected: <reason>", never silently ignored.

| # | Gate | Reject condition |
|---|---|---|
| 1 | Manifest present and parseable | missing `manifest.json`, or invalid JSON |
| 2 | Schema | `schema_version` unsupported; required fields absent |
| 3 | Identity | `pack_id` ≠ folder name; duplicate `pack_id` already loaded |
| 4 | Integrity | any `tracks/*` file missing, or `sha256` mismatch |
| 5 | Provenance | `source_bucket` not in {A,B,C}; `license_id` empty; `evidence_path` missing or outside the pack |
| 6 | Containment | any path escaping the pack root (absolute, `..`, symlink, URL); non-allowlisted extension |
| 7 | Attribution completeness | bucket B/C and `attribution_text` empty |
| 8 | Size | pack exceeds the configured cap (proposed 512 MB) |
| 9 | Network | manifest contains any remote URL other than documentation links in `license_url` — the loader never fetches |

Gates 9 and 6 together are what make the feature **offline by construction**: there is no code path that resolves a pack asset from the network, so a pack cannot phone home, auto-update, or pull a substitute track.

### 6.5 Delivery channels

| Channel | Mechanism | Notes |
|---|---|---|
| **Sideload (default)** | User copies the folder into `user://radio_packs/` (or imports a `.zip` that is unpacked into it) | Zero infrastructure, zero Play review risk, keeps the APK clean |
| **Separate download** | Optional, later, explicit user action | Requires the prompt + size disclosure in §3, plus Play compliance review |
| **Bundled in APK** | **Never** | Contradicts R3; makes every future claim a store-level problem |

### 6.6 What a pack must never contain

Executables or scripts of any kind, `.pck`/`.zip` nested archives, remote-fetch instructions, encrypted blobs that cannot be audited, artwork depicting real artists or marques without permission, and any file whose rights are not documented in `evidence/`.

---

## 7. Review and acceptance

Before a pack is listed as official (or bundled with a promo build):

1. **Rights check** — for each track: bucket assigned, licence identified, evidence file present, and (for C) the licence text read on the date recorded. A second person confirms; the pack is rejected if any track is "assumed fine".
2. **Edit check** — if the track was looped, trimmed, normalised or pitch-adjusted, confirm the licence permits adaptation, and confirm `edited: true`.
3. **Attribution check** — play the pack in a build and confirm every non-empty `attribution_text` is visible in-overlay and in Credits.
4. **Offline check** — run with networking disabled; the pack must load and play identically.
5. **Packaging check** — rebuild the APK and list its contents; no pack file, no pack audio, and no `radio_packs` path may appear inside the archive. (Reproduce with the zip-listing snippet in `ASSET_LICENSES.md` §11.)
6. **Register check** — the pack's tracks are not added to `docs/ASSET_LICENSES.csv` as project assets; they are pack content with their own manifest. The register stays a statement about what the project itself owns.

Acceptance for the feature itself: a rejected pack must fail loudly with the gate number, and a pack with a missing attribution must not play — tested as part of the existing headless suite's conventions rather than by manual inspection alone.

---

## 8. Takedown and remediation

- **Contact** — every pack's `LICENSE.txt` names a rights contact; the store listing carries the same address.
- **Response** — on receipt of a plausible claim: disable the pack by `pack_id` (a one-line block list, no rebuild required), preserve the manifest and evidence for the record, respond within 5 working days.
- **Root cause** — a taken-down track is removed from the pack and the pack re-issued with a bumped `pack_id`; the evidence file and the correspondence are retained.
- **Never** — do not "fix" a claim by re-encoding, pitch-shifting or shortening the same recording. That is the same work with extra steps.

---

## 9. What "written permission" must contain (bucket B)

A signed statement, in a durable form (PDF or signed email), that names:

1. the **track** (title, duration, file hash if available) and the **rights holder(s)** — master and composition separately if they differ;
2. the **grant**: worldwide, non-exclusive, perpetual (or a stated term), commercial use, in an interactive mobile game, including the right to **edit, loop, trim and normalise**;
3. the **scope**: which MUDRO products and distribution channels;
4. **credit** wording, or an explicit waiver of credit;
5. a **warranty** that the grantor holds the rights they are granting, and an **indemnity** for third-party claims;
6. **signature, name, role, date**.

A chat message saying "yeah you can use my song" is not this document. It may be evidence of good faith; it is not a licence to rely on.

---

## 10. Non-goals

- This policy does not cover **engine/vehicle SFX**, which remain project-synthesised and are governed by `ASSET_LICENSES.md`.
- It does not cover **streaming radio, podcasts, or user-supplied URLs**. Those introduce network dependence and a different rights surface; if ever considered, they need their own policy.
- It does not authorise **any change to the shipped pack gates** without a matching change to §6.4 and the tests in `tests/test_runner.gd`.

---

## 11. Open decisions

1. **Pack cap** — the 512 MB figure in gate 8 is a placeholder; pick a number that keeps a sideloaded pack under a tolerable storage footprint on the target device (Galaxy A23 class).
2. **Format** — OGG Vorbis is proposed for size; if the project standardises on WAV for consistency with `assets/audio/`, revisit gate 8.
3. **Attribution surface** — overlay-only is the minimum; decide whether Credits must also list every pack track or only the currently loaded pack.
4. **Localisation** — `attribution_text` is a single string; if packs are shared across the Persian-first and English UI, decide whether the manifest needs `attribution_fa` alongside it.
