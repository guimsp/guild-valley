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
| **Craftsman** | Iron Ore | Ore Mines | Smelter (`iron_ingot`) | Forge / Workshop | Iron Ingots, Tools, Equipment |
| **Tailor** | Cotton | Cotton Plants | Loom (`cloth`) | Tailor Table | Cloth, Thread, Clothing |
| **Scholar** | Cotton | Cotton Plants | Paper Maker (`paper`) | Printing Press (`book`) | Paper, Books, Financials |

### Career Building Unlocks
- **Patreon**: Mill, Bakery (Lvl 1) ➔ Farmstead (Lvl 4) ➔ Inn (Lvl 5) ➔ Tavern (Lvl 6) ➔ Distillery (Lvl 7) ➔ Event Hall (Lvl 8).
- **Craftsman**: Smelter, Tinker, Forge, Workshop.
- **Tailor**: Loom, Tailor Table.
- **Scholar**: Paper Maker, Printing Press, Bank (Lvl 1).

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
| `cotton` | Cotton | 8 G | 0.5 | Common | None |  |
| `egg` | Eggs | 2 G | 0.1 | Common | None | Fresh farm eggs, used in many baking recipes. |
| `grapes` | Grapes | 6 G | 0.1 | Common | None | Bunches of sweet red grapes harvested from vineyards. |
| `honey` | Sweet Honey | 8 G | 0.2 | Common | None | Pure sweet honey gathered from local beehives. |
| `iron_ore` | Iron Ore | 10 G | 2.0 | Common | None |  |
| `milk` | Milk | 4 G | 0.5 | Common | None | A pail of fresh cows' milk. |
| `premium_flask` | Premium Flasks | 12 G | 0.3 | Common | None | A refined, sturdy glass bottle container used to package fine spirits. |
| `seed_packet` | Seed Packets | 2 G | 0.1 | Common | None | A standard agricultural packet containing crop seeds. |
| `sugar` | Sugar | 5 G | 0.1 | Common | None | Sweet granulated sugar, used for confectionary cooking. |
| `sunflower` | Sunflower | 3 G | 0.1 | Common | None | Bright sunflower head containing seeds, used to press oil. |
| `venison` | Venison Meat | 10 G | 1.0 | Common | None | Lean red meat hunted from local wild deer. |
| `water` | Water | 1 G | 0.5 | Common | None | A bucket of fresh clean water. |
| `wheat` | Wheat | 5 G | 0.2 | Common | None |  |


### B. Semi-Elaborate
Intermediate components processed in mills, smelters, and looms, which act as inputs for finished products.
| Item ID | Display Name | Base Value | Weight | Rarity | Slot | Stats / Description |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `cloth` | Cloth | 30 G | 1.0 | Common | None |  |
| `concentrated_dyes` | Concentrated Dyes | 35 G | 0.2 | Common | None | Vibrant concentrated pigment from rare plants. |
| `corrosive_acid` | Corrosive Acid | 30 G | 0.3 | Common | None | A highly reactive acidic compound inside a glass jar. |
| `flour` | Flour | 12 G | 0.3 | Common | None |  |
| `heavy_steel_tools` | Heavy Steel Tools | 80 G | 1.5 | Common | None | Heavy-duty steel tools for woodworking and carpentry. |
| `iron_ingot` | Iron Ingot | 40 G | 5.0 | Common | None |  |
| `oil` | Oil | 12 G | 0.4 | Common | None | Pressed sunflower oil used for cooking and medicine. |
| `paper` | Paper | 15 G | 0.1 | Common | None |  |
| `spool_thread` | Spool of Thread | 10 G | 0.1 | Common | None | Finely spun thread ready for weaving. |
| `standard_timber` | Standard Timber | 15 G | 1.0 | Common | None | Milled and squared timber ready for construction. |
| `tumbler_locks` | Tumbler Locks | 40 G | 0.4 | Common | None | Intricately machined tumbler lock mechanism. |


