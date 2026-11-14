# MUDRO — Asset Provenance and Licensing Audit

**Project:** MUDRO — Offroad Physics (Godot 4.7.2, Android, `com.khiyarusa.mudro`)
**Audit date:** 2026-11-14
**Scope:** every file class under `assets/**`, plus the launcher icon, the bundled typeface and the engine notice.
**Method:** filesystem inventory, git history, generator source inspection, binary metadata of the font and the WAV headers, and a direct listing of the built APK. Every claim below is tied to a path, a line number or an APK entry. Nothing here is inherited from the previous revision of this document; where that revision's machine-readable register disagreed with disk, it is recorded as gap G4 (§6).

> **Snapshot notice.** This repository was being actively edited during the audit: between the first inventory and the final pass, five vehicle asset folders and `tools/artgen/vehicles_v3.py` appeared in the working tree. All figures below describe disk state at the **final** pass. If the 3.0 work continues, re-run §11 before relying on the counts.

> This is an engineering provenance audit, not legal advice. The jurisdictional questions it raises (§7, §8) should be confirmed by counsel before a commercial release.

---

## 1. Conclusions

1. **No third-party art, audio, model, texture, HDRI or icon pack is present in the repository.** The only third-party *asset* is one typeface family, **Vazirmatn (4 weights, SIL OFL 1.1)**; the only other third-party component is the **Godot Engine (MIT)**. Every SVG and every WAV under `assets/` was produced for this repository: the audio, environment art and UI art are emitted by generator scripts that are also in the repository (§4), and the eight shipped 2.0 vehicle sprites are project-origin art whose generator is no longer recorded (G3). **Confidence: high** — established by file inventory, by generator-to-filename matching (§4), and by a negative search for third-party pack names, download markers and licence texts (§2).
2. **`assets/` contains exactly four file types: `.svg`, `.ttf`, `.wav`, `.json`.** There is no raster image, no 3D file, and no sampled-audio container anywhere in the shipped asset tree. **Confidence: high** (command output in §2).
3. **Three compliance defects exist today, all cheap to fix:** the OFL licence text is not stored next to the font (G1), the licence register itself is compiled into the shipped APK as eight translation resources (G2), and the engine credit is a bare licence name rather than the MIT notice or Godot's sanctioned link (G5). None of them affects ownership.
4. **The largest licensing risk in this project is not asset licensing at all — it is vehicle branding.** The shipped 2.0 build is clean (fictional names, and a byte search of the APK finds none of the 3.0 model codes). The uncommitted 3.0 work depicts five **real, named production vehicles** (`SUZUKI JIMNY 1.5`, `TOYOTA HILUX 2.8 GD-6`, `NISSAN PATROL Y61`, `MITSUBISHI PAJERO 3.2 DiD`, `TOYOTA LAND CRUISER 79`) and now carries generated sprites for them, so the question is live rather than hypothetical. A marketplace or self-made model licence would not cover those manufacturers' trademark and design rights. **Confidence: high** for the facts; the legal exposure assessment is §7.

---

## 2. What was actually verified

Inventory, excluding Godot import sidecars (`.import`, `.uid`):

| Class | Path | Files | Total bytes |
|---|---|---:|---:|
| Vehicle sprites | `assets/vehicles/**` | 18 | 263,695 |
| Environment art | `assets/environments/**` | 36 | 1,384,307 |
| UI art | `assets/ui/**` | 63 | 300,264 |
| Fonts | `assets/fonts/**` | 4 | 491,820 |
| Audio | `assets/audio/**` | 46 | 5,511,878 |
| i18n | `assets/i18n/**` | 2 | 21,821 |
| Launcher icon | `icon.svg` | 1 | 19,573 |

Breakdown that reconciles with the generators:

- **Vehicle sprites 18** = 9 vehicles × (`body.svg` + `wheel.svg`): the four shipped 2.0 vehicles plus the five 3.0 vehicles now present in the working tree (§7).
- **Environment art 36** = 20 parallax layers (4 regions × `sky/far/mid/near/ground`) + 16 props in `assets/environments/common/`.
- **UI art 63** = 42 icons in `assets/ui/icons/` + 20 control skins in `assets/ui/controls/` + `assets/ui/emblem.svg`.

Negative checks (all returned empty):

