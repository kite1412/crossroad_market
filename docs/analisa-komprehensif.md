# Analisis Komprehensif — Crossroad Market

> Dibuat: 2026-07-14
> Engine: Godot 4.6 | Genre: 2D RPG Pixel Art Cozy Shop Simulation | Durasi Game: 6 Hari

---

## Daftar Isi

1. [Ringkasan Project](#1-ringkasan-project)
2. [Arsitektur & Struktur Kode](#2-arsitektur--struktur-kode)
3. [Gameplay & Mekanik](#3-gameplay--mekanik)
4. [Data & Content](#4-data--content)
5. [UI & Presentation](#5-ui--presentation)
6. [Code Quality](#6-code-quality)
7. [Documentation vs Implementation Gap](#7-documentation-vs-implementation-gap)
8. [Prioritas Revisi](#8-prioritas-revisi)

---

## 1. Ringkasan Project

### Informasi Dasar

| Aspek | Detail |
|---|---|
| **Nama** | Crossroad Market |
| **Engine** | Godot 4.6 |
| **Format** | 2D RPG Pixel Art |
| **Resolusi Native** | 480 × 270 (upscale ke 1080p, viewport stretch) |
| **Stretch Mode** | `viewport` (pixel-perfect) |
| **Texture Filter** | Nearest-Neighbor (pixel art) |
| **Durasi Game** | 6 hari × 3 fase (Morning 08:00–10:00, Day 10:00–18:00, Night 18:00–22:00) |
| **Fase Durasi** | 240 real detik per fase |

### Core Loop

```
Morning Phase → Setup shelf dari Storage
Day Phase    → Serve generic customers + Story NPC events
Night Phase  → Special events (Gooby, Slime follow-up)
Day End      → Pay tax, daily report
Day 6 End    → Calculate ending (4 variants)
```

### Struktur Direktori

```
Crossroad Market/
├── scenes/
│   ├── locations/    Store.tscn, Storage.tscn, Yard.tscn
│   ├── npc/          NPC.tscn
│   ├── objects/      Shelf.tscn, SupplyBox.tscn
│   ├── player/       Player.tscn
│   └── ui/           HUD.tscn, InventoryUI.tscn, Cashier.tscn
├── scripts/
│   ├── managers/     7 autoloads (ItemDatabase, Inventory, TimeManager, NPCScheduler, EconomyManager, RelationshipManager, BlueprintManager)
│   ├── locations/    Store.gd (stub), Storage.gd, Yard.gd, WorldLighting.gd, LocationTransition.gd
│   │   └── store/    Store.gd (1535 lines — CENTRAL CONTROLLER), 5 sub-controllers
│   ├── npc/          NPC.gd (1535 lines), NPCMovement.gd
│   │   ├── behavior/ NPCCheckoutBehavior, NPCQueueSystem, NPCShoppingBehavior
│   │   └── presentation/ NPCDialogController, NPCVisualController
│   ├── objects/      Shelf.gd, SupplyBox.gd, MysterySupplyBox.gd, ActivityBoard.gd
│   ├── player/       Player.gd, PlayerInteraction.gd, PlayerShelfInteraction.gd, PlayerNotificationBridge.gd
│   └── ui/           HUD.gd, InventoryUI.gd, Cashier.gd (stub)
│       └── cashier/  Cashier.gd (18 KB), CashierCheckoutService.gd, CashierCheckoutHistory.gd, CashierPanel.gd
├── data/
│   ├── items/        9 item .tres files + ItemData.gd base class
│   ├── npc/
│   │   ├── generic/  5 NPC templates (human_1/2/3, ghost_1, monster_1/2)
│   │   └── story/    5 NPC templates (irene, gooby, blacksmith, herbalist, mayor)
│   ├── dialogues/    generic/ (KOSONG), story/ (KOSONG), events/MysteryDialog.gd
│   ├── events/       story/{irene,gooby,blacksmith,herbalist,mayor}/ (KOSONG)
│   └── schedules/   (KOSONG)
├── docs/
│   └── polish/       day-1-mechanic-polish.md, day-1-extended-polish-and-store-os.md
├── assets/           (KOSONG — hanya .gitkeep)
└── project.godot     (Godot 4 config, 7 autoloads, input map E/Q)
```

### 7 Autoload Singletons

| Autoload | File | Tanggung Jawab |
|---|---|---|
| `ItemDatabase` | `scripts/managers/ItemDatabase.gd` | Load semua `.tres` item, expose `get_item()`, `get_all_items()`, `get_items_by_shelf()` |
| `Inventory` | `scripts/managers/Inventory.gd` | Dictionary-based inventory, emit `inventory_changed` |
| `TimeManager` | `scripts/managers/TimeManager.gd` | 6 hari × 3 fase × 240 detik, emit `phase_changed`, `day_started`, `day_ended` |
| `NPCScheduler` | `scripts/managers/NPCScheduler.gd` | Generate schedule, pace NPC spawns, Day 1 special flow |
| `EconomyManager` | `scripts/managers/EconomyManager.gd` | Gold, revenue, tax per hari `[10,10,15,15,20,25]`, daily target 50G |
| `RelationshipManager` | `scripts/managers/RelationshipManager.gd` | Trust 0–100 per story NPC, emit `trust_changed` |
| `BlueprintManager` | `scripts/managers/BlueprintManager.gd` | Static class — NPC dialog templates per `PatienceType` |

> **Catatan:** `BlueprintManager` TIDAK terdaftar sebagai autoload di project.godot. Diakses via class name langsung.

### Input Map

| Action | Key | Deadzone | Fungsi |
|---|---|---|---|
| `move_left` | `A` | 0.5 | Bergerak kiri |
| `move_right` | `D` | 0.5 | Bergerak kanan |
| `move_up` | `W` | 0.5 | Bergerak atas |
| `move_down` | `S` | 0.5 | Bergerak bawah |
| `interact` | `E` | 0.2 | Get/take/pick up/serve |
| `put` | `Q` | 0.2 | Put/place/drop/stock |

---

## 2. Arsitektur & Struktur Kode

### 2.1 Stub Files Membingungkan — HARUS DIREVISI

Dua file stub yang men-delegate ke implementasi di subdirectory:

| Stub | Ukuran | Delegate ke | Implementasi Aktual |
|---|---|---|---|
| `scripts/locations/Store.gd` | 49 bytes | `store/Store.gd` | `scripts/locations/store/Store.gd` (1535 lines) |
| `scripts/ui/Cashier.gd` | 65 bytes | `cashier/Cashier.gd` | `scripts/ui/cashier/Cashier.gd` (18 KB) |

**Masalah:**
- Stub hanya berisi `extends` tanpa logika tambahan — 2 layer indirection yang tidak perlu
- Jika ada bug, harus cek 2 tempat (stub + implementasi)
- Tidak jelas apakah scene `.tscn` mereferensikan stub atau langsung implementasi penuh
- Menyulitkan navigasi kode saat onboarding

**Tindakan:** Verifikasi di `Store.tscn` dan `Cashier.tscn` script resource path. Jika stub tidak digunakan scene, hapus. Jika digunakan, pertimbangkan single-source-of-truth (langsung point ke implementasi penuh).

### 2.2 Store.gd Terlalu Besar — 1535 Lines

`scripts/locations/store/Store.gd` adalah file terbesar di project (~1535 baris). Satu method bisa 200+ baris.

**Sub-controllers yang sudah ada tapi belum digunakan penuh:**

| Sub-Controller | File | Status |
|---|---|---|
| `StoreTransitionController.gd` | 3.7 KB | Ada tapi belum dipakai semua |
| `StoreShelfController.gd` | ~2 KB | Ada tapi banyak logic masih di Store.gd |
| `StoreNotificationBridge.gd` | ~1 KB | Ada tapi belum digunakan Store.gd |
| `StoreNpcSpawner.gd` | ~1 KB | Digunakan dengan benar |
| `StoreProgressionController.gd` | ~1 KB | Digunakan dengan benar |

**Yang perlu diekstrak dari Store.gd:**

- `_get_current_objective_text()` → `StoreObjectiveController.gd`
- `_on_daily_report()` → `StoreEconomyReport.gd`
- `_on_npc_spawn_requested` + `_setup_npc_static_data()` → ada di `StoreNpcSpawner.gd` tapi Store.gd masih memanggil
- `_register_installed_shelf()` signal wiring → `StoreShelfController.gd`
- `_update_player_depth_override()` → `StoreDepthController.gd`
- `_update_objective()` → integrasi dengan `StoreNotificationBridge.gd`

### 2.3 BlueprintManager — Static Class Bermasalah

`BlueprintManager.gd` adalah `static class` (static variables, bukan extends Node), TETAPI tidak terdaftar sebagai autoload di `project.godot`.

**Masalah:**
- Static class GDScript tidak punya `_ready()`, `_process()`, tidak bisa terima signals dengan benar
- Cache di static variable — jika data berubah, cache tidak auto-reset
- Akses langsung via `BlueprintManager.method()` — tidak ada indirection yang konsisten
- Tidak bisa di-debug dengan cara yang sama seperti autoload

**Status saat ini:** `BlueprintManager` di-register di daftar 7 manager di README/docs, tapi TIDAK ada di daftar 7 autoloads di `project.godot`. Verifikasi semua caller.

### 2.4 Static Class Variables untuk Inter-NPC Communication — RAPAT

`NPC.gd` menggunakan variabel `static` di level class untuk shared state:

```gdscript
static var current_queue: Array[NPC] = []      # shared FIFO queue
static var counter_position: Vector2 = Vector2.ZERO
static var entrance_position: Vector2 = Vector2.ZERO
static var exit_position: Vector2 = Vector2.ZERO
static var store_path_position: Vector2 = Vector2.INF
```

**Masalah:**
- Setiap NPC instance BERBAGI state ini — race condition potensial di antara `_process()` calls
- Tidak ada encapsulation — kode manapun bisa memodifikasi state langsung
- Tidak bisa di-test secara unit karena butuh seluruh scene tree
- Jika NPC crash/mati di tengah proses, queue state bisa orphan
- Tidak ada watchdog untuk state consistency

**Alternatif yang lebih baik:**
- `StoreNpcSpawner.gd` atau `Store.gd` menjadi owner semua shared state
- NPC berkomunikasi via signals: `npc_arrived_at_queue`, `npc_left_queue`, `npc_at_counter`, dll.
- Atau gunakan Resource object (`NPCSharedState.gd extends Resource`) sebagai shared state holder

### 2.5 Empty Directories — Perlu Decision

```
scripts/npc/interaction/       → .gitkeep, kosong — intended untuk masa depan
scripts/npc/movement/          → .gitkeep, kosong — intended untuk masa depan
data/schedules/                → .gitkeep, kosong — BLOKIR Days 2–6
data/dialogues/generic/         → kosong — generic NPC tanpa dialog
data/events/story/{irene,gooby,blacksmith,herbalist,mayor}/ → kosong — no story events
```

**Ini tidak sia-sia — ini blocking:**
- `data/schedules/` kosong → semua NPC schedule HARDCODED di `NPCScheduler.gd`
- `data/events/story/*/` kosong → tidak ada story event system
- `data/dialogues/generic/` kosong → generic NPC tidak punya dialog

### 2.6 Inkonsistensi Naming Conventions

- `scripts/locations/Store.gd` (lowercase) vs `scripts/locations/store/Store.gd` (lowercase dir, PascalCase file)
- `scripts/ui/Cashier.gd` vs `scripts/ui/cashier/Cashier.gd`
- NPC state names: `WALK_TO_SHELF`, `SEARCH_ITEM`, `TAKE_ITEM`, `WAIT_IN_QUEUE`, `CHECKOUT` — tidak ada `enum NPCState`
- `BlueprintManager` (static class) vs `ItemDatabase` (autoload) — akses berbeda

---

## 3. Gameplay & Mekanik

### 3.1 Day 1 Hardcoded di NPCScheduler — BLOKIR CONTENT

`NPCScheduler.gd` memiliki inline `NPCData` objects yang di-hardcode untuk Day 1:

- Bread customer
- Water customer
- Bandage customer
- Irene (Day 1, DAY phase)
- Gooby (Day 1, NIGHT phase) + slime follow-up

**Ini berarti:**
- Tidak ada schedule system untuk Days 2–6
- Setiap penambahan NPC story harus edit `NPCScheduler.gd` langsung
- `data/schedules/` tidak digunakan (directory kosong)
- Schedule logic tersebar di `NPCScheduler.gd` dan `StoreProgressionController.gd`

### 3.2 Mystery Box Trigger Condition — Rapuh

```gdscript
# MysterySupplyBox.gd / Store.gd
if _items_taken >= 4 AND _items_placed >= 4:
    unlock_mystery()
```

**Masalah:**
- 2 independent counters yang harus sinkron
- Tidak ada validasi bahwa `_items_taken` (dari SupplyBox) dan `_items_placed` (dari Shelf) adalah item yang sama
- Jika player ambil item → jual ke NPC → shelf count tidak akurat
- Tidak ada proteksi edge case: isi shelf → ambil → isi lagi → counter double-count

### 3.3 Gooby Event Logic — Tersebar di 3+ File

Story event logic tersebar:

| Lokasi | Tanggung Jawab |
|---|---|
| `NPCScheduler.gd` | Spawn Gooby + slime follow-up |
| `NPCCheckoutBehavior.gd` | Checkout flow dengan `checkout_outcome = "reject_return"` |
| `Cashier.gd` | UI two-choice panel (Give +Trust/+0G vs Refuse +item return +slime) |

**Menambah NPC story baru dengan special event** → edit di 3+ file berbeda

### 3.4 RelationshipManager — Cuma Simpan Angka

`RelationshipManager.gd` hanya:
- `set_trust(npc_id, value)` / `add_trust(npc_id, amount)`
- `get_trust(npc_id)`
- Emit `trust_changed(npc_id, new, delta)`

**Yang TIDAK ada:**
- Trust tidak mempengaruhi dialog
- Trust tidak mempengaruhi checkout behavior
- Trust tidak mempengaruhi item availability
- Trust tidak mempengaruhi ending secara visible (formula di `EconomyManager` tapi trust contribution tidak exposed)

### 3.5 Shelf Placement Detection — Magic Numbers

`Store.gd` dan `StoreShelfController.gd` mengandung:

```gdscript
# Shelf placement
8 drop candidates
4 standing spot checks
interaction_distance = 20 (Player.gd)
carry_offset = (0, -34) (Player.gd)
TALK_DISTANCE = 60 (PlayerInteraction.gd)
z_index values: 80 (carried), -1 (behind), 0 (in front)
```

**Masalah:**
- Jika shelf count berubah → edit banyak tempat
- Tidak ada `ShelfPlacementGrid` atau konfigurasi terpusat
- Edge case: player standing spot detection bisa salah di boundary

### 3.6 Player Depth Sorting — Approximation

`Store._update_player_depth_override()` menggunakan:
```gdscript
# x-overlap check + y-position relative
# Bisa salah untuk:
# - Shelf dengan tinggi tidak seragam
# - NPC dan player di posisi overlap
# - Kondisi shelf dan player sama tinggi
```

### 3.7 NPC State Machine — 8 States

```
ENTER → WALK_TO_SHELF → SEARCH_ITEM → TAKE_ITEM → WAIT_IN_QUEUE → CHECKOUT → EXIT
                            ↓
                      (no item found)
                            ↓
            LEAVE / QUEUE (patient) / BROWSE_BUY (quitter)
```

**PatienceType drives all branching:**
- `IMPATIENT` (0) → LEAVE immediately
- `PATIENT` (1) → QUEUE
- `QUITTER` (2) → BROWSE_BUY (cari alternatif)

---

## 4. Data & Content

### 4.1 Tidak Ada Dialog System

**Kondisi saat ini:**

| Jenis | Status |
|---|---|
| BlueprintManager templates | ✅ Template string per PatienceType (5 template) |
| Generic NPC dialog | ❌ `data/dialogues/generic/` kosong |
| Story NPC dialog | ❌ `data/dialogues/story/*/` kosong |
| Event dialog | ❌ `data/events/story/*/` kosong |
| Branching conversation | ❌ Tidak ada |

**BlueprintManager template types:**
1. `no_item_action` — NPC tidak menemukan item
2. `item_found` — NPC menemukan item
3. `checkout` — Saat checkout
4. `done` — Setelah transaksi
5. `queue_too_long` — Queue terlalu panjang

**Kekurangan sistem dialog yang ideal:**
- Tidak ada `DialogTree` resource (`.gd extends Resource`)
- Tidak ada `DialogNode` untuk branching
- Tidak ada NPC-specific personalized dialog sequence
- Tidak ada "quest acceptance", "quest completion", "trust threshold reached" events
- Story NPC (Irene, Gooby) tidak punya personalized dialog sequence

### 4.2 Story Event System — Tidak Ada

`data/events/story/{irene,gooby,blacksmith,herbalist,mayor}/` semuanya kosong.

**Yang seharusnya ada:**
- Quest data: quest giver, objectives, rewards
- Event trigger conditions
- Event outcomes yang mempengaruhi game state
- Multiple meeting system (NPC hadir hari berbeda dengan dialog berbeda)

### 4.3 NPC Schedule Data — Tidak Ada

`data/schedules/` kosong.

**Yang seharusnya ada:**
- Per-NPC schedule: hari apa hadir, fase apa, item yang dicari, patience type, special flags
- Day-specific pacing rules
- Special event triggers

### 4.4 Ending Scenes — Tidak Ada

README.md menjelaskan 4 ending variants:
- High Irene + High Gooby support
- High Irene + Low Gooby support
- Low Irene + High Gooby support
- Low Irene + Low Gooby support

**Yang tidak ada:**
- Ending calculation logic
- Ending scene (`.tscn`)
- Credits sequence
- "New Store" starting capital application

### 4.5 Daily Report — Tidak Ada UI

`EconomyManager.get_daily_report()` mengembalikan dictionary dengan:
```gdscript
{
    day, revenue, tax, net_profit,
    total_gold, target_reached,
    transaction_count, customer_served
}
```

**Tidak ada UI scene** untuk menampilkan ini dengan baik — hanya notification text.

### 4.6 Item Data — Lengkap

9 item `.tres` files semua ada dan lengkap:
- `bread.tres`, `water.tres`, `bandage.tres`, `pains_killer.tres`
- `energy_drink.tres`, `work_gloves.tres`, `phantom_ice_cream.tres`, `spirit_water.tres`

Item data sudah bagus sebagai foundation.

---

## 5. UI & Presentation

### 5.1 Semua Visual Adalah ColorRect Placeholder

`assets/` KOSONG. Semua node visual menggunakan `ColorRect`:
- Player, NPC, Shelf, SupplyBox, Cashier, Background — semua solid color
- Tidak ada sprite animation
- Tidak ada directional sprites
- Tidak ada texture
- Concept art ada di `Concept Art/` tapi tidak diintegrasikan ke scene

### 5.2 HUD — Notification System Sederhana

`HUD.gd`:
- Typewriter effect: 34 chars/sec
- Notification overlay (top-center) vs hint label (bottom-center)
- Action lock system (nested session counter)
- Dialog skip via mouse button press

**Keterbatasan:**
- Tidak ada color coding untuk positive/negative/neutral events
- Tidak ada notification queue — tumpang tindih bisa terjadi
- Overlay vs hint label — perlu review konsistensi

### 5.3 InventoryUI — Label-based, Bukan Grid

`InventoryUI.tscn` menggunakan `VBoxContainer` dengan label per item.

**Masalah untuk scale:**
- Game memiliki 9 item (bisa jadi lebih banyak)
- Label-based inventory tidak scalable
- Grid-based inventory (Terraria/Stardew style) lebih standard untuk game shop

### 5.4 Cashier UI — Procedural Panel Building

`CashierPanel.ensure()` membangun panel secara procedural dengan:
- Two-column layout: item buttons (kiri), detail + actions (kanan)
- Toggle buttons untuk scan selection
- Confirm/Ask-Again/Cancel actions
- Gooby special choice panel (Give +Trust vs Refuse)

**Cashier workflow:**
```
NPC reaches counter
  → Player presses E at cashier
  → try_checkout()
  → _process_scan(npc) → shows SCAN panel
  → Player selects items + confirms
  → selection_matches_customer()
  → If match → show PAID panel (or Gooby choice)
  → If wrong → "Scan mismatch"
  → NPC leaves
```

---

## 6. Code Quality

### 6.1 Tidak Ada Tests

Tidak ada `test/` directory atau test infrastructure sama sekali.

**Implikasi:**
- Perubahan di shared state (NPC queue, static variables) tidak bisa diverifikasi secara automated
- BlueprintManager cache tidak bisa di-test
- Shelf placement logic tidak bisa regression-tested

### 6.2 Magic Numbers Terdistribusi

| Constant | Value | Lokasi |
|---|---|---|
| `PHASE_DURATION` | 240 | `TimeManager.gd` |
| `MAX_WRONG_ATTEMPTS` | 1 | `Player.gd` |
| `SPAWN_INTERVAL` | 60 | `NPCScheduler.gd` |
| `DAY_1_NIGHT_SPAWN_INTERVAL` | 8 | `NPCScheduler.gd` |
| `interaction_distance` | 20 | `Player.gd` |
| `carry_offset` | `(0, -34)` | `Player.gd` |
| `TALK_DISTANCE` | 60 | `PlayerInteraction.gd` |
| `_typewriter_speed` | 34.0 | `HUD.gd` |
| `DEADZONE` | 0.2/0.5 | `project.godot` |

Semua hardcoded di body method, tidak ada named constants.

### 6.3 Error Handling Minimal

Tidak ada `_ready()` null checks, tidak ada assertions.

Contoh: `ItemDatabase.gd` loads dari `res://data/items/`, tapi tidak ada error handling jika:
- Directory tidak ada
- `.tres` file corrupt
- `item_id` kosong/null

### 6.4 Signal vs Direct Method Coupling

- **Signal-based:** TimeManager → Store/NPCScheduler/HUD/WorldLighting
- **Direct method:** Store → hud.set_objective(), Store → EconomyManager.add_gold()

Campuran ini membuat alur data sulit dilacak. Disarankan konsisten: gunakan signals untuk semua inter-component communication.

---

## 7. Documentation vs Implementation Gap

### 7.1 Polish Docs — Implementasi Belum Lengkap

**`docs/polish/day-1-mechanic-polish.md`** — 21 task spec:

| Task | Status |
|---|---|
| 1–5: Input standardization (E/Q) | ✅ Selesai |
| 6–10: Interaction timing, one-time hints | ⚠️ Parsial |
| 11–14: Shelf safety placement, cashier UI | ⚠️ Parsial |
| 15–17: NPC scheduling polish, Day 1 customer flow | ⚠️ Hardcoded |
| 18–21: Time phase polish, asset-ready scene | ❌ assets/ kosong |

**`docs/polish/day-1-extended-polish-and-store-os.md`** — 7 task spec:

| Task | Status |
|---|---|
| 1–3: NPC entry polish, door polish, one-time hint dialog | ⚠️ Parsial |
| 4: Cursor hover tooltip | ❌ Tidak ada |
| 5: Activity board glow | ❌ Tidak ada |
| 6: Cashier POS cart (add/delete/total) | ⚠️ Cashier ada, POS cart perlu review |
| 7: Store OS shell (POS app + Restock app draft) | ⚠️ Ada draft, belum full |

### 7.2 Game Design Document vs Actual

README.md sebagai game design document:

| Aspek di GDD | Status Implementasi |
|---|---|
| 6-day structure | ✅ TimeManager mendukung |
| 3 phases per day | ✅ MORNING/DAY/NIGHT |
| Irene + Gooby trust paths | ⚠️ Trust ada tapi tanpa efek |
| Item stocking (8 items) | ✅ |
| Mystery supply box | ✅ |
| Ending formula (4 variants) | ⚠️ Formula di EconomyManager, ending scene tidak ada |
| Starting capital formula | ⚠️ Di README, belum diimplementasi ending |
| Store OS (POS + Restock) | ⚠️ Cashier ada, OS shell parsial |

---

## 8. Prioritas Revisi

### MUST FIX — Blokir Semua Penambahan Fitur

| # | Masalah | Solusi | File(s) |
|---|---|---|---|
| 1 | Stub files ambigu | Verifikasi scene mereferensikan script yang tepat; hapus jika tidak perlu | `scripts/locations/Store.gd`, `scripts/ui/Cashier.gd` |
| 2 | Store.gd 1535 lines | Pecah ke sub-controllers yang sudah ada; pindahkan semua logic yang bukan orchestrator | `scripts/locations/store/Store.gd` |
| 3 | NPC schedule hardcoded Day 1 | Implementasi `data/schedules/` + refactor `NPCScheduler.gd` | `NPCScheduler.gd`, `data/schedules/` |
| 4 | Tidak ada dialog system | Minimal: expand BlueprintManager untuk NPC-specific dialog. Ideal: full DialogTree resource | `BlueprintManager.gd`, `data/dialogues/` |
| 5 | Static class NPC state | Refactor ke signals-based communication via Store/NpcSpawner sebagai owner | `NPC.gd`, `StoreNpcSpawner.gd` |
| 6 | Story event system kosong | Implementasi skeleton event system di `data/events/story/` | `data/events/story/`, `NPCScheduler.gd` |
| 7 | BlueprintManager bukan autoload | Daftarkan sebagai autoload atau ubah akses pattern | `project.godot`, `BlueprintManager.gd` |

### SHOULD FIX — Sebelum Penambahan Fitur Besar

| # | Masalah | Solusi |
|---|---|---|
| 8 | Ending scenes tidak ada | Implementasi ending calculation + ending scene |
| 9 | Daily Report tanpa UI | Buat UI scene Popup untuk daily report |
| 10 | Cursor hover tooltip tidak ada | Implementasi sesuai spec di polish docs |
| 11 | Activity board glow tidak ada | Implementasi sesuai spec |
| 12 | Generic NPC tanpa dialog | Implementasi generic dialog system |
| 13 | Store OS shell parsial | Full implementation sesuai spec |

### NICE TO HAVE — Setelah Fitur Baru Jalan

| # | Item |
|---|---|
| 14 | Replace ColorRect placeholder dengan sprite (butuh artist) |
| 15 | Add unit/integration tests |
| 16 | Named constants untuk semua magic numbers |
| 17 | Full Store OS implementation |
| 18 | NPC-specific dialog trees untuk Irene, Gooby |
| 19 | Multiple meeting system (NPC hadir hari berbeda dengan dialog berbeda) |
| 20 | RelationshipManager trust effects (dialog, behavior, availability) |

---

## Lampiran: File Map

### Manager Layer (7 Autoloads)

```
ItemDatabase          → Load items from res://data/items/*.tres
Inventory             → item→quantity dictionary singleton
TimeManager           → 6-day clock, 3 phases, 240s/phase
NPCScheduler          → NPC schedule generation + spawn pacing
EconomyManager        → Gold, revenue, tax, daily report
RelationshipManager   → Trust 0–100 per story NPC
BlueprintManager      → Dialog templates per PatienceType (STATIC, bukan autoload)
```

### Sub-Controller Pattern (Store Sub-Directory)

```
StoreNpcSpawner.gd           → Scene instantiation + signal wiring
StoreProgressionController.gd → Predicate: unlock mystery? unlock spawning? start day-1?
StoreShelfController.gd      → Player-carry detection, depth-sorting math
StoreTransitionController.gd → Player reparent, fade tween, recursive activation
StoreNotificationBridge.gd   → HUD proxy
```

### NPC State Machine (8 States)

```
ENTER → WALK_TO_SHELF → SEARCH_ITEM → TAKE_ITEM → WAIT_IN_QUEUE → CHECKOUT → EXIT
                            ↓                    ↓
                      LEAVE/QUEUE/BROWSE      WAIT_IN_QUEUE
```

### Progression Unlocks (Day 1)

```
Morning:
  Pickup human shelf (Storage) → Place in Store → Stock shelf
  (4 items taken + 4 placed) → Mystery phase unlocked

  Pickup ghost shelf → Place in Store → Stock Phantom Ice Cream
  → Customer spawning unlocked

Day:
  Generic customers (bread/water/bandage) + Irene spawn

Night:
  Gooby spawns → Player scans → Choice: Give (+trust) / Refuse (+slime)
```

---

## Verifikasi

Analisis ini berdasarkan:
- Read penuh `project.godot`
- Read 7 autoload scripts, 4 behavior scripts, Store.gd (1535 lines), NPC.gd, Player.gd, HUD.gd, Cashier.gd, Shelf.gd, SupplyBox.gd, MysterySupplyBox.gd, ActivityBoard.gd
- Mapping scene-tree dari semua `.tscn` files
- Data resource: 9 item `.tres`, 10 NPC `.tres`, BlueprintData.gd, NPCData.gd
- Docs: README.md, 2 polish specs
- Konfirmasi: tidak ada tests, tidak ada sprites, tidak ada audio, tidak ada addons
