# Licensing and the "STEAL POKÉMON" title

## What ships in this repository

* **75 original creatures** with original names, descriptions, element names,
  colours and body plans. None are Pokémon or traced from Pokémon.
* **Procedural 3D models** built from Roblox parts at runtime
  (`CreatureBuilder.luau`) — no imported meshes.
* **Original UI and card frames** drawn with Roblox UI objects.
* **Audio:** only sounds bundled with the Roblox client (`rbxasset://sounds/…`).
* **Title:** `ContentConfig.OriginalTitle = "STEAL A CRITTER"`.

Nothing was scraped, ripped, traced or copied from Pokémon games, the TCG,
websites or card scans.

## Why the game is not called "STEAL POKÉMON" by default

"Pokémon", the creature names, card designs, artwork, models, sounds and logos
are trademarks and copyrighted works of Nintendo, Creatures Inc., GAME FREAK
inc. and The Pokémon Company. Using them in a published (especially
monetized) Roblox experience without a license is likely to infringe those
rights and is against Roblox's Terms of Use, and it can get the experience
taken down or the account moderated. This project therefore **does not**
treat unlicensed Pokémon content as safe to publish.

## Switching to licensed content (only with permission)

If you obtain written permission from the rights holders:

1. Upload the licensed artwork, models and audio to **your** Roblox account.
2. Fill `src/ReplicatedStorage/Shared/Config/LicensedContent.luau`. Keys are
   the original creature IDs, values override display data:

   ```lua
   return {
       zapkit = { Name = "<licensed name>", ImageId = "rbxassetid://<id>", Model = "<ModelName>" },
   }
   ```

   * `Name`, `Description` replace text on cards, UI and announcements.
   * `ImageId` replaces the 3D card preview with your uploaded art.
   * `Model` is the name of a Model you put in
     `ReplicatedStorage.Assets.Creatures` (it must have a `PrimaryPart`); it
     replaces the procedural model in bases and on the conveyor.
3. Set `ContentConfig.LicensedMode = true`. The title becomes
   `ContentConfig.LicensedTitle` ("STEAL POKÉMON"), UI text says
   `LicensedCreatureNoun` instead of "Critter", and the overrides apply.
4. Replace audio in `SoundConfig` with licensed audio if desired.

Gameplay data (IDs, prices, rarities, save data) is unaffected by the switch,
so you can turn licensed mode on or off without migrating player saves.

*This document is not legal advice. Get permission in writing and check with
a lawyer before publishing licensed IP.*