- Search for third-party pack and marketplace markers across all text files: `kenney`, `polyhaven`, `quaternius`, `sketchfab`, `blendermarket`, `cgtrader`, `turbosquid`, `opengameart`, `freesound`, `pixabay`, `freepik`, `flaticon`, `cc0`, `creative commons`, `public domain`, `downloaded`, `purchased`, `royalty` — the only hits are in this project's own credits and licence-register text (i.e. the documents that assert originality), never in code that could reveal a source.
- Licence-text files anywhere in the tree (`*licen*`, `*copying*`, `*OFL*`, `*attribut*`, `*credits*`): the only hits are the project's own `docs/ASSET_LICENSES.*`, `scripts/ui/credits_screen.gd`, the credits screenshot and Godot editor cache. **No third-party licence file exists.**
- Non-SVG/TTF/WAV/JSON files under `assets/`: **none**.
- Raster/3D/audio-container extensions (`.png .jpg .webp .blend .fbx .obj .glb .gltf .hdr .exr .mp3 .ogg .flac .psd .ai .otf .woff`) anywhere outside `.godot/` and the local engine install: only **documentation screenshots** (`docs/screenshots/`) and **build artefacts** (`local-builds/previews/`, `local-builds/screenshots*/`, `local-builds/art_build/*.png`). None of them is an input asset.

---

## 3. Master register

Licence shorthand: **CC0-P** = CC0 1.0 as *declared by this project over its own output* (a project policy statement, not a licence received from anyone). **OFL-1.1** = SIL Open Font License 1.1.

| # | Class | Path / glob | How it was produced | Creator | Licence status | Attribution required | Commercial use |
|---|---|---|---|---|---|---|---|
| 1a | Vehicle sprites — shipped 2.0 set (SVG) | `assets/vehicles/{rocky_buggy,ranger_4x4,dune_pickup,titan_offroad}/{body,wheel}.svg` (8) | Hand-authored vector art, committed in `8575006`; **no generator script emits these files** (see G3) | MUDRO project | Project-owned → CC0-P | No | Yes, unrestricted |
| 1b | Vehicle sprites — 3.0 set (SVG) | `assets/vehicles/{jimny_jb74,hilux_an120,patrol_y61,pajero_v80,lc79}/{body,wheel}.svg` (10) | `tools/artgen/vehicles_v3.py` — deterministic, byte-identical between runs (`:29`); models named at `:733-886` | MUDRO project | Project-owned art → CC0-P, **but the depicted vehicles are subject to third-party rights (see §7)** | No (for the art) | Yes for the art; **the depicted marques are a separate clearance question** |
| 2 | Environment parallax layers (SVG) | `assets/environments/{canyon,pine,quarry}/*.svg` | `local-builds/art_build/{canyon,pine,quarry}.py` — deterministic SVG emitters, 5 layers each | MUDRO project | Project-owned → CC0-P | No | Yes, unrestricted |
| 3 | Environment — Black Ridge layers (SVG) | `assets/environments/black_ridge/{sky,far,mid,near,ground}.svg` | `tools/artgen/black_ridge.py` (declared at lines 1919–1923) | MUDRO project | Project-owned → CC0-P | No | Yes, unrestricted |
| 4 | Environment props (SVG) | `assets/environments/common/*.svg` (16) | 10 from `local-builds/art_build/decor.py`, 6 from `tools/artgen/black_ridge.py` (lines 1924–1929) | MUDRO project | Project-owned → CC0-P | No | Yes, unrestricted |
| 5 | UI icons (SVG) | `assets/ui/icons/*.svg` (42) | `local-builds/art_build/icon_set.py` — 42 `add("name", …)` calls, matching 42 files | MUDRO project | Project-owned → CC0-P | No | Yes, unrestricted |
| 6 | UI control skins (SVG) | `assets/ui/controls/*.svg` (20) | `tools/artgen/controls.py` — 20 output filenames, exact match | MUDRO project | Project-owned → CC0-P | No | Yes, unrestricted |
| 7 | Emblem + launcher icon (SVG) | `assets/ui/emblem.svg`, `icon.svg` | `local-builds/art_build/icon_set.py` (`emblem_svg()`, `UI_DIR`) | MUDRO project | Project-owned → CC0-P | No | Yes, unrestricted |
| 8 | Typeface (TTF) | `assets/fonts/Vazirmatn-{Regular,Medium,Bold,Black}.ttf` | Upstream release v33.003, unmodified | The Vazirmatn Project Authors / Saber Rastikerdar | **OFL-1.1** | **Yes** — copyright notice + licence (G1) | Yes, inside software; may not be sold standalone |
| 9 | Audio — base set (WAV) | 27 of `assets/audio/*.wav` | `tools/asset_processing/gen_audio.gd` (`OUT_DIR`, line 29; asset table lines 90–110) | MUDRO project | Project-owned → CC0-P | No | Yes, unrestricted |
| 10 | Audio — 2.0 set (WAV) | 19 of `assets/audio/*.wav` | `tools/artgen/audio_v2.py` (`@asset(...)` decorators; `AUDIO_DIR`, line 55) | MUDRO project | Project-owned → CC0-P | No | Yes, unrestricted |
| 11 | Localisation strings | `assets/i18n/{en,fa}.json` | Authored in-repo / merged by `tools/i18n_merge.py` | MUDRO project | Project-owned → CC0-P | No | Yes, unrestricted |
| 12 | Engine (shipped binary) | Godot 4.7.2 stable | Upstream engine | Godot Engine contributors | **MIT** | **Yes** — engine copyright + licence notice in documentation | Yes |

