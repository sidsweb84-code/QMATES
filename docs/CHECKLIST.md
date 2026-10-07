# Final verification checklist

Legend: ✅ implemented and covered by automated tests ·
🧪 implemented, verify by hand in Studio / on devices ·
🔧 needs your input (IDs, assets) before publishing.

"Automated" means the offline unit tests, the headless simulation of the real
scripts, and/or the in-game `/runtests` suite (see [TESTING.md](TESTING.md)).
The headless runtime is a faithful model of the Roblox APIs the game uses, but
it is not Roblox itself: rendering, physics, real DataStores and real Robux
prompts must still be checked in Studio.

## Getting it into Studio

| Check | Status | Where |
| --- | --- | --- |
| One place file opens with everything (`build/StealPokemon.rbxl`) | ✅ build / 🧪 open in Studio | `default.project.json`, `tests/check_artifacts.py` |
| One model file + Command Bar installer (`build/StealPokemon_Installer.rbxm`) | ✅ | `installer/`, sim 05 (built from the real model), `tests/check_artifacts.py` |
| Installer backs up instead of deleting, keeps the developer's Assets, refuses Play mode | ✅ | sim 05 |
| Pressing Play before installing does nothing harmful | ✅ | ServerMain saved Disabled + location guard, sim 05 |
| Committed build files match the source | ✅ | `tests/check_artifacts.py` |

## Core loop

| Check | Status | Where |
| --- | --- | --- |
| Players get a base on join (8 bases; extra joiners told the server is full) | ✅ | `BaseService`, sim 01 |
| Conveyor spawns collectibles with weighted rarity | ✅ | `ConveyorService`, `Odds`, spec 02, sim 01 |
| Buying is server-validated (cash, distance, item exists, capacity) | ✅ | `ConveyorService`, `/runtests`, sim 04 (real prompt) |
| Acquisition reveal scales with rarity (5 tiers) | ✅ / 🧪 visuals | `UI/Reveal`, sim 04 |
| Collectibles walk to the base and are displayed on slots | ✅ / 🧪 visuals | `BaseService`, `World` |
| Passive income from one central tick; collect pad + auto-collect | ✅ | `EconomyService`, `/runtests` |
| Offline earnings capped | ✅ | `EconomyService`, sim 02 |
| Base, defense, card-level and storage upgrades | ✅ | `UpgradeService`, `/runtests` |
| Selling, favouriting/locking, moving to storage | ✅ | `CollectibleService`, `/runtests` |

## Stealing & defense

| Check | Status | Where |
| --- | --- | --- |
| Grab (rarity-scaled) → carry home, progress bars | ✅ | `StealService`, `Controllers/Steal`, sims 03/04 |
| Owner alerts, base status, catch by touching thief | ✅ | sim 03, sim 04 |
| Traps stun and return the item | ✅ | sim 03 |
| Base lock blocks and cancels thefts, ejects intruders | ✅ | sim 03, `/runtests` |
| Cooldowns (pair, failure, victim protection), new-player protection | ✅ | sim 03 |
| Theft cancelled cleanly if either player leaves | ✅ owner leaving / 🧪 thief leaving | sim 03, `StealService:OnPlayerRemoving` |
| No duplication during steal or trade | ✅ | sim 03, `/runtests`, spec 03 |
| Teleport/speed abuse rubber-banded; teleporting while carrying blocked | ✅ | `AntiExploitService`, sim 03 |

## Progression

| Check | Status | Where |
| --- | --- | --- |
| Rebirth: cost, reset, multipliers, kept cards, milestones | ✅ | `RebirthService`, `/runtests`, sim 02 |
| Daily quests (3/day, reroll) and achievements | ✅ | `QuestService`, `/runtests`, sim 02 |
| 7-day daily reward, playtime and collection milestones | ✅ | `RewardService`, sim 02 |
| Collection book with completion % | ✅ | `RewardService`, `Windows/Index` |
| Mutations and traits affect income/price | ✅ | spec 02 |
| Luck is transparent (odds tab = server roll function) | ✅ | spec 02 statistical test |
| Events: rotation, seasonal, admin start/stop, modifiers | ✅ | `EventService`, `/runtests` |
| Tutorial (7 steps, skippable, rewarded) | ✅ | `TutorialService`, sim 02 |

## Shops, monetization, currencies

| Check | Status | Where |
| --- | --- | --- |
| Packs (cash only, odds shown), boosts, cosmetics, event shop | ✅ | `ShopService`, sim 02 |
| ProcessReceipt: dedupe, save before granting | ✅ | `MonetizationService`, `/runtests` |
| Gamepass perks apply/remove | ✅ | `/runtests` |
| Real gamepass / product IDs | 🔧 | `MonetizationConfig` (all `Id = 0`) |
| No paid random rewards; no pay-only power | ✅ (by design) | `MonetizationConfig` header |

## Data

| Check | Status | Where |
| --- | --- | --- |
| Load/save round trip, autosave, save on leave and shutdown | ✅ (mock) / 🧪 (real store) | `DataService`, `/runtests`, sim 02 |
| Retries with backoff on DataStore errors | ✅ | `/runtests` |
| Session locking (retry, stale takeover, lock-loss kick) | ✅ | `/runtests`, sim 03 |
| Versioning and migration, validation of corrupt data | ✅ | spec 03 |

## Security

| Check | Status | Where |
| --- | --- | --- |
| Single remote gateway, per-action rate limits | ✅ | `NetService`, `Net.Actions`, `/runtests` |
| Bad/hostile arguments rejected and flagged | ✅ | `/runtests`, sims 03/04 |
| Admin commands permission-checked server-side | ✅ | `AdminService` |
| Suspicion scores + logs, no automatic permanent bans | ✅ | `AntiExploitService` |

## UI & platforms

| Check | Status | Where |
| --- | --- | --- |
| Every window/tab/button opens and works without errors | ✅ | sim 04 (clicks every button) |
| Responsive scaling for phone/tablet/PC/console | ✅ logic / 🧪 look | `UI/Root`; check with Device Emulator |
| Gamepad navigation, keyboard shortcuts, touch prompts | 🧪 | `Controllers/Input`, `WindowManager` |
| Settings (audio, graphics, motion, UI size) apply | ✅ | sim 04 |
| Leaderboards (leaderstats + global boards) | ✅ / 🧪 (real OrderedDataStore) | `LeaderboardService` |
| Players list, inspect, visit base, trading | ✅ | sims 03/04 |

## Content & assets

| Check | Status | Where |
| --- | --- | --- |
| 75 original creatures, 9 rarities, 12 elements | ✅ | `CollectibleConfig`, spec 01 |
| No Pokémon names/art/audio shipped; licensed mode off | ✅ | [LICENSING.md](LICENSING.md) |
| Audio | 🔧 placeholders | `SoundConfig` (Roblox built-in sounds, no music) |
| Game icon / thumbnails | 🔧 | not included |
| Admin UserIds | 🔧 | `AdminConfig.UserIds` |
