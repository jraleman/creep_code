# Creep Code

**Beneath old stone, the stars still listen.**

A solo 3D puzzle ritual for the DeskCanSaw Godot 4.7 scaffold. **One persistent
stone stage transforms through six enchanted relics**, with a growing
constellation and no hub, room travel or walking commute.
Sliding window, binary search, breadth-first search, two pointers, union-find
and dynamic programming are all playable through physical mechanisms.
The stable game ID is `creep_code`.

## Play

From `godot-base`:

```powershell
godot --headless --path . --import
godot --path . -- --game=creep_code
```

The studio sting leads to a **15-second, skippable 3D opening** in a standalone
build, then the shared title screen and instructions. The opening awakens the
actual ritual stage using a demonstration manager that never touches saves.
All six mechanisms receive a short demonstration within those 15 seconds.
It inherits the regular intro's centered subtitle, skip button and progress
track, over a full-width 3D view. There is no narrative side panel.
The collection keeps its shared intro and discovers this game automatically.
An original astral-key icon brands the title screen; a matching ritual poster
appears in the picker and instructions. There is no prerecorded walkthrough.

| Default | Action |
| --- | --- |
| Click / tap the stage | Select crystals, listening seals, bridge sockets or stair choices; move through the garden or discard a warden endpoint |
| W / A / S / D | Adjust a relic, take a garden walkway, move wardens, browse/undo bridges or choose a stair stride |
| E | Arm / confirm; reveal echoes, lock a pair, connect a bridge, inscribe or climb; skip a flourish or close the grimoire |
| Q | Open / close the grimoire; reading freezes puzzle time and input |
| R | Retry for free; the garden keeps its echoes and the stair keeps its remembered plaques |
| H | Open the paused grimoire at the next inscription; repeat for another hint |
| Escape | Shared pause menu |

Every gameplay key is rebindable in the shared Controls tab. Labels use the
live bindings. The same actions have mouse/touch buttons. There is no free
walking or game-specific gamepad mapping in this
slice. No jumping, combat, precision aiming or physics stacking is required.
The stage uses the full available width at every aspect ratio. A compact,
unboxed action row sits below it, with precision direction buttons as an
alternative to tapping small objects. There is **no gameplay sidebar or
separate rune grid**. Click or tap the actual crystals, numbered listening
seals, garden platforms, endpoint pylons, bridge sockets and stair landings;
their floating numbers are targets too. Selecting a bridge or stair choice
never also confirms it. Tapping a warden endpoint discards that pylon, just
as tapping a neighboring garden platform moves the keeper.
The Sunrail keeps an untimed preview,
the shaft arrives ready to listen and the garden sends its first pulse
automatically. The three later relics arrive ready to play, without an arming
step or a deadline. Rules, hints and permanent-seal totals appear only in the
on-demand, paused grimoire.

After a solve, its keystone rises into the constellation, the mechanism folds
away and the next relic unfolds on the **same** platform. No confirmation or
travel menu is required. E can skip each presentation phase, but a skip never
also arms or probes the next puzzle. The final constellation automatically
leads into the shared results. Pause freezes the entire handoff as well as play.
Only retries or a new ritual reset attempts. Unfinished attempts last for the
current visit; restored seals also survive closing the game.

## Time, charges and points

| Readout | Meaning |
| --- | --- |
| Points (max 6) | One point per **different** relic solved during this visit. Repeating the same relic adds nothing. |
| Star Shards | Persistent outfit-store currency. A finished ritual banks one shard per visit point, up to six. Spending shards never changes a score. |
| Permanent seals | Saved progress, separate from this visit's points and the current constellation. An incomplete save resumes at its first missing seal; a complete save starts a fresh full ritual. |
| Sunrail time left | 90 seconds, starting only when armed. Preview, flourishes and reading the grimoire spend no time. Shared pause and the grimoire freeze the exact remaining budget. |
| Listens left | The shaft's remaining questions, **not seconds**. Selecting a floor is free; listening spends one charge. |
| Steps left | The garden's remaining crossings, **not seconds**. Walls and premature inputs spend nothing. |
| Pair target | The charge the two wardens must match; moving an endpoint discards one pylon, not time. |
| Bridges left | Five usable connections for six islands. Redundant links cost nothing; Undo returns a bridge. |
| Plaques to remember / Energy left | First record cheapest arrivals, then climb the stair within 17 energy. Selecting and inscribing spend no climbing energy. |
| Elapsed (no bonus) | Informational time spent in the visit, excluding pause. It never increases or reduces points. |

