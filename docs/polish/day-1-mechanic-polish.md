# Crossroad Market — Day 1 Mechanic Polish

## 1. Purpose

Day 1 focuses on **mechanic polish without final art assets**. The project may still use placeholder visuals such as `ColorRect`, simple shapes, or temporary sprites. The goal is not to add new mechanics, but to make the existing mechanics more stable, readable, testable, and ready for future Aseprite asset integration.

Main rule:

```text
Do not add new mechanics.
Polish the mechanics that already exist.
Prepare the project so final assets can be swapped in safely later.
```

This document is intended to guide AI Agent / Codex work. Every change should improve clarity, stability, feedback, onboarding, UI readability, or asset-readiness without expanding the gameplay scope.

---

## 2. Current Polish Context

The game already has a working core shop loop:

```text
Player collects stock
→ Player places item on shelf
→ NPC enters the store
→ NPC walks to shelf
→ NPC searches for item
→ NPC takes item
→ NPC queues at cashier
→ Player scans the item
→ Checkout outcome is resolved
→ NPC exits the store
→ Revenue, trust, or story consequence is updated
```

Day 1 polish should make this loop easier to understand and less fragile.

Current polish status after the Day 1 task pass:

```text
Gooby Trust HUD has a dedicated top-right layout.
Objective guidance and activity board guidance exist for the current Day 1 loop.
NPC, cashier, shelf, notification, and asset-ready structure polish have been applied.
Remaining risk is manual full-loop playtest coverage, especially the night Gooby → Slime branch timing.
```

---

## 3. Scope

### 3.1 In Scope

The following work is allowed:

- Stabilize existing player interaction.
- Stabilize existing NPC state flow.
- Improve shelf placement and shelf item feedback.
- Improve cashier scan and checkout clarity.
- Improve notification and dialogue feedback.
- Improve Gooby night choice logic.
- Improve trust/revenue feedback for Gooby.
- Fix temporary HUD layout issues, including overlapping labels.
- Add or improve lightweight objective guidance using existing mechanics.
- Add a simple activity / task board if it only explains existing actions.
- Prepare placeholder node structure for later sprite replacement.
- Add small helper methods only if they make existing logic clearer.
- Document mechanic behavior and expected outcomes.

### 3.2 Out of Scope

The following work is not allowed for Day 1:

- Adding new gameplay systems such as farming, crafting, skill tree, or store expansion.
- Adding new maps that are not needed for the current loop.
- Adding new story branches beyond the existing Gooby night choice.
- Adding complex relationship systems beyond simple trust tracking.
- Replacing all final assets before the asset pack is ready.
- Doing final animation polish that depends on final sprites.
- Reworking the whole project architecture at once.
- Adding a complex quest system.
- Adding a full minimap system.
- Adding a complex tutorial system with cutscenes.

If a proposed change creates a new way to play, it is likely a new mechanic. If it only explains, stabilizes, or clarifies an existing action, it can be treated as polish.

---

## 4. Recommended Execution Order

Use this document as a task spec. Do not ask Codex / AI Agent to execute everything at once.

```text
1 prompt = 1 task or 1 small subtask
```

Recommended order:

```text
Task 1  — Validate Gooby Night Choice
Task 2  — Polish HUD Layout and Trust Display
Task 3  — Polish Player Navigation and Objective Guidance
Task 4  — Polish Activity Board / Action Guidance
Task 5  — Polish NPC Flow
Task 6  — Polish Cashier Flow
Task 7  — Polish Shelf and Item Flow
Task 8  — Polish Feedback and Notifications
Task 9  — Review Core Loop
Task 10 — Prepare Asset-Ready Node Structure
Task 11 — Documentation Update
```

Current task status:

```text
Task 1  — Done
Task 2  — Done
Task 3  — Done
Task 4  — Done
Task 5  — Done
Task 6  — Done
Task 7  — Done
Task 8  — Done
Task 9  — Done, with manual playtest risk noted
Task 10 — Done
Task 11 — Done
```

