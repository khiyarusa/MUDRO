# ممیزی پایهٔ نسخهٔ ۲.۰ — MUDRO

**دامنه:** ساختِ commitشده در `git HEAD` روی شاخهٔ `feat/mudro-full-game` — پیش از بازنویسی ۲.۰.
**کامیت پایه:** `8575006d4a3b786309519967aa443e20e285ac2a` — *feat(mudro): build complete off-road physics game* — ۱۳ نوامبر ۲۰۲۶، ۱۷:۲۷.
**تاریخ ممیزی:** ۱۳ نوامبر ۲۰۲۶.
**قاعدهٔ شاهد:** هیچ ادعایی در این سند به درختِ کاریِ در حال ویرایش ارجاع نمی‌دهد. همهٔ ارجاع‌های `file:line` به نسخهٔ داخل worktree پاک (برابر با HEAD) اشاره می‌کنند.

---

## ۰. خلاصهٔ اجرایی

| پرسش | پاسخِ اندازه‌گیری‌شده |
|---|---|
| تست‌های headless در HEAD | **۶۸ قبول، ۰ رد** (`TESTS: 68 passed, 0 failed`)، کد خروج ۰، ۶۴٫۲ ثانیه |
| اسکرین‌شات تازه | **۱۲ تصویر** ۱۲۸۰×۷۲۰ در `local-builds/screenshots-v2/baseline/` |
| نقص‌های تأییدشده | **۱۴ مورد** (۴ بالا، ۶ متوسط، ۴ پایین) |
| ادعاهای هندسی کنترل لمسی | ۳ مورد **رد شد**، ۶ مورد **تأیید شد**، ۱ مورد در HEAD **قابل اعمال نیست** |
| تست روی دستگاه واقعی توسط من | **انجام نشد.** تنها شاهدِ دستگاه، مصنوعاتِ موجود در مخزن است (بخش ۵) |

سه یافتهٔ غیرمنتظره که مسیر ۲.۰ را عوض می‌کند:

1. **هندسهٔ لمس درست است، برخلاف فرض اولیهٔ ممیزی.** کد عرضِ مقصد را با شعاعِ مقیاس‌شده جبران می‌کند (`race_hud.gd:291-294`)، بنابراین مرکزِ بصری و مرکزِ ناحیهٔ برخورد بر هم منطبق می‌مانند و شعاع یک‌بار (نه دوبار) مقیاس می‌گیرد. اندازه‌گیری در `control_scale` ۱٫۰ و ۱٫۳۵ این را تأیید کرد.
2. **مشکل واقعیِ چیدمان، هم‌پوشانیِ ناحیه‌های برخورد هنگام بزرگ‌کردن کنترل‌هاست.** با `control_scale` ۱٫۳۵ دیسک‌های `gear_down` و `throttle` ۴۳ پیکسل هم‌پوشانی پیدا می‌کنند و در عمل `throttle` بخشی از دکمهٔ دنده را می‌بلعد (اندازه‌گیری‌شده).
3. **قفلِ کلاچ برای تعویض دنده در HEAD وجود ندارد، ولی به‌شکل دیگری:** `request_gear` هیچ پارامتر کلاچ یا سرعتی ندارد (`gearbox_state.gd:38`). با کلاچِ کاملاً باز هم تعویض پذیرفته شد، و دندهٔ عقب در ۳۵ کیلومتر بر ساعت درگیر شد.

> **هشدار روش‌شناسی:** درختِ کاری در میانهٔ ممیزی توسط مهندس دیگر تغییر کرد (`vehicle_body.gd` از ۴۰۶ به ۵۹۹ خط، `clutch_state.gd` از ۴۲ به ۷۴، `gearbox_state.gd` از ۸۷ به ۳۰۱). همهٔ شواهد این سند از worktree پاک گرفته شده و آن تغییرها بیرون از دامنه‌اند (بخش ۲).

---

## ۱. محیط

| مورد | مقدار |
|---|---|
| سیستم عامل | Windows 10 (طبق `local-builds/reports/ANDROID_BUILD_REPORT.md`)، پوستهٔ PowerShell 5.1 |
| موتور | `Godot Engine v4.7.2.stable.official.ed1daf0bf` |
| مسیر باینری | `C:\Users\Faraz_pc\Godot\Godot_v4.7.2-stable_win64_console.exe` |
| رندر | GLES3 / Compatibility — `OpenGL API 3.3.0 Core Profile Context 25.8.1.250617` — `AMD Radeon RX 580 2048SP` |
| وضوح کپچر | ۱۲۸۰×۷۲۰ |
| نرخ فیزیک | ۱۲۰ هرتز (سرآیند لاگ تست) |
| مقیاس واحد | `Units.PPM = 64.0` پیکسل بر متر |
| پروژه | `1280×720`، `stretch/mode="canvas_items"`، `stretch/aspect="expand"`، `handheld/orientation=4` (sensor landscape) |
| کامیت / شاخه | `8575006` / `feat/mudro-full-game` |

نکتهٔ محیطی: هشدارِ `ERROR: Can't create shader cache folder ... user://` در کپچر، به‌دلیل نبودِ `APPDATA` در پوستهٔ من بود؛ موتور به پوشهٔ نسبی fallback کرد و پروفایلِ پیش‌فرض بارگذاری شد. به همین دلیل تصاویر، پروفایل تازه (۶۰۰ اعتبار، ۰/۴ مدال) را نشان می‌دهند. اجرای تست‌ها از طریق `run_tests.ps1` این متغیر را خودش تنظیم می‌کند.