Machine-readable twin: [`docs/ASSET_LICENSES.csv`](ASSET_LICENSES.csv).

---

## 4. Generator evidence (the load-bearing part)

Provenance for classes 1b, 2–7, 9–10 is not asserted from documentation; it was checked by extracting every filename a generator can write and diffing that set against the files on disk.

**Vehicles (3.0) — generated, and the generator names its subjects.** `tools/artgen/vehicles_v3.py` declares `ASSET_DIR = "assets/vehicles"` (`:47`), writes `body.svg` + `wheel.svg` per vehicle, and states in its header that *"Output is byte-identical between runs (no randomness)"* (`:29`). Its vehicle definitions carry explicit model strings — `model="Toyota Land Cruiser 79 pickup (2023)"` (`:734`), `"Nissan Patrol Y61 wagon (2010)"` (`:774`), `"Toyota Hilux double cab (2018)"` (`:810`), `"Suzuki Jimny 3-door (2020)"` (`:851`), `"Mitsubishi Pajero 5-door (2012)"` (`:886`). That is a deliberate depiction of real vehicles, not an incidental resemblance — see §7 for why this is the project's main legal exposure.

**Audio — 46/46 files accounted for.** `gen_audio.gd` declares 27 names (`"name": "….wav"` entries, lines 90–110); `audio_v2.py` declares 19 (`@asset("…")`, with the header stating "19 new assets", lines 4–5). The union is exactly the 46 files present, and **no file is unexplained** — the diff of "on disk minus declared" is empty in both directions. The same split is stated by the generator headers themselves: `audio_v2.py:4-5` — *"19 new assets: 44100 Hz, mono, 16-bit PCM WAV, no DC, peak-normalised to -3.0 dBFS. Existing files in assets/audio are never touched"*.

**Audio is synthesised, not sampled.** Header inspection of four representative files returns `fmt=1 ch=1 rate=44100 bits=16` (`engine_buggy.wav`, `ui_click.wav`, `ambience_canyon.wav`, `winch_loop.wav`) — mono 16-bit PCM at 44.1 kHz, matching the generators' stated output format. Nothing in the tree is MP3/OGG/FLAC or a sampler artifact.

**UI — exact set match.** `tools/artgen/controls.py` writes exactly the 20 filenames present in `assets/ui/controls/` (`frame_plate`, `gate_knob`, `gate_panel`, `icon_drivetrain`, `icon_gear`, `icon_suspension2`, `icon_weather`, `icon_winch`, `pad_brake`, `pad_clutch`, `pad_handbrake`, `pad_pressed`, `pad_recover`, `pad_start`, `pad_throttle`, `pedal_brake`, `pedal_clutch`, `pedal_throttle`, `slider_knob`, `slider_rail`). `icon_set.py` contains 42 distinct `add("…")` icon definitions against 42 files on disk, and builds the emblem and launcher icon from `emblem_layers()`/`UI_DIR` (`icon_set.py:14-15`, `:483-549`).

**Environments — exact set match.** `black_ridge.py:1919-1929` lists its 11 outputs (5 layers + `industrial_barrier`, `ore_cart`, `pipe_stack`, `ash_rock`, `floodlight`, `steel_bridge`). `canyon.py`/`pine.py`/`quarry.py` emit `sky/far/mid/near/ground` into `OUT = "assets/environments/<region>"` (`canyon.py:7,685-691`; `pine.py:7`; `quarry.py:8`); `decor.py` emits the 10 common props (`decor.py:6,612-620`). 25 + 11 = 36, matching disk.