There is **no speed bonus and no point penalty for hints, retries or failed
attempts**. The Untimed Sunrail setting pauses that deadline live without
changing the score. No other relic has a countdown.

## The keeper's outfit store

Open **Store** from the standalone title screen or from **Pause** during any
ritual, including in the collection. The original keeper outfit is already
owned; three more looks can be bought in any order:

| Outfit | Price | Appearance |
| --- | --- | --- |
| Original Keeper | Free, already owned | Work coat, goggles and the original stargazer's hat |
| Warrior | 3 Star Shards | Bronze-trimmed armor, crimson cloak, sword and star shield |
| Ranger | 3 Star Shards | Moss-green hood and cloak, a curved bow and quiver |
| Wizard | 3 Star Shards | Star-sewn robe, pointed violet hat and crystal staff |

**Finish the ritual to earn shards.** Each different relic solved during that
visit pays one, capped at six; the results show the amount banked. Hints,
retries, speed and Untimed Sunrail do not change the payout. Leaving early
still saves permanent seals but does not bank that unfinished visit's points.
Resuming a partial save pays for only the remaining relics solved in the
finishing visit. Once all seals are restored, a fresh full ritual can earn
another six shards. Outfit prices remain three shards.

Buying an outfit equips it immediately, even from the paused shop, without
restarting the stage or changing the clock, scores or puzzle rules. Owned
outfits can be swapped for free, including back to the original keeper.
The gameplay keeper and the opening both wear the saved choice. All outfits
are **cosmetic only**: their props do not add combat or puzzle abilities.

The four shelf portraits use the same cached meshes and weathered materials
as gameplay. They turn slowly with motion enabled and settle into a fixed
three-quarter pose with Reduced motion. Full outfit names, prices and worn
status accompany the pictures; the shop preserves readable type and touch
actions on portrait phones instead of shrinking a desktop grid.

The shared `Store` owns currency, purchases and the `keeper_outfit` slot in
`user://store.cfg`, under this game's own wallet. Item IDs `keeper`, `warrior`,
`ranger` and `wizard` are permanent save keys. Unknown saved outfits fall back
to the original look without discarding their ownership. Neither previewing
an unowned outfit nor the opening's demonstration relays can spend or mint
shards.

## Design reasoning

The first three mechanisms teach different useful habits through space:
retain what is unchanged, discard what cannot be true, and explore equally
distant alternatives together. The new mechanisms extend those habits:
discard impossible endpoint pairs, merge separate networks without cycles,
and reuse the cheapest remembered subproblems rather than choosing greedily.
Rules stay visible in objects and consequences;
the player is never asked to identify an algorithm or write code.

One stable elevated camera frames the complete theatre, rather than cutting
between rooms. A goggled keeper is the stage's guide and garden cursor.
Fixed viewpoints, stable numbered markers
and deterministic retries make an unsuccessful idea informative rather than costly.

### One evolving ritual

The Sunrail, Whisper Shaft, Echo Garden, Twin Wardens, Broken Archipelago and
Memory Stair share a circular flagstone dais,
bronze inlays, old columns, candles, a hovering orrery and six numbered star
sockets. Each solve lights its own star and the links to other restored stars.
The constellation gathers above the centre of the dais and the core blooms
before the shared results appear.

Gameplay has explicit **arriving, puzzle, restoring, departing and finale**
phases. The shell's update supplies both presentation and puzzle time; only
the puzzle phase with the grimoire closed advances the model. Handoffs reject
selection, movement and retry input. There are no detached completion timers,
doorway callbacks, alternate travel paths or free-walking physics.

Seal completions are saved immediately as namespaced achievements in the
host's existing `user://achievements.cfg`. Leaving the game, a failed attempt
or Play Again never revokes them. An **incomplete save** prelights its restored
seals and begins at the first missing one; only new solves earn visit points.
A **complete save** starts a fresh six-relic ritual with an unlit current
constellation, while all permanent achievements remain earned. Historical
achievements therefore cannot immediately finish every replay. Existing saves
with the original three seals resume at the Twin Wardens, with those earlier
stars already lit and no duplicate points. Existing achievement and outfit
IDs are unchanged.