---

## ۲. روش و پاکیزگیِ شاهد

```
git -C <root> worktree add local-builds/baseline-worktree HEAD
→ Preparing worktree (detached HEAD 8575006)
→ HEAD is now at 8575006 feat(mudro): build complete off-road physics game
```

کارها در همان کپی انجام شد: `--import`، تست، کپچر، و چهار پروبِ موقت (`tools/audit_probe*.gd`). پروب‌ها بخشی از HEAD نیستند و همراه worktree حذف شدند. هیچ فایلی بیرون از `local-builds/` و `docs/BASELINE_AUDIT_2.0.md` نوشته نشد.

**تفکیک درخت‌ها (اندازه‌گیری‌شده در پایان ممیزی):**

| فایل | HEAD | درختِ کاری | وضعیت |
|---|---:|---:|---|
| `scripts/ui/race_hud.gd` | ۴۲۷ | ۴۲۷ | یکسان |
| `scripts/core/input_router.gd` | ۴۰ | ۴۰ | یکسان |
| `scripts/race/race_scene.gd` | ۴۱۹ | ۴۱۹ | یکسان |
| `scripts/core/settings_service.gd` | ۱۴۹ | ۱۴۹ | یکسان |
| `scripts/ui/settings_screen.gd` | ۱۶۶ | ۱۶۶ | یکسان |
| `tests/test_runner.gd` | ۳۴۲ | ۳۴۲ | یکسان |
| `scripts/vehicle/vehicle_body.gd` | ۴۰۶ | ۵۹۹ | **واگرا** |
| `scripts/vehicle/clutch_state.gd` | ۴۲ | ۷۴ | **واگرا** |
| `scripts/vehicle/gearbox_state.gd` | ۸۷ | ۳۰۱ | **واگرا** |

سه فایلِ واگرا همان کاری است که به‌عنوان «Transmission 2.0» در جریان است؛ چون در HEAD نیستند، در این ممیزی داوری نمی‌شوند.

---

## ۳. گزارش دستورها (خروجیِ عیناً)

### ۳٫۱ اجرای اول تست — شکست محیطی

```
$env:GODOT_BIN='C:\Users\Faraz_pc\Godot\Godot_v4.7.2-stable_win64_console.exe'
powershell -NoProfile -ExecutionPolicy Bypass -File tools/local_build/run_tests.ps1

Godot 4.7.2 verified.
Running test suite...
ERROR: SCRIPT ERROR: Parse Error: Could not find type "StageDef" in the current scope.
EXITCODE=2
```

علت: worktree تازه هیچ `.godot/global_script_class_cache.cfg` ندارد و موتور پیش از نخستین import، `class_name`ها را نمی‌شناسد. این یک نقص ابزارِ ساخت است، نه نقص بازی (BL-14).

### ۳٫۲ آماده‌سازی import

```
& $godot --headless --path . --import
→ [ 99% ] reimport | Finalizing Asset Import...   [ DONE ]
→ IMPORT_EXIT=0
→ .godot/global_script_class_cache.cfg موجود شد: True
```

### ۳٫۳ اجرای دوم تست — قبولی

```
Godot 4.7.2 verified.
Running test suite...
Log: ...\local-builds\baseline-worktree\local-builds\logs\tests.log
PASS  units: metres to pixels                    2 m = 128 px
PASS  units: newtons to pixels                   10 N = 640 px
...
PASS  content: four stages per environment       [4, 4, 4]
---
TESTS: 68 passed, 0 failed
RESULT: ALL TESTS PASSED
PASSED: TESTS: 68 passed, 0 failed
EXITCODE=0
ELAPSED_SEC=64.2
```

سرآیند خودِ رانر: `godot 4.7.2-stable (official)   physics 120 Hz   ppm 64.0`

### ۳٫۴ کپچر اسکرین‌شات

```
& $godot --path . --resolution 1280x720 res://tools/capture.tscn
SHOT 01_main_menu -> res://local-builds/screenshots/01_main_menu.png (err 0, 1280x720)
SHOT 02_career -> ... (err 0, 1280x720)
SHOT 03_stage_select -> ...
SHOT 04_garage -> ...
SHOT 05_upgrades -> ...
SHOT 06_settings -> ...
SHOT 07_credits -> ...
SHOT 08_race_intro -> ...
SHOT 09_race_driving -> ...
SHOT 10_race_debug -> ...
SHOT 11_pine_race -> ...
SHOT 12_quarry_race -> ...
CAPTURE COMPLETE
```

### ۳٫۵ پروب‌های اندازه‌گیری (گزیدهٔ عیناً)