### C. Finished Goods
Finished high-value commodities ready for consumer transactions, event certification, or services.
| Item ID | Display Name | Base Value | Weight | Rarity | Slot | Stats / Description |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `ale` | Ale | 22 G | 0.6 | Common | None | A refreshing pint of tavern ale. |
| `ancient_manuscript` | Ancient Manuscript | 0 G | 0.5 | Common | None | A delicate and historic text bound in leather. |
| `animal_feed` | Animal Feed | 6 G | 1.0 | Common | None | A bale of processed hay and wheat, used to feed farm animals. |
| `apothecary_sweet_bun` | Apothecary's Sweet Bun | 30 G | 0.4 | Common | None | A bun baked with honey and sunflower oil, offering subtle restorative properties. |
| `baked_apples` | Baked Apples | 14 G | 0.3 | Common | None | Apples roasted with sugar. Sweet and aromatic. |
| `bathhouse_ticket` | Bathhouse Ticket | 45 G | 0.0 | Common | None | A ticket representing bathhouse service at the Inn. |
| `book` | Book | 45 G | 0.5 | Common | None |  |
| `bread` | Bread | 25 G | 0.5 | Common | None |  |
| `common_wine` | Common Wine | 38 G | 0.6 | Luxury | None | Simple fermented grape wine, popular in taverns. |
| `confidential_documents` | Confidential Documents | 0 G | 0.3 | Common | None | Sensible papers sealed with dark wax. |
| `cured_pork` | Cured Pork | 35 G | 1.2 | Common | None | Pork cured with salt and dried, ideal for storage. |
| `entertainment_ticket` | Entertainment Ticket | 50 G | 0.0 | Common | None | A ticket representing tavern entertainment service. |
| `fine_aged_schnapps` | Fine Aged Schnapps | 95 G | 0.8 | Luxury | None | A premium spirit infused with wild berries and aged in oak barrels. |
| `gilded_cream_cake` | Gilded Cream Cake | 45 G | 0.8 | Luxury | None | An exquisite cream cake topped with sugar glaze, fit for nobility. |
| `hotel_dining_ticket` | Hotel Fine Dining Ticket | 90 G | 0.0 | Common | None | A ticket representing premium berry cake dining service at the Hotel. |
| `hotel_dining_ticket_gilded` | Hotel Gilded Dining Ticket | 160 G | 0.0 | Common | None | A ticket representing royal gilded cake dining service at the Hotel. |
| `kitchen_service_ticket` | Kitchen Service Ticket | 50 G | 0.0 | Common | None | A ticket representing kitchen dining service at the Inn. |
| `meadhaven` | Meadhaven | 32 G | 0.5 | Common | None | A sweet honey wine brewed with select barley grains. |
| `noble_event_certificate` | Noble Event Certificate | 250 G | 0.0 | Common | None | A certificate confirming execution of a Noble Event service. |
| `royal_event_certificate` | Royal Event Certificate | 600 G | 0.0 | Common | None | A certificate confirming execution of a Royal Event service. |
| `royal_venison_pasty` | Royal Venison Pasty | 55 G | 0.8 | Common | None | A hearty meat pie filled with venison and baked in pastry crust. |
| `savory_baked_eggs` | Savory Baked Eggs | 12 G | 0.2 | Common | None | Eggs baked in hot coals with herbs. Simple yet satisfying. |
| `smugglers_moonshine` | Smuggler's Moonshine | 65 G | 0.5 | Common | None | Strong illicit liquor brewed with farmstead grains and sugar. |
| `sweet_berry_cake` | Sweet Berry Cake | 24 G | 0.6 | Common | None | A moist cake topped with sweet forest berries. |


### D. Equipment
Items that can be slotted into employee or player slots to improve physical attributes.
| Item ID | Display Name | Base Value | Weight | Rarity | Slot | Stats / Description |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `bronze_pickaxe` | Bronze Pickaxe | 60 G | 2.5 | Common | Tool | **[Gather Yield: +25%]**  |
| `cart` | Cart | 250 G | 30.0 | Common | Transportation | **[Inventory Cap: +8]**  |
| `gold_ring` | Gold Ring | 150 G | 0.05 | Common | Ring | **[Attack: +3, Speed: +5%]**  |
| `horse` | Horse | 300 G | 50.0 | Common | Transportation | **[Speed: +50%]**  |
| `iron_chestplate` | Iron Chestplate | 120 G | 8.0 | Common | Body | **[Armor: +15]**  |
| `iron_helmet` | Iron Helmet | 50 G | 2.0 | Common | Head | **[Armor: +5]**  |
| `iron_sword` | Iron Sword | 90 G | 3.0 | Common | Weapon | **[Attack: +10]**  |
| `leather_backpack` | Leather Backpack | 45 G | 1.0 | Common | Bag | **[Inventory Cap: +4]**  |
| `leather_gloves` | Leather Gloves | 35 G | 0.5 | Common | Gloves | **[Armor: +2, Speed: +5%]**  |
| `silver_necklace` | Silver Necklace | 80 G | 0.1 | Common | Necklace | **[Speed: +10%]**  |