---

## 5. Task 1 — Validate Gooby Night Choice

### Goal

Validate the existing Gooby night branch. This task should be validation-first because the core logic is already implemented.

### Expected Flow

```text
Night phase starts
→ Gooby arrives
→ Gooby searches for Phantom Ice Cream
→ Gooby takes Phantom Ice Cream
→ Gooby queues at cashier
→ Player scans Phantom Ice Cream
→ Cashier shows Gooby-specific choice
```

At this point, player chooses one of two options:

```text
Option A: Give Item
Option B: Refuse Sale
```

### Option A — Give Item

Expected behavior:

```text
Player gives Phantom Ice Cream to Gooby
→ Gooby does not pay with gold
→ Daily revenue does not increase
→ Gooby Trust increases
→ Gooby exits
→ Slime does not spawn
```

Expected result:

```text
Revenue remains 40/50
Gooby Trust increases by +20
Story relationship path improves
Daily target remains missed unless another revenue source exists
```

Checklist:

- [x] Gooby gift option is visible in cashier UI.
- [x] Gift option does not add gold.
- [x] Gift option does not add daily revenue.
- [x] Gift option increases Gooby trust.
- [x] Gift option consumes the item.
- [x] Gooby exits after receiving gift.
- [x] Slime does not spawn after gift.
- [x] HUD trust label updates without overlapping other HUD text.
- [x] Notification explains `+Trust` and `+0G` clearly.

### Option B — Refuse Sale

Expected behavior:

```text
Player refuses Gooby
→ Gooby does not pay
→ Phantom Ice Cream returns to shelf
→ Gooby exits
→ Slime spawns
→ Slime searches for Phantom Ice Cream
→ Slime buys it normally
→ Revenue increases by 10G
```

Expected result:

```text
Revenue changes from 40/50 to 50/50 after Slime purchase
Daily target is achieved
Gooby Trust increases by +20 from the story interaction
Story relationship path improves without direct Gooby revenue
```

Checklist:

- [x] Refuse option is visible in cashier UI.
- [x] Refuse option does not add gold directly from Gooby.
- [x] Refuse option returns item to ghost shelf.
- [x] Gooby exits after refusal.
- [x] Slime spawns only once.
- [x] Slime can find Phantom Ice Cream after it returns to shelf.
- [x] Slime purchase adds revenue normally.
- [x] Target can become `50G / 50G TARGET ACHIEVED`.
- [x] Notification explains that another customer is coming.

Validation notes:

- Gooby is scheduled only during Day 1 night and requests Phantom Ice Cream.
- Gift path completes checkout as a story gift, adds Gooby Trust +20, records 0G, and does not request Slime.
- Refuse path returns Phantom Ice Cream to the ghost shelf, adds story interaction trust, records 0G from Gooby, and requests the guarded Slime consequence.
- Slime uses the returned Phantom Ice Cream and pays 10G through the normal checkout path.
- Gooby trust HUD text now uses compact right-aligned `Trust: X/100` text on its own row to avoid Wallet/Target overlap.

### AI Agent Prompt

```text
Validate Task 1 — Gooby Night Choice from docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Jangan edit file kecuali bug ditemukan.
- Fokus existing Gooby gift/refuse flow.
- Pastikan revenue dan trust tetap reward path terpisah.
- Pastikan HUD trust tidak menimpa HUD lain.

Expected output:
- File yang dicek.
- Status Give Item.
- Status Refuse Sale.
- Status Slime path.
- Bug yang ditemukan.
- Apakah Task 1 bisa ditandai done.
```

---

## 6. Task 2 — Polish HUD Layout and Trust Display

### Goal

Fix HUD readability problems. The current trust display can overlap existing HUD elements, so HUD polish is now a required Day 1 task.

This is not a new mechanic. It is UI polish for already existing game state:

```text
Wallet
Daily revenue target
Time / phase / day
Gooby Trust
Notifications
```

### Design Requirements

HUD must be readable at the project viewport size:

```text
480x270
```

Recommended temporary layout:

```text
Top-left:
- Wallet
- Daily target

Top-center:
- Day
- Phase
- Time

Top-right:
- Gooby Trust

Bottom / lower center:
- Notification text
```

If the top-right area is too cramped, use a compact label:

```text
Trust: 10/100
```

instead of:

```text
Gooby Trust: 10/100
```

### Checklist

- [x] Gooby Trust label does not overlap Wallet.
- [x] Gooby Trust label does not overlap target display.
- [x] Gooby Trust label does not overlap Day / Phase / Time.
- [x] Trust label is readable at 480x270 viewport.
- [x] Trust label updates after Give Item.
- [x] Trust label remains visible but not distracting.
- [x] Target display still updates correctly.
- [x] Notification text still appears clearly.
- [x] HUD uses stable positioning that can later be replaced with designed UI assets.
- [x] No gameplay logic is moved into HUD.

### Implementation notes

- HUD now uses dedicated top containers: `TopLeftHUD` for wallet/target, `TopCenterHUD` for day/phase/time, and `TopRightHUD` for Gooby trust.
- Gooby trust is a scene-owned `TrustLabel`, still updated through `RelationshipManager.trust_changed`.
- Target achieved text is compacted to `TARGET` so it remains readable in the top-left HUD area at 480x270.
- Notification text stays in a stable centered HUD region below the top status labels.

### Suggested Implementation Direction

Preferred temporary solution:

```text
Create a dedicated HUD container for trust display.
Use alignment/anchors instead of raw overlapping positions where possible.
Keep trust update logic connected to RelationshipManager.
```

Do not overbuild a full HUD framework yet. This task is only to make the current HUD readable.

### Test Cases

#### HUD-01 — Default HUD

```text
Start game.
Expected:
Wallet, target, day, phase, time, and trust are all readable.
No label overlaps another label.
```

#### HUD-02 — Gooby Trust Update

```text
Give item to Gooby.
Expected:
Gooby Trust changes from 0/100 to 20/100.
HUD does not overlap after update.
```

#### HUD-03 — Target Achieved

```text
Reach 50/50 revenue.
Expected:
Target achieved text is readable and does not collide with trust label.
```

### AI Agent Prompt

```text
Analisa dan implementasikan Task 2 — Polish HUD Layout and Trust Display dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Fokus memperbaiki layout HUD yang sudah ada.
- Gooby Trust tidak boleh menimpa Wallet, Target, Day, Phase, atau Time.
- Jangan pindahkan gameplay logic ke HUD.
- Cek file HUD terkait dulu sebelum edit.

Expected output:
- File yang dicek.
- Penyebab overlap.
- Perubahan layout yang dibuat.
- Test HUD default.
- Test Gooby Trust update.
- Test target achieved.
```

---

## 7. Task 3 — Polish Player Navigation and Objective Guidance

### Goal

Make the player understand where to go and what to do next, especially when a new item, shelf, or activity becomes relevant.

This is polish because it explains existing actions. It should not create a new progression system.

### Current Problem

A new player may not know:

```text
- Where to take stock from.
- Which shelf should receive which item.
- When customers can come.
- What to do when ghost shelf / Phantom Ice Cream appears.
- What board or instruction source should be checked.
- What activity is currently expected.
```

### Allowed Guidance Types

Allowed:

```text
- Short objective text in HUD.
- Notification when a new activity becomes available.
- A simple board / sign that lists current available actions.
- Object interaction hint.
- One-line instruction after important discovery.
```

Not allowed:

```text
- Full quest system.
- Complex quest tracking with multiple quest states.
- New reward mechanics.
- New map navigation system.
- Large tutorial cutscene.
```

### Recommended Temporary Objective Flow

