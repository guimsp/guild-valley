# Guild Valley - Game Design & Mechanics Overview

Welcome to the definitive overview of **Guild Valley**, a simulated medieval economy, crafting, and political strategy game. This document details all core systems, math formulas, careers, items, and NPC mechanics current in the game.

---

## 📋 Table of Contents
1. [Game Concept & Core Loop](#-1-game-concept--core-loop)
2. [Careers & Professions](#-2-careers--professions)
3. [All Game Items & Attributes](#-3-all-game-items--attributes)
4. [Recipes Matrix (Production Inputs & Outputs)](#-4-recipes-matrix-production-inputs--outputs)
5. [Buildings & Infrastructure](#-5-buildings--infrastructure)
6. [Marketplace Pricing & Spreads](#-6-marketplace-pricing--spreads)
7. [Nightly Consolidated Cycles](#-7-nightly-consolidated-cycles)
8. [Logistics, Couriers & Warehouses](#-8-logistics-couriers--warehouses)
9. [Real Estate, Housing & Marriage](#-9-real-estate-housing--marriage)
10. [Politics, Laws & Seasons](#-10-politics-laws--seasons)
11. [NPC Systems & Guard Patrols](#-11-npc-systems--guard-patrols)
12. [World Design & Navigation](#-12-world-design--navigation)
13. [Guild Rank Hierarchy & Breakthrough Quests](#-13-guild-rank-hierarchy--breakthrough-quests)
14. [Seasonal Guild Conclave](#-14-seasonal-guild-conclave)
15. [Guild Office Hierarchy Modifiers](#-15-guild-office-hierarchy-modifiers)
16. [Guild Donations & Wholesale Store](#-16-guild-donations--wholesale-store)
17. [Bureaucratic Audits](#-17-bureaucratic-audits)
18. [Decoupled Code Architecture & UI Focus Trapping](#-18-decoupled-code-architecture--ui-focus-trapping)
19. [Province Prosperity, Lot Scaling & Paved Roads](#-19-province-prosperity-lot-scaling--paved-roads)
20. [Wealth Ledger & Inventory Interactions](#-20-wealth-ledger--inventory-interactions)
21. [Character Trait Modifiers & Probabilities](#-21-character-trait-modifiers--probabilities)
22. [Macro Scale Modifier Managers](#-22-macro-scale-modifier-managers)

---

## 🌍 1. Game Concept & Core Loop
Guild Valley simulates a living economic world where the player, AI Rivals, and ambient NPC townspeople interact. The game takes place across multiple provinces (primarily **Valley Province** and **Oakhaven Province**), each containing overworld Cities and Towns.

### The Core Loop
```
Gather Raw Materials ➔ Refine into Semi-Elaborates ➔ Craft Finished Products ➔ Sell in Stalls/Markets ➔ Gain Title & Influence ➔ Dominate Regional Politics
```
- **Gathering**: Collect raw resources from dedicated Town Mega-Nodes.
- **Refinement**: Process raw goods into intermediate components inside specialized workshops.
- **Finished Production**: Manufacture valuable final consumer goods.
- **Trade & Logistics**: Establish automated trade routes with courier employees to move goods between storage nodes.
- **Retail**: Sell goods to ambient consumers at private market stalls or supply public markets.
- **Politics**: Lobby, sponsor, and vote on provincial laws that reshape tax structures and security policies.

---

## 💼 2. Careers & Professions
Characters choose a primary career path. Each career governs specialized gathering nodes, refining benches, final product recipes, and building unlocks. Hired workers gain XP from crafting, leveling up to unlock advanced structures.

| Career | Gather Resource | Gathering Site | Refining Station | Finished Station | Core Sale Product |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Patreon** | Wheat | Wheat Fields | Mill (`flour`) | Bakery (`bread`) | Bread, Alcohol, Events |
| **Craftsman** | Iron Ore, Coal, Copper, Zinc | Mines, Veins, Deposits, Pits | Bloomery Smelter, Alloy Blast Furnace | Blacksmith Forge, Armory, Siege Arsenal, Spire | Iron Bars, Steel, Brass, Tools, Equipment, Bells, Safes |
| **Tailor** | Cotton | Cotton Plants | Loom (`cloth`) | Tailor Table | Cloth, Thread, Clothing |
| **Scholar** | Wild Flax, River Reeds | Flax Fields, Reed Banks | Paper Scriptorium | Scholar Study, Printing Press, Registrar, Bank, Courthouse, Mint | Paper, Deeds, Ledgers, Visas, Contracts, fiat currency |
| **Woodworker** | Raw Log, Raw Hardwood Log | Forests, Groves | Timber Mill, Hardwood Kiln | Carpentry Workshop, Wheelwright Shop, Architecture Atelier, Engineering Guildhall, Spire | Timber, Wooden Pegs, Crates, Wagons, Structural Beams, Trusses |
| **Herbalist** | Wild Herbs, Root, Underground Fungi | Herb Fields, Root Groves, Fungi Caves | Biomass Drying Shed, Acid Still | Apothecary Shop, Infirmary, Conservatory Lab, Sanitarium, Spire | Flora Oil, Pigments, Nitre, Tonics, Salves, Catalysts, Philosopher's Stone |
| **Rogue** | Scraped Metal, Wild Animal Bones, Deadwood Twigs | Scrap Piles, Bone Fields, Twig Patches | Smuggler's Hideout, Thieves' Den (L1-4) | Cutpurse Apartments, Palace Spire | Cudgels, moonshine, pass, security vouchers, squatters writ, safe-conduct |
| **Showman** | Clay Mud, Raw Stone, Marble Block | Riverbanks, Quarries, Deposits | Artisan Atelier, Instrument Workshop, Scenic Design Loft | Busking Stage, Music Salon, Grand Amphitheater, Royal Opera House | Instruments, Statues, Tickets, Costumes, Scenic Backdrops, Opera, Domes |

### Career Building Unlocks
- **Patreon**: Mill, Bakery (Lvl 1) ➔ Farmstead, Tavern, Inn (Lvl 4) ➔ Distillery, Casino, Resort (Lvl 7) ➔ Event Hall (Lvl 8) ➔ Spire (Lvl 10).
- **Rogue**: Smuggler's Hideout, Thieves' Den L1 (Lvl 1) ➔ Thieves' Den L2, Thieves' Den L3, Informant Lookout, Cutpurse Apartments L1-2 (Lvl 4-5) ➔ Thieves' Den L4, Crime Syndicate HQ L1-2, Shadow Broker's Ring (Lvl 7-9) ➔ Black Market Palace Spire (Lvl 10).
- **Craftsman**: Bloomery Smelter, Blacksmith Forge (Lvl 1) ➔ Alloy Blast Furnace, Armory (Lvl 4) ➔ Imperial Siege Arsenal (Lvl 7), Imperial Ordnance Foundry (Lvl 8) ➔ Imperial Ironworks Spire (Lvl 10).
- **Tailor**: Loom, Tailor Table.
- **Scholar**: Paper Scriptorium, Registrar Office (Lvl 1) ➔ Scholar Study, Type-Setting Press, Provincial Bank (Lvl 4) ➔ Grand Courthouse (Lvl 7) ➔ Sovereign Mint, Library (Lvl 10).
- **Woodworker**: Timber Mill, Carpentry Workshop (Lvl 1) ➔ Hardwood Kiln, Wheelwright Shop (Lvl 4) ➔ Architecture Atelier (Lvl 7) ➔ Civil Engineering Guildhall (Lvl 8) ➔ Citadel Engineering Spire (Lvl 10).
- **Herbalist**: Biomass Drying Shed, Apothecary Shop (Lvl 1) ➔ Acid Crucible & Still, Infusion Infirmary (Lvl 4) ➔ Conservatory Lab (Lvl 7) ➔ Imperial Sanitarium (Lvl 8) ➔ Alchemical Greenhouse Spire (Lvl 10).
- **Showman**: Artisan Atelier, Busking Stage L1 (Lvl 1) ➔ Busking Stage L2, Instrument Workshop L1, Music Salon L1 (Lvl 3-4) ➔ Busking Stage L3, Music Salon L2, Scenic Design Loft L1 (Lvl 6-7) ➔ Busking Stage L4, Scenic Design Loft L2, Grand Amphitheater L1 (Lvl 8-9) ➔ Royal Opera House (Lvl 10).

---

## 🎒 3. All Game Items & Attributes
Items are defined as `.tres` custom resource instances of the `ItemData` class. Each item carries specific attributes that govern its price elasticity, weight, equipment stats, and trade behavior.

### Item Attributes
- **Item ID (`id`)**: Unique string key used in code, dictionary mappings, and inventories.
- **Display Name (`name`)**: Localized, user-facing label shown in the UI.
- **Base Market Value (`base_value`)**: Base price in gold before dynamic supply and demand adjustments.
- **Min / Max Price (`min_price` / `max_price`)**: Hard clamping boundaries preventing prices from crashing to 0 or ballooning infinitely.
- **Weight (`weight`)**: The mass of a single item unit. Couriers and player inventories have strict weight capacities.
- **Equipment Slot (`equipment_slot`)**: Specifies if the item can be slotted onto a Character (Body, Gloves, Tool, Weapon, Head, Bag, Necklace, Ring, Transportation).
- **Equipment Stats**: Boosts applied to characters when slotted (Armor, Attack, Speed multipliers, Inventory capacity bonuses, Gathering yield multipliers, Durability).

### A. Raw Materials
These items represent raw extractions harvested directly from megastops, crop nodes, or base production.
| Item ID | Display Name | Base Value | Weight | Rarity | Slot | Stats / Description |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `aging_barrel` | Aging Barrels | 20 G | 3.0 | Common | None | A heavy oak barrel used to age alcohol and enhance quality. |
| `apple` | Apples | 3 G | 0.2 | Common | None | Sweet red apples, picked from local orchards. |
| `barley_and_hops` | Barley and Hops | 6 G | 0.2 | Common | None | Grown barley grains and bitter hops blossoms, used to brew ale. |
| `berries` | Berries | 4 G | 0.1 | Common | None | Plump wild forest berries. |
| `clay_mud` | Clay Mud | 3 G | 0.5 | Common | None | Wet clay mud harvested from local riverbanks. |
| `cotton` | Cotton | 8 G | 0.5 | Common | None |  |
| `deadwood_twigs` | Deadwood Twigs | 4 G | 0.2 | Common | None | Universal Ground Scavenge. Twigs harvested from old wood. |
| `egg` | Eggs | 2 G | 0.1 | Common | None | Fresh farm eggs, used in many baking recipes. |
| `grapes` | Grapes | 6 G | 0.1 | Common | None | Bunches of sweet red grapes harvested from vineyards. |
| `honey` | Sweet Honey | 8 G | 0.2 | Common | None | Pure sweet honey gathered from local beehives. |
| `iron_ore` | Iron Ore | 10 G | 2.0 | Common | None |  |
| `marble_block` | Marble Block | 25 G | 4.0 | Common | None | Premium marble blocks harvested from rare deposits. |
| `milk` | Milk | 4 G | 0.5 | Common | None | A pail of fresh cows' milk. |
| `overworld_root` | Overworld Root | 5 G | 0.2 | Common | None | Gnarled overworld roots rich in pigments and compounds. |
| `premium_flask` | Premium Flasks | 12 G | 0.3 | Common | None | A refined, sturdy glass bottle container used to package fine spirits. |
| `raw_stone` | Raw Stone | 5 G | 2.0 | Common | None | Raw stone blocks harvested from quarries. |
| `raw_wild_herbs` | Raw Wild Herbs | 5 G | 0.1 | Common | None | Freshly harvested wild herbs. |
| `river_reeds` | River Reeds | 6 G | 0.3 | Common | None | Reedy fibers harvested from marshes, perfect for drafting paper. |
| `scraped_metal` | Scraped Metal | 4 G | 0.5 | Common | None | Universal Overworld Salvage. Scrap metal gathered from overworld highways. |
| `seed_packet` | Seed Packets | 2 G | 0.1 | Common | None | A standard agricultural packet containing crop seeds. |
| `spice_grubs` | Concentrated Spice Grubs | 35 G | 0.2 | Common | None | Spicy dried grubs, used as an exotic culinary flavor booster. |
| `sugar` | Sugar | 5 G | 0.1 | Common | None | Sweet granulated sugar, used for confectionary cooking. |
| `underground_fungi` | Underground Fungi | 15 G | 0.3 | Common | None | Rare subterranean fungi containing pure sulfur and volatile compounds. |
| `sunflower` | Sunflower | 3 G | 0.1 | Common | None | Bright sunflower head containing seeds, used to press oil. |
| `venison` | Venison Meat | 10 G | 1.0 | Common | None | Lean red meat hunted from local wild deer. |
| `water` | Water | 1 G | 0.5 | Common | None | A bucket of fresh clean water. |
| `wheat` | Wheat | 5 G | 0.2 | Common | None |  |
| `wild_animal_bones` | Wild Animal Bones | 4 G | 0.2 | Common | None | Overworld Scavenge. Bones harvested from wild beasts. |
| `wild_flax` | Wild Flax | 8 G | 0.2 | Common | None | Tough wild flax fibers used for papermaking and binding. |


### B. Semi-Elaborate
Intermediate components processed in mills, smelters, and looms, which act as inputs for finished products.
| Item ID | Display Name | Base Value | Weight | Rarity | Slot | Stats / Description |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `cloth` | Cloth | 30 G | 1.0 | Common | None |  |
| `artist_canvas` | Artist Canvas | 15 G | 0.5 | Common | None | A basic canvas stretched over a frame for painting or drafting. |
| `chemical_solvent` | Chemical Solvent | 45 G | 0.5 | Common | None | Highly concentrated alchemical solvent. |
| `concentrated_dyes` | Concentrated Dyes | 35 G | 0.2 | Common | None | Vibrant concentrated pigment from rare plants. |
| `corrosive_acid` | Corrosive Acid | 30 G | 0.3 | Common | None | A highly reactive acidic compound inside a glass jar. |
| `dried_shives` | Dried Shives | 8 G | 0.2 | Common | None | Dehydrated herbs used as a chemical substrate. |
| `fine_pigments` | Fine Pigments | 10 G | 0.2 | Common | None | Finely ground colorful pigments used for paints. |
| `flour` | Flour | 12 G | 0.3 | Common | None |  |
| `flora_oil` | Flora Oil | 12 G | 0.5 | Common | None | Pressed berry oil used as a solvent base in compounding. |
| `heavy_steel_tools` | Heavy Steel Tools | 80 G | 1.5 | Common | None | Heavy-duty steel tools for woodworking and carpentry. |
| `inkwell` | Inkwell | 20 G | 0.2 | Common | None | Dark soot ink in a glass well, essential for legal and academic works. |
| `instrument_strings` | Instrument Strings | 30 G | 0.1 | Common | None | High-quality strings drawn from animal hides. |
| `iron_ingot` | Iron Ingot | 40 G | 5.0 | Common | None |  |
| `nitre_powder` | Nitre Powder | 30 G | 0.4 | Common | None | Refined mineral compounding agent. |
| `oil` | Oil | 12 G | 0.4 | Common | None | Pressed sunflower oil used for cooking and medicine. |
| `paper` | Paper | 15 G | 0.1 | Common | None |  |
| `parchment_sheet` | Parchment Sheet | 25 G | 0.1 | Common | None | Scraped and treated animal skin sheet for high-durability documents. |
| `printing_plate` | Printing Plate | 50 G | 1.0 | Common | None | Carved wooden block with movable type characters for printing. |
| `pure_sulfur` | Pure Sulfur | 40 G | 0.5 | Common | None | Refined sulfur powder extracted from fungi. |
| `raw_pigment_powder` | Raw Pigment Powder | 10 G | 0.2 | Common | None | Crushed root pigments used in dyes. |
| `refined_clay` | Refined Clay | 10 G | 0.5 | Common | None | Purified pottery clay ready for molding instruments. |
| `spool_thread` | Spool of Thread | 10 G | 0.1 | Common | None | Finely spun thread ready for weaving. |
| `standard_timber` | Standard Timber | 15 G | 1.0 | Common | None | Milled and squared timber ready for construction. |
| `tumbler_locks` | Tumbler Locks | 40 G | 0.4 | Common | None | Intricately machined tumbler lock mechanism. |
| `unsigned_bond` | Unsigned Bond | 30 G | 0.2 | Common | None | A blank financial ledger awaiting signatures to authorize credits. |


### C. Finished Goods
Finished high-value commodities ready for consumer transactions, event certification, or services.
| Item ID | Display Name | Base Value | Weight | Rarity | Slot | Stats / Description |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `active_debt_ledger` | Active Debt Ledger | 250 G | 0.3 | Common | None | An active lending contract returning high-interest payouts over time. |
| `ale` | Ale | 22 G | 0.6 | Common | None | A refreshing pint of tavern ale. |
| `ancient_manuscript` | Ancient Manuscript | 0 G | 0.5 | Common | None | A delicate and historic text bound in leather. |
| `animal_feed` | Animal Feed | 6 G | 1.0 | Common | None | A bale of processed hay and wheat, used to feed farm animals. |
| `antitoxin_serum` | Anti-Toxin Serum | 120 G | 0.4 | Common | None | A potent serum that neutralizes toxic compounds. |
| `apothecary_sweet_bun` | Apothecary's Sweet Bun | 30 G | 0.4 | Common | None | A bun baked with honey and sunflower oil, offering subtle restorative properties. |
| `archduke_treatment_contract` | Archduke Treatment Contract | 0 G | 0.1 | Common | None | A contract to treat the Archduke's illness. |
| `baked_apples` | Baked Apples | 14 G | 0.3 | Common | None | Apples roasted with sugar. Sweet and aromatic. |
| `blank_profession_book` | Apprenticeship Tome | 80 G | 0.5 | Common | None | An Apprenticeship Tome bound with fine string, ready for academic recordings. |
| `book` | Book | 45 G | 0.5 | Common | None | A standard bound book. |
| `bread` | Bread | 25 G | 0.5 | Common | None | Freshly baked bread. |
| `busking_ticket` | Busking Ticket | 30 G | 0.0 | Common | None | A ticket certifying execution of a local street recital. |
| `casino_voucher` | Casino High-Roller Voucher | 60 G | 0.0 | Common | None | A high-roller voucher representing casino game services. |
| `central_banking_charter` | Central Banking Charter | 600 G | 0.5 | Rare | None | A masterwork charter authorizing regional fiat currency controls. |
| `common_wine` | Common Wine | 38 G | 0.6 | Luxury | None | Simple fermented grape wine, popular in taverns. |
| `concert_ticket` | Concert Ticket | 80 G | 0.0 | Common | None | A ticket certifying execution of a formal chamber concert recital. |
| `confidential_documents` | Confidential Documents | 0 G | 0.3 | Common | None | Sensible papers sealed with dark wax. |
| `crop_blight_contract` | Crop Blight Contract | 0 G | 0.1 | Common | None | A contract to eradicate crop blight in the province. |
| `cured_pork` | Cured Pork | 35 G | 1.2 | Common | None | Pork cured with salt and dried, ideal for storage. |
| `defaulted_estate_contract` | Defaulted Estate Contract | 350 G | 0.1 | Common | None | A state contract authorizing the liquidation of a bankrupt property. |
| `draught_of_infinity` | Draught of Infinity | 2000 G | 0.5 | Rare | None | A legendary draught of limitless alchemical energy. |
| `entertainment_ticket` | Entertainment Ticket | 50 G | 0.0 | Common | None | A ticket representing tavern entertainment service. |
| `fiat_currency_matrix` | Fiat Currency Matrix | 800 G | 1.5 | Rare | None | An engraved printing plate representing official sovereign currency. |
| `fine_aged_schnapps` | Fine Aged Schnapps | 95 G | 0.8 | Luxury | None | A premium spirit infused with wild berries and aged in oak barrels. |
| `gilded_cream_cake` | Gilded Cream Cake | 45 G | 0.8 | Luxury | None | An exquisite cream cake topped with sugar glaze, fit for nobility. |
| `grand_stage_set` | Grand Stage Set | 450 G | 10.0 | Common | None | A massive assembled stage set for theatrical tragedies and pageants. |
| `healing_salve` | Healing Salve | 65 G | 0.4 | Common | None | A soothing salve that cures minor ailments. |
| `imperial_trade_charter` | Imperial Trade Charter | 200 G | 0.2 | Common | None | A royal charter granting exclusive trade rights for specific resources. |
| `land_deed` | Land Deed | 120 G | 0.1 | Common | None | A legally certified document proving ownership of real estate. |
| `lethal_poison_base` | Lethal Poison Base | 220 G | 0.4 | Common | None | A highly concentrated toxic compound. |
| `masterwork_folio` | Masterwork Folio | 300 G | 1.2 | Common | None | A leather-bound masterwork book highlighting historical and scientific logs. |
| `masterpiece_opera_partiture` | Masterpiece Opera Partiture | 1200 G | 0.5 | Common | None | A masterpiece opera partiture composition sheet, of immense prestige. |
| `meadhaven` | Meadhaven | 32 G | 0.5 | Common | None | A sweet honey wine brewed with select barley grains. |
| `monopoly_defense_contract` | Monopoly Defense Contract | 400 G | 0.1 | Common | None | A defense contract securing royal protection for exclusive trade rights. |
| `monumental_acoustic_dome` | Monumental Acoustic Dome | 2000 G | 20.0 | Common | None | A massive architectural masterpiece acoustical dome physically required to upgrade civic hubs. |
| `noble_event_certificate` | Noble Event Certificate | 250 G | 0.0 | Common | None | A certificate confirming execution of a Noble Event service. |
| `noble_statue` | Noble Statue | 280 G | 8.0 | Common | None | A sculpted marble statue of a prominent noble. |
| `philosophers_stone` | Philosopher's Stone | 2500 G | 1.0 | Rare | None | A legendary catalyst capable of transmutation. |
| `plaster_bust` | Plaster Bust | 120 G | 5.0 | Common | None | A plaster bust representing high society aesthetics. |
| `registry_ledger` | Registry Ledger | 100 G | 0.8 | Common | None | A compiled directory of citizens and businesses in a settlement. |
| `restoration_flask` | Restoration Flask | 180 G | 0.5 | Common | None | A flask of rejuvenation liquid that cures diseases. |
| `royal_event_certificate` | Royal Event Certificate | 600 G | 0.0 | Common | None | A certificate confirming execution of a Royal Event service. |
| `royal_venison_pasty` | Royal Venison Pasty | 55 G | 0.8 | Common | None | A hearty meat pie filled with venison and baked in pastry crust. |
| `savory_baked_eggs` | Savory Baked Eggs | 12 G | 0.2 | Common | None | Eggs baked in hot coals with herbs. Simple yet satisfying. |
| `scenic_backdrop` | Scenic Backdrop | 160 G | 4.0 | Common | None | A large painted theatrical backdrop representing landscapes or palaces. |
| `sheet_music` | Sheet Music | 35 G | 0.1 | Common | None | A score of musical sheet music used as tutoring guides. |
| `signed_affidavit` | Signed Affidavit | 140 G | 0.1 | Common | None | A legal statement signed under oath, used to resolve local audits. |
| `smugglers_moonshine` | Smuggler's Moonshine | 65 G | 0.5 | Common | None | Strong illicit liquor brewed with farmstead grains and sugar. |
| `stamina_draught` | Stamina Draught | 25 G | 0.4 | Common | None | A refreshing herbal tonic that restores worker stamina. |
| `sweet_berry_cake` | Sweet Berry Cake | 24 G | 0.6 | Common | None | A moist cake topped with sweet forest berries. |
| `taproom_ticket` | Taproom Ticket | 30 G | 0.0 | Common | None | A ticket representing tavern taproom service. |
| `tax_exemption_writ` | Tax Exemption Writ | 160 G | 0.1 | Common | None | An official decree exempting a business from property taxes. |
| `trade_passport` | Regional Trade Passport | 150 G | 0.1 | Common | None | An official visa permitting free passage across regional borders. |
| `venture_certificate` | Venture Certificate | 300 G | 0.2 | Common | None | A certificate representing dynamic corporate shares in high-value guilds. |
| `void_catalyst` | Void Catalyst | 400 G | 0.5 | Rare | None | An extremely volatile chemical catalyst. |


### D. Equipment
Items that can be slotted into employee or player slots to improve physical attributes.
| Item ID | Display Name | Base Value | Weight | Rarity | Slot | Stats / Description |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `bandits_pass` | Bandit's Pass | 1200 G | 0.2 | Common | Necklace | Underworld safe-conduct pass granting bandit ambush immunity. |
| `bronze_pickaxe` | Bronze Pickaxe | 60 G | 2.5 | Common | Tool | **[Gather Yield: +25%]**  |
| `brass_horn` | Brass Horn | 150 G | 2.0 | Common | Weapon | **[Attack: +6]** An equippable brass horn used as a weapon or to perform chamber recitals. |
| `cart` | Cart | 250 G | 30.0 | Common | Transportation | **[Inventory Cap: +8]**  |
| `clay_flute` | Clay Flute | 25 G | 0.4 | Common | Tool | **[Is Tool]** A clay flute, equippable as a tool and used to boost street performance recitals. |
| `concealed_liner_bag` | Concealed Liner Bag | 50 G | 1.0 | Common | Bag | **[Inventory Cap: +2]** Protects cargo against heavy losses during bandit ambushes. |
| `flash_powder_bomb` | Flash Powder Bomb | 80 G | 0.5 | Common | Tool | Automatically consumed to escape arrest if caught during pickpocketing. |
| `festival_mask` | Festival Mask | 45 G | 0.3 | Common | Head | A colorful mask worn during solstice festivals. |
| `gold_ring` | Gold Ring | 150 G | 0.05 | Common | Ring | **[Attack: +3, Speed: +5%]**  |
| `horse` | Horse | 300 G | 50.0 | Common | Transportation | **[Speed: +50%]**  |
| `iron_chestplate` | Iron Chestplate | 120 G | 8.0 | Common | Body | **[Armor: +15]**  |
| `iron_helmet` | Iron Helmet | 50 G | 2.0 | Common | Head | **[Armor: +5]**  |
| `iron_sword` | Iron Sword | 90 G | 3.0 | Common | Weapon | **[Attack: +10]**  |
| `leather_backpack` | Leather Backpack | 45 G | 1.0 | Common | Bag | **[Inventory Cap: +4]**  |
| `leather_gloves` | Leather Gloves | 35 G | 0.5 | Common | Gloves | **[Armor: +2, Speed: +5%]**  |
| `masterwork_lute` | Masterwork Lute | 180 G | 1.5 | Common | Weapon | **[Attack: +5]** An equippable masterwork lute used as a weapon or to perform chamber recitals. |
| `poisoned_dagger` | Poisoned Dagger | 120 G | 0.5 | Common | Weapon | **[Attack: +15]** Guarantees escape from arrest in low-to-mid security zones. |
| `royal_regalia` | Royal Regalia | 250 G | 2.5 | Common | Body | **[Armor: +8]** A magnificent royal outfit fit for kings and emperors. |
| `silver_necklace` | Silver Necklace | 80 G | 0.1 | Common | Necklace | **[Speed: +10%]**  |
| `street_cudgel` | Street Cudgel | 25 G | 1.5 | Common | Weapon | **[Attack: +3]** Used by employees to carry out basic pickpocketing operations. |


### E. Skill Items
Special training manuals that permanently teach employees new traits.
| Item ID | Display Name | Base Value | Weight | Rarity | Slot | Stats / Description |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `book_fleet_footed` | Fleet Footed Guide | 500 G | 0.5 | Rare | None | Permanently teaches an employee the Fleet-Footed_Lvl1 trait. |
| `book_industrious` | Industrious Guide | 500 G | 0.5 | Rare | None | Permanently teaches an employee the Industrious_Lvl1 trait. |
| `book_sturdy` | Sturdy Guide | 500 G | 0.5 | Rare | None | Permanently teaches an employee the Sturdy_Lvl1 trait. |


---

## 🍳 4. Recipes Matrix (Production Inputs & Outputs)
The recipes are compiled directly from the central recipe resource files and illustrate the raw-to-finished production sequences:
| Recipe Name | Inputs (Ingredients) | Output Product | Required Career | Level | XP Reward |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Smelt Iron Ore | 3x Iron Ore | 1x Iron Ingot | Craftsman | Lvl 1 | +12 XP |
| Grind Wild Grains | 1x Wild Grains | 1x Sifted Flour | Patreon | Lvl 1 | +10 XP |
| Mill Coarse Animal Feed | 1x Wild Grains | 2x Coarse Animal Feed | Patreon | Lvl 1 | +8 XP |
| Bake Hearth Bread | 1x Sifted Flour, 1x Water | 1x Hearth Bread | Patreon | Lvl 1 | +12 XP |
| Bake Savory Eggs | 2x Riverbank Eggs | 1x Savory Baked Eggs | Patreon | Lvl 1 | +10 XP |
| Bake Orchard Apples | 2x Wild Apples | 1x Baked Apples | Patreon | Lvl 1 | +10 XP |
| Bake Sweet Berry Cake | 1x Sifted Flour, 1x Riverbank Eggs, 1x Wild Berries | 1x Sweet Berry Cake | Patreon | Lvl 3 | +25 XP |
| Bake Herb-Sweetened Bun | 1x Sifted Flour, 1x Flora Oil, 1x Wild Honey | 1x Herb-Sweetened Bun | Patreon | Lvl 3 | +30 XP |
| Bake Gilded Cream Cake | 1x Sifted Flour, 1x Riverbank Eggs, 1x Rare Sugar-Beet Extract | 1x Gilded Cream Cake | Patreon | Lvl 6 | +45 XP |
| Bake Royal Venison Pasty | 1x Sifted Flour, 1x Flora Oil, 1x Game Venison | 1x Royal Venison Pasty | Patreon | Lvl 6 | +50 XP |
| Harvest Barley & Hops | 1x Seed Packets | 3x Brewing Hops | Patreon | Lvl 4 | +15 XP |
| Cure Smokehouse Pork | 3x Coarse Animal Feed | 1x Cured Pork Slab | Patreon | Lvl 4 | +25 XP |
| Tan Raw Pelts | 2x Wild Animal Hides | 2x Tanned Leather Strips | Patreon | Lvl 4 | +20 XP |
| Ferment House Ale | 2x Brewing Hops, 1x Water | 1x House Ale | Patreon | Lvl 4 | +20 XP |
| Blend Sweet Meadhaven | 1x Brewing Hops, 1x Wild Honey | 1x Meadhaven Brew | Patreon | Lvl 4 | +25 XP |
| Tavern Taproom Service | 1x House Ale | 1x Taproom Ticket | Patreon | Lvl 4 | +20 XP |
| Traveler Lodging Quarters | 1x Savory Baked Eggs | None | Patreon | Lvl 4 | +25 XP |
| Grand Casino Lounge | 1x Stage Costume | 1x Casino High-Roller Voucher | Patreon | Lvl 7 | +50 XP |
| Ferment Common Wine | 2x Vineyard Grapes, 1x Water | 1x Common Wine Roll | Patreon | Lvl 7 | +40 XP |
| Distill Moonshine Vats | 1x Brewing Hops, 1x Rare Sugar-Beet Extract | 1x Smuggler's Moonshine | Patreon | Lvl 7 | +45 XP |
| Distill Fine Aged Schnapps | 2x Brewing Hops, 1x Wild Berries, 1x Cargo Keg | 1x Fine Aged Schnapps | Patreon | Lvl 9 | +75 XP |
| Host Noble Merchant Gala | 5x Savory Baked Eggs, 5x Baked Apples, 5x House Ales | 1x Noble Event Certificate | Patreon | Lvl 8 | +80 XP |
| Host Royal Sovereign Banquet | 5x Sweet Berry Cake, 5x Gilded Cream Cake, 5x Common Wine Roll, 5x Fine Aged Schnapps | 1x Royal Event Certificate | Patreon | Lvl 8 | +150 XP |
| Arrange Sovereign Ambush Banquet | 4x Royal Venison Pasties, 4x Gilded Cream Cakes, 2x Concentrated Spice Grubs | 1x Sovereign Banquet | Patreon | Lvl 10 | +350 XP |
| Distill Vintage Sovereign Nectar | 10x Common Wine Rolls, 4x Fine Aged Schnapps | 1x Vintage Sovereign Nectar | Patreon | Lvl 10 | +400 XP |
| Press Hemp Paper | 2x Wild Flax | 2x Paper | Scholar | Lvl 1 | +10 XP |
| Boil Soot Ink | 1x Charcoal, 1x Water | 1x Inkwell | Scholar | Lvl 1 | +10 XP |
| Scrape Parchment | 1x Wild Animal Hides | 2x Parchment Sheet | Scholar | Lvl 1 | +15 XP |
| Draft Basic Property Deed | 1x Parchment Sheet, 1x Inkwell | 1x Land Deed | Scholar | Lvl 1 | +20 XP |
| Compile Registry Ledger | 2x Paper, 1x Inkwell | 1x Registry Ledger | Scholar | Lvl 1 | +20 XP |
| Bind Apprenticeship Tome | 4x Paper, 1x Inkwell, 1x Leather Grip | 1x Apprenticeship Tome | Scholar | Lvl 1 | +30 XP |
| Local Tax Assessment | 1x Registry Ledger | None (Service Desk) | Scholar | Lvl 1 | +25 XP |
| Draft Architectural Blueprint | 2x Paper, 1x Inkwell | 1x Architectural Blueprint | Scholar | Lvl 4 | +35 XP |
| Compile Masterwork Folio | 1x Apprenticeship Tome, 2x Inkwell, 1x Gold Leaf | 1x Masterwork Folio | Scholar | Lvl 4 | +50 XP |
| Forge Regional Trade Passport | 1x Parchment Sheet, 1x Inkwell, 1x Signed Affidavit | 1x Regional Trade Passport | Scholar | Lvl 4 | +40 XP |
| Carve Movable Type | 1x Refined Hardwood, 1x Iron Nails | 1x Printing Plate | Scholar | Lvl 4 | +20 XP |
| Press Promissory Ledger | 1x Paper, 1x Printing Plate | 2x Unsigned Bond | Scholar | Lvl 4 | +25 XP |
| Print Legal Affidavit | 1x Unsigned Bond, 1x Inkwell, 1x Printing Plate | 1x Signed Affidavit | Scholar | Lvl 4 | +30 XP |
| Seal Tax Exemption Writ | 1x Unsigned Bond, 1x Inkwell, 1x Signed Affidavit | 1x Tax Exemption Writ | Scholar | Lvl 4 | +45 XP |
| Craft Imperial Trade Charter | 1x Parchment Sheet, 1x Inkwell, 1x Signed Affidavit | 1x Imperial Trade Charter | Scholar | Lvl 4 | +40 XP |
| Corporate Licensing Desk | 1x Imperial Trade Charter | None (Service Desk) | Scholar | Lvl 4 | +45 XP |
| Issue High-Interest Loan | 1x Unsigned Bond (+100 G) | 1x Active Debt Ledger (+180 G) | Scholar | Lvl 7 | +60 XP |
| Underwrite Corporate Share | 1x Unsigned Bond, 1x Printing Plate | 1x Venture Certificate | Scholar | Lvl 7 | +70 XP |
| Contract: Liquidate Defaulted Estate | 1x Land Deed, 1x Signed Affidavit | 1x Defaulted Estate Contract | Scholar | Lvl 8 | +100 XP |
| Contract: Royal Monopoly Defense | 1x Imperial Trade Charter, 1x Signed Affidavit | 1x Monopoly Defense Contract | Scholar | Lvl 8 | +120 XP |
| Engrave Central Banking Charter | 1x Masterwork Folio, 1x Venture Certificate, 2x Gold Leaf | 1x Central Banking Charter | Scholar | Lvl 10 | +200 XP |
| Print Imperial Currency Decree | 1x Central Banking Charter, 1x Printing Plate | 1x Fiat Currency Matrix | Scholar | Lvl 10 | +250 XP |
| Weave Cotton to Cloth | 3x Cotton | 1x Cloth | Tailor | Lvl 1 | +10 XP |
| Saw Timber | 1x Raw Log | 2x Standard Timber | Woodworker | Lvl 1 | +10 XP |
| Chop Firewood | 1x Raw Log | 3x Firewood | Woodworker | Lvl 1 | +8 XP |
| Shave Wooden Pegs | 1x Standard Timber | 4x Wooden Pegs | Woodworker | Lvl 1 | +8 XP |
| Assemble Basic Crate | 2x Standard Timber, 4x Wooden Pegs | 1x Basic Crate | Woodworker | Lvl 1 | +20 XP |
| Carve Tool Handles | 1x Standard Timber | 2x Tool Handle | Woodworker | Lvl 1 | +10 XP |
| Craft Cargo Keg | 2x Standard Timber, 1x Iron Bands | 1x Cargo Keg | Woodworker | Lvl 2 | +25 XP |
| Build Loom Frame | 3x Standard Timber, 4x Wooden Pegs | 1x Loom Frame | Woodworker | Lvl 2 | +25 XP |
| Construct Shipping Crate | 4x Standard Timber, 1x Basic Crate, 2x Iron Nails | 1x Shipping Crate | Woodworker | Lvl 3 | +45 XP |
| Carve Ornate Fittings | 2x Refined Hardwood, 1x Industrial Varnish | 1x Ornate Fittings | Woodworker | Lvl 4 | +55 XP |
| Cure Hardwood | 2x Raw Hardwood Log, 1x Firewood | 2x Refined Hardwood | Woodworker | Lvl 4 | +30 XP |
| Burn Industrial Charcoal | 3x Firewood | 2x Charcoal | Woodworker | Lvl 2 | +15 XP |
| Build Reinforced Wheel | 2x Refined Hardwood, 1x Iron Bands | 1x Reinforced Wheel | Woodworker | Lvl 4 | +20 XP |
| Assemble Handcart | 2x Standard Timber, 1x Reinforced Wheel | 1x Handcart | Woodworker | Lvl 4 | +25 XP |
| Local Hauling Service | None (Handcart Booster) | None | Woodworker | Lvl 4 | +20 XP |
| Construct Freight Wagon | 4x Refined Hardwood, 4x Reinforced Wheel, 2x Heavy Chain | 1x Freight Wagon | Woodworker | Lvl 7 | +50 XP |
| Imperial Transit Service | None (Freight Wagon Booster) | None | Woodworker | Lvl 7 | +35 XP |
| Mill Advanced Structural Beam | 3x Refined Hardwood, 1x Waterproofing Tar | 1x Advanced Structural Beam | Woodworker | Lvl 7 | +40 XP |
| Frame Modular Wing | 4x Refined Hardwood, 1x Ornate Fittings, 1x Architectural Blueprint | 1x Modular Wing | Woodworker | Lvl 7 | +60 XP |
| Carve Heavy Scaffolding | 6x Refined Hardwood, 2x Advanced Structural Beam | 1x Heavy Scaffolding | Woodworker | Lvl 9 | +80 XP |
| Contract: Bridge Reconstruction | 5x Advanced Structural Beam, 5x Heavy Scaffolding | 1x Bridge Reconstruction Contract | Woodworker | Lvl 8 | +150 XP |
| Contract: Palace Remodeling | 4x Modular Wing, 4x Ornate Fittings, 2x Fine Linens | 1x Palace Remodeling Contract | Woodworker | Lvl 8 | +200 XP |
| Forge Vault Door | 5x Advanced Structural Beam, 2x Imperial Vault Safe | 1x Masterwork Vault Door | Woodworker | Lvl 10 | +250 XP |
| Erect Monumental Trusses | 10x Advanced Structural Beam, 4x Heavy Scaffolding | 1x Monumental Truss | Woodworker | Lvl 10 | +300 XP |
| Press Flora Oil | 2x Berries | 1x Flora Oil | Herbalist | Lvl 1 | +10 XP |
| Dehydrate Herbs | 2x Raw Wild Herbs | 2x Dried Shives | Herbalist | Lvl 1 | +8 XP |
| Crush Root Pigment | 1x Overworld Root | 2x Raw Pigment Powder | Herbalist | Lvl 1 | +10 XP |
| Brew Stamina Draught | 1x Dried Shives, 1x Water | 1x Stamina Draught | Herbalist | Lvl 1 | +12 XP |
| Mix Wood Varnish | 1x Flora Oil, 1x Dried Shives | 1x Industrial Varnish | Herbalist | Lvl 1 | +10 XP |
| Distill Concentrated Dye | 2x Raw Pigment Powder, 1x Flora Oil | 1x Concentrated Dyes | Herbalist | Lvl 2 | +25 XP |
| Mix Nitre Compound | 2x Dried Shives, 1x Charcoal | 1x Nitre Powder | Herbalist | Lvl 2 | +20 XP |
| Refine Soothing Salve | 2x Flora Oil, 1x Sweet Honey | 1x Healing Salve | Herbalist | Lvl 3 | +45 XP |
| Brew Alchemical Acid | 2x Nitre Powder, 1x Flora Oil | 1x Corrosive Acid | Herbalist | Lvl 4 | +60 XP |
| Refine Vitriol Solvent | 2x Nitre Powder, 1x Firewood | 2x Chemical Solvent | Herbalist | Lvl 4 | +18 XP |
| Extract Sulfur Pods | 2x Underground Fungi | 1x Pure Sulfur | Herbalist | Lvl 4 | +15 XP |
| Mix Anti-Toxin | 1x Chemical Solvent, 1x Dried Shives | 1x Anti-Toxin Serum | Herbalist | Lvl 4 | +25 XP |
| Local Apothecary Clinic | None (Anti-Toxin Serum Booster) | None | Herbalist | Lvl 4 | +25 XP |
| Formulate Rejuvenation Tonic | 2x Chemical Solvent, 1x Healing Salve | 1x Restoration Flask | Herbalist | Lvl 5 | +50 XP |
| Provincial Sanitarium Desk | None (Restoration Flask Booster) | None | Herbalist | Lvl 5 | +50 XP |
| Blend Poison Base | 1x Corrosive Acid, 1x Pure Sulfur | 1x Lethal Poison Base | Herbalist | Lvl 7 | +45 XP |
| Extract Exotic Spices | 2x Underground Fungi, 1x Flora Oil | 1x Concentrated Spice Grubs | Herbalist | Lvl 7 | +50 XP |
| Synthesize Void Catalyst | 2x Chemical Solvent, 1x Lethal Poison Base | 1x Void Catalyst | Herbalist | Lvl 8 | +90 XP |
| Crop Blight Contract | 4x Chemical Solvent, 4x Nitre Powder, 2x Advanced Structural Beam | 1x Crop Blight Contract | Herbalist | Lvl 8 | +150 XP |
| Archduke Treatment Contract | 2x Restoration Flask, 2x Concentrated Spice Grubs, 1x Fine Ledger | 1x Archduke Treatment Contract | Herbalist | Lvl 8 | +200 XP |
| Distill Eternal Restlessness | 4x Restoration Flask, 2x Void Catalyst | 1x Draught of Infinity | Herbalist | Lvl 10 | +350 XP |
| Transmute Philosopher's Catalyst | 5x Pure Sulfur, 5x Corrosive Acid, 1x Monumental Truss | 1x Philosopher's Stone | Herbalist | Lvl 10 | +400 XP |
| Assemble Street Performer Kit | 1x Transit Pass, 1x Burlap Cloth Bolt | 1x Performer's Disguise Kit | Rogue | Lvl 3 | +25 XP |
| Carve Bone Buttons | 2x Wild Animal Bones | 4x Polished Bone Buttons | Rogue | Lvl 1 | +8 XP |
| Coat Weighted Stiletto | 1x Iron Shortsword, 1x Lethal Poison Base | 1x Poisoned Dagger | Rogue | Lvl 9 | +65 XP |
| Commercial Protection Desk |  | 1x Private Security Voucher | Rogue | Lvl 4 | +25 XP |
| Compile Ledger Report | 2x Paper, 2x Polished Bone Buttons | 1x Informant Report | Rogue | Lvl 4 | +20 XP |
| Concoct Signal Flash Powder | 1x Nitre Powder, 1x Flora Oil | 1x Flash Powder Bomb | Rogue | Lvl 6 | +45 XP |
| Expedited Transit Pass | 2x Paper, 1x Inkwell | 1x Transit Pass | Rogue | Lvl 3 | +15 XP |
| Fashion Street Cudgel | 2x Deadwood Twigs, 1x Coarse Cordage | 1x Street Cudgel | Rogue | Lvl 1 | +12 XP |
| Forge Extortion Mandate | 4x Venture Certificate, 2x Informant Report | 1x Squatter's Writ | Rogue | Lvl 10 | +350 XP |
| Forge Underworld Safe-Conduct | 4x Insulated Cape, 2x Flash Powder Bomb, 1x Monumental Truss | 1x Bandit's Pass | Rogue | Lvl 10 | +400 XP |
| Melt Salvaged Scrap | 2x Scraped Metal | 1x Utility Solder Bar | Rogue | Lvl 1 | +10 XP |
| Peel Willow Shoots | 2x Deadwood Twigs | 2x Coarse Cordage | Rogue | Lvl 1 | +8 XP |
| Stitch Concealed Pouch | 2x Coarse Cordage, 4x Polished Bone Buttons | 1x Traveler's Money Belt | Rogue | Lvl 1 | +10 XP |
| Stitch Hidden Liner Bag | 1x Burlap Cloth Bolt | 1x Concealed Liner Bag | Rogue | Lvl 3 | +20 XP |
| Grind Base Pigments | 1x Raw Wild Herbs | 2x Fine Pigments | Showman | Lvl 1 | +10 XP |
| Weave Basic Canvas | 1x Wild Flax | 1x Artist Canvas | Showman | Lvl 1 | +8 XP |
| Refine Pottery Clay | 1x Clay Mud, 1x Water | 2x Refined Clay | Showman | Lvl 1 | +8 XP |
| Paint Landscape | 1x Fine Pigments, 1x Artist Canvas | 1x Framed Painting | Showman | Lvl 1 | +12 XP |
| Sculpt Clay Flute | 2x Refined Clay | 1x Clay Flute | Showman | Lvl 1 | +10 XP |
| Mold Festival Mask | 1x Standard Timber, 1x Cloth | 1x Festival Mask | Showman | Lvl 2 | +25 XP |
| Assemble Stage Costume | 2x Cloth, 1x Fine Pigments | 1x Stage Costume | Showman | Lvl 2 | +25 XP |
| Cast Plaster Bust | 2x Raw Stone | 1x Plaster Bust | Showman | Lvl 6 | +45 XP |
| Sculpt Noble Statue | 2x Marble Block, 1x Industrial Varnish | 1x Noble Statue | Showman | Lvl 9 | +55 XP |
| Draw Gut Strings | 2x Wild Animal Hides | 2x Instrument Strings | Showman | Lvl 4 | +15 XP |
| Build Masterwork Lute | 2x Refined Hardwood, 1x Instrument Strings | 1x Masterwork Lute | Showman | Lvl 4 | +25 XP |
| Forge Brass Horn | 2x Brass Bar | 1x Brass Horn | Showman | Lvl 4 | +20 XP |
| Craft Sheet Music | 1x Artist Canvas, 1x Fine Pigments | 1x Sheet Music | Showman | Lvl 4 | +20 XP |
| Local Busking Service | 1x Clay Flute (Booster) | 1x Busking Ticket | Showman | Lvl 1 | +20 XP |
| Aristocratic Private Tutoring | 1x Sheet Music (Booster) | None (Tutoring Service) | Showman | Lvl 4 | +20 XP |
| Chamber Concert Recital | 1x Masterwork Lute / Brass Horn (Booster) | 1x Concert Ticket | Showman | Lvl 4 | +50 XP |
| Paint Scenic Backdrop | 3x Refined Hardwood, 2x Fine Pigments | 1x Scenic Backdrop | Showman | Lvl 7 | +40 XP |
| Tailor Royal Regalia | 3x Fine Linens, 1x Brass Bar | 1x Royal Regalia | Showman | Lvl 7 | +50 XP |
| Construct Grand Stage Set | 4x Refined Hardwood, 2x Scenic Backdrop | 1x Grand Stage Set | Showman | Lvl 8 | +80 XP |
| Compose Masterpiece Opera | 4x Grand Stage Set, 2x Registry Ledger | 1x Masterpiece Opera Partiture | Showman | Lvl 10 | +250 XP |
| Construct Acoustic Domes | 10x Refined Hardwood, 4x Brass Horn | 1x Monumental Acoustic Dome | Showman | Lvl 10 | +300 XP |

---

## 🏢 5. Buildings & Infrastructure
Buildings are defined as `.tres` resources of the `BuildingData` class. They cost gold to construct and are divided into Homes, Rentals, Production Workshops, and Utility structures.

### Building Attributes
- **Building ID (`id`)**: Unique string identifier mapping the building node to its database entry.
- **Name (`name`)**: Display label in the build menu and on-hover panels.
- **Cost (`cost`)**: Gold required to place the building.
- **Allowed Settlement (`allowed_settlement`)**: Geography restriction (e.g. `city`, `town`, or `any`).
- **Required level (`level`)**: Hired worker or career experience level required to construct/run the building.
- **Type (`type`)**: Classification of the structure (`home`, `renting`, `production`, `gathering`, `warehouse`).
- **Environment (`env`)**: Specifies coordinate restrictions (`outside`, `inside`, `any`).
- **Attractiveness (`attractiveness`)**: Baseline value representing the luxury appeal of the storefront (used by shopper AI).

### A. Cozy Houses (Personal Homes)
Act as the player's personal base of operations. Required for marriage and trade consoles.
| Building ID | Name | Cost | Settlement | Unlock Level | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `cozy_house_l2` | Comfortable House | 500 G | Any | Lvl None | Level 2 Personal Home: More space and storage room. |
| `cozy_house_l1` | Cozy House | 250 G | Any | Lvl None | Level 1 Personal Home: A cozy house to sleep and store items. |
| `cozy_house_l4` | Grand Estate | 2000 G | Any | Lvl None | Level 4 Personal Home: A massive, premium mansion. |
| `cozy_house_l3` | Manor House | 1000 G | Any | Lvl None | Level 3 Personal Home: A large estate with high security. |


### B. Rental Houses
Residential assets purchased to generate recurring daily landlord revenue from NPC tenants.
| Building ID | Name | Cost | Settlement | Unlock Level | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `rental_house_l2` | Comfortable Rental | 500 G | Any | Lvl None | Level 2 Rental House: More rooms to fetch higher rent. |
| `rental_house_l4` | Grand Rental | 2000 G | Any | Lvl None | Level 4 Rental House: A premium landlord estate. |
| `rental_house_l3` | Manor Rental | 1000 G | Any | Lvl None | Level 3 Rental House: High-class residency with supreme yield. |
| `rental_house_l1` | Rental House | 250 G | Any | Lvl None | Level 1 Rental House: Rent out to local residents for daily income. |


### C. Hired Worker / Profession Workshops
Workplaces where employees gather, refine, or manufacture finished goods.
| Building ID | Name | Cost | Settlement | Unlock Level | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `patreon_bakery_l1` | Bakery | 150 G | Any | Lvl 1 | A warm bakery containing a bread baking oven. |
| `general_bed_l1` | Comfortable Bed | 80 G | Any | Lvl None | A bed to sleep in and advance to the next day. |
| `general_bench_l1` | Crafting Bench | 50 G | Any | Lvl None | Standard crafting bench for flour and bread. |
| `patreon_mill_l1` | Flour Mill | 120 G | Any | Lvl 1 | Walk-in building with a mill station to grind wheat. |
| `tailor_loom_l1` | Loom & Table | 130 G | Any | Lvl None | Walk-in workshop containing a weaving loom. |
| `general_stall_l1` | Market Stall | 150 G | Any | Lvl None | A trade stall to buy and sell goods. |
| `craftsman_smelter_l1` | Smelter | 140 G | Any | Lvl None | Turn raw iron ore into solid iron ingots. |
| `craftsman_tinker_l1` | Tinker Workshop | 160 G | Any | Lvl None | Craft simple gadgets and mechanical parts. |
| `patreon_bakery_l2` | Bakery | 500 G | Any | Lvl 3 | An upgraded bakery to bake delicious berry cakes and sweet buns. |
| `craftsman_tinker_l2` | Tinker Factory | 320 G | Any | Lvl 2 | Automatic workbench assembly. |
| `patreon_bakery_l3` | Bakery | 1200 G | Any | Lvl 6 | A large bakery to bake gilded cream cakes and royal venison pasties. |
| `craftsman_forge_l1` | Blacksmith Forge | 400 G | Any | Lvl 3 | Forge advanced iron tools and hardware. |
| `craftsman_smelter_t2` | Blast Furnace | 600 G | Any | Lvl 3 | T2 Production: Speeds up iron ingot smelting. |
| `tailor_loom_t2` | Spinning Jenny | 550 G | Any | Lvl 3 | T2 Production: Spins thread automatically. |
| `craftsman_forge_l2` | Blast Furnace Forge | 800 G | Any | Lvl 4 | Accelerate smelting and increase security. |
| `patreon_farmstead_l1` | Farmstead | 600 G | Any | Lvl 4 | A homestead to grow barley/hops, cure pork, and tan raw pelts. |
| `patreon_tavern_l1` | Tavern & Taproom | 500 G | Any | Lvl 4 | Local Tavern providing House Ale and Taproom services. |
| `craftsman_forge_l3` | Foundry | 1600 G | Any | Lvl 5 | Highly secure and fire-proof automated foundry. |
| `craftsman_smelter_t3` | Foundry | 1800 G | Any | Lvl 5 | T3 Production: Automatic alloy production. |
| `craftsman_workshop_l1` | Industrial Workshop | 800 G | Any | Lvl 5 | Large space for alloy and steel crafting. |
| `tailor_loom_t3` | Textile Factory | 1600 G | Any | Lvl 5 | T3 Production: Mass cloth weaving factory. |
| `patreon_inn_l1` | Boarding House Inn | 500 G | Any | Lvl 4 | Traveler Lodging Quarters providing Boarding services. |
| `craftsman_workshop_l2` | Alloy Factory | 1600 G | Any | Lvl 6 | Automated line for chemical processes. |
| `patreon_tavern_l2` | Grand Casino & Lounge | 1200 G | Any | Lvl 7 | Elite high-end gaming salon and premium lounge. Replaces tavern counter with casino games. |
| `patreon_inn_l2` | Grand Traveler Resort | 1200 G | Any | Lvl 7 | A luxurious hotel with premium rooms and expanded lodging service capacity. |
| `patreon_distillery_l1` | Distillery | 1200 G | Any | Lvl 7 | A facility containing vats to ferment wines and distill liquors. |
| `craftsman_workshop_l3` | Steam Workshop | 3200 G | Any | Lvl 7 | Maximum grade steampunk machinery. |
| `patreon_event_hall_l1` | Event Hall | 2000 G | Any | Lvl 8 | A grand venue to host noble and royal banquets for massive gold payouts. Reduces province taxes. |
| `patreon_distillery_l2` | Grand Distillery | 2200 G | Any | Lvl 9 | An advanced distillery with premium aging equipment to brew fine aged schnapps. |
| `patreon_spire_l1` | Imperial Gastronomy Spire | 5000 G | Any | Lvl 10 | Legendary Masterwork Production spire for Arranging Sovereign Banquets and Distilling Vintage Sovereign Nectars. |
| `woodworker_timber_mill_l1` | Timber Mill | 120 G | Any | Lvl 1 | Saw raw logs, chop firewood, and shave wooden pegs. |
| `woodworker_carpentry_workshop_l1` | Carpentry Workshop | 150 G | Any | Lvl 1 | Assemble basic crates and carve tool handles. |
| `woodworker_carpentry_workshop_l2` | Carpentry Workshop | 500 G | Any | Lvl 3 | Craft cargo kegs and build loom frames. |
| `woodworker_carpentry_workshop_l3` | Carpentry Workshop | 1000 G | Any | Lvl 6 | Construct shipping crates. |
| `woodworker_carpentry_workshop_l4` | Carpentry Workshop | 1800 G | Any | Lvl 9 | Carve ornate structural fittings. |
| `woodworker_hardwood_kiln` | Hardwood Kiln | 600 G | Any | Lvl 4 | Cure hardwood logs and burn industrial charcoal. |
| `woodworker_wheelwright_l1` | Wheelwright & Cart Shop | 500 G | Any | Lvl 4 | Build reinforced wheels, assemble handcarts, and run hauling services. |
| `woodworker_wheelwright_l2` | Wheelwright & Cart Shop | 1200 G | Any | Lvl 7 | Construct freight wagons and run imperial transit services. |
| `woodworker_architecture_atelier_l1` | Architecture Atelier | 1200 G | Any | Lvl 7 | Mill structural beams and frame modular building wings. |
| `woodworker_architecture_atelier_l2` | Architecture Atelier | 2200 G | Any | Lvl 9 | Carve heavy structural scaffolding. |
| `woodworker_engineering_guildhall_l1` | Civil Engineering Guildhall | 2000 G | Any | Lvl 8 | Take on bridge reconstruction and palace remodeling contracts. |
| `woodworker_spire_l1` | Citadel Engineering Spire | 5000 G | Any | Lvl 10 | Forge masterwork vault doors and erect monumental trusses. |
| `herbalist_drying_shed_l1` | Biomass Drying Shed | 120 G | Any | Lvl 1 | Press flora oil and dehydrate raw herbs into shives. |
| `herbalist_apothecary_l1` | Apothecary Shop L1 | 150 G | Any | Lvl 1 | Brew basic stamina draughts and mix pigment powders. |
| `herbalist_apothecary_l2` | Apothecary Shop L2 | 500 G | Any | Lvl 3 | Brew basic stamina draughts, mix pigment powders, and blend compound nitre. |
| `herbalist_apothecary_l3` | Apothecary Shop L3 | 1000 G | Any | Lvl 6 | Advanced compounding, soot-salves, and general herbal remedies. |
| `herbalist_apothecary_l4` | Apothecary Shop L4 | 1800 G | Any | Lvl 9 | Masterpiece compounding, soot-salves, and grand herbal remedies. |
| `herbalist_acid_crucible_l1` | Acid Crucible & Still | 600 G | Any | Lvl 4 | Brew alchemical acids and refine chemical solvents. |
| `herbalist_infirmary_l1` | Infusion Infirmary L1 | 500 G | Any | Lvl 4 | A medical facility providing Local Apothecary Clinic service to citizens. |
| `herbalist_infirmary_l2` | Infusion Infirmary L2 | 1200 G | Any | Lvl 7 | An expanded medical facility providing advanced healing and clinic services. |
| `herbalist_conservatory_l1` | Conservatory Lab L1 | 1200 G | Any | Lvl 7 | Synthesize void catalysts and extract sulfur pods. |
| `herbalist_conservatory_l2` | Conservatory Lab L2 | 2200 G | Any | Lvl 9 | Advanced alchemical syntheses and extraction of exotic spores. |
| `herbalist_sanitarium_l1` | Imperial Sanitarium | 2000 G | Any | Lvl 8 | A prestigious institution providing Provincial Sanitarium Desk services and resolving grand contracts. |
| `herbalist_spire_l1` | Alchemical Greenhouse Spire | 5000 G | Any | Lvl 10 | Tier 4 Masterwork Spire. Brew draughts of infinity and transmute philosopher's stones. |
| `scholar_paper_maker_l1` | Paper Scriptorium | 120 G | Any | Lvl 1 | Press raw wild flax and river reeds into paper or scrape parchment. |
| `scholar_study_l1` | Scholar's Study L1 | 150 G | Any | Lvl 1 | Draft basic property deeds and compile registry ledgers. |
| `scholar_study_l2` | Scholar's Study L2 | 500 G | Any | Lvl 3 | Draft basic property deeds, compile registry ledgers, and bind Apprenticeship Tomes. |
| `scholar_study_l3` | Scholar's Study L3 | 1000 G | Any | Lvl 6 | Advanced study: compile masterwork folios. |
| `scholar_study_l4` | Scholar's Study L4 | 1800 G | Any | Lvl 9 | Masterpiece study: compile masterwork folios. |
| `scholar_press_l1` | Type-Setting Press | 300 G | Any | Lvl 4 | A typesetting press to carve printing plates and press Promissory Ledgers. |
| `scholar_registrar_l1` | Registrar Office L1 | 500 G | Any | Lvl 4 | A civic facility providing Local Tax Assessment services to citizens. |
| `scholar_registrar_l2` | Registrar Office L2 | 1200 G | Any | Lvl 7 | An expanded civic facility providing advanced tax and licensing services. |
| `scholar_bank_l1` | Provincial Bank | 500 G | City | Lvl 4 | A provincial banking house to issue high-interest loans. Requires 2x advanced structural beam on placement. |
| `scholar_bank_l2` | Grand Banking House | 1200 G | City | Lvl 7 | An expanded bank to underwrite corporate shares. |
| `scholar_courthouse_l1` | Grand Courthouse | 2000 G | Any | Lvl 8 | A prestigious legal institution providing Corporate Licensing Desk services and resolving grand contracts. |
| `scholar_mint_l1` | Sovereign Mint & Library | 5000 G | Any | Lvl 10 | Tier 4 Masterwork Spire. Engrave central banking charters and print fiat currency decrees. |
| `rogue_smugglers_hideout_l1` | Smuggler's Hideout | 120 G | Any | Lvl 1 | A hidden hub to melt scrap metal, carve bone buttons, and process coarse cordage. |
| `rogue_thieves_den_l1` | Thieves' Den L1 | 150 G | Any | Lvl 1 | A low-profile den for crafting street cudgels and concealed pouches. |
| `rogue_thieves_den_l2` | Thieves' Den L2 | 500 G | Any | Lvl 3 | An upgraded den for preparing transit passes, hidden liner bags, and performer disguise kits. |
| `rogue_thieves_den_l3` | Thieves' Den L3 | 1000 G | Any | Lvl 6 | A fortified den for concocting signal flash powder bombs. |
| `rogue_thieves_den_l4` | Thieves' Den L4 | 1800 G | Any | Lvl 9 | The ultimate thieves' den for coating weighted stilettos with lethal poison. |
| `rogue_informant_lookout_l1` | Informant Lookout | 600 G | Any | Lvl 4 | A high-elevation lookout post that permanently strips away fog-of-war on map details. |
| `rogue_cutpurse_apartments_l1` | Cutpurse Apartments L1 | 500 G | Any | Lvl 4 | An apartment hub organizing city-wide pickpocketing operations. |
| `rogue_cutpurse_apartments_l2` | Cutpurse Apartments L2 | 800 G | Any | Lvl 5 | An upgraded crime hub featuring a Commercial Protection Desk to extort virtual businesses. |
| `rogue_crime_syndicate_hq_l1` | Crime Syndicate HQ L1 | 1200 G | Any | Lvl 7 | A headquarters launching player strongbox heist extraction operations. |
| `rogue_crime_syndicate_hq_l2` | Crime Syndicate HQ L2 | 2000 G | Any | Lvl 8 | An advanced headquarters authorizing smuggler flags on courier fleets and black market tracking. |
| `rogue_shadow_brokers_ring_l1` | Shadow Broker's Ring | 2000 G | Any | Lvl 8 | A service center to execute high-stakes grand underworld contracts. |
| `rogue_palace_spire_l1` | Black Market Palace Spire | 5000 G | Any | Lvl 10 | The ultimate underworld masterpiece spire for high-end disruption and trade pass forgery. |
| `showman_artisan_atelier_l1` | Artisan Atelier | 120 G | Any | Lvl 1 | A starter workshop for the Showman class. Refines base pigments, woven canvases, and clay. |
| `showman_busking_stage_l1` | Busking Stage L1 | 150 G | Any | Lvl 1 | A small outdoor wooden platform to perform local busking service. |
| `showman_busking_stage_l2` | Busking Stage L2 | 500 G | Any | Lvl 3 | An upgraded outdoor stage with seating space for larger busking events. |
| `showman_busking_stage_l3` | Busking Stage L3 | 1000 G | Any | Lvl 6 | A large public stage for major theatrical recitals. |
| `showman_busking_stage_l4` | Busking Stage L4 | 1800 G | Any | Lvl 9 | A grand public amphitheater stage of imperial grade. |
| `showman_instrument_workshop_l1` | Instrument Workshop L1 | 600 G | Any | Lvl 4 | A workshop to craft fine musical instruments such as lutes and horns. |
| `showman_music_salon_l1` | Music Salon L1 | 500 G | Any | Lvl 4 | A cozy salon where the Showman offers music lessons and chamber concerts. |
| `showman_music_salon_l2` | Music Salon L2 | 1200 G | Any | Lvl 7 | An elegant music salon with premium acoustic properties for high-class recitals. |
| `showman_scenic_design_loft_l1` | Scenic Design Loft L1 | 1200 G | Any | Lvl 7 | A large studio loft used to paint and manufacture grand theatrical backdrops. |
| `showman_scenic_design_loft_l2` | Scenic Design Loft L2 | 1800 G | Any | Lvl 8 | An advanced design loft to assemble massive stage sets. |
| `showman_grand_amphitheater_l1` | Grand Amphitheater L1 | 2000 G | Any | Lvl 8 | A premium open-air theater to host grand civic pageants and musical events. |
| `showman_royal_opera_house_l1` | The Royal Opera House | 5000 G | Any | Lvl 10 | A legendary masterpiece opera house representing the absolute pinnacle of cultural prestige. Requires 1x Monumental Truss to build. |


### D. Warehouses & Utility Buildings
Storage hubs and utility objects.
| Building ID | Name | Cost | Settlement | Unlock Level | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `warehouse_l1` | Warehouse | 400 G | Any | Lvl None | Stores large item volumes. Allows setting minimum retained stock thresholds. |


---

## 💹 6. Marketplace Pricing & Spreads
Market stalls calculate item prices dynamically based on local supply and demand relative to target stock, absolute min/max prices, and price elasticity curves.

### Target Stocks & Elasticities
Rarity is defined by the item's `RarityTier` (Common, Luxury, Rare), which dictates target stock levels and price response exponents ($lpha$):
- **Common**: Target Stock = `80`, Price Elasticity ($lpha$) = `1.0` (Purely Linear)
- **Luxury**: Target Stock = `35`, Price Elasticity ($lpha$) = `1.5` (Smooth curvature)
- **Rare**: Target Stock = `10`, Price Elasticity ($lpha$) = `3.0` (Aggressive curve spikes during shortages)

### Dynamic Pricing Formula
The baseline unit price is calculated dynamically using a Piecewise Power Curve based on the item's base, min, and max values:
- **Shortage ($0 \le \text{CurrentStock} < \text{TargetStock}$)**:
  $$\text{Price} = \text{BaseValue} + (\text{MaxPrice} - \text{BaseValue}) \times \left(1.0 - \frac{\text{CurrentStock}}{\text{TargetStock}}\right)^\alpha$$
- **Surplus ($\text{TargetStock} \le \text{CurrentStock} \le 2 \times \text{TargetStock}$)**:
  $$\text{Price} = \text{MinPrice} + (\text{BaseValue} - \text{MinPrice}) \times \left(2.0 - \frac{\text{CurrentStock}}{\text{TargetStock}}\right)^\alpha$$
- **Saturation ($\text{CurrentStock} > 2 \times \text{TargetStock}$)**:
  $$\text{Price} = \text{MinPrice}$$

- **Buy Price (from Market)**: Market sells items to players at a $+10\%$ markup:
  $$\text{BuyPrice} = \text{int}(\text{Price} \times 1.1)$$
- **Sell Price (to Market)**: Market buys items from players at a $-10\%$ markdown:
  $$\text{SellPrice} = \text{int}(\text{Price} \times 0.9)$$

### Incremental Pricing Loop
When transacting in bulk (e.g. buying 10 items at once), the price is calculated **incrementally (1 unit at a time)** inside a loop. The simulated stock count updates on each iteration, causing prices to slide dynamically mid-transaction.

---

## 🌙 7. Nightly Consolidated Cycles
At exactly **midnight (00:00)**, the market runs a consolidated two-phase stabilization cycle to adjust public stocks:

### Phase A: Background Guild Consumption
To simulate city-wide demand, public market stalls consume a randomized portion of raw materials and semi-elaborate stocks:
- Deducts a random fraction between **10% and 25%** of the current stock.
- The remaining stock is clamped at a minimum floor of **1** unit.

### Phase B: Merchant Caravan Safety-Valves
To prevent runaway market deficits or oversupplies:
1. **Shortage Intervention**: If an item's stock is below **25% of target stock** for **2 consecutive days**, the caravan replenishes the stock up to **50% of target stock**.
2. **Glut Intervention**: If stock exceeds **150% of target stock**, the caravan removes **50% of the excess**.
3. **Market Disruption (Oversupply)**: Has a **20% nightly chance** to occur. Selects 1 to 3 random raw or semi-elaborate commodities, dumping a bulk amount (**50% to 100% of target stock**) into all public market stalls, triggering a global alert banner.

---

## 🚚 8. Logistics, Couriers & Warehouses
Players can automate regional transport using couriers and warehouse hubs.

### Hired Couriers
- Hired workers can be assigned to custom **Trade Routes**.
- Couriers move sequentially through a list of custom stops (`TradeRouteStop`), performing `LOAD` and `UNLOAD` actions.
- **Cargo Capacity**: Couriers carry cargo in 4 dedicated inventory slots.
- **Ingredient Filtration**: Couriers will refuse to unload an item if the destination workshop has no recipe that consumes that item.
- **Profit Strongboxes**: Any profit generated by couriers selling to market stalls is deposited directly into their home workshop strongbox.

### Player Warehouses
- Placed via the General construction tab.
- **Capacity**: 48 slots, with a maximum stack size of 50 units.
- **Minimum Retained Stock**: Players can lock down a safety threshold for specific items in the warehouse UI. Couriers are strictly prohibited from picking up items below this limit.
- **Retail Isolation**: While registered in the `production_buildings` group for placement, Warehouses are completely ignored by ambient consumer shoppers.

---

## 🏠 9. Real Estate, Housing & Marriage
Buildings in the overworld are classified by ownership types: `Public`, `Player`, `Rented`, or `NPC`.

### Residential Types
- **Cozy Houses**: Standard residential homes (levels 1-4) acting as a private player base.
- **Rentable Houses**: Residences (levels 1-4) that players can buy and rent out to NPCs for recurring daily gold income.

### Courting & Marriage
- Players must own at least one **Personal Home** in the world to marry an NPC.
- Upon marriage, the spouse NPC relocates to the player's personal home.
- The spouse becomes available as a **hireable employee** in every building controlled by the player.
- **Demolition Lock**: To protect dynastic continuity, the player is blocked from demolishing their last remaining personal home.

---

## ⚖️ 10. Politics, Laws & Seasons
The political sphere is driven by influence, legislative cycles, and seasonal tax collections.

### The 4-Day Season Calendar
Every 4 days represents one full season (e.g. Days 4, 8, 12, etc.), executing the following phases:
- **06:00 (Sponsorship Phase)**: Lawhouse opens. Players and AI Rivals can sponsor a custom law.
- **12:00 (Ballot Assembly)**: The council assembles a ballot of 3 laws (sponsored laws prioritized, conflicting laws excluded).
- **18:00 (Voting Phase)**: Factions vote. Players can spend Influence points to multiply their vote weight (1 weight + 1 per 10 Influence).
- **00:00 (Voting Resolution & Tax Processing)**: Ballot results are applied, and seasonal taxes are processed.

### Seasonal Tax Calculations
1. **Real Estate Tax**:
   - Base tax of **15 Gold** per level of each house owned.
   - **Rentable Houses** carry a size factor multiplier of **2.0x** (taxed at 30 Gold per level).
   - Taxes are modified by active laws: `real_estate_levy_inc` ($+30\%$) or `real_estate_levy_dec` ($-30\%$).
2. **Production Tax**:
   - Base tax of **25 Gold** per level of each production building owned.
   - Hospitality buildings (Inns & Taverns) are subject to a $+40\%$ tax increase if `hospitality_excise_tax` is active.

### Delinquency & Tax Backlog
If a faction cannot afford seasonal taxes, the unpaid amount is logged under their `tax_backlog`, and the faction is marked as **delinquent**. Delinquent status applies building attractiveness and work output penalties across all faction workshops until paid off at the Lawhouse console.

### The Law Database
There are 14 active law codes available in the provincial council:
- `real_estate_levy_inc` / `real_estate_levy_dec`: Increases/decreases real estate taxes.
- `infrastructure_tariff_inc` / `infrastructure_tariff_dec`: Modifies tariffs for trade and transport.
- `garrison_allocation_inc` / `garrison_allocation_dec`: Modifies regional security patrol levels.
- `labor_welfare_mandate`: Forces higher employee minimum wages.
- `hospitality_excise_tax`: Taxes Inns and Taverns (+40% excise).
- `crown_forestry_protection`: Penalizes unlicensed wood gathering.
- `noble_game_preservation`: Penalizes venison meat hunting.
- `metallurgical_monopoly`: Monopolizes iron extraction, restricting competitor operations.
- `courier_curfew`: Restricts nighttime logistics movements.
- `martial_carriage_ban`: Prohibits horse and carriage operations on trade routes.
- `usury_prohibition`: Restricts banking interest accrual.

---

## 🛡️ 11. NPC Systems & Guard Patrols
Provinces are populated by wandering villagers, influence brokers, councilors, and guard patrols.

### Guard Law Enforcement
Guards patrol the roads and check the player for legal violations based on active provincial laws:
- Fines are issued for harvesting `standard_timber` under `crown_forestry_protection` or hunting `venison` under `noble_game_preservation` without authorization.

### Shopper AI Social Classes
Ambient consumer NPCs trigger shopping desires over time, selecting shops based on class preference weights:
- **Peasant**: Price = `0.60`, Attractiveness = `0.20`, Employee Skill = `0.10`, Randomness = `0.10`.
- **Citizen**: Price = `0.40`, Attractiveness = `0.40`, Employee Skill = `0.10`, Randomness = `0.10`.
- **Noble**: Price = `0.20`, Attractiveness = `0.50`, Employee Skill = `0.20`, Randomness = `0.10`.

### AI Rivals
Rivals behave dynamically to compete with the player:
- They gather resources, craft refined and finished products, and sell them at their own private stalls.
- They buy properties, upgrade workstations, and expand their businesses relative to their selected career path (Medici, Fugger, and Welser family AI).

---

## 🛣️ 12. World Design & Navigation
The world is rendered in a 3/4 oblique projection with robust navigation logic.

### AStar2D Navigation
- GameState maintains a global grid-snapped **AStar2D Road Navigation Network** connecting all roads and market plazas.
- NPC pathfinders use the road network for primary movement, preventing random off-road wandering.
- **Lot Avoidance**: Dynamic barriers (physics collision layer 3) block NPCs from stepping onto vacant or occupied lots, keeping them on public pathways while letting the player walk freely.
- **Slide collisions**: All characters (Player, Rivals, NPCs) ignore character-to-character physical blocking, sliding past each other smoothly to prevent bottlenecks on narrow paths.

---

## 🏛️ 13. Guild Rank Hierarchy & Breakthrough Quests
- **Tiers**: Novice (L1-3), Journeyman (L4-6), Expert (L7-9), Master (L10).
- **Progression Locks**: Career experience accumulation automatically hardlocks at levels 3, 6, and 9.
- **Dedicated Guild Master NPCs**: Inside each profession's guild hall, a dedicated Guild Master (e.g. *Craftsman Guild Master*, *Scholar Guild Master*, *Tailor Guild Master*, *Patreon Guild Master*) handles professional rank advancements specifically. Interacting with them is exclusively dedicated to level up breakthroughs (Novice -> Journeyman -> Expert -> Master), and does not grant access to general Conclave services.
- **Breakthrough Rank Quest**: To unlock the next progression tier, characters must visit their specific Guild Master to generate a temporary, single-use trial recipe (`is_breakthrough_only = true`), craft it once inside a Tier 2+ workshop of that profession, and pay a flat Gold breakthrough fee (100 for Novice, 250 for Journeyman, 500 for Expert). Upon creation of the milestone item, the trial recipe is instantly deleted.


## 🗳️ 14. Seasonal Guild Conclave
- **4-Day Election Loop**:
  - **Day 1 (06:00 AM)**: Scan candidates, register players if they meet the required tier for a seat, and open the blind-bidding window.
  - **Day 2 (00:00 Midnight)**: Close bidding, calculate weighted vote scores using:
    $$\text{Total Votes} = \text{Influence Spent} \times (1.0 + \text{Title Modifier} + \text{Prestige Modifier})$$
    The candidate with the highest votes swaps into the office. Ties or zero bids default the seat to the neutral "Guild Elder" NPC.
  - **Term Limits**: Term lasts for a 4-day block (Days 2, 3, 4, and through the following Day 1 campaign phase).
- **Modifiers**:
  - **Title Modifier**: Scaled from `0.0` (Apprentice) to `0.50` (Guild Baron).
  - **Prestige Modifier**: Scaled from `0.0` to `0.30` based directly on faction permanent influence.

## 👑 15. Guild Office Hierarchy Modifiers
- **Interactive Guild Office NPCs**: The three office seats in the Guild Houses are occupied by visual, interactive NPCs representing the Grand Chairman, Donations Overseer (display name; under-the-hood office name: Logistics Overseer), and Materials Steward. Interacting with them opens their dedicated single-purpose conclave window with tab buttons hidden and cycling disabled.
- **The Grand Chairman (Master Tier)**: Province-wide tax edict. Reduces property taxes by 15% for allied faction workshops of that guild type, while applying a +5% registration levy against competitors running the same trade. Talking to them opens either the *Conclave Elections* screen or the *Edicts & Audits* panel directly.
- **The Donations Overseer (Expert Tier; office name: Logistics Overseer)**: Transit credentials. Grants +5% movement speed to all automated cargo carts and couriers assigned to the holding family within the province. Talking to them opens the *Province Donations* screen.
- **The Materials Steward (Journeyman Tier)**: 10% chance lottery on crafting completion to refund 100% of raw materials and semi-elaborates used back into the workshop's input slots. Talking to them opens the *Wholesaler Store* for buying timed material bundles.


## 💰 16. Guild Donations & Wholesale Store
- **Donation UI**: Directly linked to `prosperity_manager.gd`. Depositing Gold or commodities (Wheat, Cotton, Iron Ore) increments the Province Prosperity, which automatically syncs across all province cities and towns. The current prosperity value is displayed dynamically in brackets next to the active province name under the minimap radar.
- **Wholesalers**: Milestone levels of Prosperity unlock wholesale store packages. These packages are timed and refresh every 10 real-world minutes (600 seconds) checked globally. If a player purchases a bundle category, it is marked as sold out and unavailable to buy until the next refresh. The other categories continue to be offered independently:
  - Wholesale Iron Ore (x10): Requires 30 Prosperity (80 Gold + 5 Influence).
  - Wholesale Iron Ingot (x10): Requires 60 Prosperity (200 Gold + 15 Influence).
  - Wholesale Cloth (x10): Requires 100 Prosperity (350 Gold + 30 Influence).

## ⚖️ 17. Bureaucratic Audits
- **Inspector Summon**: Spawn an inspector NPC that navigates to the target competitor workshop, applying `is_under_audit = true` for 12 game hours (halting production and clearing storefront retail stalls).
- **Audit Cooldown**: Applies a global 2-day cooldown (`guild_audit_cooldown`) across the province.

---

## 🧱 18. Decoupled Code Architecture & UI Focus Trapping
To maintain clean code architecture and avoid large source file maintenance issues, the codebase is strictly decoupled:
- **Base Production Building Node Composition**: `base_production_building.gd` delegates worker tasks to `BuildingStaffComponent` and structural upgrades to `BuildingUpgradeComponent`. GDScript setters proxy properties transparently for compatibility.
- **HUD Decoupling**: Sub-windows (Build, Business, Title Upgrades, Alerts history) are managed by dedicated panel scripts cached in master HUD references, prohibiting parent hierarchy pointer navigation.
- **Main Ledger Views**: `main_data_view.gd` coordinates `workshop_view.gd`, `warehouse_view.gd`, and `modal_manager.gd` attached to singular parent nodes.
- **Focus Trapping Overlays**: All modal overlays (Market transaction slider, Price adjustments, Build menu tab panels, and Assignment Job popups) register a `gui_focus_changed` callback with the Viewport. If focus attempts to escape to background cards, it is immediately intercepted and snapped back to the modal popup. Quantity buttons also implement vertical wrapping (pressing Up on first loops to last) to keep navigation enclosed.
- **Hold-to-Scroll Slider Adjustments**: Intercepted key inputs map to continuous echo events, allowing player holds on `A`/`D`/Left/Right to increase/decrease quantity slider values rapidly.
- **Dynamic Gold Updates**: Gold alterations immediately dispatch a `gold_changed` event that updates active screen HUD nodes reactively, avoiding delayed syncs on window closes.
- **Build Menu Selector Focus Restoration**: Tracks the last focused construction card in the build menu and automatically restores focus to it if focus temporarily escapes or resets (such as on clock tick layout passes), preventing selection resetting back to the first tab card.
- **Employee Shift Scheduling & Workbench Routing**: Workers automatically pause crafting or gathering tasks when their shift ends, teleporting from the building interior to the doorstep to prevent getting trapped in isolated interior maps. When their shift starts and they have active tasks, they are automatically directed to return to the workbench.

---

## 🏛️ 19. Province Prosperity, Lot Scaling & Paved Roads
The game implements a shared province-wide prosperity engine that drives spatial, defensive, and infrastructure evolution.

### Prosperity Milestone Levels
Prosperity levels scale using thresholds that evaluate the global province prosperity rating:
- **Level 1 (Base/Stagnant)**: `Prosperity < 250.0` (Starts at 100.0 base)
- **Level 2**: `250.0 <= Prosperity < 500.0`
- **Level 3**: `500.0 <= Prosperity < 750.0`
- **Level 4**: `750.0 <= Prosperity < 1000.0`
- **Level 5**: `Prosperity >= 1000.0`

These levels are evaluated by the Autoload singleton `ProsperityManager` via the `get_level_for_prosperity` method.

### Settlement Security Rating
Every city and town tracks a `security_rating` property:
- **Baseline**: Starts at `100.0`.
- **Level Buffs**: For each prosperity milestone level above Level 1, the security rating is buffed by `+20.0` (e.g. Level 2 = 120.0, Level 3 = 140.0, etc.).

### Overnight Lot Expansion & Wall Upgrades
Cities automatically check for expansions overnight during sleep transition:
- If the city's target prosperity level is higher than the current count of unlocked expansion zones (up to a max of 4 zones), a random direction (North, South, East, West) is selected.
- Six new buildable lot nodes are spawned dynamically in a grid in that direction.
- The city wall tier is upgraded accordingly:
  - **Tier 1 (Palisade Walls)**: Base/Level 1.
  - **Tier 2 (Finished Wood Walls)**: Level 2.
  - **Tier 3 (Massive Stone Walls)**: Level 3+.
- Landmark visuals of public structures are upgraded programmatically (e.g. roof styling and colors).
- Navigation polygons are rebaked to update pathfinding around the new lots.

### Paved Road Overhaul & Speed Boosting
- When Level 3 is reached, the province's road segment network is overhauled to paved cobblestone.
- **Speeds**: Dirt roads apply a standard `+10%` travel speed multiplier. Paved roads apply a `+13%` multiplier (+3% speed boost on top of default road speeds) for all automated cargo carts, couriers, and characters.

### Settlement Operating Licenses & Checkpoint Toll Gates
- **Dynamic Toll Checkpoints**: Editor-placed `ColorRect` nodes named with "Gate" under `TerrainObstacles` are dynamically compiled at runtime into `TollGateTrigger` collision areas.
- **Border Tolls**: Traveling into any province other than the player's starting province triggers a 15 Gold toll prompt at checkpoint gates.
- **Physics Pushback Guardrail**: Rejecting the toll triggers a smooth, jitter-free 80px pushback. The player's physics processing is temporarily disabled (`set_physics_process(false)`) and they are translated backward via a Tween, restoring full control once verified to be completely outside the gate Area2D boundary.
- **Operating Licenses**: Permanently purchased at the local City Hall from the Councilor or Mayor via licensing quests (choice of paying 500 Gold or delivering 10 Flour). 
- **License Privileges**: Bypasses gate tolls, removes a 10 Gold Courier public market transaction fee, allows building/moving structures within the province lot grids, and grants access to local Guild Masters and Office NPCs (which otherwise reject unlicensed players with "You are not from around here" greetings).

### Prosperity-based Luxury Spawners
- **Prosperity Resource Scaling**: Spawning of higher-tier gathering nodes is locked behind province prosperity milestone levels:
  - **Level 1 Nodes** (timber, wheat, coal, etc.): Always spawned.
  - **Level 3 Nodes** (copper, zinc, hardwood, venison): Spawned when the province prosperity reaches Level 3 (Prosperity >= 500.0).
  - **Level 4 Nodes** (marble, hops, fungi, hides): Spawned when the province prosperity reaches Level 4 (Prosperity >= 750.0).
- **Volatile Rebuilding**: Dynamic luxury nodes are strictly volatile (not serialized in game saves). On load, the world spawner naturally queries the province's saved Prosperity Level to cleanly reconstruct the resource landscape, avoiding duplicate overlapping node bugs.

---

## 🎒 20. Wealth Ledger & Inventory Interactions
Two additional major player-focused utility interfaces improve transaction auditing and inventory management.

### Global Wealth Transaction Ledger
- All gold modifications (`GameState.gold`) require a source attribution:
  - `change_reason`: High-level source category (e.g. Trade, Rent, Construction, Fines, Bank, Taxes).
  - `change_detail`: Detailed description of the transaction (e.g. `"Sold 5 Bread to Market Stall"`).
- The historical transactions list is recorded in a global ledger.
- A new dedicated tab displays the historical ledger records inside the F1 Character Screen.

### Inventory Context Options Menu
- Double-clicking or selecting an item in the player inventory slots opens a context Options popup menu:
  - **Equip** (for weapons, armor, tools, and bags) / **Consume** (for foods, ingredients, and career manuals).
  - **More Data**: Opens the detailed item specification dialog displaying attributes and lore.
  - **Delete**: Prompts a warning confirmation overlay to permanently destroy exactly 1 unit of the item.

---

## 🧠 21. Character Trait Modifiers & Probabilities
The game features a dynamic trait generation and resolution system for players, competitor rivals, and employees. Spawning characters roll random traits weighted by local prosperity, and their stats or event completion checks are procedurally altered based on the active trait tiers.

### Traits Specifications

| Trait Name | Level 1 | Level 2 | Level 3 | Trigger Hook |
| :--- | :--- | :--- | :--- | :--- |
| **Fleet-Footed** | +5% Speed | +10% Speed | +15% Speed | Applied directly to character walking velocity and movement speed multipliers. |
| **Diligent Master** | +3% Productivity | +6% Productivity | +10% Productivity | Speeds up item crafting and service execution times. |
| **Scythe-Wielder** | +5% Yield | +10% Yield | +15% Yield | Multiplies resource gathering amount gathered per tick at Mega-Nodes. |
| **Miracle Artisan** | 3% Duplicate | 7% Duplicate | 15% Duplicate | Chance to double output quantities on completion or skip service ingredient costs. |
| **Scavenger's Eye** | 3% Drop | 6% Drop | 10% Drop | Chance to find bonus Level 1 Raw Materials when harvesting high-tier nodes. |

### Trait Resolution Hooks
1. **Movement Speed**: Applied inside `player.gd` (Player), `ai_rival.gd` (Rival), and `npc_navigation_component.gd` (Employee NPCs) speed calculation properties.
2. **Productivity Modifiers**: Applied directly to player/employee/rival productivity multiplier values to scale down base craft duration bounds.
3. **Logistics Harvesting**: Applies `Scythe-Wielder` multipliers to gathering ticks inside `logistics_manager.gd` and executes `Scavenger's Eye` drops to deposit items to active inventories.
4. **Miracle Crafting / Service**: Doubling chance on player manual workbench yields (`base_production_building.gd`) and employee workspace schedules (`BuildingStaffComponent.gd`). If a Miracle Artisan service provider triggers, the booster/inputs are not consumed from building storage during `execute_leisure_transaction()` in `npc_employee_scheduler.gd`.

---

## 🌐 22. Macro Scale Modifier Managers
To prevent structural scaling calculations from polluting individual character resource definitions, the engine evaluates regional/civic modifiers at runtime. These modifiers scale base values on-demand without mutating the underlying save/load state database.

### Modifier Scopes and Structures
1. **Settlement Scope (City / Town)**:
   - **Storage**: Mapped inside the `modifiers: Dictionary` export of the settlement entity instance.
   - **Boundary Gating**: Applies only to nodes located within the settlement's local circle boundary (`radius_of_influence`).
2. **Province Scope (Regional)**:
   - **Storage**: Mapped in `ProvinceMasterData` singleton arrays/dictionaries.
   - **Boundary Gating**: Affects all entities, outposts, and workshops whose nearest settlement belongs to the designated province domain.
3. **Map Scope (Global)**:
   - **Storage**: Tracked in `GlobalProfile` singleton arrays.
   - **Boundary Gating**: Blanket empire-wide adjustments applying universally to all provinces, settlements, players, and rival agents.

### Resolution Pipelines
The centralized evaluation is executed in `GameState.apply_macro_modifier(node, key, base)` which resolves Settlement, Province, and Map scopes:
- **Speeds & Attributes**: Scales character walking speed (Player, Rivals, NPC couriers) and production/service productivity.
- **Crafting & Services**: Reduces or scales manual player workbench crafting times, employee workshop schedules, and tavern/inn guest service slots (cooldowns) at runtime.

---
*Document last updated: June 24, 2026 - 16:00.*