```
PROBE scale=1.00  pos=(1100.0, 544.0)  scale=(1.0, 1.0)  tex=(168.0, 168.0)  shape_r=84.0  effective_hit_r=84.0
PROBE   touch at centre -> throttle=true | at 0.92r -> true | at 1.12r -> false
PROBE scale=1.30  pos=(1074.8, 518.8)  scale=(1.3, 1.3)  tex=(168.0, 168.0)  shape_r=84.0  effective_hit_r=109.2
PROBE   touch at centre -> throttle=true | at 0.92r -> true | at 1.12r -> false
PROBE paused-tree touch on throttle -> action pressed = true
PROBE hud process_mode=3  tree.paused=true
PROBE2 hud textures: 7 buttons, cache entries 14
PROBE2 RaceHUD.setup() (build + 14 procedural textures): 111.0 ms
PROBE2 scale=1.00  |gear_down - throttle| centres = 132.5 px, sum of hit radii = 130.0 px, overlap = false
PROBE2 scale=1.35  |gear_down - throttle| centres = 132.5 px, sum of hit radii = 175.5 px, overlap = true
PROBE2   |handbrake - brake| centres = 129.6 px, sum of hit radii = 118.0 px, overlap = false   (1.00)
PROBE2   |handbrake - brake| centres = 129.6 px, sum of hit radii = 159.3 px, overlap = true    (1.35)
PROBE2 drag test: pressed at centre -> throttle=true
PROBE2   after drag to (420,200) -> throttle=true (still latched?)
PROBE2   after release at (420,200) -> throttle=false
PROBE3 two fingers (throttle idx0 + brake idx1): throttle=true brake=true
PROBE3 after lifting finger 0 only: throttle=false brake=true
PROBE4 shift_down #1 -> gear 2 at 37.0 km/h rpm 3327
PROBE4 shift_down #2 -> gear 1 at 36.8 km/h rpm 4571
PROBE4 shift_down #3 -> gear 0 at 35.4 km/h rpm 4495
PROBE4 shift_down #4 -> gear -1 at 28.5 km/h rpm 3374
PROBE4 one second later in reverse: 12.1 km/h (drivetrain now braking the car)
PROBE3 request_gear(1) with clutch fully open accepted = true -> gear 1
PROBE3 vehicle.shift_up() with clutch open -> gear 1 (no interlock)
```

لاگ‌های کامل: `local-builds/logs/baseline_tests_HEAD.log`، `local-builds/logs/baseline_baseline_capture.log`، `local-builds/logs/baseline_audit_probe{,2,3,4}.log`.

---

## ۴. فهرست اسکرین‌شات‌ها

همه در `local-builds/screenshots-v2/baseline/` — کپچر دسکتاپ، GLES3، ۱۲۸۰×۷۲۰.

| فایل | صفحه | نکتهٔ دیداری |
|---|---|---|
| `01_main_menu.png` | منوی اصلی | پس‌زمینهٔ پارالاکس، دکمهٔ اصلی، زبان فارسی/RTL |
| `02_career.png` | مسیر حرفه‌ای | کارت‌های محیط، ۰/۴ مدال، ۶۰۰ اعتبار |
| `03_stage_select.png` | انتخاب مرحله | فیلتر محیط `canyon` |
| `04_garage.png` | گاراژ | نمای خودرو، آمار |
| `05_upgrades.png` | ارتقاها | رده‌های موتور/توربو/… |
| `06_settings.png` | تنظیمات | زبان، صدا، گرافیک؛ بخش «کنترل‌ها» زیر خط تا است و در این فریم دیده نمی‌شود |
| `07_credits.png` | سازندگان | — |
| `08_race_intro.png` | مقدمهٔ مسابقه | شمارش معکوس، HUD کامل |
| `09_race_driving.png` | رانندگی (بیابان) | هفت دیسک لمسی روی جهان؛ `recover` روی گوشهٔ پنل هدف |
| `10_race_debug.png` | رانندگی + دیباگ | اورلی F3 |
| `11_pine_race.png` | مرحلهٔ کاج | محیط `pine` |
| `12_quarry_race.png` | مرحلهٔ معدن | محیط `quarry` |

**کپچرهای دستگاه (از مخزن، نه کار من):** `local-builds/screenshots/device_01.png` … `device_03.png` — ۲۰۰۰×۸۹۷ (نسبت ۲٫۲۳، معادل ۲۰:۹). `docs/screenshots/device_main_menu.png` نسخهٔ کپی `device_03.png` است (هر دو ۶۶۲٬۰۳۵ بایت). `device_02.png` نمای مسابقه روی دستگاه است و هفت دکمهٔ لمسی را نشان می‌دهد.

---

## ۵. واقعیت‌های دستگاه — چه چیزی روی سخت‌افزار تأیید شده است

**من هیچ اجرایی روی دستگاه انجام ندادم.** آنچه در ادامه می‌آید، بازخوانیِ مصنوعاتِ مخزن است، نه آزمونِ من.

| مورد | مقدار | سطح شاهد |
|---|---|---|
| APK | `local-builds/android/MUDRO-debug.apk` — ۳۸٬۰۸۷٬۶۳۶ بایت | **من هش را گرفتم:** `27300A666ACD01D7595A097FBA096E091DB5953970C3F9C55973261985DE4C20` — با گزارش یکی است |
| بسته/نسخه | `com.khiyarusa.mudro`، کد ۱، نام `1.0.0`، arm64-v8a، minSdk 24، target/compile 36 | `export_presets.cfg:33-38` + گزارش |
| جهت | userLandscape / sensor landscape (`orientation=4`) | `project.godot:42` + گزارش |
| Immersive | فعال (`screen/immersive_mode=true`) — نوارهای سیستم پنهان | `export_presets.cfg:53` |
| نصب و اجرا | `adb install -r` → Success؛ منو/مسیر/انتخاب مرحله/مسابقه رندر شد؛ بدون کرش | **فقط ادعای گزارش** (`ANDROID_BUILD_REPORT.md`)؛ من بازآزمایی نکردم |
| فریم‌ریت روی دستگاه | اندازه‌گیری نشده | گزارش خودش این را در «What is not verified» می‌نویسد |