```text
Morning:
Objective: Bring the human shelf from storage.

After human shelf placed:
Objective: Stock the human shelf with normal items.

After enough human stock:
Objective: Check the storage corner.

After ghost shelf discovered:
Objective: Place the ghost shelf and stock Phantom Ice Cream.

After ghost shelf stocked:
Objective: Open the store and wait for night customers.

At night:
Objective: Serve Gooby at the cashier.

After refusing Gooby:
Objective: Wait for the next strange customer.
```

### Checklist

- [x] Player gets a clear initial objective.
- [x] Objective changes after shelf placement.
- [x] Objective changes after stock placement.
- [x] Objective changes after mystery / ghost shelf discovery.
- [x] Objective tells player what to do with Phantom Ice Cream.
- [x] Objective tells player to serve Gooby at night.
- [x] Objective or notification explains what happens after refusing Gooby.
- [x] Objective text is short enough for 480x270 viewport.
- [x] Objective UI does not overlap existing HUD.
- [x] Objective guidance does not add new mechanics.

### Implementation notes

- Added a compact HUD `ObjectiveLabel` for current Day 1 guidance.
- Store updates the objective from existing state only: human shelf setup, human stock, mystery corner, ghost shelf, Phantom Ice Cream, night cashier service, and Gooby refusal consequence.
- Cashier notifies Store after Gooby refusal only to update guidance text; Slime spawning and item return logic remain unchanged.
- Objective text is clipped/ellipsized in a bottom-center HUD region away from wallet, target, time, trust, and notification text.

### Test Cases

#### NAV-01 — First Objective

```text
Start Day 1.
Expected:
Player receives clear direction to bring human shelf from storage.
```

#### NAV-02 — Stocking Objective

```text
Place human shelf in store.
Expected:
Objective changes to stock the human shelf.
```

#### NAV-03 — Ghost Item Objective

```text
Unlock / discover ghost shelf flow.
Expected:
Objective explains what to do with the ghost shelf or Phantom Ice Cream.
```

#### NAV-04 — Night Objective

```text
Night starts with ghost shelf ready.
Expected:
Objective explains that strange customers may arrive and player should use cashier.
```

### AI Agent Prompt

```text
Analisa dan implementasikan Task 3 — Polish Player Navigation and Objective Guidance dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Jangan buat quest system kompleks.
- Fokus objective/hint untuk existing core loop.
- Pastikan text tidak menimpa HUD lain.
- Cek Store, HUD, dan notification flow sebelum edit.

Expected output:
- File yang dicek.
- Titik gameplay yang belum punya arahan.
- Objective/hint yang ditambahkan.
- Test tiap perubahan objective.
- Risiko overlap UI.
```

---

## 8. Task 4 — Polish Activity Board / Action Guidance

### Goal

Add or polish a simple **activity board** / **shop board** / **instruction board** that helps the player know available actions.

This is optional if objective HUD is already enough, but it is useful if the player needs a stable place to check what to do.

### Design Purpose

The board should answer:

```text
What can I do right now?
Where should I go next?
What item or shelf is relevant now?
```

### Recommended Board Content

The board should show short, current-action text such as:

```text
Today's Work
- Bring shelf from storage
- Stock human shelf
- Serve customers at cashier
```

After ghost flow begins:

```text
Strange Notes
- Check the dark storage corner
- Place the ghost shelf
- Stock Phantom Ice Cream
- Watch the store at night
```

During Gooby branch:

```text
Night Choice
- Give item: Trust +, Revenue 0G
- Refuse sale: Item returns, another customer may come
```

### Implementation Boundary

Allowed:

```text
- A simple interactable board.
- A simple panel with static or state-based text.
- Reuse existing notification/objective state.
```

Not allowed:

```text
- New quest reward system.
- New task completion economy.
- New unlock system.
- Complex journal UI.
```

### Checklist

