# Crossroad Market — Day 1 Mechanic Polish

## 1. Purpose

Day 1 focuses on **mechanic polish without final art assets**. The goal is not to add major new mechanics, but to make the existing shop loop more stable, readable, testable, and ready for future Aseprite asset integration.

Main rule:

```text
Do not add major new mechanics.
Polish the mechanics that already exist.
Prepare the project so final assets can be swapped in safely later.
```

This document is intended to guide AI Agent / Codex work. Use it as a task spec. Do not execute everything at once.

```text
1 prompt = 1 task or 1 small subtask
```

---

## 2. Current Revision Context

The project already has a playable Day 1 shop loop, but current playtest feedback shows several polish mismatches that should be fixed before deeper content work.

Important user decisions:

```text
E = get / take / pick up / interact / serve
Q = put / place / drop / stock
18:00 = Night
Trust belongs to NPC world UI, not permanent player HUD
Normal Day revenue should reach 40G before the Gooby / Slime branch
Gooby gift = trust path, revenue missed
Gooby refuse = revenue path through Slime
```

Recent playtest notes:

```text
- Interaction hints appear after pressing the button, but they should appear before input.
- Player needs button/click guidance at least once so they understand E/Q and panel buttons.
- Objective text exists, but its purpose and source must be audited.
- Item/object hover should show the item/object name.
- Shelf pickup after placement is too strict.
- Cashier restricted area still needs danger-line feedback.
- Store entry position does not align with the door.
- Cashier Ask Again UI is hard to read because NPC dialogue can be hidden behind the panel.
- Day/Night timing and Day revenue pacing need adjustment.
- Gooby/Slime logic should be revised: Slime comes after Gooby outcome, not only as a direct refusal spawn.
```

---

## 3. Scope

### 3.1 In Scope

Allowed Day 1 polish:

- Stabilize existing player interaction.
- Standardize E/Q input mapping.
- Improve interaction hints and one-time button guidance.
- Improve cashier panel readability and button/click instructions.
- Improve shelf placement, pickup, and no-drop safety.
- Improve cashier restricted area feedback.
- Improve door transition / entry alignment.
- Improve NPC state flow and normal Day revenue pacing.
- Improve TimeManager phase split so Night starts at 18:00.
- Improve Gooby / Slime night branch clarity.
- Move trust display from player HUD to NPC world-space UI.
- Add hover/name labels for existing items and objects.
- Prepare UI and scene structure for later Aseprite asset replacement.
- Document expected behavior and test cases.

### 3.2 Out of Scope

Not allowed for Day 1 polish:

- Adding farming, crafting, skill trees, or store expansion.
- Adding new maps not needed for the current loop.
- Adding complex quest systems or quest rewards.
- Adding complex relationship systems beyond simple trust tracking.
- Replacing all final assets before the asset pack is ready.
- Reworking the whole architecture at once.
- Adding new story branches beyond the existing Gooby / Slime night decision.

If a proposed change only explains, stabilizes, or clarifies an existing action, it is polish. If it creates a new way to play, treat it as a new mechanic and keep it out of Day 1.

---

## 4. Recommended Execution Order

```text
Task 1  — Standardize Input Mapping: E Get, Q Put
Task 2  — Revise Interaction Prompt Timing
Task 3  — Add One-Time Button / Click Guidance
Task 4  — Add Hover / Object Name Feedback
Task 5  — Polish Shelf Pickup Reachability
Task 6  — Polish Shelf Placement Safety / No-Drop Zones
Task 7  — Polish Cashier Restricted Area Danger Line
Task 8  — Fix Store Door Entry Alignment
Task 9  — Move Trust Display to NPC World UI
Task 10 — Polish Cashier Ask Again UI
Task 11 — Polish Cashier Panel Button Guidance
Task 12 — Audit Objective HUD Guidance
Task 13 — Polish Activity Board / Action Guidance
Task 14 — Polish Time / Phase Split
Task 15 — Polish Day Revenue Pacing to 40G
Task 16 — Revise Gooby / Slime Follow-Up Logic
Task 17 — Validate Gooby Night Choice
Task 18 — Review Full Core Loop
Task 19 — Prepare Asset-Ready Node Structure
Task 20 — Documentation Update
```

Current status:

```text
All tasks in this revision should be treated as pending or needing validation unless Codex has already implemented and tested them after this document update.
```

---

## 5. Task 1 — Standardize Input Mapping: E Get, Q Put

### Goal

Make player input consistent across shelf, supply box, cashier, board, and item interactions.

Recommended mapping:

```text
E = interact / get / take / pick up / serve / read
Q = put / place / drop / stock
Esc = close / cancel UI
```

### Examples

```text
Supply Box:
- E to take stock

Shelf object:
- E to pick up shelf
- Q to drop/place carried shelf

Shelf item:
- Q to place/stock item on shelf
- E to take/get item from shelf, if current feature supports it

Cashier:
- E to serve customer / interact with cashier

Activity Board:
- E to read board
```

### Checklist

- [x] Input action names are consistent.
- [x] Prompt text follows the same E/Q rule.
- [x] SupplyBox uses E for get/take stock.
- [x] Shelf pickup uses E.
- [x] Shelf placement / drop uses Q.
- [x] Shelf stocking uses Q.
- [x] Cashier interaction uses E.
- [x] Board interaction uses E.
- [x] No prompt contradicts the mapping.

### Implementation Notes