**تأییدشده روی دسکتاپ (این ماشین):** ۶۸ تست، ۱۲ اسکرین‌شات، هندسهٔ برخورد لمس، مالتی‌تاچ، نشتِ ورودی در توقف، چسبیدن پس از drag، دندهٔ عقب در سرعت، تعویض با کلاچ باز، هزینهٔ ساخت HUD.

**تأییدنشده (نه روی دستگاه، نه روی دسکتاپ):** حسِ واقعی لمس، رفتار safe-area/ناچ، تأخیر صدا، رفتار pause/resume در پس‌زمینهٔ اندروید، مصرف حافظه، و اینکه کپچرهای دستگاه از دقیقاً همین APK گرفته شده‌اند (هیچ همبستگیِ زمانی در مخزن نیست).

---

## ۶. ماتریس تأییدشده / استنباطی / تأییدنشده

| ادعا | حکم | شاهد |
|---|---|---|
| مجموعهٔ تست در HEAD قبول می‌شود | ✅ تأیید | `TESTS: 68 passed, 0 failed`، کد خروج ۰ |
| ۱۲ اسکرین‌شات از صفحه‌های خواسته‌شده گرفته شد | ✅ تأیید | فایل‌های بخش ۴ |
| مرکز دیسک لمسی با مرکز ناحیهٔ برخورد یکی است | ✅ تأیید (اندازه‌گیری) | پروب ۱ در ۱٫۰ و ۱٫۳۰/۱٫۳۵ |
| شعاع برخورد یک‌بار مقیاس می‌گیرد | ✅ تأیید (اندازه‌گیری) | `effective_hit_r` ۸۴ → ۱۰۹٫۲ |
| مالتی‌تاچ دو انگشتی کار می‌کند | ✅ تأیید (اندازه‌گیری) | پروب ۳: throttle+brake هم‌زمان، رهاسازی مستقل |
| ورودی لمسی در حالت pause همچنان action می‌زند | ✅ تأیید (اندازه‌گیری) | پروب ۱: `tree.paused=true` و `throttle=true` |
| انگشتِ لغزیده از دکمه، action را نگه می‌دارد | ✅ تأیید (اندازه‌گیری) | پروب ۲: تا رهاسازی در (۴۲۰٬۲۰۰) |
| تعویض دنده کلاچ‌بند ندارد | ✅ تأیید (کد + اندازه‌گیری) | `gearbox_state.gd:38`؛ کلاچ باز و `request_gear` پذیرفته |
| دندهٔ عقب در سرعت درگیر می‌شود | ✅ تأیید (اندازه‌گیری) | پروب ۴: gear −1 در ۲۸٫۵ km/h |
| `control_opacity` اثری ندارد | ✅ تأیید (کد) | `settings_screen.gd:67` می‌نویسد؛ `race_hud.gd` هرگز نمی‌خواند |
| safe-area رعایت نمی‌شود | ✅ تأیید (کد) | هیچ ارجاعی به `DisplayServer.get_display_safe_area` در `scripts/` نیست |
| هزینهٔ ساخت HUD روی موبایل زیاد است | 🟡 استنباط | ۱۱۱ ms روی دسکتاپ اندازه‌گیری شد؛ ضریب موبایل اندازه‌گیری نشده |
| رفتار focus-loss روی اندروید باعث گازِ چسبیده می‌شود | 🟡 استنباط | نبودِ handler تأیید شد؛ رفتار OS تأیید نشد |
| ناچ/بریدگی روی دکمه‌ها می‌افتد | 🟡 استنباط | هندسه تأیید شد؛ بریدگیِ واقعیِ A23 اندازه‌گیری نشد |
| APK همین ساخت، روی A23 اجرا شده | 🟡 استنباط | هشِ فایل با گزارش می‌خواند؛ خودِ اجرا بازآزمایی نشد |
| فریم‌ریت ۶۰ روی دستگاه | ❌ تأییدنشده | هیچ داده‌ای در مخزن نیست |

---

## ۷. فهرست نقص‌ها

شدت‌ها: **بالا** = رفتار بازیکن را خراب می‌کند یا کنترل را از دست او می‌گیرد؛ **متوسط** = تجربه/کارایی را به‌طور محسوس کم می‌کند؛ **پایین** = دیداری یا کیهانی.

