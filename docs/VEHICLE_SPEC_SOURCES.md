# MUDRO 3.0 — Vehicle Specification Sources

**Status:** research deliverable, compiled 2026-11-14.
**Scope:** one exact, documented variant per vehicle for the five 4×4s used in MUDRO 3.0. Every value below belongs to the single variant named in that vehicle's header. No value is carried across trims, model years or markets except where a note says so explicitly.
**Machine-readable twin:** `local-builds/research/vehicle_specs.json` carries the same numbers under the same names.

---

## 0. How to read this document

**Units.** All values are SI: kW, N·m, rpm, kg (kerb), mm, litres, cc. Gear ratios and final drives are dimensionless.

**Evidence tiers used in this file**

| Tier | Meaning | Examples here |
|---|---|---|
| **A — factory** | Manufacturer brochure, specification sheet or press document for the exact variant | Toyota South Africa LC79 sheet, Nissan Australia Y61 brochure, Toyota UK Hilux technical specification, Suzuki Australia specification page, Mitsubishi Australia Pajero brochure |
| **B — service/manual** | Workshop-manual or manufacturer technical documentation, sometimes for a neighbouring model year | Toyota Hilux workshop-manual specification page (transfer ratio) |
| **C — secondary** | Specialist/enthusiast technical write-up, traceable to factory data but not itself factory | Team Ghetto Racing JB74 gearing page |

Every numeric claim in the tables below carries the URL of the page it came from. All pages listed were opened and read during this run; nothing is cited from search-result snippets, memory or inference. Pages that were opened but are *not* used as the basis of a value are listed in §11 as cross-checks.

**Rule applied to conflict:** where two sources disagree, the manufacturer document for the exact variant wins; the losing figure is still recorded in §7 so the disagreement stays visible.

---

## 1. Variant selection and why

| # | Vehicle | Chosen variant | Market / MY | Why this one | Not chosen |
|---|---|---|---|---|---|
| 1 | Toyota Land Cruiser 70 | **LC79 Double Cab 4.2 D (1HZ), 5MT, 4×4** | South Africa, MY2026 | The only 70 Series variant for which a *current* factory sheet gives engine, gearbox ratios, final drive, kerb, tracks, tyre and suspension in one document. The brief allowed 1HZ "whichever you can source best". | 4.5 V8 1VD-FTV: Toyota Australia, Toyota Gibraltar and Toyota South Africa have all dropped the V8 from their live spec pages, so no factory V8 sheet could be opened. Australian V8 figures exist only in secondary summaries. |
| 2 | Nissan Patrol Y61 | **Patrol ST 5-door wagon, 3.0 Di (ZD30DDTi), 5MT** | Australia, MY2015 | Nissan Australia's own Y61 brochure prints the complete table including **both** gearbox variants, final drive, transfer high/low, tare, tracks, tyre and suspension. | Patrol Pickup 3.0 Di (Nissan South Africa): also fully specified, but a leaf-sprung single-cab pickup — a different vehicle behaviour from the coil-sprung wagon. Kept as cross-check only. |
| 3 | Toyota Hilux AN120 | **Hilux Invincible Double Cab 2.8 GD-6 (1GD-FTV), 6MT, 4×4** | UK, MY2021 | Toyota UK publishes a real technical-specification PDF with all six ratios, final drive, kerb range, tracks and tyre fitment per grade. | 2.8 GD-6 automatic (500 N·m): ratios and final drive also in the same sheet, but a torque-converter model is a different simulation problem. Toyota ZA's current Hilux sheet is 2.4 GD-6 only. |
| 4 | Suzuki Jimny JB74 | **Jimny 3-door 1.5 (K15B), 5MT, part-time 4WD** | Australia, MY2024 (nominal) | Suzuki Australia's specification page prints every gear ratio, the final drive, kerb, tracks, tyre and both axle layouts. | Jimny XL (5-door, 2590 mm wheelbase): same engine but a different body; excluded to keep one wheelbase. Automatic: different transfer ratios (1.320/2.643) and final drive (4.300). |
| 5 | Mitsubishi Pajero V80 | **Pajero GLX 5-door 3.2 DiD (4M41), 5MT** | Australia, MY2010 | Mitsubishi Australia's Pajero brochure contains the full factory table: both transmissions, **transfer 1.000/1.900**, final drive, kerb, tracks, tyre, suspension. | 3.2 DiD automatic: 118 kW/378 N·m with 3.917 final drive (same brochure) — documented, but the manual is the cleaner reference case. 2012+ 147 kW tune: no factory sheet opened. |