- `project.godot` now uses `interact` on E and `put` on Q; the old `carry` / `take_shelf_item` input actions are no longer used.
- Player E handles get/take/pickup/interact/read/serve: supply box stock pickup, shelf item pickup, shelf object pickup, cashier service, NPC interaction, and activity board reading.
- Player Q handles put/place/drop/stock: shelf stocking and carried shelf placement.
- Store and Storage expose shelf pickup/drop request methods so the player interaction layer can keep E/Q behavior consistent across locations.

### Codex Prompt

```text
Analisa dan implementasikan Task 1 — Standardize Input Mapping: E Get, Q Put dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Fokus konsistensi input existing.
- E berarti interact/get/take/pick up/serve/read.
- Q berarti put/place/drop/stock.
- Update prompt/hint text agar tidak kontradiktif.
- Cek project input map, Player, Shelf, SupplyBox, Cashier, ActivityBoard, HUD hint text sebelum edit.

Expected output:
- File yang dicek.
- Mapping input final.
- Perubahan yang dibuat.
- Test supply box, shelf pickup, shelf placement, shelf stock, cashier, board.
```

---

## 6. Task 2 — Revise Interaction Prompt Timing

### Goal

Prompt interaction should appear **before** the player presses the input, when the player enters the relevant interaction area.

Expected flow:

```text
Player enters object InteractionArea / CollisionShape2D
→ Prompt appears immediately
→ Prompt shows object name and available action
→ Player presses E or Q
→ Action happens
```

### Checklist

- [x] Prompt appears on area enter / hover / proximity.
- [x] Prompt appears before pressing E/Q.
- [x] Prompt disappears on area exit.
- [x] Prompt identifies object/item name.
- [x] Prompt explains the correct input.
- [x] Prompt does not block player movement.
- [x] Prompt does not overlap cashier modal / board modal.

### Implementation Notes

- Added a non-blocking HUD `InteractionHintLabel` for compact proximity prompts.
- Player updates the hint every frame from existing interaction-area overlap detection before E/Q is pressed.
- Prompt text follows Task 1 mapping: E for get/take/pickup/interact/read/serve and Q for put/place/drop/stock.
- Prompt text identifies current target names such as Supply Box, Human Shelf, Ghost Shelf, Cashier, Activity Board, NPC display name, and door names.
- HUD hides the interaction hint while cashier or activity board overlays are open.

### Codex Prompt

```text
Analisa dan implementasikan Task 2 — Revise Interaction Prompt Timing dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Prompt harus muncul saat player memasuki interaction area, sebelum input ditekan.
- Prompt harus mengikuti mapping E/Q dari Task 1.
- Jangan gunakan blocking notification untuk prompt kecil.
- Cek Player interaction detection, HUD hint label, Shelf, SupplyBox, Cashier, ActivityBoard, dan item/object interaction areas.

Expected output:
- Penyebab timing hint salah.
- File yang dicek.
- Perubahan yang dibuat.
- Test prompt shelf, supply box, cashier, board, item.
```

---

## 7. Task 3 — Add One-Time Button / Click Guidance

### Goal

Player should receive clear guidance at least once about what each input/button does. This is especially important because E/Q are contextual.

This is not a permanent tutorial spam. It is a **first-time explanation** for new controls, panels, or item/object categories.

### Expected Behavior

```text
First time near Supply Box:
Show: Supply Box — Press E to take stock.

First time carrying an item near Shelf:
Show: Shelf — Press Q to place item here.

First time near placed Shelf:
Show: Shelf — Press E to pick up shelf.

First time opening Cashier Panel:
Show short panel guide explaining what each button does.
```

After the first explanation:

```text
Only compact prompts repeat, not the long tutorial explanation.
```

### Cashier Panel Button Guidance

The cashier panel should explain button meanings once, or show compact tooltips/labels:

```text
Confirm Scan — process selected item.
Ask Again — repeat the customer's request.
Close — cancel / leave cashier panel.
Give Item — give item for trust, no gold.
Refuse Sale — return item and continue the night consequence.
Receive Payment — finish normal paid checkout.
```

### Checklist

- [x] First-time button guidance exists for core input mapping.
- [x] Cashier panel has clear button labels or one-time guidance.
- [x] Guidance runs once per input/object/panel category.
- [x] Guidance does not loop every time.
- [x] Guidance does not block cashier decision flow.
- [x] Compact prompts still appear after first-time guidance.

### Implementation Notes

- Player proximity hints now use one-time guidance keys per category, then fall back to compact prompts.
- One-time guidance covers supply box take, shelf pickup, carried shelf placement, shelf stocking, shelf item pickup, cashier interaction, NPC interaction, and activity board reading.
- Cashier panel now has a non-blocking guide label that explains Scan, Paid, and Gooby choice buttons once per panel type.
- Cashier guide text does not use blocking notifications, so scan/payment/Gooby decisions remain clickable immediately.

### Codex Prompt

```text
Analisa dan implementasikan Task 3 — Add One-Time Button / Click Guidance dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Tambahkan informasi button/click minimal sekali agar player tidak bingung.
- Jangan membuat tutorial panjang yang selalu looping.
- Cashier panel harus menjelaskan fungsi tombol penting dengan jelas.
- Gunakan flag/set sederhana untuk first-time guidance jika dibutuhkan.

Expected output:
- File yang dicek.
- Control/button yang butuh first-time guidance.
- Perubahan UI/prompt yang dibuat.
- Test bahwa guidance muncul sekali dan tidak looping.
```

---

## 8. Task 4 — Add Hover / Object Name Feedback

### Goal