| شناسه | شدت | فایل:خط | خلاصه |
|---|---|---|---|
| BL-01 | بالا | `scripts/vehicle/gearbox_state.gd:38` | تعویض دنده بدون قفل کلاچ |
| BL-02 | بالا | `scripts/vehicle/gearbox_state.gd:38` | درگیری دندهٔ عقب در سرعت |
| BL-03 | بالا | `scripts/ui/race_hud.gd:41` | ماندن action لمسی در pause |
| BL-04 | بالا | `scripts/ui/race_hud.gd:194` | نبودِ رهاسازی در از‌دست‌دادن فوکوس |
| BL-05 | متوسط | `scripts/ui/race_hud.gd:195` | نبودِ drag/cancel؛ چسبیدن گاز |
| BL-06 | متوسط | `scripts/ui/race_hud.gd:291` | هم‌پوشانی ناحیهٔ برخورد با `control_scale` |
| BL-07 | پایین | `scripts/ui/race_hud.gd:284` | هم‌پوشانی `recover` با پنل هدف و لبهٔ صفحه |
| BL-08 | متوسط | `scripts/ui/race_hud.gd:249` | تنظیم `control_opacity` بی‌اثر |
| BL-09 | متوسط | `scripts/ui/race_hud.gd:205` | تولید پیکسل‌به‌پیکسلِ تصویر دکمه‌ها (۱۱۱ ms) |
| BL-10 | پایین | `scripts/ui/race_hud.gd:194` | نمایش همیشگی کنترل لمسی روی دسکتاپ |
| BL-11 | متوسط | `scripts/ui/race_hud.gd:278` | نبودِ safe-area |
| BL-12 | پایین | `scripts/vehicle/gearbox_state.gd:63` | برنامهٔ دندهٔ خودکار فقط بر rpm |
| BL-13 | پایین | `scripts/ui/race_hud.gd:293` | بزرگ‌نمایی تصویر رستری (نرمی) با `control_scale` |
| BL-14 | متوسط | `tools/local_build/run_tests.ps1:21` | تست در checkout سرد بدون import اجرا نمی‌شود |

### BL-01 — تعویض دنده بدون قفل کلاچ · بالا

`GearboxState.request_gear(target: int, force: bool = false)` (`gearbox_state.gd:38`) هیچ پارامتری برای وضعیت کلاچ یا سرعت ندارد و تنها نگهبانش `is_shifting()` است (`:46`). زنجیرهٔ فراخوانی هم چیزی اضافه نمی‌کند: `VehicleBody.shift_up()` → `request_gear(gear + 1)` (`vehicle_body.gd:426-428`) و `RaceScene._read_input()` → `vehicle.shift_up()` (`race_scene.gd:222-227`).

اندازه‌گیری: با کلاچ کاملاً باز (`pedal 0.00`, `engagement 0.00`) هم `request_gear(1)` و هم `vehicle.shift_up()` پذیرفته شدند. در نتیجه، وقتی بازیکن از تنظیمات کلاچ را «دستی» می‌کند، پدال کلاچ هیچ نقش بازی‌ای ندارد جز راه‌اندازی؛ کلاچ تزئینی است.

### BL-02 — دندهٔ عقب در سرعت · بالا

همان `request_gear` تنها `clampi(target, -1, gear_count())` را اعمال می‌کند. اندازه‌گیری: از دندهٔ ۳ در ۳۳٫۴ km/h، چهار بار `shift_down` → دنده‌های ۲، ۱، ۰، **−۱** در ۲۸٫۵ km/h؛ یک ثانیه بعد سرعت به ۱۲٫۱ km/h افتاد، یعنی درایو‌ترین داشت خودرو را می‌کشید. برای یک شبیه‌ساز آفرود، این هم رفتار غلط است و هم به موتور/گیربکس آسیب می‌زند.

### BL-03 — ماندن action لمسی در pause · بالا

HUD با `process_mode = PROCESS_MODE_ALWAYS` ساخته می‌شود (`race_hud.gd:41`) تا پنل توقف کار کند؛ اما `TouchScreenButton`ها هم زیر همان گره‌اند و ورودی‌شان به pause گره‌ای نیست. `RaceScene._process` در حالت `paused` هیچ ورودی‌ای نمی‌خواند (`race_scene.gd:157-190`، `_read_input` در `:212`).

اندازه‌گیری: با `tree.paused = true`، لمس روی گاز → `Input.is_action_pressed("throttle") == true`. چون action رها نمی‌شود، پس از «ادامه» خودرو با گازِ فشرده شروع می‌کند تا انگشت برداشته شود. این یک گازِ چسبیدهٔ کلاسیک است.

### BL-04 — نبودِ رهاسازی در از‌دست‌دادن فوکوس · بالا

هیچ‌جای `scripts/` به `NOTIFICATION_APPLICATION_FOCUS_OUT` یا `NOTIFICATION_WM_WINDOW_FOCUS_OUT` واکنش نمی‌دهد؛ `git grep` برای `action_release` تنها یک نتیجه دارد: `tools/capture.gd:71`. اگر اندروید لمس را قطع کند (تماس، نوتیفیکیشن، قطع‌شدن برنامه) و رویداد release هرگز نرسد، action تا ابد فشرده می‌ماند. شاهد کد قطعی است؛ رفتار واقعیِ OS تأیید نشد.

### BL-05 — نبودِ drag/cancel · متوسط

`btn.passby_press = false` (`race_hud.gd:195`) و هیچ‌جا `InputEventScreenDrag` پردازش نمی‌شود. اندازه‌گیری: فشار در مرکز گاز → drag تا (۴۲۰٬۲۰۰) → `throttle` همچنان `true`؛ رهاسازی در همان نقطهٔ دور → `false`. پیامد: در پیچ، اگر شست از پدال بلغزد، گاز کامل باقی می‌ماند و راهی برای لغزیدنِ نرم از گاز به ترمز وجود ندارد.