**The generators are self-contained and deterministic** — this is what makes the "no third-party input" claim verifiable rather than a promise:

- `controls.py:11-13` — *"All artwork is emitted from this file: no external references, no fonts, no raster images and no SVG filters … Output is pure function of the constants below - no timestamps, no RNG without a fixed seed."*
- `black_ridge.py:7-17` — *"the only SVG features used are paths, polygons, ellipses, rects, groups, linearGradient, radialGradient and opacity. No filters, no raster, no fonts, no external references … The script is deterministic: every file uses its own seeded RNG, so repeated runs produce byte-identical output."*
- `artlib.py:1-6` — shared painter emitting only SVG 1.1 primitives.
- `audio_v2.py:60-68` — RNG seeded from `sha256(tag)`, so each asset is reproducible and independent of run order.

**Structural corroboration:** no SVG in the tree contains `inkscape`, `adobe`, `illustrator`, a `generator` attribute, `base64`, or an `<image>` element. The files carry no export signature from any graphics application, which is consistent with script emission and inconsistent with an asset-pack download.

---

## 5. The one third-party asset: Vazirmatn

Read from the font binaries themselves (embedded name and licence metadata), not from the folder name:

- Copyright string: `Copyright 2015 The Vazirmatn Project Authors (https://github.com/rastikerdar/vazirmatn)`
- Version: `Version 33.003` (all four weights)
- Licence field: `This Font Software is licensed under the SIL Open Font License, Version 1.1 … https://scripts.sil.org/OFL`
- Additional embedded note: Latin glyphs in the full family derive from **Roboto Variable v3.004 under Apache-2.0**; the original Vazir design began from DejaVu 2.35 (public domain).

Upstream licence text, as actually read: <https://raw.githubusercontent.com/rastikerdar/vazirmatn/master/OFL.txt>. OFL-1.1 conditions that matter here:

- **Condition 2** — the font may be bundled and redistributed with software *"provided that each copy contains the above copyright notice and this license"*, and the notice may live in *"machine-readable metadata fields within text or binary files as long as those fields can be easily viewed by the user"*.
- **Condition 1** — the font may not be sold by itself.
- **Condition 5** — the font must remain under OFL; this does **not** extend to the game.

**Status in this repo:** the in-app Credits screen already carries the attribution in Persian and English (`scripts/ui/credits_screen.gd:17-18` and `:38-39`), and the font's own metadata carries the copyright and the licence URL. That satisfies the attribution requirement in substance. What is missing is the licence **text file** in the distribution (G1).

---

## 6. Compliance gaps found

**G1 — OFL licence text is not shipped with the font.** `assets/fonts/` contains only the four `.ttf` files and their `.import` sidecars; there is no `OFL.txt`. OFL-1.1 condition 2 permits notice carried in the font's own machine-readable metadata, and that metadata does contain the copyright line and the licence URL — so this is arguably compliant in substance — but it is the weaker reading of a condition that also says the notice must be *easily viewed by the user*, and the fix is a single file. **Recommendation:** add `assets/fonts/OFL.txt` (verbatim upstream text) and reference it from the Credits screen. Confidence that the file is absent: **certain**.

**G2 — the licence register ships inside the APK.** `docs/ASSET_LICENSES.csv` is inside the project tree, so Godot imports it as a translation table: `docs/ASSET_LICENSES.csv.import:3` reads `importer="csv_translation"` and lists eight `docs/ASSET_LICENSES.*.translation` dependency files. With `export_presets.cfg:9` set to `export_filter="all_resources"`, those resources are packed. **Verified in the built artefact:** `local-builds/android/MUDRO-2.0-debug.apk` (35,996,516 bytes, 2026-11-13) contains `assets/docs/ASSET_LICENSES.{type,path,source,creator,license,commercial,attribution,modifications}.translation`. Confidence: **certain** (direct zip listing). This matters twice: the register is public in every install, and it proves that "a file lives in the repo folder" does **not** mean "it stays out of the APK" — the exact trap the radio Content Pack format must avoid (see `docs/RADIO_CONTENT_POLICY.md` §6.1).
*Note:* this CSV is documentation. Godot's importer treats any project `.csv` as translations, so replacing it changes the key columns that become translation keys. If that is undesirable, move the register outside `res://` or set an explicit `.csv` import skip. **Out of scope for this audit — no project settings were changed.**

