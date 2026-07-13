# Crossroad Market — Day 1 Mechanic Polish

## 1. Purpose

Day 1 focuses on **mechanic polish without final art assets**. The project may still use placeholder visuals such as `ColorRect`, simple shapes, or temporary sprites. The goal is not to add new major mechanics, but to make the existing mechanics more stable, readable, testable, and ready for future Aseprite asset integration.

Main rule:

```text
Do not add major new mechanics.
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

Recent playtest notes show several implementation mismatches that must be treated as **revision tasks**, not as completed polish:

```text
- Interaction hint appears after pressing the button, but it should appear before the button is pressed.
- Objective text exists, but its purpose and source must be clarified because it behaves like HUD guidance.
- Item/object hover should show the item/object name.
- Shelf pickup after placement is still awkward, especially for ghost shelf / storage flow.
- Trust should not live as player HUD state; trust should be shown above each relevant NPC.
```

---

## 3. Scope

### 3.1 In Scope

The following work is allowed:

- Stabilize existing player interaction.
- Stabilize existing NPC state flow.
- Improve shelf placement, pickup, and shelf item feedback.
- Improve cashier scan and checkout clarity.
- Improve notification and dialogue feedback.
- Improve Gooby night choice logic.
- Improve trust/revenue feedback for Gooby.
- Fix temporary HUD layout issues, including overlapping labels.
- Add or improve lightweight interaction hints using existing mechanics.
- Add or improve lightweight objective guidance using existing mechanics.
- Add or improve a simple activity / task board if it only explains existing actions.
- Add hover/name labels for existing objects and items.
- Move NPC trust display to NPC world-space UI.
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

Recommended revised order:

```text
Task 1  — Validate Gooby Night Choice
Task 2  — Revise Interaction Prompt Timing
Task 3  — Audit Objective HUD Guidance
Task 4  — Add Hover / Object Name Feedback
Task 5  — Polish Shelf Pickup Reachability
Task 6  — Move Trust Display to NPC World UI
Task 7  — Polish Activity Board / Action Guidance
Task 8  — Polish NPC Flow
Task 9  — Polish Cashier Flow
Task 10 — Polish Shelf and Item Flow
Task 11 — Polish Feedback and Notifications
Task 12 — Review Core Loop
Task 13 — Prepare Asset-Ready Node Structure
Task 14 — Documentation Update
```

Current task status:

```text
Task 1  — Implemented, needs validation
Task 2  — Pending revision
Task 3  — Pending audit / possible revision
Task 4  — Pending
Task 5  — Pending revision
Task 6  — Pending revision
Task 7  — Implemented, needs validation
Task 8  — Implemented, needs validation
Task 9  — Implemented, needs validation
Task 10 — Implemented, needs validation
Task 11 — Implemented, needs validation
Task 12 — Pending manual full-loop playtest
Task 13 — Implemented, needs validation
Task 14 — Ongoing
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
Gooby Trust increases
Story relationship path improves
Daily target remains missed unless another revenue source exists
```

Checklist:

- [ ] Gooby gift option is visible in cashier UI.
- [ ] Gift option does not add gold.
- [ ] Gift option does not add daily revenue.
- [ ] Gift option increases Gooby trust.
- [ ] Gift option consumes the item.
- [ ] Gooby exits after receiving gift.
- [ ] Slime does not spawn after gift.
- [ ] Notification explains `+Trust` and `+0G` clearly.
- [ ] Trust display appears above Gooby or relevant NPC, not as permanent player HUD.

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
Gooby trust behavior follows the agreed story rule
```

Checklist:

- [ ] Refuse option is visible in cashier UI.
- [ ] Refuse option does not add gold directly from Gooby.
- [ ] Refuse option returns item to ghost shelf.
- [ ] Gooby exits after refusal.
- [ ] Slime spawns only once.
- [ ] Slime can find Phantom Ice Cream after it returns to shelf.
- [ ] Slime purchase adds revenue normally.
- [ ] Target can become `50G / 50G TARGET ACHIEVED`.
- [ ] Notification explains that another customer is coming.

### AI Agent Prompt

```text
Validate Task 1 — Gooby Night Choice from docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Jangan edit file kecuali bug ditemukan.
- Fokus existing Gooby gift/refuse flow.
- Pastikan revenue dan trust tetap reward path terpisah.
- Pastikan trust display tidak menjadi permanent player HUD state.

Expected output:
- File yang dicek.
- Status Give Item.
- Status Refuse Sale.
- Status Slime path.
- Status trust display.
- Bug yang ditemukan.
```