When player hovers or enters interaction range of an item/object, show the item/object name.

### Examples

```text
Bread
Water
Bandage
Human Shelf
Ghost Shelf
Phantom Ice Cream
Cashier
Supply Box
Activity Board
```

### Checklist

- [x] Hover/proximity label shows object name.
- [x] Label appears before input.
- [x] Label disappears on exit.
- [x] Label works for items, shelves, cashier, board, and supply boxes.
- [x] Hover name is separate from one-time tutorial explanation.
- [x] Label does not overlap major HUD or modal panels.

### Implementation Notes

- Added a separate HUD `ObjectNameLabel` above the compact interaction prompt.
- Player hover/proximity feedback now sends object name and action prompt separately.
- Object names are resolved from existing data: NPC display name, stocked shelf item display name, shelf type, supply box type, cashier, activity board, and door labels.
- The object name label hides when no target is in range, when actions are locked, or when cashier/activity board overlays are open.

### Codex Prompt

```text
Analisa dan implementasikan Task 4 — Add Hover / Object Name Feedback dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Fokus existing items/objects.
- Hover/proximity label harus muncul sebelum input.
- Tutorial explanation dan hover name harus dipisah.
- Cek Player interaction detection dan HUD/Label display sebelum edit.

Expected output:
- File yang dicek.
- Cara object name ditentukan.
- Perubahan yang dibuat.
- Test item name, shelf name, cashier name, supply box name.
```

---

## 9. Task 5 — Polish Shelf Pickup Reachability

### Goal

Shelf pickup should not require touching a tiny physical CollisionShape2D. Player should be able to pick up the shelf reliably after placing it.

### Requirement

```text
CollisionShape2D = physical blocking / body collision
InteractionArea = detection for prompt and pickup
```

Expand the shelf interaction area, not the physics collision.

### Checklist

- [x] Shelf pickup detection uses a larger reachable InteractionArea.
- [x] Physical collision remains normal size.
- [x] Prompt appears before pressing E.
- [x] Player can pick shelf up again after placing it.
- [x] Ghost shelf retrieval flow is reliable.
- [x] Enlarged interaction area does not conflict with door, cashier, board, or other interactions.

### Implementation Notes

- Shelf `InteractionArea` is expanded from `64x48` to `92x68` so the player can get pickup prompts from a practical standing distance.
- Shelf `PhysicsBody/CollisionShape2D` stays at `64x32`, so this does not enlarge physical blocking or shelf placement collision.
- Existing interaction priority remains unchanged: doors are checked first, cashier/NPC/supply targets still outrank shelves, and shelf pickup continues through existing Store/Storage request methods.

### Codex Prompt

```text
Analisa dan implementasikan Task 5 — Polish Shelf Pickup Reachability dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Jangan memperbesar physics collision secara asal.
- Pisahkan CollisionShape2D fisik dan InteractionArea untuk pickup.
- InteractionArea shelf boleh diperbesar agar pickup lebih mudah.
- Pastikan prompt muncul sebelum menekan E.
- Pastikan tidak konflik dengan StorageDoor, Cashier, atau ActivityBoard.

Expected output:
- File/scene yang dicek.
- Penyebab shelf sulit diambil.
- Perubahan InteractionArea yang dibuat.
- Test pickup human shelf dan ghost shelf.
```

---

## 10. Task 6 — Polish Shelf Placement Safety / No-Drop Zones

### Goal

Prevent shelf placement in positions that break navigation, block doors, block cashier, or make the shelf difficult to retrieve.

### Checklist

- [x] Shelf cannot be dropped on StorageDoor transition area.
- [x] Shelf cannot be dropped on YardDoor transition area.
- [x] Shelf cannot be dropped in cashier restricted area.
- [x] Shelf cannot block main path or queue path.
- [x] If first drop position is unsafe, fallback positions are tested.
- [x] If all drop positions are unsafe, player keeps carrying shelf.
- [x] Player receives clear feedback when drop is rejected.

### Implementation Notes

- Store shelf placement already rejects StorageDoor, YardDoor, cashier restricted area, body collision overlap, and unreachable shelf interaction positions.
- Added customer path no-drop validation using existing `EntrancePos` and `CounterPos` markers.
- Added checkout queue no-drop validation below `CounterPos`, matching the existing NPC queue target flow.
- Existing fallback candidates remain active; if no candidate is valid, the shelf stays carried and the player receives rejection feedback.

### Codex Prompt

```text
Analisa dan implementasikan Task 6 — Polish Shelf Placement Safety / No-Drop Zones dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Fokus existing shelf carry/drop flow.
- Cegah shelf ditempatkan di pintu, cashier, path utama, atau posisi yang membuat shelf sulit diambil.
- Jika posisi utama invalid, coba fallback position.
- Jika semua invalid, shelf tetap dibawa player dan tampilkan feedback.

Expected output:
- File/scene yang dicek.
- No-drop zone yang ditemukan/dibuat.
- Perubahan validasi drop.
- Test drop dekat storage door, cashier, wall/corner.
```

---

## 11. Task 7 — Polish Cashier Restricted Area Danger Line

### Goal

Cashier restricted/no-drop area should be visually communicated when the player tries to place a shelf there.

### Visual Direction

```text
A danger line surrounds the cashier restricted area.
Hidden by default.
When invalid shelf drop happens near cashier:
→ danger line appears
→ fades in/out over 2 seconds
→ repeats 3 times
→ hides again
```

### Checklist

