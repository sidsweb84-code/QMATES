# Testing

There are four layers of tests. `./scripts/test.sh` runs the first three
(set `TOOLS=/path/to/tools` if the binaries are not in `./tools`).

```bash
./scripts/setup-tools.sh   # once: rojo, luau, luau-lsp + Roblox type definitions
./scripts/test.sh          # prints "All checks passed" on success
```

## 1. Static checks

* **Type check:** `scripts/check.sh` runs `luau-lsp analyze` with the Roblox
  type definitions and a Rojo sourcemap over every script. Must be clean.
* **Registry check:** `tests/check_registry.py` verifies that every
  `Registry.<Service>:<Method>` call in the codebase refers to a service and
  method that actually exist.
* **Build artifacts:** `tests/check_artifacts.py` rebuilds both Studio files
  and fails if `build/StealPokemon.rbxl` or `build/StealPokemon_Installer.rbxm`
  is out of date. It also reads the binary model and checks that ServerMain is
  saved as `Disabled` there (Studio does not load `Enabled` from files) and
  enabled in the place file.

## 2. Unit tests (offline, no Roblox needed)

`tests/run.py` bundles the shared modules with a small mock of Roblox
datatypes (`tests/mock_roblox.luau`) and runs the specs in `tests/specs/`
with the standalone `luau` interpreter:

* `01_catalog_config_spec` — every config cross-reference (quests, rewards,
  packs, events, cosmetics, monetization), rarity/economy curves, map plots.
* `02_odds_economy_spec` — odds sum to 100%, luck favours rarer tiers and is
  clamped, a statistical check that rolls match the displayed odds, event and
  rebirth gating, economy formulas (income, sell value, level-ups, steal
  times, rebirth, slots), number formatting.
* `03_data_schema_spec` — defaults, migrations, validation/repair of corrupt
  data, duplicate-item protection, string-only keys, receipt trimming, and the
  token-bucket rate limiter.

## 3. Headless game simulation

`tests/sim/run.py` loads **the real server and client scripts** into a
headless Roblox runtime (`tests/sim/runtime.luau`: instances, signals,
attributes, DataStores, MarketplaceService, players and characters, a
virtual clock) and plays scripted sessions:

| Scenario | Covers |
| --- | --- |
| `01_server_boot` | Map generation, join pipeline, snapshot privacy, conveyor spawning, server-full handling |
| `02_player_journey` | Tutorial, buying, income, collecting, upgrades, quests, rewards, packs, shops, cosmetics, rebirth, events, products/passes, save + rejoin, the in-game test suite |
| `03_multiplayer_stealing` | Session-lock takeover, new-player protection, full steal, catches, traps, base lock, owner leaving mid-theft, speed-hack rubber-banding, trading, two-player test suite |
| `04_client_ui` | Boots the client UI, buys through the real prompt, plays every reveal tier, opens every window/tab and clicks every button, steal alerts and panel, trade UI, settings |
| `05_installer_model` | Starts from the installer model in a template place (Baseplate, an older install, the developer's own assets), runs the installer, checks every script/setting/backup, then boots and plays the installed game |

Any error thrown by game code — or logged by it (`[ERROR]`, WindowManager,
Reveal, ActionBus) — fails the scenario.

## 4. In-game integration tests (Roblox Studio)

`ServerScriptService/Tests/TestRunner` contains 20 tests that run against the
live services in Studio. Run them with **`/runtests`** (admin), or set
`GameConfig.Testing.AutoRunInStudio = true`. Your own data is snapshotted and
restored afterwards.

They cover: joining, save/load round trip, save retries, session locking,
conveyor purchase validation, insufficient cash, income generation, spending
on upgrades, inventory actions, duplication prevention, bad-input rejection,
remote rate limiting, rebirth, quests, events, rare spawns + luck, developer
products (no double grants), gamepasses, base lock defense, and an end-to-end
steal (needs a second player: pick *Server & Clients* with 2 clients in the dropdown next to Play; older Studio: *Test → Clients and Servers*).

## Manual test pass (recommended before publishing)

1. Solo Play: complete the tutorial; buy from the conveyor; watch the reveal;
   collect cash; upgrade base and defenses; open every window on PC.
2. Studio's Device Emulator: check phone and tablet layouts and touch prompts.
3. Gamepad (or emulator): navigate HUD and windows with the D-pad, B closes.
4. 2–3 player local server: steal, get caught, trigger a trap, lock a base,
   trade, visit and inspect other bases, check alerts.
5. With API access on: play, leave, rejoin — progress persists.
6. `/testproduct CashSmall`, `/testpass VIP` — rewards appear once.