### E. Skill Items
Special career unlocking manuals that enable access to specific professions.
| Item ID | Display Name | Base Value | Weight | Rarity | Slot | Stats / Description |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `book_craftsman` | Craftsman Manual | 1000 G | 0.5 | Rare | None | Unlocks the Craftsman career when read from your inventory. |
| `book_patreon` | Patreon Guide Book | 1000 G | 0.5 | Rare | None | Unlocks the Patreon career when read from your inventory. |
| `book_scholar` | Scholar Thesis | 1000 G | 0.5 | Rare | None | Unlocks the Scholar career when read from your inventory. |
| `book_tailor` | Tailor Handbook | 1000 G | 0.5 | Rare | None | Unlocks the Tailor career when read from your inventory. |


---

## 🍳 4. Recipes Matrix (Production Inputs & Outputs)
The recipes are compiled directly from the central recipe resource files and illustrate the raw-to-finished production sequences:
| Recipe Name | Inputs (Ingredients) | Output Product | Required Career | Level | XP Reward |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Smelt Iron Ore | 3x Iron Ore | 1x Iron Ingot | Craftsman | Lvl 1 | +12 XP |
| Bake Bread | 1x Flour, 1x Water | 1x Bread | Patreon | Lvl 1 | +15 XP |
| Bake Savory Eggs | 2x Eggs | 1x Savory Baked Eggs | Patreon | Lvl 1 | +12 XP |
| Bake Sweet Apples | 2x Apples | 1x Baked Apples | Patreon | Lvl 1 | +14 XP |
| Grind Animal Feed | 1x Wheat | 1x Animal Feed | Patreon | Lvl 1 | +8 XP |
| Grind Wheat | 1x Wheat | 1x Flour | Patreon | Lvl 1 | +10 XP |
| Press Oil | 1x Sunflower | 1x Oil | Patreon | Lvl 1 | +12 XP |
| Brew Ale | 2x Barley and Hops, 1x Water | 1x Ale | Patreon | Lvl 2 | +20 XP |
| Tavern Entertainment Service | None | 1x Entertainment Ticket | Patreon | Lvl 2 | +20 XP |
| Bake Sweet Berry Cake | 1x Flour, 1x Eggs, 1x Berries | 1x Sweet Berry Cake | Patreon | Lvl 3 | +28 XP |
| Cure Pork | 3x Animal Feed | 1x Cured Pork | Patreon | Lvl 3 | +22 XP |
| Grow Barley and Hops | 1x Seed Packets | 2x Barley and Hops | Patreon | Lvl 3 | +18 XP |
| Bake Apothecary's Sweet Bun | 1x Flour, 1x Oil, 1x Sweet Honey | 1x Apothecary's Sweet Bun | Patreon | Lvl 4 | +32 XP |
| Bathhouse Service | 1x Water | 1x Bathhouse Ticket | Patreon | Lvl 4 | +25 XP |
| Kitchen Service (Baked Eggs) | 1x Savory Baked Eggs | 1x Kitchen Service Ticket | Patreon | Lvl 4 | +28 XP |
| Ferment Common Wine | 1x Grapes, 1x Water | 1x Common Wine | Patreon | Lvl 5 | +35 XP |
| Brew Meadhaven | 1x Barley and Hops, 1x Sweet Honey | 1x Meadhaven | Patreon | Lvl 6 | +38 XP |
| Distill Smuggler's Moonshine | 1x Barley and Hops, 1x Sugar, 1x Premium Flasks | 1x Smuggler's Moonshine | Patreon | Lvl 7 | +45 XP |
| Hotel Fine Dining (Berry Cake) | 1x Sweet Berry Cake | 1x Hotel Fine Dining Ticket | Patreon | Lvl 7 | +35 XP |
| Hotel Fine Dining (Gilded Cake) | 1x Gilded Cream Cake | 1x Hotel Gilded Dining Ticket | Patreon | Lvl 7 | +45 XP |
| Bake Gilded Cream Cake | 1x Flour, 1x Eggs, 1x Sugar, 1x Milk | 1x Gilded Cream Cake | Patreon | Lvl 8 | +50 XP |
| Host Noble Event | 5x Savory Baked Eggs, 5x Baked Apples, 5x Ale | 1x Noble Event Certificate | Patreon | Lvl 8 | +80 XP |
| Host Royal Event | 5x Sweet Berry Cake, 5x Gilded Cream Cake, 5x Common Wine, 5x Smuggler's Moonshine | 1x Royal Event Certificate | Patreon | Lvl 8 | +150 XP |
| Bake Royal Venison Pasty | 1x Flour, 1x Oil, 1x Venison Meat | 1x Royal Venison Pasty | Patreon | Lvl 9 | +60 XP |
| Distill Fine Aged Schnapps | 1x Barley and Hops, 1x Berries, 1x Aging Barrels | 1x Fine Aged Schnapps | Patreon | Lvl 10 | +80 XP |
| Make Paper | 2x Cotton | 1x Paper | Scholar | Lvl 1 | +15 XP |
| Print Book | 3x Paper | 1x Book | Scholar | Lvl 2 | +30 XP |
| Weave Cotton to Cloth | 3x Cotton | 1x Cloth | Tailor | Lvl 1 | +10 XP |


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
| `scholar_paper_maker_l1` | Paper Maker | 150 G | Any | Lvl None | A workshop to press and dry raw cotton fibers into paper sheets. |
| `craftsman_smelter_l1` | Smelter | 140 G | Any | Lvl None | Turn raw iron ore into solid iron ingots. |
| `craftsman_tinker_l1` | Tinker Workshop | 160 G | Any | Lvl None | Craft simple gadgets and mechanical parts. |
| `patreon_bakery_l2` | Bakery | 500 G | Any | Lvl 2 | An upgraded bakery to bake delicious berry cakes and sweet buns. |
| `craftsman_tinker_l2` | Tinker Factory | 320 G | Any | Lvl 2 | Automatic workbench assembly. |
| `patreon_bakery_l3` | Bakery | 1200 G | Any | Lvl 3 | A large bakery to bake gilded cream cakes and royal venison pasties. |
| `craftsman_forge_l1` | Blacksmith Forge | 400 G | Any | Lvl 3 | Forge advanced iron tools and hardware. |
| `craftsman_smelter_t2` | Blast Furnace | 600 G | Any | Lvl 3 | T2 Production: Speeds up iron ingot smelting. |
| `scholar_press_l1` | Printing Press | 300 G | Any | Lvl 3 | A printing workshop to press ink onto paper and bind books. |
| `tailor_loom_t2` | Spinning Jenny | 550 G | Any | Lvl 3 | T2 Production: Spins thread automatically. |
| `craftsman_forge_l2` | Blast Furnace Forge | 800 G | Any | Lvl 4 | Accelerate smelting and increase security. |
| `patreon_farmstead_l1` | Farmstead | 600 G | Any | Lvl 4 | A homestead to grow barley/hops and cure pork. |
| `patreon_tavern_l1` | Mead Tavern | 400 G | Any | Lvl 4 | A cozy local tavern to brew ale and entertain patrons. |
| `craftsman_forge_l3` | Foundry | 1600 G | Any | Lvl 5 | Highly secure and fire-proof automated foundry. |
| `craftsman_smelter_t3` | Foundry | 1800 G | Any | Lvl 5 | T3 Production: Automatic alloy production. |
| `craftsman_workshop_l1` | Industrial Workshop | 800 G | Any | Lvl 5 | Large space for alloy and steel crafting. |
| `scholar_bank_l1` | Provincial Bank | 500 G | City | Lvl 5 | Safely deposit gold and earn 5% daily interest. |
| `tailor_loom_t3` | Textile Factory | 1600 G | Any | Lvl 5 | T3 Production: Mass cloth weaving factory. |
| `patreon_inn_l1` | Traveler's Inn | 400 G | Any | Lvl 5 | Generates visitor revenue. Offers lodging and kitchen services. |
| `craftsman_workshop_l2` | Alloy Factory | 1600 G | Any | Lvl 6 | Automated line for chemical processes. |
| `patreon_tavern_l2` | Casino | 1200 G | City | Lvl 6 | A high-stakes casino attracting wealthy patrons. Replaces tavern counter with casino games. |
| `patreon_inn_l2` | Grand Hotel | 1600 G | Any | Lvl 6 | A luxurious hotel with premium rooms, expanded bathhouse, and upgraded dining service. |
| `patreon_distillery_l1` | Distillery | 1000 G | Any | Lvl 7 | A facility containing vats to ferment wines and distill liquors. |
| `craftsman_workshop_l3` | Steam Workshop | 3200 G | Any | Lvl 7 | Maximum grade steampunk machinery. |
| `patreon_event_hall_l1` | Event Hall | 2000 G | Any | Lvl 8 | A grand venue to host noble and royal banquets for massive gold payouts. Reduces province taxes. |
| `patreon_distillery_l2` | Grand Distillery | 2500 G | Any | Lvl 8 | An advanced distillery with premium aging equipment to brew fine aged schnapps. |


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
*Document last updated: June 20, 2026 - 19:25.*