- [x] Cashier restricted area exists or is clearly defined.
- [x] Shelf drop in cashier restricted area is rejected.
- [x] Player keeps carrying shelf after invalid drop.
- [x] Danger line surrounds the cashier restricted area.
- [x] Danger line is hidden by default.
- [x] Danger line fades in/out over 2 seconds.
- [x] Fade animation repeats 3 times.
- [x] Danger line hides after animation.
- [x] Animation does not block player input.
- [x] Animation does not interfere with cashier UI or NPC queue.

### Implementation Notes

- Cashier restricted area uses the same `CounterPos`-based no-drop rect as shelf placement validation.
- Added runtime `CashierRestrictedDangerLine` as a hidden `Line2D` around the cashier restricted rect.
- Invalid cashier-area shelf drop starts a non-blocking danger-line tween: fade in 1 second, fade out 1 second, repeated 3 cycles.
- The line is hidden again after the final fade and does not change cashier UI, NPC queue, or shelf carry state.

### Codex Prompt

```text
Analisa dan implementasikan Task 7 — Polish Cashier Restricted Area Danger Line dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Fokus existing cashier restricted/no-drop area feedback.
- Shelf tetap tidak boleh diletakkan di area cashier/counter.
- Tambahkan visual danger line yang mengelilingi restricted area cashier.
- Danger line hidden by default.
- Saat invalid shelf drop di restricted area, danger line fade in/out selama 2 detik dan ulangi 3 kali.
- Setelah 3 kali, danger line harus hidden lagi.
- Player tetap membawa shelf jika drop invalid.
- Jangan buat modal blocking.
- Jangan ganggu cashier UI, queue NPC, atau interaction prompt.

Expected output:
- File/scene yang dicek.
- Lokasi restricted area cashier saat ini.
- Cara danger line dibuat.
- Cara animasi fade in/out 2 detik × 3 cycle dibuat.
- Test invalid drop, normal drop, repeated invalid drop, cashier UI.
```

---

## 12. Task 8 — Fix Store Door Entry Alignment

### Goal

Player entry/return position should match the actual door position.

### Checklist

- [x] Returning from storage spawns player near StorageDoor.
- [x] Returning from yard/outside spawns player near the correct door.
- [x] Player does not spawn inside door trigger.
- [x] Player does not instantly re-trigger transition.
- [x] Player does not spawn inside wall/shelf/cashier restricted area.
- [x] Door markers are visually aligned with door assets/placeholders.

### Implementation Notes

- `StorageReturnPos` already sits below `StorageDoor`, outside the door trigger.
- `YardReturnPos` is aligned to `YardDoor` x-position and remains above the trigger so the player does not instantly re-enter the yard.
- Yard return fallback position now matches the marker alignment when the marker is missing.

### Codex Prompt

```text
Analisa dan implementasikan Task 8 — Fix Store Door Entry Alignment dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Fokus marker/position transition existing.
- Posisi enter store harus sesuai posisi pintu.
- Jangan spawn player di dalam trigger pintu atau collision.
- Cek Store scene markers, door transition code, StorageReturnPos, YardReturnPos, PlayerSpawn.

Expected output:
- File/scene yang dicek.
- Marker pintu yang tidak align.
- Perubahan posisi marker atau transition logic.
- Test return dari storage dan area lain.
```

---

## 13. Task 9 — Move Trust Display to NPC World UI

### Goal

Trust is not permanent player HUD state. Trust belongs to the relevant NPC and should be displayed above that NPC when relevant.

### Checklist

- [x] Remove/hide permanent Gooby Trust HUD label.
- [x] Add trust label/bar above Gooby/story NPC.
- [x] Trust display follows NPC movement.
- [x] Trust updates after Gooby interaction.
- [x] Generic NPCs do not show unnecessary trust bars.
- [x] RelationshipManager remains source of truth.

### Implementation Notes

- Removed the permanent `TrustLabel` from HUD and stopped HUD from subscribing to `RelationshipManager.trust_changed`.
- Added an NPC world-space `TrustLabel` above `NameLabel`, hidden by default.
- Story NPCs connect to `RelationshipManager.trust_changed` and show their own trust value; generic NPCs keep the trust label hidden.
- RelationshipManager remains the source of truth for all trust values.

### Codex Prompt

```text
Analisa dan implementasikan Task 9 — Move Trust Display to NPC World UI dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah relationship system kompleks.
- RelationshipManager tetap source of truth.
- Trust bukan permanent player HUD status.
- Trust harus tampil di atas NPC/story NPC yang relevan.
- Jangan merusak NameLabel/DialogBubble NPC.
- Pastikan Gooby trust update tetap jalan setelah gift/refuse flow.

Expected output:
- File yang dicek.
- Cara trust saat ini tampil di HUD.
- Perubahan untuk memindahkan trust ke NPC world UI.
- Test Gooby trust display, trust update, generic NPC.
```

---

## 14. Task 10 — Polish Cashier Ask Again UI

### Goal

When the player presses `Ask Again`, the customer's request should be readable inside the cashier panel. Player should not need to peek behind the cashier panel to read NPC bubble text.

### Preferred UI Behavior

```text
Cashier panel should include:
- Customer name
- Requested item
- Current scanned/selected item
- Total value
- Customer request text / repeated request text
- Clear buttons
```

Example layout:

```text
CHECKOUT
Customer: Gooby
Request: "I want Phantom Ice Cream."
Selected: Phantom Ice Cream
Total: 0G

[Confirm Scan] [Ask Again 1/3] [Close]
```

### Checklist

