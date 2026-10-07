# Architecture

## Principles

1. **The server is the only authority** over cash, tokens, ownership,
   inventory, thefts, purchases, rewards, quests and upgrades. Clients send
   *intents* ("buy item X", "start stealing Y"); the server validates
   everything (distance, cost, ownership, cooldowns, locks, rate limits) and
   replies with a result. Clients never send amounts or outcomes.
2. **Data-driven.** All tunable content is in `Shared/Config/*`. Shared pure
   modules (`Economy`, `Odds`, `Catalog`) are used by both server and client so
   numbers shown in the UI are exactly what the server applies.
3. **Centralised loops.** One income tick, one conveyor loop, one steal loop,
   one client render loop. No per-item `while true` scripts.

## Boot

`ServerMain.server.luau`:

1. Requires `MapBuilder` and the 23 services into `Registry` (service locator,
   no circular requires).
2. `MapBuilder.Build()` generates the whole map (hub, conveyors, 8 bases,
   kiosks, leaderboards, decorations) and hands the map references to services.
3. Calls `Init()` on every service, then `Start()`.

`PlayerService` owns the join pipeline: load data (`DataService`) → run each
service's `OnPlayerLoaded` in a fixed order (monetization perks → inventory →
base assignment → income → quests → rewards → cosmetics → leaderboards →
tutorial → admin) → set `DataLoaded` → spawn the character. Leaving runs
`OnPlayerRemoving` (cancel trades and thefts, settle income, release the plot)
and then saves and releases the session lock.

## Networking (`Shared/Net.luau`, `NetService`)

* `Remotes.Request` (RemoteFunction) — every client action. The first
  argument is an action name from `Net.Actions`; each action has a token-bucket
  rate limit. Unknown actions, wrong types, and rate-limit hits are rejected
  and reported to `AntiExploitService`. Handlers return
  `{ Ok, Message, Data }`; errors inside handlers are caught and logged.
* `Remotes.Event` (RemoteEvent) — server → client notifications (toasts,
  reveals, alerts, announcements, effects).
* `Remotes.Sync` (RemoteEvent) — server → client data patches with sequence
  numbers; the client `State` controller keeps a read-only mirror of the
  profile (private keys such as receipts and session locks are never sent).
  A client firing `Sync` is flagged.
* Rarities with `Announce = "Global"` are also announced to other servers via `MessagingService`
  (failures are ignored; the local server is always announced first).

## Server services

| Service | Responsibility |
| --- | --- |
| `NetService` | Remote dispatch, rate limits, notifications |
| `DataService` | Profiles: load with session lock, autosave, save on leave/shutdown, retries, validation, migrations, mock store in Studio |
| `AntiExploitService` | Movement checks (speed/teleport, rubber-banding), suspicion scores, flags, admin reports — no automatic bans |
| `BoostService` | Personal and server boosts with expiry |
| `EventService` | Event rotation, weekend/seasonal events, modifiers, admin overrides |
| `EconomyService` | Cash/tokens/event currency, central income tick, offline earnings, collect pad |
| `CollectibleService` | Inventory: grant, remove, transfer, swap, sell, level, lock, move, serial numbers, duplication guards |
| `BaseService` | Plot assignment, slots and creature models, lock door, alarms, traps, intruder checks, themes |
| `ConveyorService` | Spawning (Odds), item lifetime, server-validated purchases, rare-spawn announcements, packs |
| `StealService` | Grab/carry thefts, catches, traps, cooldowns, protections, owner alerts |
| `UpgradeService` | Base levels, defense tracks, card levels, storage |
| `RebirthService` | Rebirth requirements, reset, kept cards, milestones |
| `QuestService` | Daily quests (rolled per UTC day), rerolls, achievements; listens to `ActionBus` |
| `RewardService` | Daily streak, playtime milestones, collection milestones, collection book |
| `ShopService` | Packs, boost items, event shop |
| `CosmeticService` | Ownership/equipping of trails, name tags, card frames, base themes, effects |
| `MonetizationService` | Gamepasses, `ProcessReceipt`, receipt dedupe, Studio simulation |
| `LeaderboardService` | `leaderstats`, global OrderedDataStore boards, in-world boards, server showcase |
| `TradeService` | Requests, offers, both-sides ready + countdown, atomic re-validated swap |
| `TutorialService` | 7-step onboarding driven by `ActionBus` |
| `AdminService` | Permission-checked commands, logs |
| `HandlerService` | Registers every request handler in one place and routes it to the owning service; also quick travel, inspect, visit base, settings |
| `PlayerService` | Join/leave pipeline, character spawning, movement speed, stuns |

`ActionBus` is a tiny in-process event bus: gameplay services fire actions
("Acquire", "Steal", "Collect", …) and quests, achievements, and the tutorial
listen, so the gameplay code knows nothing about quests.

## Data

`DataSchema` defines the default profile, `Version` (currently 2),
`Migrations[n]` (n → n+1) and `Validate` (clamps numbers, drops unknown
collectible IDs, repairs slots). Dictionaries are string-keyed only (DataStore
safe). Session locks are stored in the profile (`SessionLock = { JobId,
Time }`): a fresh lock from another server makes loading retry; a stale lock
(older than `SessionLockTimeout`) is taken over; if a save discovers the lock
was taken by another server, this server stops saving and kicks the player
so two servers can never write the same profile.

## Economy maths (`Shared/Economy.luau`, `Shared/Util/Odds.luau`)

* Income per second = Σ(base income × mutation × trait × card level) ×
  rebirth multiplier × boosts × gamepass × event × admin/server multiplier.
* Conveyor rolls: weight × `Luck^min(tierDistance × 0.5, 2)` for rarer tiers;
  mutation chance × `Luck^0.5` (capped). The Index → Odds tab renders the same
  function, so displayed odds are exact.

## Client

`ClientMain` waits for data, then initialises controllers and the UI.

* **Controllers:** `State` (data mirror + signals), `Sound`, `Effects`
  (camera shake, particles, reduced-motion aware), `Interaction` (custom
  ProximityPrompt styling, buy/steal/collect prompts), `World` (one render loop
  that moves conveyor items from attributes, animates creatures with an LOD
  budget, plays travel animations), `Steal` (theft bars, owner alerts),
  `Tutorial` (markers and steps), `Input` (keyboard shortcuts, gamepad).
* **UI:** a virtual 1100×680 canvas scaled with `UIScale` for every screen
  size; `UIKit` component helpers; `WindowManager` (one window at a time,
  gamepad selection, Esc/B to close); `CardView` trading-card component with
  live 3D previews; `Reveal` acquisition sequences (tiers 1–5); `HUD`;
  `Notifications` (toasts, announcements, modal popups queue).

## Adding content

* **New creature:** add an entry to `CollectibleConfig` (id, name, rarity,
  element, price, income, colours, body plan). Run `./scripts/test.sh`.
* **New event:** add to `EventConfig.Events` with modifiers; optionally add
  limited creatures with `Event = "<EventId>"`.
* **New request:** add the action to `Net.Actions` (with a rate limit) and
  register it with `NetService:Handle("Action", fn)` in `HandlerService`.