### 1. The Sunrail - Sliding Window (playable)

- **Space:** twelve numbered, faceted crystals under a brass three-cell frame.
  Heights and explicit numbers communicate charge without relying on colour.
- **Interaction:** preview with left/right or click/tap a crystal to begin a
  frame there; at the end of the rail the frame stays within its last three
  cells. Then arm it. Arming **retains the previewed frame and
  record**. A direct selection reveals only that range, not skipped readings.
  Each one-notch shift releases one end cell, takes the new end cell and
  retains the overlap. The record meter
  remembers the strongest reading.
- **Feedback:** crystals float and selected crystals lift; the brass frame
  glides over exactly three neighboring cells and reacts to each adjustment. Tile
  highlights, charge and record numbers, a short tone and the compact caption
  reflect the same model.
- **Win:** lock a globally maximum-charge segment. Any tied maximum counts.
  Locking a weaker segment gives feedback but leaves the attempt running.
- **Fail:** the 90-second capacitor expires. Reset restores the same rail and
  timer. Preview is untimed. The Game tab's **Untimed Sunrail** toggle pauses
  the deadline live; turning it off resumes the retained time. The shared pause
  menu and grimoire freeze it. Reading the always-visible short instructions
  outside the grimoire does not pause an already armed clock.
- **Inscription:** "Keep the middle. Release one cell. Take the next."
  Later inscriptions explain the record and its cell range.

`puzzles/sliding_window.gd` documents both the rolling update and independent
maximum calculation. Each shift is O(1); direct selection sums only the frame's
width; the initial maximum is O(n). It handles negative totals, width-one rails,
full-width frames, ties and both directions.

### 2. The Whisper Shaft - Binary Search (playable)

- **Space:** a circular brass listening astrolabe, numbered seals and a hovering
  violet keystone. Its seals represent the shaft's floors without demanding
  a towering room or a different camera.
- **Interaction:** click/tap a numbered listening seal or use up/down (left/right
  also work), then listen. A turning pointer follows the selected seal; the
  keystone rises or dips with the clue. Selection is restricted to the remaining
  open interval. No separate arming action is required.
- **Feedback:** every wrong probe gives a truthful HIGHER or LOWER inscription,
  an explicit direction, pitched cue and a caption request. Impossible floors
  become dark and acquire X marks. The range, remaining charges and latest
  clue stay readable in the native-resolution HUD and bottom caption.
- **Win:** find the beacon among 15 floors within four probes.
  A hit on the final charge is valid.
- **Fail:** use every charge on incorrect floors. Retry reopens the same shaft
  and keeps its beacon in place. Only a new ritual chooses a new beacon.
- **Inscription:** "A good question silences half the tower."
  A second request identifies a midpoint of the remaining interval, never
  the hidden target.

`puzzles/binary_search.gd` documents the inclusive-bound invariant and integer
probe budget. The player chooses the midpoint; the selector does not secretly
perform the search. Higher excludes the queried floor and everything below;
lower excludes that floor and everything above.

### 3. The Echo Garden - BFS / Shortest Path (playable)

- **Space:** inscribed stone platforms and equal-cost old wooden walkways form a
  small maze. Broken masonry and violet mushrooms are walls, not high-cost edges.
  A small keystone marks the exit; its distance shares that tile's EXIT label.
- **Interaction:** the first pulse starts on arrival; E can reveal the remaining
  echoes immediately without spending a charge. Once all echoes
  settle, inspect the platform numbers, then tap one direction per walkway
  or click/tap an adjacent 3D platform.
  Movement is one connected graph edge, never a
  diagonal or a free shortcut across the floor.
- **Feedback:** each beat blooms an entire equal-distance layer; the keeper
  makes short, readable hops along valid edges. First
  discovery permanently labels a platform. The keeper marks the current
  platform, EXIT labels the goal and masonry marks walls. Each real crossing
  uses one charge.
- **Win:** reach the exit within exactly the shortest-route budget. Different
  equally short paths are accepted.
- **Fail:** spend the last charge anywhere other than the exit. Retry returns
  to the entrance **with the revealed distance field intact**, immediately
  ready for another route. A new ritual still begins with an unrevealed map.
  Walls and moving before the pulse settles produce feedback without
  consuming charge.
