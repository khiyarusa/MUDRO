# MUDRO — Mobile controls (2.0)

The 1.0 HUD drew touch buttons with `TouchScreenButton` and a runtime-generated
circle texture. 2.0 replaces that with a single input layer that owns pointer
routing, a shared `VehicleInputState`, and three real control presets.

## 1. One contract, every source

```
keyboard ─┐
touch    ─┼─► VehicleInputState ─► RaceScene ─► VehicleBody.set_input_state()
gamepad  ─┘
```

`VehicleInputState` (`scripts/core/vehicle_input.gd`):

| field | range | meaning |
|---|---|---|
| `throttle`, `brake`, `handbrake` | 0..1 | pedal / lever pressure |
| `clutch` | 0..1 | **pedal pressed**: 0 = released (engaged), 1 = floor (open) |
| `requested_gear` | -1..N | one-shot gear request |
| `gear_step` | int | sequential +1 / -1 |
| `engine_start_requested`, `recover_requested`, `winch_requested`, `transfer_requested`, `diff_requested` | bool | one-shot commands |

`sanitize()` clamps every analog channel; `merge()` overlays two sources taking
the strongest value; `copy()` never aliases. The physics layer reads only this
object. No UI node touches `VehicleBody`, and no widget reads the simulation.

`VehicleBody` converts once: `clutch_input = 1.0 - state.clutch`, because the
drivetrain maths wants "release position" internally.

## 2. Finger ownership (`scripts/input/touch_controls.gd`)

One full-rect `Control` receives every `InputEventScreenTouch` / `ScreenDrag`
through `_input()`, does its own hit testing, and keeps `finger_index → widget`.

Rules that are enforced, not hoped for:

* a finger is owned by exactly one widget until it is lifted or cancelled;
* `press`, `drag` outside the widget and `release` all route to the owner;
* lifting finger A never changes finger B's widget;
* pause, results, focus loss (Android home / notification) and `release_all()`
  zero every widget and clear the registry;
* the layer lives on a `CanvasLayer` (layer 25), so the race camera cannot pan it;
* hit areas are computed in *canvas* coordinates from the same four floats used
  to place the art (`get_global_transform_with_canvas().affine_inverse()`).

`TouchControls._begin(finger, point)` / `_end(finger)` are the routing primitives
the tests call directly to prove independent ownership without a real device.

## 3. Presets

| Preset | Controls | Input character |
|---|---|---|
| **Buttons** | throttle, brake, clutch, handbrake, gear, recover, winch, starter | digital, held = continuous 1.0 |
| **Slider** | vertical throttle rail, independent brake rail, clutch rail, handbrake, gear | **analog**: finger travel along the rail *is* the value |
| **Pedals** | wide accelerator plate, wide brake plate, narrower clutch plate | **analog**: press depth along the plate |

Slider details (`touch_slider.gd`): press anywhere on the rail jumps to that
value; drag maps linearly with a response curve (`SettingsService.slider_sensitivity`);
release decays to zero at `slider_release` instead of snapping; the fill and knob
show the commanded value.

Pedals (`touch_pedal.gd`) use the same contract with a 10 % dead zone and a faster
return spring, and the plate art moves with the travel.

Digital buttons (`touch_button.gd`) keep their value at 1.0 while the finger is
captured, including outside the circle — that is what prevents a stuck throttle.

## 4. Gear selector panel (`gear_panel.gd`)

The gear control opens a panel; it is a mechanical gate, not a list of buttons.

* **H-pattern** — the lever is projected onto the legal gate segments generated
  from `TransmissionProfile.gate_segments()`. A diagonal from 2nd to 5th is
  impossible: the lever must travel through the neutral rail. The gate commits
  only inside `GATE_COMMIT_RADIUS` of a node, and only with the clutch at ≥ 98 %
  (`VehicleInputState.CLUTCH_FULL`) unless assist is on. A rejected shift snaps
  the lever back to neutral, flashes the reason, plays `gear_grind` and vibrates.
* **Sequential** — a centre-sprung lever; crossing the detent emits ±1.
* **Automatic** — a PRNDL gate; pressing a range calls `GearboxState.set_range()`.

The panel tracks its own finger index, so holding the clutch with the left thumb
and dragging the lever with the right thumb is one simultaneous gesture. After a
successful shift the panel auto-closes after 0.55 s and can always be reopened.

## 5. Layout editor

`control_layout_editor.gd` is an in-race overlay (race pauses underneath):

* drag any control; its centre is stored as `(preset, control) → [x, y]` in
  `SettingsService.control_positions` and survives restarts;
* preset, hand side, scale, opacity, edge margin, sensitivity, return rate, touch
  margin and per-control visibility are editable;
* reset restores the authored layout;
* the same editor is reachable from Settings → Controls.

Authored layouts are anchored to the screen edges with a unit derived from the
viewport (`u = min(h/720, w/1280) * control_scale`), so 16:9, 19.5:9, 20:9 and
tablet ratios all keep the controls on screen without stretching their art.

## 6. Tests (`tests/test_runner.gd`)

* `touch: two fingers own two controls`, `lifting the throttle keeps the clutch down`,
  `lifting the second finger releases it`, `pause / focus loss releases everything`;
* `touch: every control stays on screen at 4 aspects` (1280×720, 1560×720,
  1600×720, 2340×1080) and `throttle and brake never overlap`;
* each preset builds its control set; layout overrides move the control;
* the race integration test proves a manual shift is refused with the pedal up
  and accepted at 100 %, then cycles the transfer case and differential through
  the same input path.

## 7. What is still device-only

The suite runs headless; it cannot measure Android touch latency, a real notch,
or the feel of a finger on glass. The debug APK and the honest status are in
`docs/MUDRO_2.0.md`. No claim of a Galaxy A23 run is made for 2.0 unless the
device was actually connected.

---

## خلاصهٔ فارسی

معماری کنترل لمسی از پایه بازنویسی شد: یک لایهٔ ورودی، یک قرارداد مشترک
(`VehicleInputState`)، و سه پریست واقعی (دکمه، اسلایدر آنالوگ، پدال آنالوگ).
هر انگشت تا لحظهٔ رها شدن مالک یک کنترل است؛ رها کردن گاز کلاچ را آزاد نمی‌کند و
ورود به Pause یا از دست رفتن فوکوس همهٔ ورودی‌ها را صفر می‌کند. پنل دنده یک گیت
مکانیکی واقعی است: در H-pattern اهرم باید از خلاص عبور کند و بدون کلاچ ۹۸٪ دنده
درگیر نمی‌شود. چیدمان با کشیدن کنترل‌ها قابل ویرایش و ذخیره است.