- [x] Board exists or current guidance alternative is documented.
- [x] Board explains current activity clearly.
- [x] Board text updates at major existing milestones if implemented.
- [x] Board does not introduce new gameplay requirements.
- [x] Board UI can be closed safely.
- [x] Board does not permanently lock input.
- [x] Board does not conflict with cashier UI.
- [x] Board can be replaced with final board sprite later.

Implementation notes:

- Added a simple interactable `ActivityBoard` in the store.
- Board guidance reads existing store state only; it does not create rewards, unlocks, or task completion logic.
- Board text covers current existing milestones: human shelf setup, human shelf stock, dark storage corner, ghost shelf setup, Phantom Ice Cream stocking, cashier service, and night Gooby choice.
- Board panel uses a temporary UI layer and releases player action lock when closed.
- Board scene structure uses `VisualRoot/PlaceholderRect` so the visual can later be replaced by a final board sprite.

### Test Cases

#### BOARD-01 — Open Board

```text
Interact with board.
Expected:
Board panel opens and shows current guidance.
```

#### BOARD-02 — Close Board

```text
Close board panel.
Expected:
Player control returns normally.
```

#### BOARD-03 — Updated Guidance

```text
Reach ghost shelf / Gooby flow.
Expected:
Board text reflects the current existing activity.
```

### AI Agent Prompt

```text
Analisa Task 4 — Polish Activity Board / Action Guidance dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan edit file dulu.
- Jangan tambah mechanic baru.
- Tentukan apakah objective HUD sudah cukup atau perlu simple board.
- Jika board perlu dibuat, rancang implementasi kecil yang tidak menjadi quest system kompleks.

Expected output:
- Apakah board diperlukan sekarang.
- File/scene yang akan terdampak.
- Rencana UI board sederhana.
- Risiko scope creep.
- Test case yang perlu dijalankan.
```

---

## 9. Task 5 — Polish NPC Flow

### Goal

Make NPC flow understandable from entrance to exit.

Expected NPC state flow:

```text
ENTER
→ WALK_TO_SHELF
→ SEARCH_ITEM
→ TAKE_ITEM
→ WAIT_IN_QUEUE
→ CHECKOUT
→ EXIT
```

### Checklist

- [x] NPC spawns at entrance.
- [x] NPC walks to the correct shelf type.
- [x] NPC does not exit without clear reason.
- [x] NPC pauses/searches briefly at shelf.
- [x] NPC takes item if available.
- [x] NPC gives dialogue if item is missing.
- [x] NPC joins queue after taking item.
- [x] NPC only enters checkout when first in queue.
- [x] NPC exits after checkout outcome is resolved.
- [x] NPC does not remain in queue after leaving.
- [x] Story NPC outcome can differ from normal purchase outcome.
- [x] Gooby and Slime still follow readable NPC movement flow.

### Implementation notes

- NPCs now pause briefly at the shelf before switching from search to item pickup, so the shelf interaction reads clearly.
- If a requested item disappears before pickup, the NPC shows a short reason before exiting.
- NPC queue cleanup now runs when an NPC enters `EXIT` and when it leaves the tree, preventing stale queue entries.
- Existing state flow is preserved; no new NPC states or purchase mechanics were added.

### AI Agent Rule

```text
Avoid adding new states unless required to fix a bug.
Prefer clearer helper methods over large state rewrites.
```

---

## 10. Task 6 — Polish Cashier / Checkout Flow

### Goal

Make checkout behavior clear for normal NPCs and story NPCs.

Normal customer flow:

```text
NPC waits at cashier
→ Player scans requested item
→ Player confirms scan
→ Player receives payment
→ Revenue increases
→ NPC exits
```

### Checklist