- **Inscription:** "Where the light arrives first, the journey is shortest."
  Later: trace the numbers backward from the exit, decreasing by one per edge.

`puzzles/breadth_first.gd` marks nodes when enqueued, stores their first
predecessor, and advances complete frontiers. The model computes a route but
does not draw an automatic solution arrow. It reports a disconnected authored
map explicitly rather than pretending an empty path is a solution.

### 4. The Twin Wardens - Two Pointers (playable)

- **Space:** eight sorted crystal pylons, two winged brass drones and a live
  charge beam. LEFT and RIGHT labels identify the current endpoints; discarded
  pylons darken and acquire X marks.
- **Interaction:** Left advances the left warden inward; Right advances the
  right one. Clicking or tapping either endpoint pylon or its drone does the
  same. A middle pylon is not a shortcut. Interact locks the chosen pair.
- **Feedback:** the drones glide between pylons and gently hover. Explicit
  TOO FAINT / TOO BRIGHT clues, the sum and the target remain readable without
  animation, sound or color. The beam turns gold when the pair balances.
- **Win:** match target 15 using two distinct pylons. Equal-valued but distinct
  pylons are valid in the model. A weak lock gives a clue without ending play.
- **Fail:** discard until the wardens meet without a pair. Retry restores both
  endpoints and the same charges immediately. There is no countdown.
- **Inscription:** "Too faint? Leave the faintest behind. Too bright? Leave the brightest."

`puzzles/two_pointers.gd` validates sorted, solvable input. Each discard is O(1);
following the comparison clues finds a pair in O(n), including duplicates and
negative charges. The player makes every discard and the final lock.

### 5. The Broken Archipelago - Union-Find (playable)

- **Space:** six floating stone islands, nine numbered bridge sockets and
  colored network runes. Each island also shows its explicit `NET` number:
  the lowest numbered island in its connected component.
- **Interaction:** select a socket by touch/click or Left/Right, then Connect
  bridge. Up, labeled Undo, returns the most recently built bridge and charge.
- **Feedback:** a useful bridge unfolds from its socket, the merged islands
  share a network emblem, and small energy crystals travel along powered
  links. Undo immediately restores the separated emblems and removes the link.
- **Win:** connect all six islands with five useful bridges. Any spanning tree
  of the authored graph works; the final connection restores the seal.
- **Rejected action:** a redundant link says "Already connected" and spends
  nothing, including when its islands are linked only indirectly. Selection,
  retries and undo are free. There is no countdown.
- **Inscription:** "A bridge matters when it joins two separate worlds."

`puzzles/union_find.gd` uses path compression and union by size, with a stable
minimum-island emblem independent of the internal root. Undo rebuilds the small
forest from retained edges instead of trying to reverse path compression.
Authored sockets must form a connected graph with no duplicate or self edges.

### 6. The Memory Stair - Dynamic Programming (playable)

- **Space:** eight rising stone landings, each displaying its `FEE` and a
  remembered `BEST` arrival total. START has a free total of zero. A hovering
  keystone and two local light threads identify the plaque and its predecessors.
- **Remember:** work up the stair one plaque at a time. Left/Up chooses the
  record one landing behind; Right/Down chooses two behind. Tapping a valid
  predecessor also selects it. Interact adds the current fee to that record.
  Only a cheapest predecessor is accepted; ties both work. A newly learned
  plaque blooms, while a rejected record gives a readable comparison. The
  native-resolution caption repeats both predecessor totals; the paused
  grimoire includes the full fee/remembered-cost table for small screens.
- **Climb:** after all plaques are remembered, choose a reachable landing one
  or two steps ahead and confirm. The keeper hops up the actual stair; rapid
  confirmation cannot queue unseen steps. Each visited landing spends its fee.
- **Win:** reach the summit using its cheapest total, exactly 17 energy in the
  authored puzzle. Choosing the cheapest next fee greedily does **not** solve it.
- **Fail:** spend more than the available energy, even on the summit. Retry
  refunds energy and returns the keeper to START, retaining learned plaques.
  A fresh ritual clears those records. There is no countdown.
- **Inscription:** "Remember the cheapest way here. Build the next step from that."

`puzzles/dynamic_programming.gd` computes
`best[i] = fee[i] + min(best[i - 1], best[i - 2])` in O(n). Only legal
predecessors are selectable; START can reach either of the first two landings.
The model accepts all tied cheapest routes, including zero-cost landings, and
never mistakes exhausting the budget before a free final step for failure.