---

## 6. Task 2 — Revise Interaction Prompt Timing

### Goal

Fix player interaction guidance so prompts appear **before** the player presses the action key, not after.

The intended behavior is:

```text
Player enters object InteractionArea / CollisionShape2D
→ Prompt appears immediately
→ Prompt says object name and available action
→ Player presses the required button
→ Action happens
```

This task fixes the current mismatch where some hints are shown only after the player presses `F` or another input.

### Design Requirements

Interaction prompts must explain:

```text
- What object this is.
- What button to press.
- What the button will do.
```

Examples:

```text
Human Shelf
Press F to pick up shelf.

Ghost Shelf
Press F to pick up shelf.

Supply Box
Press E to take stock.

Human Shelf Slot
Press E to place item.
Press Q to take item from shelf.

Cashier
Press E to serve customer.

Activity Board
Press E to read board.
```

### One-Time Rule for New Items

For every new item/object/activity, the tutorial-style prompt should run only once per object type or item type.

Expected behavior:

```text
First time player enters bread interaction context:
Show explanation for bread.

Second time player enters bread interaction context:
Show only compact action prompt, or no tutorial explanation.
```

This avoids looping tutorial text.

### Checklist

- [ ] Prompt appears when player enters interaction area.
- [ ] Prompt appears before button press.
- [ ] Prompt identifies the object or item name.
- [ ] Prompt explains the correct input.
- [ ] Prompt disappears when player leaves the interaction area.
- [ ] Prompt does not permanently block player input.
- [ ] Tutorial explanation runs once per item/object type.
- [ ] Compact action prompt can repeat if needed.
- [ ] Prompt works for shelf, supply box, cashier, activity board, ghost shelf, and items.
- [ ] Prompt does not overlap cashier modal / board modal.

### Suggested Implementation Direction

Prefer a lightweight interaction hint system:

```text
InteractionHintController / HUD hint label
```

or an existing HUD method such as:

```text
show_interaction_hint(text)
hide_interaction_hint()
show_once_tutorial_hint(key, text)
```

Do not use normal notification for all interaction prompts if notification blocks action or has long timing. Interaction hints should be lighter than story notifications.

### Test Cases

#### HINT-01 — Shelf Pickup Prompt

```text
Move player into shelf interaction area.
Expected:
Prompt appears before pressing F.
Text explains shelf name and pickup input.
```

#### HINT-02 — One-Time Item Tutorial

```text
Encounter Phantom Ice Cream for the first time.
Expected:
Tutorial explanation appears once.
Leave and re-enter area.
Expected:
Tutorial explanation does not loop.
```

#### HINT-03 — Cashier Prompt

```text
Move player near cashier while customer is waiting.
Expected:
Prompt says Press E to serve customer.
```

### AI Agent Prompt

```text
Analisa dan implementasikan Task 2 — Revise Interaction Prompt Timing dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Fokus existing interaction flow.
- Prompt harus muncul saat player memasuki area interaksi, sebelum tombol ditekan.
- Tutorial explanation hanya muncul 1 kali per item/object/activity baru.
- Jangan gunakan notification blocking untuk prompt kecil jika itu membuat input terasa telat.
- Cek Player, HUD, Shelf, SupplyBox, Cashier, ActivityBoard, dan object interaction areas sebelum edit.

Expected output:
- Penyebab timing hint salah.
- File yang dicek.
- Perubahan yang dibuat.
- Test HINT-01, HINT-02, HINT-03.
```

---

## 7. Task 3 — Audit Objective HUD Guidance

### Goal

Clarify whether objective text should exist as part of HUD, activity board, or interaction hint.

The current question:

```text
Teks objective itu bagian dari HUD-nya datang dari mana?
```

This must be audited because objective guidance can be useful, but it must not become a confusing extra system.

### Expected Decision

Objective text is allowed only if it acts as lightweight guidance for the existing loop.

Allowed:

```text
Objective: Bring the human shelf from storage.
Objective: Stock the ghost shelf with Phantom Ice Cream.
Objective: Serve Gooby at the cashier.
```

Not allowed:

```text
Complex quest list
Quest rewards
Quest completion system
Quest journal progression
```

### Design Options

Option A — Keep objective in HUD:

```text
Use small bottom-center objective text.
Only show the next immediate action.
```

Option B — Move objective into Activity Board:

```text
HUD stays clean.
Player checks board for guidance.
```

Option C — Use contextual hints only:

```text
No persistent objective.
Prompt appears near relevant object.
```

Recommended direction for Day 1:

```text
Use contextual interaction hints as primary guidance.
Keep HUD objective only if it is short, non-overlapping, and clearly useful.
Activity Board can serve as optional backup guidance.
```

### Checklist

- [ ] Identify where objective text is created.
- [ ] Identify which file updates the objective text.
- [ ] Confirm whether objective belongs in HUD or board.
- [ ] Ensure objective does not overlap HUD labels.
- [ ] Ensure objective does not duplicate interaction hints too much.
- [ ] If retained, objective should be one-line only.
- [ ] If removed, board/hints must still guide the player.

### AI Agent Prompt

```text
Analisa Task 3 — Audit Objective HUD Guidance dari docs/polish/day-1-mechanic-polish.md.

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

## 8. Task 4 — Add Hover / Object Name Feedback

### Goal

When player hovers or enters interaction range of an item/object, the game should show the name of that item/object.

This is polish because it helps player understand what they are looking at without adding a new mechanic.

### Expected Behavior

```text
Player enters item/object hover area
→ Name label appears
→ Optional action prompt appears
→ Player leaves area
→ Name label disappears
```

Examples:

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

### Important Distinction

Hover/name feedback is not the same as tutorial prompt.

```text
Hover name: can appear repeatedly.
Tutorial explanation: should appear once per item/object type.
```

### Checklist

- [ ] Hover or proximity label shows object name.
- [ ] Label appears before interaction button is pressed.
- [ ] Label disappears when player leaves range.
- [ ] Label does not block player action.
- [ ] Label works for items, shelves, cashier, board, and supply boxes.
- [ ] Label does not overlap major HUD elements.
- [ ] Label can later be restyled with final UI assets.

### Test Cases

#### HOVER-01 — Item Name

```text
Move near item/stock.
Expected:
Item name appears before pressing any button.
```

#### HOVER-02 — Shelf Name

```text
Move near human shelf or ghost shelf.
Expected:
Shelf name appears.
```

#### HOVER-03 — Cashier Name

```text
Move near cashier.
Expected:
Cashier label or prompt appears.
```

### AI Agent Prompt

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
- Test HOVER-01, HOVER-02, HOVER-03.
```

---

## 9. Task 5 — Polish Shelf Pickup Reachability

### Goal

Fix shelf pickup and shelf placement usability, especially after player places shelf in the store and needs to go back to retrieve the ghost shelf.

Current playtest issue:

```text
After putting a shelf in the store, player must touch a very specific CollisionShape2D area to pick up / interact again.
This feels too strict and can make shelf pickup confusing.
```

### Design Requirement

Shelf pickup should be easier than exact collision contact.

Allowed polish:

```text
- Increase shelf pickup / interaction area.
- Use a larger shadow-like interaction area.
- Keep actual physical collision smaller.
- Use a separate InteractionArea from CollisionShape2D.
```

Recommended temporary size:

```text
Use a larger interaction area, approximately the previous shadow / half-room guidance area, but do not make it so large that it triggers from across unrelated spaces.
```

### Important Distinction

```text
CollisionShape2D = physical blocking / body collision.
InteractionArea = detection for prompt and pickup.
```

Do not make the physical collision huge just to make pickup easier. Expand the interaction area, not necessarily the physics collision.

### Checklist

- [ ] Shelf can still be physically blocked by its normal collision.
- [ ] Shelf pickup detection uses larger reachable interaction area.
- [ ] Prompt appears before pickup input.
- [ ] Player can pick shelf up again after placing it in the store.
- [ ] Player can continue ghost shelf flow without touching a tiny exact collision shape.
- [ ] Enlarged area does not conflict with cashier, door, or activity board interaction.
- [ ] Shelf still cannot be placed in invalid no-drop zones.
- [ ] Shelf interaction remains asset-ready for Aseprite sprite replacement.

### Test Cases

#### SHELF-PICKUP-01 — Human Shelf After Placement

```text
Place human shelf in store.
Move near shelf but not directly touching physical body.
Expected:
Pickup prompt appears and shelf can be picked up with F.
```

#### SHELF-PICKUP-02 — Ghost Shelf Retrieval