- [x] Cashier only processes a valid checkout NPC.
- [x] Cashier tells player if no customer is waiting.
- [x] Cashier tells player if customer is still walking.
- [x] Scan mismatch gives clear feedback.
- [x] Correct scan leads to checkout resolution.
- [x] Normal paid checkout increases daily revenue.
- [x] Gooby checkout uses Gooby choice panel instead of normal payment.
- [x] Checkout UI does not leave player action locked.
- [x] Checkout state resets after payment, gift, refusal, or cancel.
- [x] Repeated Enter/interact input does not accidentally choose a Gooby branch.

### Implementation notes

- Cashier now only scans the front NPC in the queue when that NPC is already in `CHECKOUT`.
- If the front queued NPC is still walking, cashier keeps the existing “Customer is still walking to the counter.” feedback.
- Normal paid checkout, Gooby gift, Gooby refusal, cancel, and customer-left outcomes clear scan state and release the HUD action lock.
- Enter/interact on the Gooby choice panel only repeats instruction text; the branch still requires pressing a visible choice button.

### AI Agent Rule

```text
Do not turn cashier into a new minigame.
Polish only the current scan-confirm-outcome flow.
```

---

## 11. Task 7 — Polish Shelf and Item Flow

### Goal

Make shelf logic stable for both player and NPC.

### Checklist

- [x] Player can place valid item on matching shelf type.
- [x] Wrong shelf placement gives clear feedback.
- [x] Shelf slot limit is respected.
- [x] Item leaves inventory when placed on shelf.
- [x] Item leaves shelf when taken by NPC.
- [x] Item can return to shelf when a checkout is rejected.
- [x] Returned Phantom Ice Cream can be found by Slime.
- [x] No item duplication happens after Gooby refusal.
- [x] No item loss happens after Gooby gift.
- [x] Shelf visual placeholder is separated from collision and interaction shape.
- [x] Shelf node structure is ready for Aseprite sprite replacement.

### Implementation Notes

- `Shelf.place_item()` validates item type and free slot before removing the item from inventory.
- `Shelf.take_item_for_npc()` removes item stock from the shelf without returning it to player inventory.
- Checkout refusal returns NPC cart items through `Shelf.stock_item_direct()`, while Gooby gift clears the cart after the item is accepted.
- Shelf slot reads now guard invalid slot indexes so player, NPC, and shelf controller checks do not crash if slot counts or asset nodes change during polish.
- Store shelf drop now rejects no-drop zones around storage door, yard door, cashier/counter, blocked collision, and unreachable shelf interaction positions.
- If the first drop position is unsafe, the store tries existing fallback positions; if no safe position exists, the player keeps carrying the shelf and receives feedback.
- Installed shelves can be picked up again with `F`; carried shelves are removed from the active shelf group until placed back down so NPCs do not path to a shelf being carried.
- Shelf visuals remain under `VisualRoot`, separate from interaction area, collision body, and slot nodes for later Aseprite sprite replacement.

### AI Agent Rule

```text
Do not add new shelf types for Day 1.
Focus on existing human shelf and ghost shelf behavior.
```

---

## 12. Task 8 — Polish Feedback and Notifications

### Goal

Player should always understand what changed and why.

### Checklist

- [x] Notification appears when item is picked up.
- [x] Notification appears when item is placed on shelf.
- [x] Notification appears when item is incompatible with shelf.
- [x] Notification appears when cashier has no valid customer.
- [x] Notification appears when scan mismatch happens.
- [x] Notification appears when Gooby cannot pay.
- [x] Notification appears when Gooby trust increases.
- [x] Notification appears when refusing Gooby triggers the next consequence.
- [x] Notification duration is readable.
- [x] Notification does not permanently block input.
- [x] Notification does not cover critical cashier choices.
- [x] Notification does not overlap objective text or trust label.

Suggested text examples:

```text
Gooby Trust +20 | No revenue gained.
Refused Gooby. Trust +20. The item returns to the shelf... something else is coming.
Daily target achieved.
```

### Implementation notes