- [x] Ask Again request appears inside cashier panel.
- [x] NPC dialogue bubble can still exist, but it is not required to read request.
- [x] Cashier panel does not cover its own important text.
- [x] Buttons are spaced/readable at 480x270.
- [x] Ask Again count, if used, is visible.
- [x] Gooby choice panel remains clear.
- [x] Panel closes/unlocks input correctly.

### Implementation Notes

- Added a cashier panel `request_label` so customer request text appears inside the panel.
- Scan panel now separates customer name, request text, selected item, total, and Ask Again count.
- `Ask Again` still triggers the NPC bubble, but the player can read the repeated request from the panel.
- Paid and Gooby choice panels keep request/customer context without changing checkout flow.

### Codex Prompt

```text
Analisa dan implementasikan Task 10 — Polish Cashier Ask Again UI dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Fokus readability panel cashier.
- Saat Ask Again, request NPC harus terlihat di dalam panel cashier.
- Jangan membuat player perlu melihat bubble NPC di belakang overlay.
- Jangan merusak normal checkout atau Gooby choice panel.
- Cek Cashier scene/script dan HUD/modal interaction lock.

Expected output:
- File yang dicek.
- Penyebab request sulit dibaca.
- Perubahan UI panel.
- Test Ask Again normal NPC dan Gooby.
```

---

## 15. Task 11 — Polish Cashier Panel Button Guidance

### Goal

Cashier panel should communicate what each button does, at least once, so player does not need to memorize controls or guess panel behavior.

### Design Requirement

Button guidance can be implemented as:

```text
- Clear button labels
- Short helper text inside panel
- One-time cashier tutorial line
- Tooltip-like text when hovering/focusing a button, if simple
```

Do not overbuild a full tutorial system. The goal is just to prevent confusion.

### Example Helper Text

```text
Select the requested item, then confirm the scan.
Ask Again repeats what the customer wants.
Close cancels checkout.
```

For Gooby:

```text
Give Item increases trust but gives no gold.
Refuse Sale returns the item and continues the night event.
```

### Checklist

- [x] Cashier panel explains core button functions at least once.
- [x] Normal checkout button labels are clear.
- [x] Gooby choice button labels are clear.
- [x] Ask Again button has clear meaning.
- [x] Guidance does not clutter panel permanently.
- [x] Guidance does not block player control.
- [x] Guidance follows E/Q mapping where keyboard prompts are shown.

### Implementation Notes

- Cashier panel keeps one-time helper text for scan, paid, and Gooby decision states.
- Button labels were clarified for closing checkout and returning to scan item selection.
- Cashier buttons now have tooltip guidance for selection, confirm scan, ask again, close, receive payment, Gooby gift, Gooby refusal, and back-to-scan actions.
- Guidance stays in the panel/button UI and does not add blocking notifications or new mechanics.

### Codex Prompt

```text
Analisa dan implementasikan Task 11 — Polish Cashier Panel Button Guidance dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Fokus membuat UI cashier lebih jelas.
- Button/click guidance perlu muncul setidaknya sekali.
- Jangan buat tutorial panjang yang mengganggu flow.
- Pastikan normal checkout dan Gooby choice sama-sama jelas.

Expected output:
- File yang dicek.
- Button yang diberi label/helper text.
- Cara guidance dibuat agar tidak looping/mengganggu.
- Test normal checkout, Ask Again, Gooby Give Item, Gooby Refuse Sale.
```

---

## 16. Task 12 — Audit Objective HUD Guidance

### Goal

Clarify whether objective text should remain in HUD, move to Activity Board, or be replaced by contextual hints.

### Design Options

```text
Option A — Keep objective in HUD:
Use one-line bottom/side objective only.

Option B — Move objective into Activity Board:
HUD stays cleaner; board stores guidance.

Option C — Contextual hints only:
No persistent objective; object prompts guide the player.
```

Recommended for Day 1:

```text
Use contextual interaction hints as primary guidance.
Use Activity Board as backup guidance.
Keep HUD objective only if it is short, non-overlapping, and clearly useful.
```

### Codex Prompt

```text
Analisa Task 12 — Audit Objective HUD Guidance dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan edit file dulu.
- Jangan tambah mechanic baru.
- Jelaskan dari mana ObjectiveLabel dibuat dan siapa yang mengubahnya.
- Rekomendasikan apakah objective tetap di HUD, dipindah ke board, atau diganti contextual hints.

Expected output:
- File yang dicek.
- Sumber objective text.
- Kapan objective berubah.
- Apakah objective perlu dipertahankan.
- Rekomendasi perubahan.
```

---

## 17. Task 13 — Polish Activity Board / Action Guidance

### Goal

Use the activity board only as lightweight guidance for current existing actions, not as a quest system.

### Example Content

```text
Today's Work
- Bring shelf from storage
- Stock human shelf
- Serve customers at cashier
```

After ghost flow:

```text
Strange Notes
- Check the dark storage corner
- Place the ghost shelf
- Stock Phantom Ice Cream
- Watch the store at night
```

Night branch:

```text
Night Choice
- Give item: Trust +, Revenue 0G
- Refuse sale: Item remains available for another customer
```

### Checklist

- [x] Board explains current activity clearly.
- [x] Board does not create rewards or quest completion mechanics.
- [x] Board UI can be closed safely.
- [x] Board does not conflict with cashier UI.
- [x] Board can later be replaced by final board sprite.

### Implementation Notes

