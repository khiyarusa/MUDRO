"""Merge MUDRO 2.0 UI strings into assets/i18n/{fa,en}.json.

Run with the system Python 3.14 interpreter:
    C:\\Users\\Faraz_pc\\AppData\\Local\\Programs\\Python\\Python314\\python.exe tools\\i18n_merge.py
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
I18N = ROOT / "assets" / "i18n"

STRINGS: dict[str, tuple[str, str]] = {
    # touch control captions
    "ctl_throttle": ("گاز", "Throttle"),
    "ctl_brake": ("ترمز", "Brake"),
    "ctl_clutch": ("کلاچ", "Clutch"),
    "ctl_handbrake": ("ترمزدستی", "Handbrake"),
    "ctl_gear": ("دنده", "Gear"),
    "ctl_winch": ("وینچ", "Winch"),
    # HUD
    "hud_clutch": ("کلاچ", "CLUTCH"),
    "hud_transfer": ("انتقال", "TRANSFER"),
    "hud_diff": ("دیفرانسیل", "DIFF"),
    # gearbox feedback
    "gearbox_clutch_needed": ("کلاچ را کامل فشار بده", "Press the clutch fully"),
    "gearbox_overrev": ("این دنده دور موتور را بیش از حد بالا می‌برد", "That gear would over-rev the engine"),
    "gearbox_reverse_blocked": ("برای دنده عقب اول بایست", "Stop before selecting reverse"),
    "gearbox_refused": ("تعویض دنده رد شد", "Gear change refused"),
    "gearbox_shifting": ("گیربکس در حال تعویض است", "Gearbox is shifting"),
    "gearbox_manual_h": ("دستی H", "H-PATTERN"),
    "gearbox_manual_seq": ("ترتیبی", "SEQUENTIAL"),
    "gearbox_auto": ("اتوماتیک", "AUTOMATIC"),
    "gearbox_kickdown": ("کیک‌داون", "KICKDOWN"),
    "gearbox_panel_hint": ("اهرم را روی الگوی دنده بکش", "Drag the lever along the gate"),
    "gearbox_up": ("بالا", "Up"),
    "gearbox_down": ("پایین", "Down"),
    "range_park": ("پارک", "Park"),
    "range_reverse": ("دنده عقب", "Reverse"),
    "range_neutral": ("خلاص", "Neutral"),
    "range_drive": ("دنده", "Drive"),
    # winch / transfer
    "winch_unavailable": ("این خودرو وینچ ندارد", "This vehicle has no winch"),
    "winch_attached_obstacle": ("کابل به لنگر وصل شد", "Cable attached to anchor"),
    "winch_attached_stake": ("کابل به میخ زمین وصل شد", "Cable attached to ground stake"),
    "winch_detached": ("کابل آزاد شد", "Cable released"),
    "winch_no_anchor": ("لنگر مجازی در محدوده پیدا نشد", "No legal anchor in range"),
    "transfer_none": ("این خودرو جعبه انتقال ندارد", "This vehicle has no transfer case"),
    # control layout editor
    "pause_controls": ("چیدمان کنترل", "Control layout"),
    "layout_title": ("چیدمان کنترل", "CONTROL LAYOUT"),
    "layout_hint": ("هر کنترل را با انگشت جابه‌جا کن؛ تغییرات ذخیره می‌شود", "Drag any control; changes are saved"),
    "layout_reset": ("بازگردانی", "Reset"),
    "layout_done": ("تمام", "Done"),
    "layout_buttons": ("دکمه‌ای", "Buttons"),
    "layout_slider": ("اسلایدر", "Slider"),
    "layout_pedals": ("پدال", "Pedals"),
    "layout_left": ("چپ‌دست", "Left-hand"),
    "layout_right": ("راست‌دست", "Right-hand"),
    "layout_margin": ("فاصله از لبه", "Edge gap"),
    "layout_sensitivity": ("حساسیت", "Sensitivity"),
    # settings
    "settings_control_layout": ("چیدمان کنترل", "Control layout"),
    "settings_side": ("سمت کنترل", "Control side"),
    "settings_preset": ("سبک کنترل", "Control style"),
    "settings_slider_sensitivity": ("حساسیت اسلایدر", "Slider sensitivity"),
    "settings_slider_release": ("سرعت بازگشت اسلایدر", "Slider return rate"),
    "settings_edge_margin": ("فاصله از لبهٔ صفحه", "Edge margin"),
    "settings_show_clutch": ("نمایش کلاچ", "Show clutch"),
    "settings_show_handbrake": ("نمایش ترمزدستی", "Show handbrake"),
    "settings_show_winch": ("نمایش وینچ", "Show winch"),
    "settings_show_recover": ("نمایش بازیابی", "Show recover"),
    "settings_edit_layout": ("ویرایش چیدمان", "Edit layout"),
    "settings_touch_margin": ("حاشیهٔ لمس", "Touch margin"),
    "settings_reset_layout": ("بازگردانی چیدمان", "Reset layout"),
    "settings_transmission_note": (
        "گیربکس و انتقال قدرت برای هر خودرو در گاراژ و صفحهٔ معرفی مسیر انتخاب می‌شود.",
        "Each vehicle's gearbox and driveline are chosen in the garage and the route briefing.",
    ),
    # route briefing
    "briefing_title": ("معرفی مسیر", "ROUTE BRIEFING"),
    "briefing_length": ("طول مسیر", "Route length"),
    "briefing_max_grade": ("بیشترین شیب", "Max grade"),
    "briefing_avg_grade": ("شیب متوسط", "Average grade"),
    "briefing_rock": ("مسیر سنگی", "Rock"),
    "briefing_dirt": ("مسیر خاکی", "Dirt"),
    "briefing_mud": ("گل و برف", "Mud & snow"),
    "briefing_obstacles": ("موانع", "Obstacles"),
    "briefing_climbs": ("صعودهای دشوار", "Hard climbs"),
    "briefing_descents": ("فرودهای طولانی", "Long descents"),
    "briefing_vehicle": ("خودرو", "Vehicle"),
    "briefing_transmission": ("گیربکس", "Transmission"),
    "briefing_transfer": ("انتقال قدرت", "Transfer case"),
    "briefing_diff": ("دیفرانسیل", "Differential"),
    "briefing_tires": ("لاستیک", "Tyres"),
    "briefing_suspension": ("تعلیق", "Suspension"),
    "briefing_start": ("شروع مسابقه", "START"),
    "briefing_recommend": ("پیشنهاد", "Suggestion"),
    "briefing_warning": ("انتخاب نامناسب روی نتیجه اثر می‌گذارد", "A poor choice will show in the result"),
    "briefing_winch": ("وینچ", "Winch"),
    "recommend_low_range": ("برای این شیب، ۴L و دندهٔ یک", "Low range 4L and first gear for this grade"),
    "recommend_short_gears": ("نسبت‌های کوتاه و دندهٔ پایین", "Short ratios and a low gear"),
    "recommend_mud_tires": ("لاستیک گلی برای سطوح خیس", "Mud tyres for the wet surfaces"),
    "recommend_rock_tires": ("لاستیک سنگی برای مسیر خشک", "Rock tyres for the dry stone"),
    "recommend_descent": ("دندهٔ پایین برای فرودهای طولانی", "A low gear for the long descents"),
    "recommend_standard": ("پیکربندی استاندارد کافی است", "The stock setup is enough"),
    # garage
    "garage_transmission": ("گیربکس", "Transmission"),
    "garage_setup": ("پیکربندی", "SETUP"),
    "garage_apply": ("اعمال", "Apply"),
    "garage_diff": ("دیفرانسیل", "Differential"),
    "garage_transfer": ("جعبهٔ انتقال", "Transfer case"),
    "garage_tires": ("لاستیک", "Tyres"),
    "garage_suspension": ("تعلیق", "Suspension"),
    "garage_stock": ("استاندارد", "Stock"),
    "garage_fitted": ("نصب‌شده", "Fitted"),
    "garage_ratio": ("ضرایب دنده", "Gear ratios"),
    "garage_final": ("نسبت نهایی", "Final drive"),
    "garage_gears": ("تعداد دنده", "Gears"),
    "garage_capacity": ("ظرفیت گشتاور", "Torque capacity"),
    "setup_note": ("هر تغییر همین حالا روی شبیه‌سازی اثر می‌گذارد؛ این اعداد از پروفایل واقعی خودرو خوانده می‌شوند.", "Every change takes effect in the simulation immediately; these numbers come from the vehicle's real profile."),
    # weather
    "weather_clear": ("صاف", "Clear"),
    "weather_cloudy": ("ابری", "Cloudy"),
    "weather_rain": ("باران", "Rain"),
    "weather_heavy_rain": ("باران شدید", "Heavy rain"),
    "weather_snow": ("برف", "Snow"),
    "weather_fog": ("مه", "Fog"),
    "stage_region_black_ridge": ("یال سیاه", "BLACK RIDGE"),
}


def main() -> None:
    for lang_index, code in enumerate(("fa", "en")):
        path = I18N / f"{code}.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        added = 0
        for key, pair in STRINGS.items():
            if key not in data:
                added += 1
            data[key] = pair[lang_index]
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"{code}.json: {len(data)} keys ({added} new)")


if __name__ == "__main__":
    main()
