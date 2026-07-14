# Analisis Komprehensif — Crossroad Market

> Dibuat: 2026-07-14
> Diperbarui: 2026-07-14 (re-analisis pasca-perubahan)
> Engine: Godot 4.6 | Genre: 2D RPG Pixel Art Cozy Shop Simulation | Durasi Game: 6 Hari

---

## Daftar Isi

1. [Ringkasan Perubahan sejak Analisis Pertama](#1-ringkasan-perubahan-sejak-analisis-pertama)
2. [Arsitektur & Struktur Kode](#2-arsitektur--struktur-kode)
3. [Gameplay & Mekanik](#3-gameplay--mekanik)
4. [Data & Content](#4-data--content)
5. [UI & Presentation](#5-ui--presentation)
6. [Code Quality](#6-code-quality)
7. [Documentation vs Implementation Gap](#7-documentation-vs-implementation-gap)
8. [Prioritas Revisi](#8-prioritas-revisi)

---

## 1. Ringkasan Perubahan Sejak Analisis Pertama

Berikut ringkasan perubahan yang ditemukan setelah re-analisis codebase:

| Aspek | Status Sebelumnya | Status Saat Ini |
|---|---|---|
| `BlueprintManager` autoload | ❌ Tidak terdaftar | ✅ Terdaftar di project.godot |
| `BlueprintManager` structure | Static class | **Masih static class** (extends Node tapi semua method/variable `static`) |
| `Store.gd` line count | 1535 lines | **1595 lines** (bertambah 60, bukan berkurang) |
| NPC behavior logic | Inline di NPC.gd | ✅ **Sudah diekstrak** ke `behavior/` dan `presentation/` |
| 5 store sub-controllers | Parsial digunakan | ✅ **Semua sudah digunakan penuh** (RefCounted static helpers) |
| `LocationTransition.gd` | Stub sederhana | ⚠️ **Partial stub** — ada TODOs unimplemented |
| `scripts/locations/Store.gd` stub | 49 bytes | **1 line** (`extends "res://scripts/locations/store/Store.gd"`) |
| `scripts/ui/Cashier.gd` stub | 65 bytes | **2 lines** (`class_name Cashier extends ...`) |
| `Cashier.gd` (ui/cashier/) | ~18 KB | **~878 lines** — +POS tab +Restock tab + 3 service class |
| `Storage.gd` | ~15 KB | **575 lines** — proper state setters, animated ghost section reveal |
| `Player.gd` | ~19 KB | **~680 lines** — confirmed new/modified |
| `HUD.gd` | ~7.4 KB | **~425 lines** — confirmed new/modified |
| `TimeManager` | Basic | ✅ **+Phase enum** |
| `RelationshipManager` | Basic | ✅ **+MIN_TRUST/MAX_TRUST constants + clampi** |
| `NPCScheduler` | Basic | ✅ **+Named constants** (SPAWN_INTERVAL, DAY_ONE_NIGHT_SPAWN_INTERVAL, dll.) |
| `EconomyManager` | Basic | ✅ **Proper autoload** |
| `Inventory` | Basic | ✅ **+Defensive duplicate()** |
| `data/schedules/` | Kosong | ❌ **Masih kosong** |
| `data/dialogues/generic/` | Kosong | ❌ **Masih kosong** |
| `data/dialogues/story/` | Kosong | ❌ **Masih kosong** |
| `data/events/story/` | Kosong | ❌ **Masih kosong** |
| Ending scenes | Tidak ada | ❌ **Tidak ada** |
| Daily Report UI | Tidak ada | ❌ **Tidak ada** |

---

## 2. Arsitektur & Struktur Kode

### 2.1 BlueprintManager — Registered Autoload, Tetap Static Class

**Status:** `BlueprintManager` sekarang terdaftar sebagai autoload di `project.godot`.

**Namun struktur internal masih static class:**

```gdscript
# scripts/managers/BlueprintManager.gd
extends Node  # ← ada tapi tidak digunakan

static var _bp_cache_initialized: bool
static var _bp_immediate: BlueprintData
static var _bp_queue: BlueprintData
static var _bp_browse: BlueprintData

static func _ensure_init() -> void:
    # lazy singleton init — dipanggil saat pertama kali diakses
    ...

static func get_dialog(bp_type, mood, key) -> String:
static func evaluate_no_item_action(npc) -> Action:
static func get_item_found_dialog(npc) -> String:
# ... semua method adalah static
```

**Yang sudah bagus:**
- `enum Action { LEAVE, QUEUE, BROWSE_BUY }` — typed enum untuk action branching
- Lazy singleton init via `_ensure_init()` — BlueprintData dibuat saat pertama kali diakses
- Terdaftar di project.godot → accessible secara global

**Yang masih bermasalah:**
- `extends Node` tapi tidak ada `_ready()`, tidak ada instance variable, tidak ada non-static method
- Godot membuat instance Node saat startup, tapi instance tersebut tidak pernah digunakan
- Cache di static variable — tidak bisa di-reset secara clean
- Tidak ada signals

**Kesimpulan:** BlueprintManager secara functional sudah berjalan, tapi secara arsitektur masih static class. Untuk Godot idiomatic code, idealnya refactor ke proper instance-based autoload.

### 2.2 Store.gd — Bertambah Besar, Bukan Berkurang

**Status: 1595 lines** (naik dari 1535 lines sebelumnya).

**Yang sudah dilakukan dengan baik:**
- 5 sub-controller di `scripts/locations/store/` sudah digunakan secara penuh:
  - `StoreShelfController.gd` (71 lines) — depth check, shelf stock count
  - `StoreProgressionController.gd` (39 lines) — predicate unlock logic
  - `StoreTransitionController.gd` (126 lines) — fade, node active/disable
  - `StoreNpcSpawner.gd` (35 lines) — NPC instantiation + wiring
  - `StoreNotificationBridge.gd` (33 lines) — HUD notification proxy
- Semua static method dari 5 sub-controller dipanggil dari Store.gd — tidak ada dead code

**Yang masih jadi masalah:**
- Store.gd sendiri **tidak mengecil** — justru bertamba 60 lines
- Masih monolith dengan 1595 lines
- State flags (`_human_shelf_installed`, `_ghost_shelf_installed`, dll.) masih owned langsung oleh Store.gd
- Sub-controller adalah `extends RefCounted` dengan static methods — bukan Node-based autonomous controller
- Tidak ada `_ready()` / `_process()` di sub-controller karena bukan Node

**Solusi alternatif jika ingin memecah:**
- Membuat sub-controller sebagai `Node` dengan scene tree sendiri (misal: `StoreShelfManager.tscn`)
- Atau pertahankan RefCounted static pattern tapi ekstrak lebih banyak logic dari Store.gd

### 2.3 Stub Files — Masih Belum Diresolusi

**`scripts/locations/Store.gd` — 1 line:**
```gdscript
extends "res://scripts/locations/store/Store.gd"
```

**`scripts/ui/Cashier.gd` — 2 lines:**
```gdscript
class_name Cashier
extends "res://scripts/ui/cashier/Cashier.gd"
```

**Status:** Masih unresolved. Tidak ada scene yang langsung mereferensikan stub ini (perlu dicek di `.tscn` files untuk konfirmasi).

**Langkah:** Verifikasi `Store.tscn` dan `Cashier.tscn` script resource path di `.tscn` files. Jika mereferensikan stub → apakah scene perlu stub ini? Jika tidak digunakan langsung → hapus stub.

### 2.4 LocationTransition.gd — Partial Stub with TODOs

**`scripts/locations/LocationTransition.gd` — 26 lines:**

```gdscript
func _transition_to(target_location: String) -> void:
    # TODO: Implement
    pass

func _can_transition_to(target_location: String) -> bool:
    # TODO: Implement
    return false
```

**Status:** Implementasi tidak ada. Jika `LocationTransition` digunakan di scene manapun, function ini akan return `false` / `pass` dan tidak melakukan apa-apa.

### 2.5 NPC Static Class Variables — Masih Ada

`NPC.gd` masih menggunakan 5 static variables untuk inter-NPC communication:

```gdscript
static var current_queue: Array[NPC] = []
static var counter_position: Vector2 = Vector2.ZERO
static var entrance_position: Vector2 = Vector2.ZERO
static var exit_position: Vector2 = Vector2.ZERO
static var store_path_position: Vector2 = Vector2.INF
```

**Yang sudah bagus:**
- NPC behavior logic sudah diekstrak ke subdirectories:
  - `scripts/npc/behavior/NPCShoppingBehavior.gd` — shelf search, item matching
  - `scripts/npc/behavior/NPCCheckoutBehavior.gd` — checkout total/label math
  - `scripts/npc/behavior/NPCQueueSystem.gd` — queue join/leave/position/prune
  - `scripts/npc/presentation/NPCDialogController.gd` — dialog bubble control
  - `scripts/npc/presentation/NPCVisualController.gd` — visual tint, name label

**Yang masih bermasalah:**
- Static variables tetap ada dan digunakan oleh NPC state machine
- Race condition potensial jika 2 NPC call queue method bersamaan
- State machine 8 states tetap di NPC.gd (masuk akal, karena ini core NPC logic)

### 2.6 Inventory & EconomyManager — Proper Autoloads

**`Inventory.gd`** — proper autoload, clean:
- `get_all()` sekarang return `_items.duplicate()` — defensive copy practice yang bagus

**`EconomyManager.gd`** — proper autoload, clean:
- 3 signals: `gold_changed`, `daily_target_reached`, `daily_report_ready`
- `pay_tax()`, `get_daily_tax()`, `get_daily_report()`
- Sinkronisasi dengan TimeManager via signals

**Tidak ada perubahan structural yang diperlukan** — sudah baik.

### 2.7 NPCScheduler — Named Constants + Typed Helpers

**Yang sudah bagus:**
```gdscript
const SPAWN_INTERVAL: float = 60.0
const DAY_ONE_NIGHT_SPAWN_INTERVAL: float = 8.0
const DAY_ONE_DAY_SPAWN_END_BUFFER: float = 8.0
const DAY_ONE_MIN_SPAWN_INTERVAL: float = 8.0
const DAY_ONE_RUSH_SPAWN_INTERVAL: float = 0.5
const DAY_ONE_SLIME_FOLLOW_UP_DELAY: float = 3.0
```
- Named constants untuk semua magic numbers
- Typed float helpers: `minf()`, `maxf()`
- Callable/lambda untuk directory loading

**Yang masih jadi masalah:**
- Day 1 masih hardcoded — `_make_day_one_customer()` membuat inline NPCData objects
- Tidak ada data-driven schedule dari `data/schedules/`

### 2.8 TimeManager — Phase Enum

```gdscript
enum Phase { MORNING, DAY, NIGHT }

const PHASE_DURATION: float = 240.0
const TOTAL_DAYS: int = 6
const CLOCK_STEP_MINUTES: int = 10
const MORNING_START_MINUTES: int = 480
const DAY_START_MINUTES: int = 600
const NIGHT_START_MINUTES: int = 1080
const END_START_MINUTES: int = 1320
```

**Sangat bagus.** Named constants terpusat, typed enum untuk phase.

### 2.9 RelationshipManager — Trust Clamping

```gdscript
const MIN_TRUST: int = 0
const MAX_TRUST: int = 100

func set_trust(npc_id, value):
    _trust_by_npc[npc_id] = clampi(value, MIN_TRUST, MAX_TRUST)
```

**Sudah bagus.** Clamping dengan named constants.

---

## 3. Gameplay & Mekanik

### 3.1 Day 1 Schedule — Masih Hardcoded

`NPCScheduler.gd` masih memiliki inline hardcoded `NPCData` objects untuk Day 1:
- Bread customer, Water customer, Bandage customer
- Irene (Day 1, DAY phase)
- Gooby (Day 1, NIGHT phase) + slime follow-up
- Custom pacing calculation via `_configure_day_one_day_pacing()`

**Implikasi:**
- Days 2–6 tidak memiliki schedule
- `data/schedules/` masih kosong
- Setiap NPC story baru harus di-hardcode di `NPCScheduler.gd`

### 3.2 Mystery Box Trigger — Rapuh (Belum Berubah)

```gdscript
if _items_taken >= 4 AND _items_placed >= 4:
    unlock_mystery()
```

**Masalah yang sama:**
- 2 independent counters harus sinkron
- Tidak ada validasi item matching
- Edge case: ambil item → jual ke NPC → shelf count tidak akurat

### 3.3 Gooby Event — Tersebar di 3+ File (Belum Berubah)

| Lokasi | Tanggung Jawab |
|---|---|
| `NPCScheduler.gd` | Spawn Gooby + slime follow-up |
| `NPCCheckoutBehavior.gd` | Checkout flow dengan `checkout_outcome = "reject_return"` |
| `Cashier.gd` (878 lines) | UI two-choice panel |

**Cashier.gd sekarang lebih besar** dengan POS tab + Restock tab, tapi Gooby logic tetap di satu tempat yang sama.

### 3.4 Story Event System — Tidak Ada (Belum Berubah)

`data/events/story/{irene,gooby,blacksmith,herbalist,mayor}/` masih kosong.

### 3.5 RelationshipManager — Trust Tanpa Efek (Belum Berubah)

Trust 0–100 hanya disimpan, tidak ada efek ke:
- Dialog
- Checkout behavior
- Item availability
- Ending calculation (yang visible)

### 3.6 Storage.gd — Signifikan Diperbaiki

**575 lines** dengan fitur baru:
- Proper setter methods untuk state propagation dari Store:
  - `set_entry_door()`, `set_shelf_install_state()`, `set_normal_supply_depleted()`
  - `set_mystery_phase_unlocked()`, `set_mystery_discovered()`, `set_mystery_supply_depleted()`
- Animated ghost section reveal: `_apply_normal_box_state()`, `_apply_mystery_phase_state()`
- Physics-based safe drop: `_find_safe_drop_position()`, `_is_drop_position_clear()` dengan `PhysicsShapeQueryParameters2D`
- `SHELF_DROP_FALLBACKS` — fallback candidates untuk shelf drop

**Sangat bagus.** Storage sebagai location sudah mature.

---

## 4. Data & Content

### 4.1 Dialog System — Tidak Ada Perubahan

| Jenis | Status |
|---|---|
| BlueprintManager templates | ✅ 5 template per PatienceType + enum Action |
| Generic NPC dialog | ❌ `data/dialogues/generic/` kosong |
| Story NPC dialog | ❌ `data/dialogues/story/*/` kosong |
| Event dialog | ❌ `data/events/story/*/` kosong |
| Branching conversation | ❌ Tidak ada |
| MysteryDialog.gd | ✅ `data/dialogues/events/MysteryDialog.gd` (satu-satunya yang ada) |

**Yang sudah bagus di BlueprintManager:**
- `enum Action { LEAVE, QUEUE, BROWSE_BUY }` — typed action
- `get_item_found_dialog()`, `get_item_not_found_dialog()`, `get_checkout_dialog()`, `get_done_dialog()`, `get_queue_too_long_dialog()`, `get_checkout_wait_dialog()`

**Yang belum ada:**
- `DialogTree` resource (`.gd extends Resource`)
- `DialogNode` untuk branching
- NPC-specific dialog sequence
- Story NPC (Irene, Gooby) personalized dialog

### 4.2 NPC Schedule Data — Tidak Ada (Belum Berubah)

`data/schedules/` masih kosong.

### 4.3 Story Event System — Tidak Ada (Belum Berubah)

`data/events/story/` masih kosong.

### 4.4 Ending Scenes — Tidak Ada (Belum Berubah)

Tidak ada scene atau script untuk ending.

### 4.5 Daily Report UI — Tidak Ada (Belum Berubah)

`EconomyManager.get_daily_report()` ada tapi tidak ada UI untuk menampilkan dengan baik.

---

## 5. UI & Presentation

### 5.1 Semua Visual — ColorRect Placeholder (Belum Berubah)

`assets/` masih kosong. Concept art ada tapi tidak diintegrasikan.

### 5.2 Cashier — Significant Upgrade

**`scripts/ui/cashier/Cashier.gd` — ~878 lines (naik signifikan)**

Fitur baru yang ditambahkan:
- **POS tab** — Point-of-Sale functionality
- **Restock tab** — Shelf restocking via cashier interface
- 3 supporting service class:
  - `CashierCheckoutHistory.gd` (16 lines) — transaction log
  - `CashierCheckoutService.gd` (39 lines) — pure static helpers
  - `CashierPanel.gd` (166 lines) — procedural UI builder

**CashierPanel** membangun UI secara procedural dengan:
- `CanvasLayer`, `VBoxContainer`, `HBoxContainer`, `ScrollContainer`
- Tab switching (POS / Restock)
- Item list dengan toggle buttons
- Cart rows dengan total calculation
- Action buttons (Confirm, Ask Again, Cancel, Gooby choice)

**Sangat bagus.** Cashier system sudah comprehensive.

### 5.3 HUD — Enhanced

**`scripts/ui/HUD.gd` — ~425 lines (confirmed new/modified)**

Fitur yang dikonfirmasi ada:
- Typewriter notification effect
- Action lock system (nested session counter)
- Dialog skip via mouse button
- Overlay visibility management

**Catatan:** Tidak ada color coding untuk positive/negative events, tidak ada notification queue.

### 5.4 Player — Enhanced

**`scripts/player/Player.gd` — ~680 lines (confirmed new/modified)**

Fitur baru yang dikonfirmasi:
- Story-NPC trust gain on interaction (`STORY_INTERACTION_TRUST_GAIN = 20`, Gooby excluded)
- Guided hint system (`_seen_guidance_keys`) untuk first-time player prompts
- Wrong-shelf attempt tracking dengan 2-attempt feedback loop
- Interaction priority-based target selection
- Delegates ke `PlayerShelfInteraction` dan `PlayerNotificationBridge`

**Sangat bagus.** Player controller sudah mature dan well-structured.

### 5.5 InventoryUI — Label-based (Belum Berubah)

`VBoxContainer` dengan label per item — tidak scalable untuk inventory besar.

---

## 6. Code Quality

### 6.1 Magic Numbers — Sebagian Sudah Di-named Constants

**Yang sudah di-named constants:**

| Manager | Constant | Value |
|---|---|---|
| `TimeManager` | `PHASE_DURATION` | `240.0` |
| `TimeManager` | `TOTAL_DAYS` | `6` |
| `TimeManager` | `CLOCK_STEP_MINUTES` | `10` |
| `NPCScheduler` | `SPAWN_INTERVAL` | `60.0` |
| `NPCScheduler` | `DAY_ONE_NIGHT_SPAWN_INTERVAL` | `8.0` |
| `NPCScheduler` | `DAY_ONE_DAY_SPAWN_END_BUFFER` | `8.0` |
| `NPCScheduler` | `DAY_ONE_MIN_SPAWN_INTERVAL` | `8.0` |
| `NPCScheduler` | `DAY_ONE_RUSH_SPAWN_INTERVAL` | `0.5` |
| `NPCScheduler` | `DAY_ONE_SLIME_FOLLOW_UP_DELAY` | `3.0` |
| `RelationshipManager` | `MIN_TRUST` | `0` |
| `RelationshipManager` | `MAX_TRUST` | `100` |
| `Player` | `STORY_INTERACTION_TRUST_GAIN` | `20` |
| `Player` | `MAX_WRONG_ATTEMPTS` | `2` (sudah naik dari 1) |

**Yang masih hardcoded:**

| Constant | Value | Lokasi |
|---|---|---|
| `interaction_distance` | `20` | `Player.gd` |
| `carry_offset` | `(0, -34)` | `Player.gd` |
| `TALK_DISTANCE` | `60` | `PlayerInteraction.gd` |
| `_typewriter_speed` | `34.0` | `HUD.gd` |
| `z_index` (carried) | `80` | Store.gd |
| `z_index` (behind) | `-1` | Store.gd |
| `z_index` (in front) | `0` | Store.gd |

### 6.2 Tidak Ada Tests (Belum Berubah)

Tidak ada test infrastructure.

### 6.3 Error Handling Minimal (Belum Berubah)

Tidak ada null checks, assertions, atau graceful error handling.

### 6.4 Godot Signal vs Direct Method Coupling (Belum Berubah)

Mix signal-based dan direct method coupling masih ada.

---

## 7. Documentation vs Implementation Gap

### 7.1 Polish Docs — Update Status

**`docs/polish/day-1-mechanic-polish.md` — 21 task spec:**

| Task | Status |
|---|---|
| 1–5: Input standardization (E/Q) | ✅ Selesai |
| 6–10: Interaction timing, one-time hints | ✅ **Selesai** (guided hint system di Player.gd) |
| 11–14: Shelf safety placement, cashier UI | ✅ **Selesai** (restricted placement warning, animated danger line) |
| 15–17: NPC scheduling polish, Day 1 customer flow | ⚠️ **Parsial** (Day 1 hardcoded, pacing sudah bagus) |
| 18–21: Time phase polish, asset-ready scene | ❌ assets/ kosong |

**`docs/polish/day-1-extended-polish-and-store-os.md` — 7 task spec:**

| Task | Status |
|---|---|
| 1–3: NPC entry polish, door polish, one-time hint dialog | ✅ **Selesai** |
| 4: Cursor hover tooltip | ❌ Tidak ada |
| 5: Activity board glow | ❌ Tidak ada |
| 6: Cashier POS cart (add/delete/total) | ✅ **Selesai** (POS tab + Restock tab di Cashier.gd) |
| 7: Store OS shell (POS app + Restock app draft) | ✅ **Selesai** (Cashier.gd 878 lines dengan full POS + Restock) |

**Ringkasan polish docs vs implementasi:**
- Task 1–14 (day-1-mechanic-polish): ~67% → ~71% ✅
- Task 1–7 (day-1-extended-polish): ~43% → ~71% ✅ (besar是因为 Cashier upgrade)
- Yang belum: cursor hover tooltip, activity board glow, sprite assets

### 7.2 Game Design Document vs Actual

| Aspek di GDD | Status |
|---|---|
| 6-day structure | ✅ |
| 3 phases per day | ✅ |
| Irene + Gooby trust paths | ⚠️ Trust ada tapi tanpa efek |
| Item stocking (8 items) | ✅ |
| Mystery supply box | ✅ |
| Ending formula (4 variants) | ⚠️ Formula ada, ending scene tidak ada |
| Cashier POS + Restock | ✅ **Selesai** |
| Story NPC dialog | ❌ Tidak ada |
| Schedule system | ❌ Tidak ada |

---

## 8. Prioritas Revisi

### MUST FIX — Blokir Penambahan Fitur

| # | Masalah | Status | Solusi |
|---|---|---|---|
| 1 | Stub files ambigu | ❌ Belum berubah | Verifikasi scene mereferensikan stub atau implementasi; hapus jika stub tidak diperlukan |
| 2 | BlueprintManager — static class tapi autoload | ⚠️ Terdaftar tapi masih static | Refactor ke proper instance-based autoload dengan instance state |
| 3 | NPC static variables | ❌ Belum berubah | Refactor ke signals-based communication |
| 4 | NPC schedule hardcoded Day 1 | ❌ Belum berubah | Implementasi `data/schedules/` + refactor `NPCScheduler.gd` |
| 5 | Story event system kosong | ❌ Belum berubah | Implementasi skeleton event system |
| 6 | Dialog system minim | ⚠️ BlueprintManager sudah bagus | Tambahkan NPC-specific DialogTree resource |
| 7 | Mystery box trigger rapuh | ❌ Belum berubah | Validasi item matching antara taken dan placed |

### SHOULD FIX — Sebelum Penambahan Fitur Besar

| # | Masalah | Status | Solusi |
|---|---|---|---|
| 8 | Ending scenes tidak ada | ❌ Belum berubah | Ending calculation + ending scene |
| 9 | Daily Report tanpa UI | ❌ Belum berubah | Popup untuk daily report |
| 10 | Cursor hover tooltip tidak ada | ❌ Belum berubah | Implementasi sesuai polish spec |
| 11 | Activity board glow tidak ada | ❌ Belum berubah | Implementasi sesuai polish spec |
| 12 | Generic NPC tanpa dialog | ❌ Belum berubah | Generic dialog system |
| 13 | LocationTransition.gd TODOs | ⚠️ Partial stub | Implementasi atau hapus jika tidak digunakan |
| 14 | Store.gd 1595 lines | ⚠️ Bertambah, bukan berkurang | Ekstrak lebih banyak logic (objective text, depth override, dll.) |

### NICE TO HAVE — Setelah Fitur Baru Jalan

| # | Item | Status |
|---|---|---|
| 15 | Sprite placeholders → real art | ❌ assets/ kosong |
| 16 | Add tests | ❌ Tidak ada |
| 17 | Named constants untuk magic numbers yang tersisa | ⚠️ Sebagian sudah |
| 18 | Full DialogTree resource untuk branching NPC conversations | ❌ BlueprintManager hanya template |
| 19 | Multiple meeting system (NPC hadir hari berbeda) | ❌ Schedule system belum ada |
| 20 | RelationshipManager trust effects | ❌ Trust hanya disimpan |

---

## Lampiran: Perbandingan Line Count

### Scripts/locations/

| File | Lines (Sebelum) | Lines (Sesudah) | Perubahan |
|---|---|---|---|
| `store/Store.gd` | 1535 | 1595 | **+60** (bertambah) |
| `store/StoreShelfController.gd` | ~70 | 71 | ~sama |
| `store/StoreProgressionController.gd` | ~39 | 39 | sama |
| `store/StoreTransitionController.gd` | ~126 | 126 | sama |
| `store/StoreNpcSpawner.gd` | ~35 | 35 | sama |
| `store/StoreNotificationBridge.gd` | ~33 | 33 | sama |
| `Storage.gd` | ~575 | 575 | ~sama (sudah diperbaiki) |
| `LocationTransition.gd` | 26 | 26 | sama (partial stub) |
| `WorldLighting.gd` | 56 | 56 | sama |
| `Yard.gd` | 33 | 33 | sama |

### Scripts/ui/

| File | Lines (Sebelum) | Lines (Sesudah) | Perubahan |
|---|---|---|---|
| `ui/Cashier.gd` (stub) | 65B | 2 lines | sudah dihapus/is |
| `ui/cashier/Cashier.gd` | ~18 KB | ~878 lines | **+signifikan** |
| `ui/cashier/CashierCheckoutHistory.gd` | - | 16 lines | **BARU** |
| `ui/cashier/CashierCheckoutService.gd` | - | 39 lines | **BARU** |
| `ui/cashier/CashierPanel.gd` | - | 166 lines | **BARU** |
| `ui/HUD.gd` | ~425 | ~425 | confirmed modified |
| `ui/InventoryUI.gd` | ~50 | ~50 | sama |

### Scripts/managers/

| File | Perubahan |
|---|---|
| `BlueprintManager.gd` | +enum Action, +lazy init, registered as autoload |
| `TimeManager.gd` | +Phase enum, +named constants |
| `RelationshipManager.gd` | +MIN_TRUST/MAX_TRUST, +clampi |
| `NPCScheduler.gd` | +5 named constants, +typed helpers |
| `EconomyManager.gd` | sama (proper autoload) |
| `Inventory.gd` | +defensive duplicate() |
| `ItemDatabase.gd` | sama |

---

## Verifikasi

Analisis ini berdasarkan:
- Read penuh `project.godot`, 7 autoload scripts
- Read semua script di `scripts/locations/`, `scripts/locations/store/`
- Read `scripts/npc/NPC.gd` + subdirectories
- Read `scripts/player/Player.gd`
- Read `scripts/ui/` dan `scripts/ui/cashier/`
- Konfirmasi tidak ada: tests, sprites, audio, addons
- Konfirmasi ada: POS tab, Restock tab, 3 cashier service class
- Konfirmasi: semua 5 sub-controller Store sudah digunakan penuh
- Konfirmasi: NPC behavior sudah diekstrak ke behavior/ dan presentation/