- Activity Board content remains sourced from existing Store state and only describes current actions.
- Board panel no longer adds a HUD action lock; it can be closed with the Close button, Escape, or right click.
- Board refuses to open while `CashierUILayer` is visible, preventing overlap with cashier checkout.
- Board scene structure stays placeholder/asset-ready for a future final board sprite.

### Codex Prompt

```text
Analisa dan implementasikan Task 13 — Polish Activity Board / Action Guidance dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah quest system.
- Board hanya menjelaskan existing actions.
- Pastikan board bisa dibuka/tutup tanpa mengunci input.
- Pastikan board tidak konflik dengan cashier panel.

Expected output:
- File/scene yang dicek.
- Konten board final.
- Perubahan yang dibuat.
- Test open/close board dan updated guidance.
```

---

## 18. Task 14 — Polish Time / Phase Split

### Goal

Make in-game time phases more intuitive. 18:00 should be Night, not Day.

Recommended split:

```text
Morning / Setup: 08:00 → 10:00
Day / Store Open: 10:00 → 18:00
Night / Strange Customers: 18:00 → 22:00
End / Report: after 22:00
```

Alternative if setup needs longer:

```text
Morning / Setup: 08:00 → 11:00
Day / Store Open: 11:00 → 18:00
Night / Strange Customers: 18:00 → 22:00
End / Report: after 22:00
```

Preferred for Day 1:

```text
18:00 = Night
```

### Checklist

- [x] Time display matches phase.
- [x] Night starts at 18:00.
- [x] Gooby/Slime night logic triggers only during Night.
- [x] Day NPC revenue pacing stops before 18:00.
- [x] End/report timing remains clear.

### Implementation Notes

- Phase clock split is now Morning `08:00-10:00`, Day `10:00-18:00`, Night `18:00-22:00`.
- Time display uses per-phase world-minute durations, so Day starts at `10:00` and Night starts at `18:00`.
- NPCScheduler now only spawns NPCs whose `VisitPhase` matches the current TimeManager phase.
- Day 1 Night spawning still waits for Night; normal Day 1 customer pacing is handled by Task 15.

### Codex Prompt

```text
Analisa dan implementasikan Task 14 — Polish Time / Phase Split dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Fokus pembagian phase dan time display existing.
- 18:00 harus masuk Night.
- Pastikan normal Day NPC spawn berhenti sebelum Night.
- Pastikan Gooby/Slime night branch tidak berjalan sebelum Night.
- Cek TimeManager, NPCScheduler, HUD time/phase label.

Expected output:
- File yang dicek.
- Phase split sebelum/sesudah.
- Perubahan yang dibuat.
- Test 10:00 Day, 18:00 Night, Gooby Night trigger.
```

---

## 19. Task 15 — Polish Day Revenue Pacing to 40G

### Goal

Before the Gooby/Slime night branch, normal Day customers should produce 40G total revenue. The final 10G should depend on the Slime branch.

Expected Day economy:

```text
Daily target: 50G
Normal Day NPC revenue: 40G
Night item value / Slime purchase: 10G
```

### Dynamic Spawn Idea

After the player finishes managing shelf setup, calculate remaining time until 18:00 and divide it by 4 normal NPCs.

Example:

```text
Player finishes shelf setup at 10:00
Day window until Night: 10:00 → 18:00 = 8 hours
Normal NPC count: 4
Spawn interval: 8 / 4 = 2 hours per NPC
```

Another example:

```text
Player finishes shelf setup at 08:00
Remaining time until Night: 10 hours
Normal NPC count: 4
Spawn interval: 10 / 4 = 2.5 hours per NPC
```

Expected result:

```text
By 18:00, normal NPC sales should total 40G.
Then Gooby/Slime branch decides whether final target reaches 50G.
```

### Checklist

- [x] Normal Day NPC revenue target is 40G.
- [x] Normal Day NPC count or purchase value reliably reaches 40G.
- [x] Spawn schedule considers remaining Day time until 18:00.
- [x] Day NPCs do not continue generating revenue after Night begins.
- [x] Slime remains the final 10G opportunity.
- [x] Gift Gooby path can leave revenue at 40/50.
- [x] Refuse Gooby path can allow Slime to reach 50/50.

### Implementation Notes

- Day 1 normal customers remain four scripted Day customers with checkout totals `10G + 5G + 15G + 10G = 40G`.
- Day 1 Day spawn interval is now calculated from the remaining time between shelf setup completion and the 18:00 Night phase.
- Scheduler keeps a small guard before Night so Day NPCs are not intentionally queued at the exact 18:00 phase transition.
- If setup completes very late, Day 1 customer pacing can rush within the remaining Day window instead of continuing into Night.
- Phantom Ice Cream remains `10G`, so Slime stays the final 10G opportunity after the Gooby branch.

### Codex Prompt

```text
Analisa dan implementasikan Task 15 — Polish Day Revenue Pacing to 40G dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Fokus existing NPCScheduler/EconomyManager/item pricing.
- Target harian 50G.
- Revenue normal sebelum Night harus 40G.
- Slime menjadi peluang final 10G.
- Jika player selesai setup shelf lebih cepat/lambat, jadwalkan 4 NPC normal dalam sisa waktu sampai 18:00.
- Cek TimeManager, NPCScheduler, EconomyManager, ItemData pricing, day customer spawning.

Expected output:
- File yang dicek.
- Cara revenue normal Day dihitung.
- Perubahan spawn/pacing yang dibuat.
- Test setup selesai jam 10:00, NPC normal total 40G, Night 18:00, Slime +10G.
```

---

## 20. Task 16 — Revise Gooby / Slime Follow-Up Logic

