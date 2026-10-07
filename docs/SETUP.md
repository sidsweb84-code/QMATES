# Setup & publishing guide

Everything gameplay-related works as soon as you open the place. The steps
below connect the game to *your* Roblox experience (saving, Robux items,
admins, audio) and must be done before you publish publicly.

## 1. Open the project

* **Quickest:** open `build/StealPokemon.rbxl` in Roblox Studio and *File →
  Publish to Roblox As…* to create your experience.
* **Into an existing place:** insert `build/StealPokemon_Installer.rbxm`, then
  run `require(workspace.StealPokemon_Installer.StealPokemon_Install)()` in the
  Command Bar (see the README). It applies the same settings as the place
  file and backs up anything it replaces into ServerStorage.
* **With Rojo:** run `./scripts/setup-tools.sh` once, then `tools/rojo serve`
  and press *Connect* in the Rojo Studio plugin (install it from the Creator
  Store or with `tools/rojo plugin install`). Edits to files under `src/`
  sync live. `./scripts/build.sh` rebuilds the `.rbxl`.

The project file already sets: Players.CharacterAutoLoads = false (the server
spawns characters after data loads), respawn time, camera zoom limits,
gravity, lighting, and creates `ReplicatedStorage.Remotes` and
`ReplicatedStorage.Assets`.

## 2. Game settings (Studio → *Home → Game Settings*)

| Setting | Value |
| --- | --- |
| Security → **Enable Studio Access to API Services** | On (needed for saving in Studio; live servers always have it) |
| Places → server size / **Max Players** | **8** (one per base). `GameConfig.MaxPlayers` and `MapConfig.PlotOrigins` both assume 8. Extra joiners are sent back with a "server full" message. |
| Avatar → **Avatar type** | R15 or R6 both work. |
| Communication → Chat | TextChatService (default) is fine. |

Without API access in Studio the game falls back to an in-memory
`MockDataStore` (a banner in Settings says progress is not saved).

## 3. Monetization (`src/ReplicatedStorage/Shared/Config/MonetizationConfig.luau`)

1. Creator Dashboard → your experience → **Monetization**.
2. Create each **Game Pass** listed under `MonetizationConfig.Gamepasses`
   (VIP, ExtraSlots, FastWalk, CollectorVault, PremiumNameTag, BaseEffects,
   ExclusiveCosmetics) and each **Developer Product** under
   `MonetizationConfig.Products` (CashSmall/Medium/Large, IncomeBoost,
   LuckBoost, ServerLuck, …).
3. Paste each numeric ID into its `Id` field. `PriceHint` is display only —
   the real price is read from Roblox.
4. Items left at `Id = 0` show as "Coming soon" and cannot be purchased.

Test without spending Robux in Studio: `/testproduct CashSmall`,
`/testpass VIP` (and `/testpass VIP off`). Real Studio test purchases through
the Roblox prompt also work once IDs are set.

How purchases stay safe: `MonetizationService` is the only `ProcessReceipt`
handler. Each `PurchaseId` is recorded in the player's saved `Receipts` and
the profile is **saved before** returning `PurchaseGranted`, so a product is
never granted twice and never lost. Gamepass ownership is checked server-side
and cached; `PromptGamePassPurchaseFinished` refreshes it.

## 4. Admins (`src/ServerScriptService/Modules/AdminConfig.luau`)

* Add your Roblox **UserId** to `AdminConfig.UserIds`.
* Optionally set `AdminConfig.Group = { Id = <groupId>, MinRank = 254 }`.
* `StudioEveryoneIsAdmin = true` only affects Studio play-testing.
* `AdminConfig` lives in ServerScriptService, so clients can never read it;
  every command is permission-checked on the server.

## 5. Audio (`SoundConfig.luau`)

All sounds point at files bundled with the Roblox client
(`rbxasset://sounds/...`) so nothing copyrighted ships. Upload your own or
properly licensed audio on the Creator Dashboard and paste
`rbxassetid://<id>` into each `Id`. `SoundConfig.Music.Main/Event` are empty
(no music) until you add tracks. An empty `Id` simply plays nothing.

## 6. Artwork

Cards use live 3D `ViewportFrame` previews of the procedural creature models,
so no images are required. To use your own 2D art for a creature, set
`ImageId` through `LicensedContent` (licensed mode) or add your own field
mapping in `Catalog.luau`. You still need to make your own game icon,
thumbnails and badges.

## 7. Tuning

Every number lives in `src/ReplicatedStorage/Shared/Config/`:

| File | Controls |
| --- | --- |
| `GameConfig` | starting cash/tokens, data store name, autosave, offline income, trading rules, announcements, leaderboards |
| `RarityConfig` | rarity order, colours, spawn weights, steal times, reveal tier, announcements |
| `CollectibleConfig` | every creature (add a table entry to add a creature) |
| `MutationConfig`, `TraitConfig` | mutation/trait chances and multipliers |
| `ConveyorConfig` | spawn rate, speed, item lifetime, luck rules, Elite conveyor gate |
| `UpgradeConfig` | base levels/slots, card levels, defense tracks, storage |
| `RebirthConfig` | rebirth cost curve, multipliers, kept cards, milestones |
| `StealConfig` | grab/carry times, cooldowns, catch range, protection, traps |
| `QuestConfig`, `RewardConfig` | daily quest pool, achievements, daily streak, playtime, collection milestones |
| `EventConfig`, `BoostConfig` | events, rotation, seasonal dates, boosts |
| `ShopConfig`, `CosmeticConfig` | packs (with odds), boost items, event shop, cosmetics |
| `MapConfig` | plot positions, conveyor paths, hub, kiosks, leaderboards |

After changing configs run `./scripts/test.sh` — the config spec catches
configuration errors, broken cross-references and economy curves that stop increasing with rarity.

**Changing the save format?** Bump `DataSchema.Version` and add a migration
function in `DataSchema.Migrations`. Never rename `GameConfig.Data.StoreName`
on a live game unless you intend to wipe everyone's progress.

## 8. Publish checklist

- [ ] Studio API access enabled; tested saving with two sessions.
- [ ] Server size set to 8.
- [ ] All Robux IDs set (or intentionally left "Coming soon").
- [ ] Your UserId in `AdminConfig.UserIds`.
- [ ] Placeholder audio replaced (optional but recommended).
- [ ] `ContentConfig.LicensedMode` is **false** unless you hold a license
      (see [LICENSING.md](LICENSING.md)).
- [ ] Ran `/runtests` in a 2-player local server — all tests pass.
- [ ] Game icon, thumbnails, description and age-rating questionnaire done.