### BL-06 — هم‌پوشانی ناحیهٔ برخورد · متوسط

مرکزها ثابت‌اند (`race_hud.gd:278-286`) ولی شعاعِ برخورد با `control_scale` رشد می‌کند (`:291-294`). اندازه‌گیری:

| جفت | فاصلهٔ مرکزها | جمع شعاع در ۱٫۰ | جمع شعاع در ۱٫۳۵ | نتیجه |
|---|---:|---:|---:|---|
| `gear_down` ↔ `throttle` | ۱۳۲٫۵ px | ۱۳۰٫۰ px | ۱۷۵٫۵ px | ۴۳ پیکسل هم‌پوشانی در ۱٫۳۵ |
| `brake` ↔ `handbrake` | ۱۲۹٫۶ px | ۱۱۸٫۰ px | ۱۵۹٫۳ px | ۲۹٫۷ پیکسل هم‌پوشانی در ۱٫۳۵ |

در ۱٫۰ فاصلهٔ دو دیسک فقط ۲٫۵ پیکسل است. لمسِ نقطهٔ مشترک در ۱٫۳۵ فقط `throttle` را فعال کرد، نه `gear_down` را؛ یعنی دکمهٔ دنده بخشی از سطح مؤثرش را به گاز می‌دهد.

### BL-07 — هم‌پوشانی `recover` با پنل هدف · پایین

`recover` در `(w-58, 118)` با شعاع ۳۶ (`race_hud.gd:284`, `:143`) در بازهٔ x از `w-94` تا `w-22` و y از ۸۲ تا ۱۵۴ می‌نشیند؛ پنل هدف `(w-316..w-24, 18..96)` است (`:260-264`) → هم‌پوشانی ۷۰×۱۴ پیکسل. در `09_race_driving.png` و `device_02.png` دیده می‌شود. فاصلهٔ آن تا لبهٔ راست صفحه ۲۲ پیکسل است.

### BL-08 — تنظیم بی‌اثرِ `control_opacity` · متوسط

`SettingsService.control_opacity` تعریف، بارگذاری، ذخیره و در UI با اسلایدر تنظیم می‌شود (`settings_service.gd:19`, `settings_screen.gd:67`, `:161-162`)، اما `race_hud.gd` تنها `control_scale` را می‌خواند (`:249`) و هیچ‌جا شفافیت دکمه‌ها را اعمال نمی‌کند. کاربر اسلایدر را حرکت می‌دهد و هیچ اتفاقی نمی‌افتد.

### BL-09 — تولید پیکسل‌به‌پیکسل تصویر دکمه‌ها · متوسط

`_button_texture()` (`race_hud.gd:205`) یک `Image` با حلقهٔ تودرتوی `for y`/`for x` و `img.set_pixel` برای هر پیکسل می‌سازد (`:216-226`) — برای هر دکمه دو نسخه (عادی/فشرده). اندازه‌گیری: ۷ دکمه، ۱۴ بافتِ کش‌شده، و `RaceHUD.setup()` = **۱۱۱٫۰ ms** روی دسکتاپ، پیش از هر هزینهٔ موبایل. این هزینه در لحظهٔ ورود به مسابقه پرداخت می‌شود.

### BL-10 — نمایش همیشگی کنترل لمسی روی دسکتاپ · پایین

`btn.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS` (`race_hud.gd:194`). در همهٔ اسکرین‌شات‌های مسابقه، هفت دیسک روی جهان دیده می‌شوند؛ برای بیلد دسکتاپ شلوغی دیداری است (شاید عامدانه برای تست).

### BL-11 — نبودِ safe-area · متوسط

هیچ ارجاعی به `DisplayServer.get_display_safe_area()` در `scripts/` نیست. با `stretch/aspect="expand"` و `orientation=4` (`project.godot:40-42`)، در یکی از دو جهتِ landscape دکمهٔ pause در `(24,20)` (`race_hud.gd:252`) و پنل تایمر در `(92,18)` دقیقاً در محدودهٔ بریدگیِ دوربین قرار می‌گیرند. `immersive_mode=true` نوارهای سیستم را حذف می‌کند ولی بریدگی را نه. کپچر دستگاه نسبت ۲۰:۹ را تأیید می‌کند؛ خودِ بریدگی اندازه‌گیری نشد.

### BL-12 — برنامهٔ دندهٔ خودکار فقط بر rpm · پایین

`auto_update(dt, rpm, throttle, speed_mps)` (`gearbox_state.gd:63`) تنها rpm، دریچه، سرعت و یک نگه‌داشت ۰٫۴۵ ثانیه‌ای (`:67`) را می‌بیند؛ بالا‌رفتن با `rpm > up_rpm` و دروازهٔ خام `speed_mps > 2.2` (`:79-84`). هیچ بار موتور، شیب یا لغزش تایر وارد نمی‌شود. در HEAD این تنها حالتِ خودکار است (از تنظیمات `transmission=auto` قابل دسترسی).

### BL-13 — بزرگ‌نمایی تصویر رستری · پایین