## One fixed configuration

The original relics retain their defaults: **12 positive crystals with a three-cell
frame, 15 listening seals with four questions, and a 5x5 garden with an
eight-crossing route**. The additions use **eight sorted pylons targeting 15,
six islands with nine bridge sockets and five bridges, and eight stair landings
with a 17-energy optimum**. There is no difficulty option or solo setup question.
Old `game/creep_code_difficulty` values are ignored, not deleted from merged
saves; permanent achievements and rebound controls are unchanged. The
**Untimed Sunrail** accessibility assist remains available.

Hints never cost score. A future combined relic could let bridges alter a graph
before a shortest-route challenge, or have a strongest solar segment reveal
the initial interval of a shaft. These combinations are not shipped here.

## Implementation and extension

| File | Responsibility |
| --- | --- |
| `game.gd` | Manifest, theme, credits, instructions and achievements |
| `intro.gd` / `.tscn` | Regular intro subtitles over the full-width, demonstration-only ritual stage |
| `creep_code_options.gd` | Fixed puzzles, bindings, untimed assist and the outfit/Star Shard catalogue |
| `gameplay.gd` / `.tscn` | Inherited shell, deterministic ritual phases, persistence, input and grimoire |
| `puzzle_manager.gd` | Ordered relic handoff, separate saved/current seals, retries and completion signals |
| `puzzles/puzzle_state.gd` | Common phase and signal contract, no scene dependencies |
| `puzzles/sliding_window.gd` | Sliding frame, running sum, maximum, timer and hints |
| `puzzles/binary_search.gd` | Inclusive interval, truthful comparisons and probe budget |
| `puzzles/breadth_first.gd` | Layered traversal, retained retry discoveries and shortest-route budget |
| `puzzles/two_pointers.gd` | Sorted endpoint elimination, truthful sum comparisons and distinct-pair locking |
| `puzzles/union_find.gd` | Compressed component forest, stable network emblems, bridge budget and rebuild-based undo |
| `puzzles/dynamic_programming.gd` | Player-built cheapest-arrival records, weighted climbing and retained retry knowledge |
| `art/palette.gd` | Game-owned colours and the shared weathered material for stage and shop |
| `art/toy_models.gd` | Original cached relic, masonry and four keeper-outfit meshes (historical filename) |
| `world/observatory.gd` / `.tscn` | Persistent stage, actual-mesh/number picking, animation and local lights |
| `ui/ritual_hud.gd` | Compact bottom actions, persistent clue captions and an on-demand grimoire |
| `ui/outfit_preview.gd` / `.tscn` | Isolated 3D outfit portrait, turntable and native preview framing |

The **Puzzle Manager** has the reusable singleton/autoload role, but is mounted
once under this game's gameplay root rather than registered in `project.godot`.
Its lifetime spans the entire ritual. New puzzles subclass `PuzzleState` and
register an ID, title and model through `register_puzzle()`. Registration order
defines sequence. `advance_to_next()` requires the current relic to be solved.
Add the corresponding game-owned view, options and
achievement declaration; no shared framework script needs to learn the game
or algorithm name.

The models emit `changed`, `cue`, `solved` and `failed`. The manager emits
`stage_changed`, `changed`, `feedback` and `puzzle_completed`. It never writes a
profile itself. Gameplay translates completed IDs into the existing
AchievementManager API and ends the ritual through `GameShell`.

The 3D world is an isolated `SubViewport` under `%Playfield`. Stretching is
owned by its container, not competing manual viewport-size assignments.
The stage, core, keeper, camera and lighting persist; only the mechanism child
is replaced. Garden movement follows the model's graph, not a physics shortcut.
An input Control supplies local coordinates over the viewport; picking checks
the actual billboard numbers and cached mesh triangles, so empty corners of a
mushroom's bounds do not steal a walkway tap. Mouse emulation cannot repeat a
touch. Pause, reading and handoffs reject input before it reaches a model.
Presentation progress is supplied explicitly; pause, replay and exit cannot
leave an asynchronous room replacement behind.

### Antique observatory art