- Existing pickup, shelf placement, incompatible shelf, cashier, scan mismatch, Gooby gift, and Gooby refusal notifications were validated in code.
- First pickup of each item now explains what the item is for and which input to use for shelf stocking or shelf item pickup.
- Notification placement now uses a fixed centered HUD region below the top status labels so it avoids trust/objective text and critical cashier choices.
- Notification duration now has a readable minimum and scales up for longer text.
- Notification skip input no longer consumes clicks while cashier or activity board overlays are open.

---

## 13. Task 9 — Review Core Loop

### Goal

Review the full playable loop after the focused polish tasks are done.

### Checklist

- [x] Player can start Day 1 and understand first action.
- [x] Player can bring shelf from storage.
- [x] Player can stock human shelf.
- [x] Human customers can buy items.
- [x] Ghost shelf / mystery flow can be reached.
- [x] Gooby arrives at night.
- [x] Gooby gift path works.
- [x] Gooby refuse → Slime path works.
- [x] Daily target can be missed or achieved depending on branch.
- [x] HUD remains readable throughout the flow.
- [x] Player never loses control due to stuck UI state.

### Review Notes

- Day 1 starts with intro/objective guidance pointing the player to storage and the human shelf.
- Storage shelf carry, store shelf placement, human stock placement, and mystery unlock use existing shelf, inventory, and storage state only.
- Customer spawning remains locked until the ghost shelf has stock; Day 1 night spawns Gooby through `NPCScheduler`.
- Gooby gift adds trust and 0G revenue; Gooby refusal returns Phantom Ice Cream, requests the guarded Slime customer, and keeps the revenue branch available.
- Daily target outcome remains branch-dependent: gift path can miss target, while refusal plus Slime can still add normal checkout revenue.
- HUD lock, notification skip handling, cashier cancel/reset, and activity board close paths were reviewed for stuck input risk.

### Remaining Risk

- Full branch timing still needs manual playtest because NPC spawning depends on the current phase when the ghost shelf becomes ready.
- Godot smoke validation confirms startup, but it does not simulate player carry, scan selection, or the full night transaction.

### AI Agent Prompt

```text
Review Task 9 — Review Core Loop dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan edit file dulu.
- Jangan tambah mechanic baru.
- Jalankan review berdasarkan mechanic yang sudah ada.
- Fokus menemukan friction point, UI overlap, atau bug.

Expected output:
- Status core loop dari awal sampai transaksi malam.
- Bagian yang sudah stabil.
- Bagian yang masih rawan.
- Rekomendasi task kecil berikutnya.
```

---

## 14. Task 10 — Prepare Asset-Ready Node Structure

### Goal

Prepare scenes so placeholder visuals can be swapped with Aseprite assets later without breaking mechanics.

### Checklist

- [x] Visual nodes are separated from logic nodes.
- [x] Placeholder visuals are grouped under a stable visual root where possible.
- [x] Collision shapes do not depend directly on placeholder size.
- [x] Interaction areas remain stable when sprite changes.
- [x] Scene node names are stable.
- [x] Script does not depend directly on `ColorRect` for gameplay logic.
- [x] `Sprite2D` or `AnimatedSprite2D` replacement path is clear.
- [x] Temporary UI / board / HUD layout can later be replaced by final UI assets.

### Implementation notes

- Added stable `AssetSprite` nodes under `VisualRoot` for player, shelf, supply box, NPC, cashier, and activity board visuals.
- Existing `PlaceholderRect` nodes remain active as temporary visuals, so the current playable loop still renders the same placeholders.
- Shelf, mystery box, and NPC visual tint code now falls back to `VisualRoot/AssetSprite` when placeholder rectangles are replaced.
- Collision and interaction nodes remain outside `VisualRoot`, so future sprite size changes do not move gameplay shapes.
- Storage inherited scene overrides were updated to keep `PlaceholderRect` targeting stable after adding `AssetSprite`.

Recommended pattern:

```text
NPC
├── VisualRoot
│   ├── PlaceholderRect
│   └── AnimatedSprite2D
├── NameLabel
├── DialogBubble
├── CollisionShape2D
└── InteractionArea
```