**G3 — the eight shipped 2.0 vehicle SVGs have no recorded production method.** No script in the repository emits `assets/vehicles/{rocky_buggy,ranger_4x4,dune_pickup,titan_offroad}/{body,wheel}.svg`; they were added wholesale in commit `8575006`. They are consistent with the rest of the art (same viewBox conventions, ThorVG-safe feature set, no external signatures), and there is no evidence of a third-party origin, but the audit can only establish "authored for this project", not "generated by script X". The 3.0 set does **not** share this gap — `tools/artgen/vehicles_v3.py` covers it (§4). Confidence in "project-origin": **high**; in "hand-drawn vs generated": **unrecorded**.

**G4 — the previous CSV register was incomplete (superseded by this document).** The prior `docs/ASSET_LICENSES.csv` had 23 rows and covered vehicles, the three region layer sets, ten common props, the icon set, the emblem, the launcher icon, three audio groups, the fonts and the engine. It had **no rows for** the 20 control skins (`assets/ui/controls/`), the 11 Black Ridge outputs (`assets/environments/black_ridge/` plus six props in `common/`), the 19 `audio_v2.py` assets, or the two locale files — i.e. it predated the 2.0 art and audio pass and was never extended. Its summary prose in the old `.md` was consistent with disk (44 = 42 icons + emblem + launcher; 27 + 19 = 46 audio), so this is an omission problem, not a miscount problem. Fixed by the 21-row register shipped alongside this document.

**G5 — the engine credit is a licence name, not the notice.** `scripts/ui/credits_screen.gd:6` and `:27` say `Godot Engine 4.7.2 Stable (MIT license)` / `(مجوز MIT)`. MIT's condition is that *the copyright notice and permission notice* accompany copies of the Software; a bare licence name is not that notice. Godot's own guidance offers an easy out — <https://godotengine.org/license/> states the developers *"consider that a link to this page (godotengine.org/license) in your game documentation or credits would be an acceptable way to satisfy the license terms"* — but no such link is present in the credits screen. **Recommendation:** add the link (one line) or ship the MIT text in the Credits screen / an in-app licences page.

---

## 7. Vehicle branding: the real exposure

**What ships today (2.0):** fictional names only — Rocky Buggy, Ranger 4x4, Dune Pickup, Titan Offroad. No manufacturer logos or badges exist anywhere in `assets/**` (no raster files at all, and no brand strings in any shipped asset; the i18n note at `assets/i18n/en.json:114` asserts original artwork and is accurate for 2.0).

**What is in the working tree for 3.0 (uncommitted, untracked):** `scripts/vehicle/vehicle_catalog.gd` builds five vehicles from real, current-production models, with manufacturer strings and real trim designations:

| Line | `id` | Display name | `manufacturer` |
|---|---|---|---|
| `:23` | `jimny_jb74` | `SUZUKI JIMNY 1.5` | Suzuki |
| `:112` | `hilux_an120` | `TOYOTA HILUX 2.8 GD-6` | Toyota |
| `:203` | `patrol_y61` | `NISSAN PATROL Y61 3.0 Di` | Nissan |
| `:294` | `pajero_v80` | `MITSUBISHI PAJERO 3.2 DiD` | Mitsubishi |
| `:385` | `lc79` | `TOYOTA LAND CRUISER 79 4.5 V8` | Toyota |

The sprite directories for those five ids **now exist** and hold generated sprites (`assets/vehicles/{jimny_jb74,hilux_an120,patrol_y61,pajero_v80,lc79}/`, 2 SVG each, produced by `tools/artgen/vehicles_v3.py`, whose definitions name the real models at `:733-886`). So 3.0 is no longer a broken asset reference — it is a complete, renderable depiction of five real production vehicles, sitting untracked in the working tree.

**What the shipped build contains is a different question, and the answer is clean.** A byte search of `local-builds/android/MUDRO-2.0-debug.apk` returns **0** occurrences of `jimny_jb74`, `hilux_an120` and `TOYOTA HILUX`, and 6 each of `rocky_buggy` and `titan_offroad`. The 2.0 artefact therefore carries only fictional identities; the exposure arrives with the next build unless the branding is decided first. Supporting research is in `docs/VEHICLE_SPEC_SOURCES.md` (172 brand mentions) and `local-builds/research/vehicle_specs.json` (90), which cite manufacturer brochures.

Two distinctions that are easy to conflate, and should not be:

1. **Engineering data is not the problem.** Power, torque, ratios and kerb weights are facts; a specification table is not protected by copyright in the way an image is, and using published figures as simulation input is ordinary practice.
2. **Brand identity is the problem.** Model names, badges, grille and silhouette trade dress, and the "look" of a recognisable vehicle are trademark / design-right subject matter that exists **independently of any model file you might buy or draw**. See §8.3.

**Also flagged, lower severity:** the shipped names `Ranger 4x4` and `Titan Offroad` are generic English words but are also model names of the Ford Ranger and Nissan Titan. Combined with "4x4"/"Offroad" and no badges or logos they are unlikely to be read as brand references, but a naming review before store submission is cheap insurance.

---

## 8. Research: what asset marketplaces actually permit for a commercial mobile game

Every statement below is taken from a page read during this audit (URLs given). Where a page could not be retrieved, that is stated rather than filled in from memory.

### 8.1 Summary table

| Source | Licence model | Commercial game OK? | Attribution | Standalone redistribution | Key catch |
|---|---|---|---|---|---|
| **polyhaven.com** | CC0 for all HDRIs, textures, models | Yes, explicitly | Not required | Permitted | None for the assets; site *content* (logos, renders) is not CC0 |
| **quaternius.com** | CC0 for all packs | Yes, explicitly | Not required | Not restricted | None material |
| **kenney.nl** | CC0 ("public domain") | Yes, explicitly | Not required; do not use their logo | Not restricted | Logo is reserved to the studio |
| **sketchfab.com** (Store) | Royalty-free "Standard", or "Editorial" | Standard: yes. Editorial: **no** | Conditional credit clause | **Prohibited** as standalone file | Licensor gives **no** warranty for depicted trademarks/designs |
| **sketchfab.com** (free downloads) | Creative Commons — CC BY is the baseline, with NC/ND/SA added optionally | Yes only if no NC | **Yes**, always | Depends on the CC variant | Attribution cannot be switched off; a free download is never attribution-free |
| **blendermarket.com** (now Superhive) | Royalty Free | Yes | Not required by the RF text | **Prohibited** to resell/redistribute/repack | Cannot be used in a logo, watermark or trademark |
| **cgtrader.com** | Royalty Free / RF-no-AI / Editorial / Custom | Yes, as "Incorporated Product" only | Not required by RF text | **Prohibited** | For software you must take *"all commercially reasonable measures"* to stop end users reaching the file |
| **turbosquid.com** | Royalty Free unless otherwise noted; some models are Editorial | RF: yes. Editorial-marked models carry extra restrictions | Per licence | Prohibited | Manufacturer-branded content sits under separate Ford / GM / Saleen agreements |

### 8.2 What each page actually says

**Poly Haven — <https://polyhaven.com/license>.** *"All assets (HDRIs, textures and 3D models) on this site are the original work of Poly Haven staff… Our assets are all licensed as CC0, which is effectively Public Domain"*, and explicitly: *"You can use our assets for any purpose, including commercial work… You do not need to give credit… You can redistribute them… or even in a product you sell."* Their ToS reserves only the site's own content (logos, example renders, copy).

**Quaternius — <https://quaternius.com/faq.html>.** *"Yes, these assets can be used for free without the need for attribution in commercial, educational, and personal projects. All models are under the CC0 License."* Modification is allowed; attribution *"is not necessary"*.

**Kenney — <https://kenney.nl/support>.** *"Yes, all game assets on the asset pages are public domain licensed (CC0). You're free to use them, even in commercial projects."* Attribution *"is not required"*, and: *"Do not use our logo, as it is reserved for official projects by our studio."* (The standalone FAQ page <https://kenney.nl/faq> confirms commercial use and that any credit form is acceptable.)

**Sketchfab — <https://sketchfab.com/licenses>.** Two very different regimes:

- *Editorial* assets *"cannot be used for any commercial or promotional use"*, cannot suggest brand association, and may only appear in works that comment on or criticise the subject.
- *Standard* assets are royalty-free but carry hard restrictions: no use *"in a way that allows others to use or access the 3D asset as a stand-alone file"*; no distribution of a derivative *"so similar to the original … that the Licensee Work cannot qualify as an original work of authorship"*; no incorporation *"into a logo, corporate name, trademark"*; and no use that *"violates anyone's intellectual property rights"*.
- Decisive for vehicle work — **§4 Releases**: *"Licensor does not grant any right or make any warranty with regard to the use of names, people, trademarks, trade dress, logos or registered, unregistered or copyrighted audio, designs or works of art or architecture depicted in any Licensed Material."* The buyer is *"solely responsible for determining whether release(s) … is/are required"*.
- Free downloads are a separate track with attribution welded on: per Sketchfab's own explainer <https://sketchfab.com/blogs/community/an-introduction-to-creative-commons-licenses>, *"CC BY – Attribution (default, always on) … cannot be changed"*, with optional NC/ND/SA added on top. The article lists no attribution-free option for free downloads.