```text
After human shelf setup, return to get ghost shelf.
Move near ghost shelf interaction range.
Expected:
Prompt appears before pressing F and pickup works reliably.
```

#### SHELF-PICKUP-03 — Door Conflict

```text
Move near shelf and storage door at the same time.
Expected:
Interaction priority remains predictable.
Player does not accidentally trigger the wrong action without clear prompt.
```

### AI Agent Prompt

```text
Analisa dan implementasikan Task 5 — Polish Shelf Pickup Reachability dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Jangan memperbesar physics collision secara asal.
- Fokus pisahkan CollisionShape2D fisik dan InteractionArea untuk pickup.
- InteractionArea shelf boleh diperbesar agar pickup lebih mudah.
- Pastikan prompt muncul sebelum menekan F.
- Pastikan tidak konflik dengan StorageDoor, Cashier, atau ActivityBoard.

Expected output:
- File/scene yang dicek.
- Penyebab shelf sulit diambil.
- Perubahan InteractionArea yang dibuat.
- Test SHELF-PICKUP-01, 02, 03.
```

---

## 10. Task 6 — Move Trust Display to NPC World UI

### Goal

Fix the trust display concept. Trust is not a permanent player HUD score. Trust belongs to the relevant NPC and should be displayed near / above the NPC when relevant.

Current mismatch:

```text
Trust was shown in HUD as if it were player status.
Expected: trust bar / trust label appears above each NPC or story NPC.
```

### Expected Behavior

For story NPCs such as Gooby:

```text
Gooby appears
→ Gooby has name label and/or trust bar above NPC
→ After Give Item / relevant story interaction, Gooby trust value updates
→ Trust feedback appears near Gooby or as short notification
```

Temporary display is allowed:

```text
Gooby
Trust: 20/100
```

Later final art can replace it with a proper bar.

### Design Requirements

- Trust display should be world-space UI attached to NPC scene.
- Trust display should follow the NPC as it moves.
- Trust display should not overlap the player HUD.
- Trust display should be visible only for relevant story NPCs or when trust is relevant.
- Trust value should still be stored in `RelationshipManager` or equivalent manager.
- HUD should not own trust as a permanent player stat.

### Checklist

- [ ] Remove permanent Gooby Trust label from player HUD, or hide it if replaced by NPC trust bar.
- [ ] Add trust label/bar above Gooby or story NPC visual root.
- [ ] Trust label follows NPC movement.
- [ ] Trust updates after Gooby interaction.
- [ ] Trust display does not overlap cashier UI or notification UI.
- [ ] RelationshipManager remains the source of truth.
- [ ] Normal generic NPCs do not show unnecessary trust bars.
- [ ] Design remains asset-ready for future final UI sprite/bar.

### Test Cases

#### TRUST-01 — Gooby Trust Display

```text
Gooby enters store.
Expected:
Gooby has visible trust label/bar above NPC.
HUD does not show permanent Gooby Trust as player stat.
```

#### TRUST-02 — Trust Update

```text
Give item to Gooby.
Expected:
Trust value above Gooby updates.
Revenue remains 0G from Gooby.
```

#### TRUST-03 — Generic NPC

```text
Generic customer enters store.
Expected:
No unnecessary trust bar unless explicitly configured.
```

### AI Agent Prompt

```text
Analisa dan implementasikan Task 6 — Move Trust Display to NPC World UI dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah relationship system kompleks.
- RelationshipManager tetap boleh menjadi source of truth.
- Trust bukan permanent player HUD status.
- Trust harus tampil di atas NPC/story NPC yang relevan.
- Jangan merusak NameLabel/DialogBubble NPC.
- Pastikan Gooby trust update tetap jalan setelah gift/refuse flow.

Expected output:
- File yang dicek.
- Cara trust saat ini tampil di HUD.
- Perubahan untuk memindahkan trust ke NPC world UI.
- Test TRUST-01, TRUST-02, TRUST-03.
```

---

## 11. Task 7 — Polish Activity Board / Action Guidance

### Goal

Add or polish a simple **activity board** / **shop board** / **instruction board** that helps the player know available actions.

This is optional if contextual hints are already enough, but it is useful if the player needs a stable place to check what to do.

### Design Purpose

The board should answer:

```text
What can I do right now?
Where should I go next?
What item or shelf is relevant now?
```

### Recommended Board Content

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

### Checklist