---

## 2. Toyota Land Cruiser 79 Double Cab 4.2 D (1HZ)

**Variant:** LC79 Double Cab, 4.2 litre diesel, 5-speed manual, part-time 4×4 — South African specification, sheet issued 2026-01-14.
**Source (Tier A):** https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf

| Field | Value | Unit | Source |
|---|---|---|---|
| manufacturer | Toyota | — | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| model | Land Cruiser 79 Double Cab | — | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| model_year | 2026 | year | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| trim | LC79 4.2 D Double Cab (5MT, 4×4) | — | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| engine_code | 1HZ | — | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| displacement_cc | 4164 | cc | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| cylinders | 6, inline | — | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| aspiration | naturally aspirated (sheet lists no turbocharger for this column) | — | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| max_power_kw | 96 @ 3800 rpm | kW | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| max_torque_nm | 285 @ 2200 rpm | N·m | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| gearbox_type | manual, 5-speed | — | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| gear_ratios | 4.313 / 2.330 / 1.436 / 1.000 / 0.838 | — | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| reverse_ratio | 4.220 | — | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| final_drive | 4.100 | — | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| transfer_case_ratios | high 1.000 / **low null — see §8** | — | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| mass_kg (kerb) | 2225 | kg | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| wheelbase_mm | 3180 | mm | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| length_mm | 5235 | mm | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| width_mm | 1870 | mm | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| height_mm | 1945 | mm | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| track_mm | front 1555 / rear 1460 | mm | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| tyre_size | 265/70R16 (front and rear, alloy) | — | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| suspension_front | rigid axle, coil springs | — | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| suspension_rear | rigid axle, leaf springs | — | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| drivetrain | part-time 4WD, 2-speed transfer case, 4WD selector lever | — | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| fuel_type | diesel | — | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |
| fuel_tank_l | 130 | L | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf |

**Additional factory data from the same sheet (useful for the game, not in the required field list):** GVM 3200 kg, GCM 4700 kg, ground clearance 235 mm, approach 33°, departure 27°, turning circle 7.2 m, top speed 165 km/h, compression 22.4:1, bore × stroke 94.0 × 100.0 mm, service interval 12 months/10 000 km.

**Why the V8 is absent:** the 4.5 V8 D-4D (1VD-FTV) was the headline 70 Series engine for years, but the live 70 Series pages of Toyota Australia, Toyota Gibraltar and Toyota South Africa have all moved to 2.8 GD-6 / 1HZ / 4.0 petrol. Rather than assemble a V8 from secondary sources with mixed market tunes (151 kW/430 N·m in some markets, 162 kW/430 N·m in others), this document uses the one variant with a complete current factory sheet — which the brief explicitly permits.

---

## 3. Nissan Patrol Y61 ST 5-door, 3.0 Di (ZD30DDTi)

**Variant:** Patrol Y61 ST wagon, 5 doors, 7 seats, 3.0 litre common-rail intercooled turbo-diesel, 5-speed manual, part-time 4WD — Australian specification, brochure updated June 2015.
**Source (Tier A):** http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf

| Field | Value | Unit | Source |
|---|---|---|---|
| manufacturer | Nissan | — | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| model | Patrol Y61 (GU) | — | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| model_year | 2015 | year | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| trim | ST 5-door wagon, 3.0 Di, 5MT | — | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| engine_code | ZD30DDTi | — | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| displacement_cc | 2953 | cc | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| cylinders | 4, inline, DOHC 16-valve | — | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| aspiration | turbocharger with intercooler, common rail | — | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| max_power_kw | 118 @ 3200–3400 rpm (manual) | kW | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| max_torque_nm | 380 @ 2000–2400 rpm (manual) | N·m | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| gearbox_type | manual, 5-speed | — | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| gear_ratios | 4.556 / 2.625 / 1.591 / 1.000 / 0.837 | — | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| reverse_ratio | 4.246 | — | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| final_drive | 4.111 | — | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| transfer_case_ratios | high 1.000 / low 2.02 | — | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| mass_kg (tare) | 2478 (ST, manual) | kg | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| wheelbase_mm | 2970 | mm | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| length_mm | 5050 | mm | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| width_mm | 1940 | mm | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| height_mm | 1855 | mm | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| track_mm | front 1605 / rear 1625 | mm | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| tyre_size | 275/65R17 on 8JJ17 alloy (ST) | — | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| suspension_front | 3-link coil spring with stabiliser bar | — | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| suspension_rear | 5-link coil spring with stabiliser bar | — | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| drivetrain | part-time 4WD, 2-speed transfer; manual free-wheel hubs on ST (DX gets automatic locking hubs) | — | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| fuel_type | diesel | — | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |
| fuel_tank_l | 125 (95 main + 30 sub) | L | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf |

**Additional factory data:** GVM 3060 kg (manual), ground clearance 210 mm, approach 36°, departure 30°, wading 700 mm, turning circle 12.6 m, 7 seats, part-time 4WD (ST on manual free-wheel hubs, DX on automatic locking hubs). The same brochure lists the automatic variant separately: 118 kW @ 3600 rpm, 354 N·m @ 2000 rpm, ratios 2.784/1.544/1.000/0.694, final drive 4.375 — deliberately *not* mixed into the figures above.

---

## 4. Toyota Hilux Invincible Double Cab 2.8 GD-6 (1GD-FTV), 6MT

**Variant:** Hilux AN120 Double Cab, 2.8 litre diesel, 6-speed manual, 4×4 — UK specification, Toyota GB technical specification sheet (ref. 210129M, published March 2021).
**Source (Tier A):** https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf
**Transfer ratio (Tier B):** https://toyotamanuals.gitlab.io/pz471-zx006-ca/htmlweb/ncf/ncf258e/m_07_0340.pdf

| Field | Value | Unit | Source |
|---|---|---|---|
| manufacturer | Toyota | — | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| model | Hilux (AN120) Double Cab | — | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| model_year | 2021 | year | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| trim | Invincible Double Cab, 2.8 GD-6, 6MT, 4WD | — | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| engine_code | 1GD-FTV | — | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| displacement_cc | 2755 | cc | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| cylinders | 4, inline, 16-valve DOHC | — | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| aspiration | turbocharger, intercooled, common rail | — | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| max_power_kw | 150 @ 3000–3400 rpm | kW | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| max_torque_nm | 420 @ 1400–3400 rpm (6MT; the 6AT is 500 N·m @ 1600–2800) | N·m | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| gearbox_type | manual, 6-speed | — | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| gear_ratios | 4.784 / 2.423 / 1.443 / 1.000 / 0.826 / 0.643 | — | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| reverse_ratio | 4.066 | — | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| final_drive | 3.583 | — | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| transfer_case_ratios | high 1.000 / low 2.566 (see §9 — Tier B) | — | https://toyotamanuals.gitlab.io/pz471-zx006-ca/htmlweb/ncf/ncf258e/m_07_0340.pdf |
| mass_kg (kerb) | 2120 (documented range for Double Cab 2.8 6MT: 2120–2335) | kg | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| wheelbase_mm | 3085 | mm | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| length_mm | 5325 | mm | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| width_mm | 1855 | mm | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| height_mm | 1815 | mm | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| track_mm | front 1540 / rear 1550 | mm | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| tyre_size | 265/60R18 (Invincible & Invincible X); 265/65R17 on Active & Icon | — | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| suspension_front | double wishbone | — | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| suspension_rear | leaf springs, rigid axle | — | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| drivetrain | part-time 4WD (selectable 4×4, 2-speed transfer) | — | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| fuel_type | diesel | — | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |
| fuel_tank_l | 80 | L | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf |

**Additional factory data:** GVW 3210 kg, payload 1015 kg (2.8 6MT; the sheet's Double Cab range across all four drivetrains is 1010–1030 kg), ground clearance (Double Cab) 310 mm, approach 29°, departure 26°, wading 700 mm, turning circle 6.4 m (body 6.7 m), 0–62 mph 10.13 s (2.8 6MT), top speed 109 mph.

---

## 5. Suzuki Jimny 3-door 1.5 (K15B), 5MT

**Variant:** Jimny JB74 3-door, 1.5 litre K15B, 5-speed manual, part-time 4WD — Australian specification.
**Source (Tier A):** https://www.suzuki.com.au/vehicles/4x4/jimny/specifications
**Transfer ratio (Tier C):** https://teamghettoracing.com/vehicles/cars/2019-jimny-jb74w/gearing

| Field | Value | Unit | Source |
|---|---|---|---|
| manufacturer | Suzuki | — | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| model | Jimny (JB74, 3-door) | — | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| model_year | 2024 (nominal — page carries no MY; see §8) | year | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| trim | Jimny 3-door, 1.5 VVT, 5MT | — | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| engine_code | K15B | — | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| displacement_cc | 1462 | cc | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| cylinders | 4, inline, 16-valve, VVT | — | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| aspiration | naturally aspirated petrol | — | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| max_power_kw | 75 @ 6000 rpm | kW | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| max_torque_nm | 130 @ 4000 rpm | N·m | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| gearbox_type | manual, 5-speed | — | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| gear_ratios | 4.425 / 2.304 / 1.674 / 1.190 / 1.000 | — | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| reverse_ratio | 5.151 | — | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| final_drive | 4.090 | — | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| transfer_case_ratios | high 1.000 / low 2.00 (source states 2:1) | — | https://teamghettoracing.com/vehicles/cars/2019-jimny-jb74w/gearing |
| mass_kg (kerb) | 1095 (minimum, manual) | kg | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| wheelbase_mm | 2250 | mm | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| length_mm | 3645 | mm | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| width_mm | 1645 | mm | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| height_mm | 1725 | mm | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| track_mm | front 1395 / rear 1405 | mm | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| tyre_size | 195/80 R15 (15-inch steel or alloy) | — | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| suspension_front | 3-link rigid axle with coil spring | — | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| suspension_rear | 3-link rigid axle with coil spring | — | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| drivetrain | part-time 4WD | — | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| fuel_type | petrol | — | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |
| fuel_tank_l | 40 | L | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications |

**Additional factory data:** GVM 1435 kg, ground clearance 210 mm, approach 37°, ramp breakover 28°, departure 49°, turning circle 4.9 m, compression 10.0:1, bore × stroke 74.0 × 85.0 mm, braked towing 1300 kg.

**Automatic variant (documented separately in the same table, not used):** 4-speed, ratios 2.875/1.568/1.000/0.697, reverse 2.300, final drive 4.300, kerb 1110 kg.

---

## 6. Mitsubishi Pajero GLX 5-door 3.2 DiD (4M41), 5MT

**Variant:** Pajero V80 5-door, 3.2 litre DI-D, 5-speed manual, Super Select II 4WD — Australian specification, MY2010 brochure.
**Source (Tier A):** https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf

| Field | Value | Unit | Source |
|---|---|---|---|
| manufacturer | Mitsubishi | — | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| model | Pajero (V80, 5-door) | — | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| model_year | 2010 | year | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| trim | GLX 5-door, 3.2 DiD, 5MT | — | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| engine_code | 4M41 | — | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| displacement_cc | 3200 | cc | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| cylinders | 4, inline, DOHC 16-valve | — | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| aspiration | turbocharger with intercooler, common rail | — | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| max_power_kw | 125 @ 3800 rpm (manual) | kW | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| max_torque_nm | 358 @ 2000 rpm (manual) | N·m | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| gearbox_type | manual, 5-speed | — | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| gear_ratios | 4.234 / 2.238 / 1.398 / 1.000 / 0.760 | — | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| reverse_ratio | 3.553 | — | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| final_drive | 4.100 | — | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| transfer_case_ratios | high 1.000 / low 1.900 | — | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| mass_kg (kerb) | 2270 (3.2D M/T, GLX/VRX) | kg | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| wheelbase_mm | 2780 | mm | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| length_mm | 4900 | mm | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| width_mm | 1875 | mm | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| height_mm | 1900 | mm | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| track_mm | front 1570 / rear 1570 | mm | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| tyre_size | 265/65R17 112H (GLX, 17×7.5 alloy); 265/60R18 on VRX/Exceed | — | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| suspension_front | independent, double wishbone, coil spring, stabiliser bar | — | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| suspension_rear | independent, multi-link, coil spring, stabiliser bar | — | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| drivetrain | full-time 4WD (Super Select II): 2H / 4H / 4HLc / 4LLc | — | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| fuel_type | diesel | — | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |
| fuel_tank_l | 88 | L | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf |

**Additional factory data:** GVM 3030 kg (3.2D M/T), payload 760 kg, ground clearance 225 mm, wading 700 mm, approach 36.6°, ramp breakover 22.5°, departure 25.0°, turning circle 11.4 m, compression 17.0:1, bore × stroke 98.5 × 105.0 mm.

**Automatic variant (documented in the same table, not used):** 118 kW @ 3800 rpm, 378 N·m @ 2000 rpm, ratios 3.789/2.057/1.421/1.000/0.731, reverse 3.865, final drive 3.917, transfer 1.000/1.900, kerb 2260 kg. Every variant in that table — both engines and both transmissions — carries the same transfer ratios (1.000 high / 1.900 low), which is why the 1.900 figure is treated as high confidence.

---

## 7. Where the sources disagree

| Item | Figure A | Figure B | Choice and reason |
|---|---|---|---|
| **Patrol Y61 overall width** | 1940 mm — Nissan Australia brochure | 1840 mm — auto-data.net (EU 3.0 Di, 2004–2016) | **1940 mm.** Manufacturer figure for the exact variant; consistent with the 1605/1625 mm tracks plus the ST's over-fenders. The 1840 mm figure is most likely body width without flares. |
| **Patrol Y61 kerb mass** | 2478 kg — Nissan Australia, ST manual | 2410–2510 kg — auto-data.net, EU 3.0 Di automatic | **2478 kg.** Matches the chosen manual ST wagon; the EU range covers a different transmission and trim mix. |
| **Pajero V80 kerb mass** | 2270 kg — Mitsubishi Australia, 3.2D M/T | 2310 kg — auto-data.net, EU 3.2 Di-DC automatic 5-door | **2270 kg.** The chosen variant is the manual; the 2310 kg figure belongs to the heavier automatic with a different final drive. |
| **Pajero V80 power/torque** | 125 kW / 358 N·m — Mitsubishi Australia, manual | 118 kW / 378 N·m — same brochure, automatic; 121 kW / 381 N·m — auto-data.net, EU automatic | **125 kW / 358 N·m.** Australian manual calibration; the automatic is torque-limited by its gearbox and is a different drivetrain. |
| **Pajero V80 power/torque column pairing** | the PDF's text order places the labels "M/T A/T" before the value pair 118 kW / 378 N·m and 125 kW / 358 N·m, so the pairing of numbers to columns is ambiguous in the extracted layout | auto-data.net, EU automatic 5-door: 121 kW / 381 N·m | **Manual = 125 kW / 358 N·m; automatic = 118 kW / 378 N·m.** The automatic figure is the one that matches the independent EU automatic entry (121 kW / 381 N·m), so the two brochure columns are read in that order. Flagged because the PDF text order alone does not settle it. |
| **Pajero V80 height** | 1900 mm — Mitsubishi Australia, 5-door | 1870 mm — auto-data.net, EU 5-door | **1900 mm.** Manufacturer, 5-door body. The 1870 mm figure appears to be a different suspension/tyre combination. |
| **Hilux kerb mass** | 2120–2335 kg range — Toyota UK, Double Cab 2.8 6MT | single value required for simulation | **2120 kg** recorded as the baseline (lightest documented 2.8 6MT Double Cab), with the full range in `mass_kg_range`. A fully optioned Invincible sits near the top of that range. |
| **Land Cruiser 79 kerb mass** | 2225 kg — Toyota South Africa, 4.2 D double cab | 2165 kg — same sheet, 4.0 petrol double cab | **2225 kg.** Same document, same body, diesel variant chosen. |
| **Jimny track** | front 1395 / rear 1405 mm | the Suzuki table's row order is visually ambiguous in the extracted HTML | **1395/1405.** The two values appear under "Track — Front" and the immediately preceding "Rear" row; the 10 mm rear bias is consistent with the JB74 axle. Flagged, not silently resolved. |

---

## 8. Nulls, estimates and nominal values

| Vehicle | Field | Treatment | Reasoning |
|---|---|---|---|
| Land Cruiser 79 4.2 D | `transfer_case_ratios.low` | **null, `estimated: true`** | The Toyota South Africa sheet lists "Transfer Case" and a 4WD selector but prints no ratio. The part-time transfer used behind the 1HZ is widely quoted at 2.488:1, but no manufacturer or workshop-manual page stating that for the 79 could be opened in this run. **Provisional gameplay value 2.488** is recorded in `notes.provisional_gameplay_value`, explicitly not factory data. |
| Hilux 2.8 GD-6 | `transfer_case_ratios.low` | value 2.566, **`estimated: true`**, confidence medium | Toyota's Hilux 4×4 workshop-manual specification page states transfer H4/L4 = 1.000/2.566 for the Hilux 4WD (R151F era). The AN120 uses the VF2A transfer and Toyota UK's AN120 sheet prints no transfer ratio, so the figure is carried across the Hilux 4WD transfer family — documented, but not confirmed for the AN120 by a factory document. |
| Jimny JB74 | `transfer_case_ratios` | 1.000 / 2.00, confidence medium | The Tier C source tabulates the manual JB74 as 1:1 high and 2:1 low and states it is built from Suzuki Australia plus Suzuki New Zealand data (Suzuki NZ publishes transfer ratios). The unrounded factory figure quoted elsewhere is 2.002; the 0.1 % difference is irrelevant to the simulation, and 2.00 is what the opened source actually says. |
| Jimny JB74 | `model_year` | 2024, marked nominal | Suzuki Australia's specification page is undated and carries no model year. 2024 is a label for the listing, not a claim that the page is MY2024-specific. The K15B/5MT 3-door data are the values listed at access time (2026-11-14). |
| Hilux | `tyre_size` | 265/60R18 | Chosen because the variant is Invincible; the same sheet gives 265/65R17 for Active/Icon. Not an estimate, but a grade-dependent field. |
| Pajero | `mass_kg` | 2270 kg | GLX/VRX manual; the Exceed automatic is 2310 kg in the same table. |

No other field in this document is estimated: every remaining number is printed in a manufacturer document for the exact variant named in the section header.

---

## 9. Evidence quality and known weak links

1. **Land Cruiser 79 transfer ratio (weakest link).** No opened source. Treated as null rather than filled from memory.
2. **Hilux transfer ratio (Tier B, cross-generation).** Toyota workshop manual, but for the previous Hilux 4WD generation. The VF2A transfer family and the 2.566 low ratio are consistent across both, but this is an inference and is labelled as such.
3. **Jimny transfer ratio (Tier C).** A specialist gearing page that explicitly derives its table from Suzuki Australia and Suzuki New Zealand specifications. No Suzuki page printing the transfer ratio itself could be opened.
4. **Pajero brochure provenance.** The PDF is an archived copy hosted by autocatalogarchive.com; its content is Mitsubishi Motors Australia's MY2010 brochure. Treated as Tier A because the document is the manufacturer's, but the hosting is third-party.
5. **Patrol brochure provenance.** Hosted on a dealer-resource domain (`resource.digitaldealer.com.au`), watermarked "Nissan Motor Co (Australia) Pty. Ltd.", updated June 2015. Same caveat as above.
6. **Model years are model-year labels, not build dates.** The LC79 sheet is dated 2026-01-14; the Patrol brochure June 2015; the Hilux sheet March 2021; the Pajero brochure MY2010; the Jimny page undated.

---

## 10. Trademark and design-rights note

Toyota, Land Cruiser, Hilux, Nissan, Patrol, Suzuki, Jimny, Mitsubishi and Pajero are registered trademarks of their respective owners. MUDRO 3.0 uses these names **descriptively only**, to identify the real vehicles whose published specifications inform the simulation. The game is **not affiliated with, sponsored by, or endorsed by** Toyota Motor Corporation, Nissan Motor Co., Suzuki Motor Corporation or Mitsubishi Motors Corporation.

No manufacturer logos, badges, wordmarks, grille badges or trade dress are reproduced in the game or in this document. Vehicle shapes in the game are original low-poly interpretations, not copies of protected designs; where a design right or registered design might subsist in a body panel, the game's geometry must be independently authored rather than traced from manufacturer drawings or photographs. Specification data (dimensions, ratios, masses) are facts and are used as functional reference data.

If MUDRO 3.0 is ever distributed commercially, the vehicle names should be reviewed for each target market: some jurisdictions treat the use of a mark to identify a real product in an interactive work as nominative fair use, others are narrower. This note is engineering documentation, not legal advice.

---

## 11. Source register (all opened during this run, 2026-11-14)

**Used as the basis of values**

| ID | URL | Document | Tier |
|---|---|---|---|
| S1 | https://media.cdntoyota.co.za/spec-sheets/Land-Cruiser-79-Double-Cab.pdf | Toyota South Africa Motors, "Land Cruiser 79 Double Cab — Specifications", issued 2026-01-14 | A |
| S2 | http://resource.digitaldealer.com.au/pdf/1400498761584a36bc7993f197613174.pdf | Nissan Motor Co. (Australia), "Patrol Y61 — Specifications", updated June 2015 (NIS2992) | A |
| S3 | https://media.toyota.co.uk/wp-content/uploads/sites/5/2021/03/1611922571210129MHiluxTechSpec.pdf | Toyota GB, "Hilux Technical Specifications", ref. 210129M, March 2021 | A |
| S4 | https://www.suzuki.com.au/vehicles/4x4/jimny/specifications | Suzuki Australia, Jimny range specifications (undated) | A |
| S5 | https://autocatalogarchive.com/wp-content/uploads/2017/05/Mitsubishi-Pajero-2010-AU.pdf | Mitsubishi Motors Australia, MY2010 Pajero brochure (archived copy) | A |
| S6 | https://toyotamanuals.gitlab.io/pz471-zx006-ca/htmlweb/ncf/ncf258e/m_07_0340.pdf | Toyota workshop manual, "Hilux — Major Technical Specifications" (transfer ratio table) | B |
| S7 | https://teamghettoracing.com/vehicles/cars/2019-jimny-jb74w/gearing | Team Ghetto Racing, "JB74 gear ratios and gearing" (built from Suzuki AU/NZ data) | C |

**Opened as cross-checks, not used as the basis of a value**

| URL | Why it was opened | Outcome |
|---|---|---|
| https://www.auto-data.net/en/nissan-patrol-v-5-door-y61-facelift-2004-3.0-di-160hp-4x4-automatic-43053 | Independent check of Y61 dimensions, kerb, engine code | Confirms 2970 mm wheelbase, 2953 cc, ZD30DDTi; disagrees on width and kerb (see §7) |
| https://www.auto-data.net/en/mitsubishi-pajero-iv-3.2-di-dc-165hp-5-doors-15483 | Independent check of Pajero IV dimensions and kerb | Confirms 4900/1875/2780 mm and 4M41; disagrees on height and kerb (see §7) |
| https://www.toyota.com.au/landcruiser-70 | Check whether a V8 70 Series spec still exists | No: Toyota Australia now lists 2.8 turbo-diesel only, 151 kW/500 N·m |
| https://www.toyota-gib.com/en/models/land-cruiser-70.html | Check for a 1HZ/V8 70 Series spec sheet | No ratio data in the page text; variants are 1GD-FTV and 1HZ, no transfer table |
| https://www.toyota-gib.com/en/models/hilux.html | Check for a 2.8 GD-6 spec sheet | Only 2.4 GD-6 (2GD-FTV) and older 5L variants listed |
| https://media.cdntoyota.co.za/spec-sheets/Hilux-Double-Cab.pdf | Check Toyota ZA's current Hilux sheet | Now 2.4 GD-6 only — no 2.8 data, so not usable |
| https://www.ultimatespecs.com/car-specs/Nissan/6750/Nissan-Patrol-GR-(Y61)-Long-30-Di-Turbo.html | Try to corroborate Patrol ratios | Blocked by a bot-verification wall; no data read |

---

## 12. Open items worth one more pass

1. **LC79 transfer low ratio.** Find the Toyota 70 Series repair-manual specification page (HF1A transfer, "Transfer gear ratio H4/L4") or a Toyota Gibraltar HZJ79 spec-sheet PDF. If found, 2.488:1 stops being provisional.
2. **Hilux AN120 transfer ratio.** Toyota's VF2A transfer documentation for the GUN/AN120 (the "05-AT-A750" manual section) or a Toyota Gibraltar GUN126 spec sheet would upgrade §9 item 2 from inference to factory.
3. **Jimny transfer ratio.** Suzuki New Zealand or Suzuki Gibraltar specification page that prints the transfer case ratio directly would retire the Tier C citation.
4. **A V8 70 Series dataset**, if the game specifically wants the 1VD-FTV: the 2021–2022 Toyota Australia brochure PDF is the most likely factory source, and its 151 kW/430 N·m tune would need to be kept separate from the 162 kW/430 N·m markets.