### Goal

Revise the night branch so Slime comes after Gooby's outcome, not only as a direct refusal spawn. The result depends on whether Phantom Ice Cream is still available.

### Revised Story Logic

```text
Night starts at 18:00
→ Gooby arrives and requests Phantom Ice Cream
→ Player resolves Gooby outcome
→ Shortly after Gooby outcome, Slime arrives
→ Slime asks for the same item
```

### Branch A — Give Item to Gooby

```text
Player gives Phantom Ice Cream to Gooby
→ Gooby Trust increases
→ Gooby pays 0G
→ Phantom Ice Cream is consumed / unavailable
→ Slime arrives shortly after
→ Slime asks for Phantom Ice Cream
→ Item is already gone
→ Player can respond that the item is out of stock
→ Slime cannot buy
→ Revenue remains 40/50
```

### Branch B — Refuse Gooby

```text
Player refuses to give Phantom Ice Cream to Gooby
→ Gooby pays 0G
→ Phantom Ice Cream remains available or returns to shelf
→ Slime arrives shortly after
→ Slime asks for Phantom Ice Cream
→ Item is available
→ Player sells item to Slime
→ Revenue increases by 10G
→ Revenue reaches 50/50
```

### Design Rule

This should preserve the core trade-off:

```text
Give Gooby = trust path, daily target missed
Refuse Gooby = revenue path, daily target achieved through Slime
```

Recommended trust rule for prototype:

```text
Give Gooby = Trust +20
Refuse Gooby = Trust +0
```

Optional softer variant if desired later:

```text
Give Gooby = Trust +20
Refuse politely = Trust +5
```

For Day 1, prefer the clear version:

```text
Trust path vs Revenue path
```

### Timing Recommendation

Slime should arrive **after Gooby checkout/outcome is resolved**, with a short delay.

Reason:

```text
- Prevents cashier queue confusion.
- Makes cause/effect readable.
- Keeps Gooby choice clear.
- Makes Slime feel like a follow-up event.
```

### Checklist

- [x] Slime is scheduled as a night follow-up after Gooby outcome.
- [x] Slime can come after both Gooby gift and Gooby refusal.
- [x] If Gooby received the item, Slime finds item unavailable.
- [x] If Gooby was refused, item remains available / returns to shelf for Slime sale.
- [x] Slime does not duplicate spawn.
- [x] Slime does not buy unavailable item.
- [x] Slime sale is the final 10G opportunity.
- [x] Gift path ends at 40/50 revenue.
- [x] Refuse path can reach 50/50 revenue.
- [x] Notifications/panel text explain why Slime can or cannot buy.

### Implementation Notes

- Gooby gift now schedules the Slime follow-up, consumes Phantom Ice Cream through the existing NPC cart flow, grants Trust +20, and adds 0G.
- Gooby refusal now schedules the same Slime follow-up, returns Phantom Ice Cream to the ghost shelf, grants Trust +0, and adds 0G.
- NPCScheduler delays the Slime follow-up by a short timer and blocks duplicate Slime spawns.
- Slime uses the existing Night NPC checkout flow for Phantom Ice Cream at 10G.
- If Phantom Ice Cream is gone, Slime uses the existing no-item leave behavior and cannot generate revenue.
- Store objective changes to "Wait for the next strange customer." after either Gooby outcome.

### Codex Prompt

```text
Analisa dan implementasikan Task 16 — Revise Gooby / Slime Follow-Up Logic dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah story branch baru di luar Gooby/Slime Day 1 night branch.
- Slime harus datang setelah Gooby outcome, bukan hanya saat Gooby ditolak.
- Jika item diberikan ke Gooby, Slime datang tetapi item habis/tidak tersedia dan tidak ada revenue dari Slime.
- Jika Gooby ditolak, item tetap tersedia/kembali ke shelf dan Slime bisa membelinya.
- Give Gooby = trust path, revenue tetap 40/50.
- Refuse Gooby = revenue path, Slime +10G, target 50/50.
- Cegah duplicate Slime spawn.
- Cek Cashier, NPCScheduler, Store, Shelf, EconomyManager, RelationshipManager.

Expected output:
- File yang dicek.
- Flow Gooby gift setelah revisi.
- Flow Gooby refuse setelah revisi.
- Cara Slime follow-up dijadwalkan.
- Test gift path: Slime datang tapi tidak bisa beli.
- Test refuse path: Slime datang dan bisa beli.
```

---

## 21. Task 17 — Validate Gooby Night Choice

### Goal

Validate the complete night branch after Time, Revenue Pacing, and Gooby/Slime follow-up revisions.

### Checklist

- [ ] Normal Day revenue reaches 40G before Night.
- [ ] Night starts at 18:00.
- [ ] Gooby arrives during Night.
- [ ] Gooby asks for Phantom Ice Cream.
- [ ] Give Gooby increases trust and gives 0G.
- [ ] Slime still arrives after gift but cannot buy unavailable item.
- [ ] Gift path ends at 40/50.
- [ ] Refuse Gooby leaves/returns item available.
- [ ] Slime arrives after refusal and can buy item.
- [ ] Refuse path reaches 50/50.
- [ ] No duplicate Slime or duplicate revenue.

### Codex Prompt

```text
Validate Task 17 — Gooby Night Choice from docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Jangan edit file kecuali bug ditemukan.
- Fokus full branch after latest revisions.
- Pastikan revenue dan trust tetap reward path terpisah.

Expected output:
- File yang dicek.
- Status normal Day revenue 40G.
- Status Give Gooby path.
- Status Slime after gift path.
- Status Refuse Gooby path.
- Status Slime after refuse path.
- Bug yang ditemukan.
```