- [ ] Board exists or current guidance alternative is documented.
- [ ] Board explains current activity clearly.
- [ ] Board text updates at major existing milestones if implemented.
- [ ] Board does not introduce new gameplay requirements.
- [ ] Board UI can be closed safely.
- [ ] Board does not permanently lock input.
- [ ] Board does not conflict with cashier UI.
- [ ] Board can be replaced with final board sprite later.

---

## 12. Task 8 — Polish NPC Flow

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

- [ ] NPC spawns at entrance.
- [ ] NPC walks to the correct shelf type.
- [ ] NPC does not exit without clear reason.
- [ ] NPC pauses/searches briefly at shelf.
- [ ] NPC takes item if available.
- [ ] NPC gives dialogue if item is missing.
- [ ] NPC joins queue after taking item.
- [ ] NPC only enters checkout when first in queue.
- [ ] NPC exits after checkout outcome is resolved.
- [ ] NPC does not remain in queue after leaving.
- [ ] Story NPC outcome can differ from normal purchase outcome.
- [ ] Gooby and Slime still follow readable NPC movement flow.

AI Agent rule:

```text
Avoid adding new states unless required to fix a bug.
Prefer clearer helper methods over large state rewrites.
```

---

## 13. Task 9 — Polish Cashier / Checkout Flow

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

- [ ] Cashier only processes a valid checkout NPC.
- [ ] Cashier tells player if no customer is waiting.
- [ ] Cashier tells player if customer is still walking.
- [ ] Scan mismatch gives clear feedback.
- [ ] Correct scan leads to checkout resolution.
- [ ] Normal paid checkout increases daily revenue.
- [ ] Gooby checkout uses Gooby choice panel instead of normal payment.
- [ ] Checkout UI does not leave player action locked.
- [ ] Checkout state resets after payment, gift, refusal, or cancel.
- [ ] Repeated Enter/interact input does not accidentally choose a Gooby branch.

AI Agent rule:

```text
Do not turn cashier into a new minigame.
Polish only the current scan-confirm-outcome flow.
```

---

## 14. Task 10 — Polish Shelf and Item Flow

### Goal

Make shelf logic stable for both player and NPC.

### Checklist

- [ ] Player can place valid item on matching shelf type.
- [ ] Wrong shelf placement gives clear feedback.
- [ ] Shelf slot limit is respected.
- [ ] Item leaves inventory when placed on shelf.
- [ ] Item leaves shelf when taken by NPC.
- [ ] Item can return to shelf when a checkout is rejected.
- [ ] Returned Phantom Ice Cream can be found by Slime.
- [ ] No item duplication happens after Gooby refusal.
- [ ] No item loss happens after Gooby gift.
- [ ] Shelf visual placeholder is separated from collision and interaction shape.
- [ ] Shelf node structure is ready for Aseprite sprite replacement.
- [ ] Shelf placement rejects no-drop zones around doors, cashier, and blocked navigation paths.
- [ ] If the first drop position is unsafe, fallback positions are tested.
- [ ] If all positions are unsafe, player keeps carrying the shelf and gets feedback.

AI Agent rule:

```text
Do not add new shelf types for Day 1.
Focus on existing human shelf and ghost shelf behavior.
```

---

## 15. Task 11 — Polish Feedback and Notifications

### Goal

Player should always understand what changed and why.

### Checklist

- [ ] Notification appears when item is picked up.
- [ ] Notification appears when item is placed on shelf.
- [ ] Notification appears when item is incompatible with shelf.
- [ ] Notification appears when cashier has no valid customer.
- [ ] Notification appears when scan mismatch happens.
- [ ] Notification appears when Gooby cannot pay.
- [ ] Notification appears when Gooby trust increases.
- [ ] Notification appears when refusing Gooby triggers the next consequence.
- [ ] Notification duration is readable.
- [ ] Notification does not permanently block input.
- [ ] Notification does not cover critical cashier choices.
- [ ] Notification does not overlap objective text or trust label.
- [ ] Small interaction prompts are not implemented as blocking long notifications.

Suggested text examples:

```text
Gooby Trust +20 | No revenue gained.
Refused Gooby. The item returns to the shelf... something else is coming.
Daily target achieved.
```

---

## 16. Task 12 — Review Core Loop

### Goal

Review the full playable loop after the focused polish tasks are done.

### Checklist