**Blender Market / Superhive — <https://superhivemarket.com/page/royalty-free-license>.** *"This license grants you … the ability to make use of the purchased product for personal, educational, and or commercial purposes"*, subject to: *"You may not resell, redistribute, or repackage the purchased product without explicit permission from the original creator"* and *"You may not use the purchased product in a logo, watermark, or trademark of any kind."* Commercial games are therefore fine; shipping the source `.blend` alongside is not. (The legacy `blendermarket.com/pages/...` URLs now redirect to the Superhive storefront, which is why the licence text is only readable on the `superhivemarket.com/page/...` host.)

**CGTrader — <https://www.cgtrader.com/pages/terms-and-conditions>.** The most explicit of the set about software products:

- §21A.2: the licence *"is strictly limited to Incorporated Product"*; use that is not incorporated is *"strictly prohibited"*.
- **§21A.3:** *"If you use any Product in software products (such as video games, simulations, or VR-worlds) you must take all commercially reasonable measures to prevent the end user from gaining access to the Product."* — i.e. a shipped game must not expose the model file.
- §20.4: *"Buyers do not own any Product"*; the seller retains copyright.
- §22: products marked *"editorial"* may be used only for journalistic/editorial purposes.
- §18.2: releases are the **seller's** warranty, which is precisely why a buyer cannot assume a licensed car model carries manufacturer permissions.

**TurboSquid — <https://resources.turbosquid.com/general-info/terms-agreements>** and **<https://www.turbosquid.com/help/en/articles/9937424-editorial-use-information>.** The index page states *"TurboSquid products are Royalty Free unless otherwise noted"* and points to the 3D Model License as *"the final and authoritative agreement"*. The help-centre article on editorial use lists related articles **"Associated Brands Information"**, **"Ford License: Editorial"**, **"SHELBY LICENSE: EDITORIAL"**, **"FORD + SHELBY LICENSE: EDITORIAL"**; the index separately lists a **Ford Artist Agreement**, a **General Motors Artist Agreement** and a **Saleen Automotive Artist Agreement**. *Retrieval gap:* the full 3D Model License text did not load through the fetch tool on this run (`turbosquid.com/licensing` and the resource sub-pages returned empty bodies), so the specific clause wording is **not verified here** — only the royalty-free claim and the existence/character of the brand-specific agreements are.

### 8.3 A 3D model licence is not a vehicle licence

The clean way to hold this: **four separate rights can attach to one car, and an asset marketplace can only sell you the first.**

1. **Copyright in the model file** — the artist's mesh, textures, UVs. This is what Sketchfab, CGTrader, TurboSquid and Superhive license.
2. **Trademark** — the marque and model name, the badge, and in some markets the distinctive grille or silhouette as trade dress. Used to identify the source of goods; a game that labels a car "TOYOTA HILUX" uses that mark in commerce.
3. **Registered/unregistered design rights** — the shape of a body panel or lamp can be protected as a design (EU/UK registered and unregistered design right; US design patents). This is about the *appearance*, and it exists whether the model was bought, drawn by hand, or generated.
4. **Patents and other rights** — mechanical implementations, and separately personality/venue rights for people and places.

Marketplaces say this themselves, which is the strongest available evidence that the gap is real rather than theoretical:

- Sketchfab, §4: the licensor warrants **nothing** about *"trademarks, trade dress, logos … designs"* depicted, and puts release-checking on the buyer.
- CGTrader, §18.2: releases are the seller's representation, and buyers are told to consult their own advisers.
- TurboSquid: maintains **separate** Ford/GM/Saleen artist agreements and Ford/Shelby editorial-only licences — i.e. the platform treats manufacturer permission as a distinct permission it must negotiate, not something the standard model licence conveys.

**Consequence for MUDRO.** Buying or making a Hilux-shaped model would settle right (1) and settle nothing about (2) or (3). Conversely, using manufacturer **specification figures** engages none of (1)–(3); the risk sits in the **name and the visual identity**, not the numbers. That is why the 3.0 naming table in §7 is the item to decide, and why the 2.0 fictional-name approach was the safer design.