---

## 22. Task 18 — Review Full Core Loop

### Goal

Review the full playable Day 1 loop after all focused polish tasks.

### Checklist

- [ ] Player understands E/Q mapping.
- [ ] Player sees prompt before input.
- [ ] First-time guidance appears once and does not loop.
- [ ] Hover/object name feedback works.
- [ ] Player can bring shelf from storage.
- [ ] Door return positions are correct.
- [ ] Player can place and pick up shelves reliably.
- [ ] Cashier restricted danger line works.
- [ ] Cashier panel and Ask Again UI are readable.
- [ ] Trust display is above relevant NPC.
- [ ] Time phase split is readable.
- [ ] Normal Day revenue reaches 40G.
- [ ] Gooby/Slime branch works as designed.
- [ ] Temporary UI remains readable at 480x270.
- [ ] Player never loses control due to stuck UI state.

### Codex Prompt

```text
Review Task 18 — Review Full Core Loop dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan edit file dulu.
- Jangan tambah mechanic baru.
- Jalankan review berdasarkan mechanic yang sudah ada.
- Fokus menemukan friction point, UI overlap, input confusion, atau branch bug.

Expected output:
- Status core loop dari setup sampai laporan malam.
- Bagian yang sudah stabil.
- Bagian yang masih rawan.
- Rekomendasi task kecil berikutnya.
```

---

## 23. Task 19 — Prepare Asset-Ready Node Structure

### Goal

Prepare scenes so placeholder visuals can be replaced with Aseprite assets later without breaking mechanics.

Recommended object pattern:

```text
Object
├── VisualRoot
│   ├── PlaceholderRect
│   └── AssetSprite / AnimatedSprite2D
├── CollisionShape2D
├── InteractionArea
└── Labels / UI anchors
```

Recommended NPC pattern:

```text
NPC
├── VisualRoot
│   ├── PlaceholderRect
│   └── AnimatedSprite2D
├── NameLabel
├── TrustBar / TrustLabel
├── DialogBubble
├── CollisionShape2D
└── InteractionArea
```

Checklist:

- [ ] Visual nodes are separated from logic/collision nodes.
- [ ] Interaction areas remain stable when sprite changes.
- [ ] Scene node names are stable.
- [ ] Script does not depend directly on `ColorRect` for gameplay logic.
- [ ] Trust UI and interaction hint UI can later be replaced by final UI art.
- [ ] Danger line can later be replaced by final restricted-area sprite/tiles.

---

## 24. Task 20 — Documentation Update

### Goal

Keep this file useful as an AI Agent task spec.

Checklist:

- [ ] Mark tasks as done / partially done / pending after Codex implementation.
- [ ] Add discovered bugs to relevant sections.
- [ ] Add new test cases if playtest reveals missing cases.
- [ ] Keep Day 1 scope focused on polish, not feature expansion.
- [ ] Keep implementation notes aligned with actual behavior.

---

## 25. Definition of Done — Day 1

Day 1 can be considered done when:

- [ ] E/Q input mapping is consistent.
- [ ] Interaction prompts appear before input.
- [ ] Button/click guidance appears at least once and does not loop.
- [ ] Hover/object name feedback works.
- [ ] Shelf pickup and placement are reliable.
- [ ] No-drop zones prevent broken placement.
- [ ] Cashier restricted danger line works.
- [ ] Door entry positions align with doors.
- [ ] Trust display appears on relevant NPC, not as permanent player HUD stat.
- [ ] Cashier Ask Again and panel button guidance are readable.
- [ ] Objective/board guidance source is clear.
- [ ] 18:00 is Night.
- [ ] Normal Day revenue reaches 40G.
- [ ] Gooby gift path gives trust and misses target.
- [ ] Slime comes after Gooby gift but cannot buy if item is gone.
- [ ] Gooby refusal path lets Slime buy and reach 50G.
- [ ] No duplicate Slime or duplicate revenue.
- [ ] Temporary UI is readable at 480x270.
- [ ] Project remains ready for Aseprite asset integration.

---

## 26. Suggested Trello / Branch Naming

Trello activities:

```text
standardize_input_mapping_e_get_q_put_day_1
revise_interaction_prompt_timing_day_1
add_one_time_button_click_guidance_day_1
add_hover_object_name_feedback_day_1
polish_shelf_pickup_reachability_day_1
polish_shelf_placement_no_drop_zones_day_1
polish_cashier_restricted_danger_line_day_1
fix_store_door_entry_alignment_day_1
move_trust_display_to_npc_world_ui_day_1
polish_cashier_ask_again_ui_day_1
polish_cashier_panel_button_guidance_day_1
audit_objective_hud_guidance_day_1
polish_activity_board_guidance_day_1
polish_time_phase_split_day_1
polish_day_revenue_pacing_to_40g_day_1
revise_gooby_slime_follow_up_logic_day_1
validate_gooby_night_choice_day_1
review_full_core_loop_day_1
prepare_asset_ready_node_structure_day_1
```

Branch:

```text
polish/day-1-mechanic-polish
```

Suggested commit messages:

```text
docs: revise day 1 mechanic polish tasks
fix: standardize E and Q interaction prompts
feat: add one-time cashier button guidance
fix: improve cashier ask again readability
fix: revise Gooby Slime follow-up branch
chore: document day revenue pacing target
```