- [ ] Player can start Day 1 and understand first action.
- [ ] Player can bring shelf from storage.
- [ ] Player can stock human shelf.
- [ ] Human customers can buy items.
- [ ] Ghost shelf / mystery flow can be reached.
- [ ] Gooby arrives at night.
- [ ] Gooby gift path works.
- [ ] Gooby refuse → Slime path works.
- [ ] Daily target can be missed or achieved depending on branch.
- [ ] HUD remains readable throughout the flow.
- [ ] NPC trust bar does not overlap HUD.
- [ ] Player never loses control due to stuck UI state.
- [ ] Interaction prompts appear before input.
- [ ] Hover/object name feedback is readable.
- [ ] Shelf pickup remains reliable after placement.

### Remaining Risk

- Full branch timing still needs manual playtest because NPC spawning depends on the current phase when the ghost shelf becomes ready.
- Godot smoke validation confirms startup, but it does not simulate player carry, scan selection, or the full night transaction.

---

## 17. Task 13 — Prepare Asset-Ready Node Structure

### Goal

Prepare scenes so placeholder visuals can be swapped with Aseprite assets later without breaking mechanics.

### Checklist

- [ ] Visual nodes are separated from logic nodes.
- [ ] Placeholder visuals are grouped under a stable visual root where possible.
- [ ] Collision shapes do not depend directly on placeholder size.
- [ ] Interaction areas remain stable when sprite changes.
- [ ] Scene node names are stable.
- [ ] Script does not depend directly on `ColorRect` for gameplay logic.
- [ ] `Sprite2D` or `AnimatedSprite2D` replacement path is clear.
- [ ] Temporary UI / board / HUD layout can later be replaced by final UI assets.
- [ ] NPC trust world UI can later be replaced with final trust bar art.
- [ ] Interaction hint UI can later be replaced with final prompt art.

Recommended pattern:

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

AI Agent rule:

```text
Do not replace final assets yet.
Prepare the structure so replacement is easy later.
```

---

## 18. Task 14 — Documentation Update

### Goal

Keep this file useful as an AI Agent task spec.

### Checklist

- [ ] Mark tasks as done / partially done / pending when appropriate.
- [ ] Add discovered bugs to the relevant task section.
- [ ] Add new test cases if playtest reveals missing cases.
- [ ] Remove or rewrite tasks that are already fully completed.
- [ ] Keep Day 1 scope focused on polish, not feature expansion.
- [ ] Keep implementation notes aligned with actual behavior.

AI Agent prompt:

```text
Update Task 14 — Documentation Update dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan ubah mechanic.
- Update dokumentasi berdasarkan hasil validasi terakhir.
- Tandai task yang sudah done, partially done, dan pending.
- Tambahkan catatan bug/follow-up jika ada.
```

---

## 19. Definition of Done — Day 1

Day 1 can be considered done when:

- [ ] No new major mechanic was added.
- [ ] Core shop loop can be played from setup to checkout.
- [ ] Gooby gift path works and gives trust without revenue.
- [ ] Gooby refuse path works and enables Slime revenue path.
- [ ] Trust display appears on relevant NPC, not as permanent player HUD stat.
- [ ] Player has clear contextual interaction prompts before pressing input.
- [ ] New item / object tutorial prompt runs once per item/object type.
- [ ] Item/object hover name feedback works.
- [ ] Player can reliably pick up shelves after placement.
- [ ] Ghost shelf retrieval flow is clear and not dependent on tiny collision contact.
- [ ] Objective guidance source is understood and does not confuse HUD purpose.
- [ ] Activity board or contextual hints explain current activity.
- [ ] NPC flow is stable enough for playtest.
- [ ] Cashier UI cleans up after each checkout outcome.
- [ ] Shelf/item flow does not duplicate or lose items incorrectly.
- [ ] Temporary UI is readable at 480x270.
- [ ] Project remains ready for Aseprite asset integration.

---

## 20. Suggested Trello / Branch Naming

Trello activities:

```text
validate_gooby_night_choice_day_1
revise_interaction_prompt_timing_day_1
audit_objective_hud_guidance_day_1
add_hover_object_name_feedback_day_1
polish_shelf_pickup_reachability_day_1
move_trust_display_to_npc_world_ui_day_1
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
docs: revise day 1 polish task scope
fix: show interaction hints before input
feat: add object hover name feedback
fix: improve shelf pickup interaction range
refactor: move trust display to npc world ui
chore: audit objective guidance source
```