### AI Agent Rule

```text
Do not replace final assets yet.
Prepare the structure so replacement is easy later.
```

---

## 15. Task 11 — Documentation Update

### Goal

Keep this file useful as an AI Agent task spec.

### Checklist

- [x] Mark tasks as done / partially done / pending when appropriate.
- [x] Add discovered bugs to the relevant task section.
- [x] Add new test cases if playtest reveals missing cases.
- [x] Remove or rewrite tasks that are already fully completed.
- [x] Keep Day 1 scope focused on polish, not feature expansion.

### Documentation Notes

- Top-level polish status was updated so it no longer describes already-fixed HUD overlap and missing guidance as current issues.
- Task status is now summarized near the recommended execution order.
- No new bugs were found during the latest code-level review; the remaining risk is documented under Task 9 as manual full-loop playtest coverage.
- No new test cases were added because no new playtest-only missing case was discovered in this documentation pass.
- Completed task sections are retained as an audit trail, with their checklists and implementation/review notes updated instead of deleting historical context.

### AI Agent Prompt

```text
Update Task 11 — Documentation Update dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan ubah mechanic.
- Update dokumentasi berdasarkan hasil validasi terakhir.
- Tandai task yang sudah done, partially done, dan pending.
- Tambahkan catatan bug/follow-up jika ada.
```

---

## 16. Definition of Done — Day 1

Day 1 can be considered done when:

- [x] No new major mechanic was added.
- [x] Core shop loop can be played from setup to checkout.
- [x] Gooby gift path works and gives trust without revenue.
- [x] Gooby refuse path works and enables Slime revenue path.
- [x] Trust label does not overlap HUD.
- [x] Player has clear objective guidance for current activity.
- [x] New item / ghost item activity is explained through objective, notification, or board.
- [x] NPC flow is stable enough for playtest.
- [x] Cashier UI cleans up after each checkout outcome.
- [x] Shelf/item flow does not duplicate or lose items incorrectly.
- [x] Temporary UI is readable at 480x270.
- [x] Project remains ready for Aseprite asset integration.

### Validation notes

- Day 1 polish stayed within existing mechanics: setup, shelf stocking, NPC shopping, cashier checkout, Gooby gift/refuse, Slime consequence, HUD, notifications, activity guidance, and asset-ready node structure.
- Gooby gift uses the story gift path, adds trust, records 0G, clears cashier state, and does not request Slime.
- Gooby refusal returns Phantom Ice Cream to the ghost shelf, clears cashier state, and requests the guarded one-time Slime consequence.
- Cashier outcomes call `_clear_scan()` / `_hide_cashier_panel()` and unlock player actions through the existing HUD action lock.
- Shelf item movement uses `place_item`, `take_item_for_npc`, `stock_item_direct`, and cart clearing to avoid duplicate/lost item state in the Gooby branch.
- HUD and temporary UI use stable containers and asset-ready visual roots; final Aseprite sprites can replace `AssetSprite` / placeholder visuals later.
- Code-level validation and Godot smoke loading passed; a manual full playthrough is still recommended before treating this as release-ready QA.

---

## 17. Suggested Trello / Branch Naming

Trello activities:

```text
validate_gooby_night_choice_day_1
polish_hud_trust_layout_day_1
polish_player_navigation_objective_day_1
polish_activity_board_guidance_day_1
polish_npc_flow_day_1
polish_cashier_flow_day_1
polish_shelf_item_flow_day_1
review_core_loop_day_1
prepare_asset_ready_node_structure_day_1
```

Branch:

```text
polish/day-1-mechanic-polish
```

Suggested commit messages:

```text
docs: expand day 1 mechanic polish tasks
fix: prevent trust hud overlap
feat: add lightweight objective guidance for existing loop
chore: document Gooby night choice validation
refactor: prepare placeholder visuals for asset integration
```