**Practical options, cheapest first:** (a) keep fictional names and non-derivative silhouettes — what 2.0 already does, zero cost; (b) keep real engineering data but rename — e.g. model the LC79's drivetrain under an invented marque; (c) seek written permission from each manufacturer — slow, usually refused for small studios, and not something a marketplace purchase substitutes for; (d) rely on nominative fair use — narrow, jurisdiction-specific, and a poor foundation for content that is the core of a commercial product.

---

## 9. Ownership note on the project's own assets

The register marks classes 1–7, 9–11 as **CC0-P**: a declaration by the project over output it controls. Two caveats worth recording so the claim is not over-read:

- **Godot's own position is helpful here.** <https://godotengine.org/license/> states: *"Godot Engine's license terms and copyright do not apply to the content you create with it; you are free to license your games how you see best fit, and will be their sole copyright owner(s)."* Nothing in the engine's MIT licence reaches the art or audio.
- **Wholly automated output may attract no copyright at all in some jurisdictions,** because human authorship is a precondition (the US Copyright Office position is the best-known example). If no copyright subsists, a CC0 dedication is a no-op rather than a mistake — but it also means the "we own this and license it to you" framing in the Credits screen is doing less work than it appears to. Nothing here needs to change for shipping; it matters only if the art is ever marketed as a reusable asset pack.

---

## 10. Obligations checklist before a commercial release

| # | Obligation | Status |
|---|---|---|
| 1 | Vazirmatn copyright + OFL notice reachable by the user | **Met** in-app (`credits_screen.gd:17-18,38-39`); licence **text file** missing (G1) |
| 2 | Godot Engine MIT notice in documentation | **Partially met** — engine named with its licence (`credits_screen.gd:6,27`); no MIT notice text and no `godotengine.org/license` link (G5) |
| 3 | No third-party asset used without recorded provenance | **Met** — nothing third-party except the font |
| 4 | No manufacturer logo, badge or trade dress in shipped art | **Met for the shipped 2.0 APK** (verified by byte search); **open for 3.0** — real-model sprites now exist in the working tree (§7) |
| 5 | Vehicle naming cleared for trademark | **Met for 2.0** (fictional; review "Ranger"/"Titan"); **open for 3.0** |
| 6 | Licence register not silently published inside the APK | **Not met** (G2) |
| 7 | Radio audio provenance regime | **Open** — see `docs/RADIO_CONTENT_POLICY.md` |

---

## 11. Reproducing this audit

```powershell
# 1. inventory + counts per class
Get-ChildItem assets -Recurse -File | Where-Object { $_.Extension -notin '.import','.uid' } |
  Group-Object Extension | Select-Object Name,Count

# 2. third-party markers (expect no hits)
Get-ChildItem -Recurse -File -Include *.gd,*.py,*.md,*.json,*.cfg,*.csv |
  Select-String -Pattern 'kenney|polyhaven|quaternius|sketchfab|cgtrader|turbosquid|opengameart|freesound|cc0'

# 3. audio: generator-declared names vs disk (expect empty diff both ways)
Select-String tools/asset_processing/gen_audio.gd -Pattern '"name":\s*"([a-z0-9_]+)\.wav"'
Select-String tools/artgen/audio_v2.py      -Pattern '@asset\("([a-z0-9_]+)"'

# 4. font licence metadata
$b=[IO.File]::ReadAllBytes("assets/fonts/Vazirmatn-Regular.ttf")
[Text.Encoding]::BigEndianUnicode.GetString($b) -match 'SIL Open Font License'

# 5. what the APK actually ships
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::OpenRead((Resolve-Path 'local-builds/android/MUDRO-2.0-debug.apk')).Entries |
  Where-Object { $_.FullName -like '*ASSET_LICENSES*' } | Select-Object FullName,Length
```

---

## 12. Open items

1. **Decide the 3.0 vehicle branding** (§7). Highest-value action in this document.
2. **Add `assets/fonts/OFL.txt`** (G1) and **the engine notice or its sanctioned link** (G5) — two small edits that close the only live attribution gaps.
3. **Keep the register out of the export** (G2) — move it, or exclude `.csv` from import; verify by re-listing a rebuilt APK.
4. **Record the production method for the eight 2.0 vehicle SVGs** (G3) so the next audit does not have to say "unrecorded".
5. **If any purchased asset is ever added,** adopt the CGTrader-style bar as house policy: no extractable standalone files, a per-asset row in this register, and a saved copy of the licence page as it read on the purchase date (marketplace terms change).