بافت با شعاع پایه ساخته می‌شود (`:205`) و بعد با `btn.scale` بزرگ می‌شود (`:294`). هندسه درست می‌ماند ولی تصویر بازنمونه‌برداری می‌شود؛ در `control_scale` بالا لبه‌ها نرم می‌شوند. راه درست: تولید بافت با شعاع `base × scale` (کلید کش شامل scale).

### BL-14 — تست در checkout سرد · متوسط

`run_tests.ps1` هیچ مرحلهٔ import ندارد (`:21-23`) و در کپیِ تازه با `Parse Error: Could not find type "StageDef"` و کد خروج ۲ می‌میرد. برای CI یا هر کلون تازه، این یعنی «تست‌ها خراب‌اند» در حالی که فقط کشِ کلاس‌ها نیست. راه‌حل: یک `--import` پیش از اجرا یا بررسی وجود `.godot/global_script_class_cache.cfg`.

---

## ۸. بررسی ادعاهای کنترل لمسی

| # | ادعا | حکم |
|---|---|---|
| ۱ | جابه‌جایی مرکز بصری و مرکز shape به اندازهٔ `radius×(scale−1)` | **رد شد** |
| ۲ | شعاع shape دو بار مقیاس می‌گیرد | **رد شد** |
| ۳ | تصویر دکمه‌ها پیکسل‌به‌پیکسل و فقط دایره‌ای تولید می‌شود | **تأیید شد** |
| ۴ | هیچ مالکیتِ per-finger وجود ندارد | **رد شد** (در سطح موتور) |
| ۵ | هیچ معنای drag/cancel وجود ندارد | **تأیید شد** |
| ۶ | رهاسازی در focus-loss یا pause انجام نمی‌شود | **تأیید شد** |
| ۷ | دیکشنری موقعیت ثابت، بدون safe-area؛ بدون مدیریت نسبت تصویر | **نیمه:** safe-area تأیید، نسبت تصویر رد، هم‌پوشانی تأیید |
| ۸ | تنظیمات سراسری `transmission`/`clutch` مشخصات هر خودرو را override می‌کند | **در HEAD قابل اعمال نیست** |
| ۹ | قفل کلاچ برای تعویض دنده نیست | **تأیید شد** |
| ۱۰ | تعویض خودکار فقط بر rpm است | **تأیید شد** |

**۱ و ۲ — چرا رد شدند.** `Node2D.scale` حول مبدأ گره اعمال می‌شود و مبدأ بافت/شکل همان گوشهٔ بالا-چپ است؛ پس اگر کد `position = center − (base_r, base_r)` می‌گذاشت، مرکزِ رسم‌شده به اندازهٔ `base_r×(scale−1)` جابه‌جا می‌شد — همان چیزی که ادعا می‌گفت. اما کد شعاع مقیاس‌شده را در offset به کار می‌برد: `var radius = base_r * scale_f` (`race_hud.gd:291`) و `btn.position = center − Vector2(radius, radius)` (`:293`)، سپس `btn.scale = scale_f` (`:294`). بنابراین مرکز رسم‌شده = `position + r·scale_f = center`. اندازه‌گیری: در ۱٫۰ و ۱٫۳۵ لمسِ مرکز نامی موفق و لمسِ ۱٫۱۲r ناموفق بود. شعاع شکل هم در `Shape2D` بدون مقیاس ذخیره می‌شود (`:197`) و یک‌بار با transform گره مقیاس می‌گیرد: ۸۴ → ۱۰۹٫۲ که دقیقاً با شعاع رسم‌شده می‌خواند. تنها اثر باقی‌مانده، BL-13 (نرمی تصویر) است.

**۴ — چرا رد شد.** مستندات موتور صریح است که `TouchScreenButton` از مالتی‌تاچ پشتیبانی می‌کند و چند دکمه هم‌زمان فشارده می‌شوند؛ اندازه‌گیری هم تأیید کرد: دو انگشت → `throttle=true` و `brake=true`، و برداشتن یکی فقط همان را رها کرد. آنچه واقعاً غایب است، نگاشتِ صریحِ انگشت→کنترل در لایهٔ بازی و در نتیجه نبودِ drag/re-target/cancel است (BL-05). این را باید به‌عنوان «نبودِ معنای drag» نوشت، نه «نبودِ مالکیت انگشت».

**۷ — تفکیک دقیق.** موقعیت‌ها نسبت به `w`/`h` محاسبه می‌شوند (`:279-285`)، پس با تغییر نسبت تصویر جابه‌جا می‌شوند و «بدون مدیریت نسبت تصویر» درست نیست؛ کپچر ۲۰:۹ دستگاه هم همین را نشان می‌دهد. اما safe-area صفر است و هیچ نگهبانِ هم‌پوشانی/حداقل‌فاصله وجود ندارد؛ BL-06 و BL-11 همین‌اند.

**۸ — چرا در HEAD قابل اعمال نیست.** `VehicleDef` در HEAD هیچ مشخصاتِ گیربکس/کلاچِ هر خودرو ندارد؛ تنها `clutch_capacity`/`clutch_stiffness` (`vehicle_def.gd:36-37`) و یک `GearboxConfig` (`:41`). منبعِ تنها، تنظیمات سراسری است: `race_scene.gd:85-87`. این ادعا دربارهٔ درختِ کاریِ ۲٫۰ (که `transmissions[]` و `stock_transmission` اضافه کرده) معنا دارد، نه دربارهٔ HEAD — و همان‌جا باید حل شود.