The circular dungeon theatre has real flagstones, chipped masonry, bronze
inlays, a broken vault, worn banners, candle clusters and old books. A cached 128x128
procedural grain adds world-space weathering without an asset download.
The goggled keeper, floating crystal rail, listening astrolabe, rune garden,
winged wardens, floating islands and rising memory stair retain clear
silhouettes and legible numbers against the darker stone.

All models and SVG artwork are original and owned by this game: no downloaded
assets, external licences or additional packages are required. Each prop is
one indexed vertex-painted surface; immutable props, the masonry and weathering
texture are shared. Puzzle indicators stay separate from furniture paint.
Four bounded, non-shadowing local lights illuminate two lanterns, the central
constellation and active mechanism; the finale retains the three persistent
lights. One directional light supplies shadows. The scan frame carries its
actual light with it. Orbiting rings, floating crystals, turning pointers,
layer-by-layer rune blooms, gliding endpoint drones, unfolding bridges,
traveling network energy, remembered-plaque blooms, 24 faint motes,
28 solve sparks and curved keystone
flights need no bloom, volumetric fog,
Forward+ feature or renderer plugin. Everything uses `gl_compatibility`.

Reduced motion parks the orrery, floating crystals, pointer interpolation,
garden/stair hops, warden flights, island hovering, bridge unfolding and energy
particles, remembered-plaque blooms, motes, candle modulation and any live celebration. It replaces
unfolding/folding with short opacity-only transitions, removes keystone flights
and presents the finale already settled instead of moving/scaling into place.
Effects-off suppresses motes, light surges and solve
sparks and bridge energy particles; steady illumination, network emblems and
meaningful distance/cost discovery remain.
There are no full-screen flashes, camera sweeps or custom shake. The opening
applies both settings live and uses opacity-only text/stage fades.
P1 labels honor the shared
preference and clear the equipped outfit's hat. The wardrobe changes the mesh,
not the keeper node, so garden hops and their input guards are preserved.
All meaningful sounds request captions, and information always has
a number, word or shape.

## Checks

From `godot-base`, run one at a time:

```powershell
godot --headless --path . --script res://games/creep_code/tests/puzzle_models_test.gd -- --game=all
godot --headless --path . --script res://games/creep_code/tests/toy_models_test.gd -- --game=all
godot --headless --path . --script res://games/creep_code/tests/expedition_test.gd -- --game=all
godot --headless --path . --script res://games/creep_code/tests/outfits_test.gd -- --game=all
godot --path . --resolution 1280x720 --script res://games/creep_code/tests/observatory_view_test.gd -- --game=all
```

The view suite requires a real graphics display and intentionally refuses
headless mode. Geometry checks include paint, triangle budgets, exterior
winding and an actually hollow arch. The view suite covers the fixed ritual
at landscape, portrait and ultrawide sizes, including all six mechanisms,
bounded lighting, actual
solve effects, progressive constellation, native controls, the opening and
draw/triangle budgets. It also checks every rendered number's picking target,
real GUI clicks at every resolution, full-width stages, regular intro subtitles,
all outfit silhouettes on the keeper, turntable framing and the shop's native
text/touch sizes. The historical `expedition_test.gd` suite now covers
automatic ritual progression, stable stage/core identities, pause and skip
guards, grimoire timing, native input, retained garden echoes, partial-save
resumption, legacy three-seal upgrades, full-save replay, bridge undo, retained
stair records, retired difficulty values and exact budgets/points.
It also drives the
six-card opening timeline and proves natural completion and early skip navigate once.
The model suite compares two-pointer searches against every attainable pair
in randomized sorted arrays, union-find partitions against graph traversal,
and every small stair table against exhaustive route enumeration.
`outfits_test.gd` completes real rituals, buys all three costumes, equips from
pause, checks unchanged puzzle state, reloads the wallet and saved outfit,
and exercises reduced-motion previews and unknown saved equipment. It restores
the original store file and in-memory wallet on exit.
`expedition_fixture.gd` and `intro_fixture.gd` are helpers, not suites; they
intercept achievement writes and menu navigation. The expedition fixture also
suppresses wallet writes unless the outfit suite explicitly opts in. Existing
framework suites automatically cover this manifest's shell, settings,
store, standalone branding and accessibility contracts.

The **Windows - Creep Code (standalone)** export uses the `creep_code` feature
tag and stable save directory `DeskCanSaw Games/Creep Code`. Other games and
development scripts are excluded. Source launches use the shared development
profile, as every other `--game` source launch does.