---

## ۹. آنچه ۲.۰ نباید بشکند

1. **مرز واحدها.** همهٔ کمیت‌ها در SI محاسبه و فقط در مرز به پیکسل تبدیل می‌شوند: `Units.PPM = 64`، `n2px = N×PPM`، `nm2px = Nm×PPM²`، `px2kmh`، `rpm_from_omega`/`omega_from_rpm` (`scripts/core/units.gd`). تست‌ها این مرز را قفل کرده‌اند: «2 m = 128 px»، «1 Nm = 4096 px»، «ppm 64.0».
2. **نیرو فقط در `_integrate_forces`.** `vehicle_body.gd:133`؛ سه نقطهٔ اعمال نیرو: `apply_central_force` (`:168`)، `apply_force` برای فنر (`:237`) و تایر (`:252`) و مقاومت غلتشی (`:262`). هیچ teleport یا نوشتن مستقیم سرعت در مسیر عادی نیست؛ تنها استثنا `reset_motion()` برای recover است.
3. **قفل‌شدن کلاچ (lock-up).** `can_lock` (`:327`)، `clutch.locked = true` و هم‌تراز‌کردن `engine.rpm` با `driveline_rpm` (`:331-332`)، و حالت لغزش با محدودیت گشتاور (`:341`). این مدل جایگزین فنرِ سخت شده و باید بماند؛ در غیر این صورت نوسان ۱۲۰ Hz و «دور بالا با چرخِ کند» برمی‌گردد.
4. **قطع نسبت در حین تعویض.** `effective_ratio()` تا وقتی `is_shifting()` است صفر برمی‌گرداند (`gearbox_state.gd:29-34`) و `shift_interlock` کلاچ را باز می‌کند (`vehicle_body.gd:317-320`). نسبتِ صفر یعنی گشتاور صفر — این رفتار باید حفظ شود.
5. **قالب ذخیرهٔ v3.** `version, credits, xp, selected_vehicle, owned_vehicles, records{best_time, medal, attempts, completed, mode}, upgrades, play_time_s, distance_m, created` (`save_manager.gd:18-32`)، نوشتن اتمی با `.tmp` و `.bak` (`:73-90`) و پرکردن پیش‌فرض‌ها در `_migrate` (`:47-63`). مهاجرت باید افزایشی بماند؛ کلیدها حذف نشوند.
6. **ساختار مجموعهٔ تست.** یک `test_runner.tscn` headless با ۱۴ گروه و ۶۸ assert، قرارداد کد خروج ۰/۱ (`test_runner.gd:34-41`)، هارنس `_spawn/_sim/_state` (`:120-176`)، و بازگرداندن snapshot پروفایل در پایان (`:12`, `:26-28`). اسکریپت `run_tests.ps1` کد ۲ را برای «محیط خراب» نگه می‌دارد.

**افزودهٔ پیشنهادی برای ۲.۰ (خارج از دامنهٔ این ممیزی):** پیش از هر بازنویسی، BL-14 را حل کنید تا تست‌ها در CI هم اجرا شوند، و برای کنترل لمسی یک لایهٔ `TouchRouter` با مالکیت انگشت، drag/cancel و رهاسازیِ متمرکز روی pause/focus بگذارید تا BL-03/04/05 ریشه‌ای بسته شوند.

---

## ۱۰. آنچه تأیید نشد

* هیچ اجرای واقعی روی دستگاه اندروید توسط من انجام نشد؛ تنها مصنوعات مخزن بازخوانی شد.
* فریم‌ریت، حس لمس، تأخیر صدا و مصرف حافظه روی A23 اندازه‌گیری نشد.
* رفتار اندروید در focus-loss و pause/resume (BL-04) استنباط از کد است، نه مشاهده.
* بریدگی/ناچ دستگاه و اثر واقعی آن روی `pause`/`timer` (BL-11) اندازه‌گیری نشد.
* هزینهٔ ۱۱۱ ms روی موبایل ضریب‌گیری نشد.
* سه فایل درختِ کاری (`vehicle_body`, `clutch_state`, `gearbox_state`) در حال تغییر بودند و داوری نشدند؛ هر یافتهٔ ۲٫۰ دربارهٔ آن‌ها باید پس از تثبیت دوباره سنجیده شود.
* رابطهٔ زمانیِ کپچرهای دستگاه با APKِ موجود در مخزن قابل اثبات نیست.

---

## پیوست — مسیرها

| مورد | مسیر |
|---|---|
| این سند | `docs/BASELINE_AUDIT_2.0.md` |
| خلاصهٔ ماشین‌خوان | `local-builds/reports/baseline_summary.json` |
| اسکرین‌شات‌های پایه | `local-builds/screenshots-v2/baseline/01…12_*.png` |
| لاگ تست HEAD | `local-builds/logs/baseline_tests_HEAD.log` |
| لاگ کپچر | `local-builds/logs/baseline_baseline_capture.log` |
| لاگ پروب‌ها | `local-builds/logs/baseline_audit_probe{,2,3,4}.log` |
| کپچرهای دستگاه (موجود) | `local-builds/screenshots/device_01..03.png` |
| گزارش ساخت اندروید | `local-builds/reports/ANDROID_BUILD_REPORT.md` |
