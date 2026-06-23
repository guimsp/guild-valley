// Default Guild Valley Game Data for Canvas Visualizer and JSON Builder
window.INITIAL_GAME_DATA = {
  professions: [
    {
      id: "patreon",
      name: "Patreon",
      color: "#f59e0b",
      description: "Focuses on gathering wheat, milling, baking, brewing alcohol, and hosting grand events."
    },
    {
      id: "craftsman",
      name: "Craftsman",
      color: "#0ea5e9",
      description: "Focuses on mining iron ore, smelting ingots, forging advanced tools, armor, weapons, and mechanical workshops."
    },
    {
      id: "tailor",
      name: "Tailor",
      color: "#ec4899",
      description: "Focuses on gathering cotton, weaving cloth, and manufacturing fine clothes and equipment."
    },
    {
      id: "scholar",
      name: "Scholar",
      color: "#a855f7",
      description: "Focuses on making paper, printing books, banking, and managing financial systems."
    }
  ],
  items: [
    // --- Raw Materials ---
    { id: "aging_barrel", name: "Aging Barrels", category: "raw_material", base_value: 20, min_price: 8, max_price: 50, rarity: "Common", weight: 3.0, desc: "A heavy oak barrel used to age alcohol and enhance quality." },
    { id: "apple", name: "Apples", category: "raw_material", base_value: 3, min_price: 1, max_price: 8, rarity: "Common", weight: 0.2, desc: "Sweet red apples, picked from local orchards." },
    { id: "barley_and_hops", name: "Barley and Hops", category: "raw_material", base_value: 6, min_price: 2, max_price: 15, rarity: "Common", weight: 0.2, desc: "Grown barley grains and bitter hops blossoms, used to brew ale." },
    { id: "berries", name: "Berries", category: "raw_material", base_value: 4, min_price: 2, max_price: 10, rarity: "Common", weight: 0.1, desc: "Plump wild forest berries." },
    { id: "cotton", name: "Cotton", category: "raw_material", base_value: 8, min_price: 3, max_price: 20, rarity: "Common", weight: 0.5, desc: "Fluffy white cotton fibers harvested from plants." },
    { id: "egg", name: "Eggs", category: "raw_material", base_value: 2, min_price: 1, max_price: 5, rarity: "Common", weight: 0.1, desc: "Fresh farm eggs, used in many baking recipes." },
    { id: "grapes", name: "Grapes", category: "raw_material", base_value: 6, min_price: 2, max_price: 15, rarity: "Common", weight: 0.1, desc: "Bunches of sweet red grapes harvested from vineyards." },
    { id: "honey", name: "Sweet Honey", category: "raw_material", base_value: 8, min_price: 3, max_price: 20, rarity: "Common", weight: 0.2, desc: "Pure sweet honey gathered from local beehives." },
    { id: "iron_ore", name: "Iron Ore", category: "raw_material", base_value: 10, min_price: 4, max_price: 25, rarity: "Common", weight: 2.0, desc: "Raw iron ore mined from deep within earth veins." },
    { id: "milk", name: "Milk", category: "raw_material", base_value: 4, min_price: 2, max_price: 10, rarity: "Common", weight: 0.5, desc: "A pail of fresh cows' milk." },
    { id: "premium_flask", name: "Premium Flasks", category: "raw_material", base_value: 12, min_price: 5, max_price: 30, rarity: "Common", weight: 0.3, desc: "A refined, sturdy glass bottle container used to package fine spirits." },
    { id: "seed_packet", name: "Seed Packets", category: "raw_material", base_value: 2, min_price: 1, max_price: 5, rarity: "Common", weight: 0.1, desc: "A standard agricultural packet containing crop seeds." },
    { id: "sugar", name: "Sugar", category: "raw_material", base_value: 5, min_price: 2, max_price: 12, rarity: "Common", weight: 0.1, desc: "Sweet granulated sugar, used for confectionary cooking." },
    { id: "sunflower", name: "Sunflower", category: "raw_material", base_value: 3, min_price: 1, max_price: 8, rarity: "Common", weight: 0.1, desc: "Bright sunflower head containing seeds, used to press oil." },
    { id: "venison", name: "Venison Meat", category: "raw_material", base_value: 10, min_price: 4, max_price: 25, rarity: "Common", weight: 1.0, desc: "Lean red meat hunted from local wild deer." },
    { id: "water", name: "Water", category: "raw_material", base_value: 1, min_price: 1, max_price: 3, rarity: "Common", weight: 0.5, desc: "A bucket of fresh clean water." },
    { id: "wheat", name: "Wheat", category: "raw_material", base_value: 5, min_price: 2, max_price: 12, rarity: "Common", weight: 0.2, desc: "Stalks of golden wheat harvested from fields." },

    // --- Semi-Elaborate ---
    { id: "cloth", name: "Cloth", category: "semi_elaborate", base_value: 30, min_price: 12, max_price: 75, rarity: "Common", weight: 1.0, desc: "Woven cotton fabric sheets." },
    { id: "concentrated_dyes", name: "Concentrated Dyes", category: "semi_elaborate", base_value: 35, min_price: 14, max_price: 90, rarity: "Common", weight: 0.2, desc: "Vibrant concentrated pigment from rare plants." },
    { id: "corrosive_acid", name: "Corrosive Acid", category: "semi_elaborate", base_value: 30, min_price: 12, max_price: 75, rarity: "Common", weight: 0.3, desc: "A highly reactive acidic compound inside a glass jar." },
    { id: "flour", name: "Flour", category: "semi_elaborate", base_value: 12, min_price: 5, max_price: 30, rarity: "Common", weight: 0.3, desc: "Finely ground wheat powder." },
    { id: "heavy_steel_tools", name: "Heavy Steel Tools", category: "semi_elaborate", base_value: 80, min_price: 32, max_price: 200, rarity: "Common", weight: 1.5, desc: "Heavy-duty steel tools for woodworking and carpentry." },
    { id: "iron_ingot", name: "Iron Ingot", category: "semi_elaborate", base_value: 40, min_price: 16, max_price: 100, rarity: "Common", weight: 5.0, desc: "A solid bar of smelted iron." },
    { id: "oil", name: "Oil", category: "semi_elaborate", base_value: 12, min_price: 5, max_price: 30, rarity: "Common", weight: 0.4, desc: "Pressed sunflower oil used for cooking and medicine." },
    { id: "paper", name: "Paper", category: "semi_elaborate", base_value: 15, min_price: 6, max_price: 38, rarity: "Common", weight: 0.1, desc: "Pressed cotton fibers dried into pages." },
    { id: "spool_thread", name: "Spool of Thread", category: "semi_elaborate", base_value: 10, min_price: 4, max_price: 25, rarity: "Common", weight: 0.1, desc: "Finely spun thread ready for weaving." },
    { id: "standard_timber", name: "Standard Timber", category: "semi_elaborate", base_value: 15, min_price: 6, max_price: 38, rarity: "Common", weight: 1.0, desc: "Milled and squared timber ready for construction." },
    { id: "tumbler_locks", name: "Tumbler Locks", category: "semi_elaborate", base_value: 40, min_price: 16, max_price: 100, rarity: "Common", weight: 0.4, desc: "Intricately machined tumbler lock mechanism." },

    // --- Finished Goods ---
    { id: "ale", name: "Ale", category: "finished_good", base_value: 22, min_price: 9, max_price: 55, rarity: "Common", weight: 0.6, desc: "A refreshing pint of tavern ale." },
    { id: "ancient_manuscript", name: "Ancient Manuscript", category: "finished_good", base_value: 200, min_price: 80, max_price: 500, rarity: "Rare", weight: 0.5, desc: "A delicate and historic text bound in leather." },
    { id: "animal_feed", name: "Animal Feed", category: "finished_good", base_value: 6, min_price: 2, max_price: 15, rarity: "Common", weight: 1.0, desc: "A bale of processed hay and wheat, used to feed farm animals." },
    { id: "apothecary_sweet_bun", name: "Apothecary's Sweet Bun", category: "finished_good", base_value: 30, min_price: 12, max_price: 75, rarity: "Common", weight: 0.4, desc: "A bun baked with honey and sunflower oil, offering subtle restorative properties." },
    { id: "baked_apples", name: "Baked Apples", category: "finished_good", base_value: 14, min_price: 5, max_price: 35, rarity: "Common", weight: 0.3, desc: "Apples roasted with sugar. Sweet and aromatic." },
    { id: "bathhouse_ticket", name: "Bathhouse Ticket", category: "finished_good", base_value: 45, min_price: 18, max_price: 110, rarity: "Common", weight: 0.0, desc: "A ticket representing bathhouse service at the Inn." },
    { id: "book", name: "Book", category: "finished_good", base_value: 45, min_price: 18, max_price: 110, rarity: "Common", weight: 0.5, desc: "Bound sheets of paper filled with written text." },
    { id: "bread", name: "Bread", category: "finished_good", base_value: 25, min_price: 10, max_price: 60, rarity: "Common", weight: 0.5, desc: "Freshly baked loaf of wheat bread." },
    { id: "common_wine", name: "Common Wine", category: "finished_good", base_value: 38, min_price: 15, max_price: 95, rarity: "Luxury", weight: 0.6, desc: "Simple fermented grape wine, popular in taverns." },
    { id: "confidential_documents", name: "Confidential Documents", category: "finished_good", base_value: 150, min_price: 60, max_price: 375, rarity: "Rare", weight: 0.3, desc: "Sensible papers sealed with dark wax." },
    { id: "cured_pork", name: "Cured Pork", category: "finished_good", base_value: 35, min_price: 14, max_price: 88, rarity: "Common", weight: 1.2, desc: "Pork cured with salt and dried, ideal for storage." },
    { id: "entertainment_ticket", name: "Entertainment Ticket", category: "finished_good", base_value: 50, min_price: 20, max_price: 125, rarity: "Common", weight: 0.0, desc: "A ticket representing tavern entertainment service." },
    { id: "fine_aged_schnapps", name: "Fine Aged Schnapps", category: "finished_good", base_value: 95, min_price: 38, max_price: 240, rarity: "Luxury", weight: 0.8, desc: "A premium spirit infused with wild berries and aged in oak barrels." },
    { id: "gilded_cream_cake", name: "Gilded Cream Cake", category: "finished_good", base_value: 45, min_price: 18, max_price: 110, rarity: "Luxury", weight: 0.8, desc: "An exquisite cream cake topped with sugar glaze, fit for nobility." },
    { id: "hotel_dining_ticket", name: "Hotel Fine Dining Ticket", category: "finished_good", base_value: 90, min_price: 36, max_price: 225, rarity: "Common", weight: 0.0, desc: "A ticket representing premium berry cake dining service at the Hotel." },
    { id: "hotel_dining_ticket_gilded", name: "Hotel Gilded Dining Ticket", category: "finished_good", base_value: 160, min_price: 64, max_price: 400, rarity: "Common", weight: 0.0, desc: "A ticket representing royal gilded cake dining service at the Hotel." },
    { id: "kitchen_service_ticket", name: "Kitchen Service Ticket", category: "finished_good", base_value: 50, min_price: 20, max_price: 125, rarity: "Common", weight: 0.0, desc: "A ticket representing kitchen dining service at the Inn." },
    { id: "meadhaven", name: "Meadhaven", category: "finished_good", base_value: 32, min_price: 12, max_price: 80, rarity: "Common", weight: 0.5, desc: "A sweet honey wine brewed with select barley grains." },
    { id: "noble_event_certificate", name: "Noble Event Certificate", category: "finished_good", base_value: 250, min_price: 100, max_price: 600, rarity: "Rare", weight: 0.0, desc: "A certificate confirming execution of a Noble Event service." },
    { id: "royal_event_certificate", name: "Royal Event Certificate", category: "finished_good", base_value: 600, min_price: 240, max_price: 1500, rarity: "Rare", weight: 0.0, desc: "A certificate confirming execution of a Royal Event service." },
    { id: "royal_venison_pasty", name: "Royal Venison Pasty", category: "finished_good", base_value: 55, min_price: 22, max_price: 140, rarity: "Common", weight: 0.8, desc: "A hearty meat pie filled with venison and baked in pastry crust." },
    { id: "savory_baked_eggs", name: "Savory Baked Eggs", category: "finished_good", base_value: 12, min_price: 5, max_price: 30, rarity: "Common", weight: 0.2, desc: "Eggs baked in hot coals with herbs. Simple yet satisfying." },
    { id: "smugglers_moonshine", name: "Smuggler's Moonshine", category: "finished_good", base_value: 65, min_price: 26, max_price: 160, rarity: "Common", weight: 0.5, desc: "Strong illicit liquor brewed with farmstead grains and sugar." },
    { id: "sweet_berry_cake", name: "Sweet Berry Cake", category: "finished_good", base_value: 24, min_price: 10, max_price: 60, rarity: "Common", weight: 0.6, desc: "A moist cake topped with sweet forest berries." },

    // --- Equipment ---
    { id: "bronze_pickaxe", name: "Bronze Pickaxe", category: "equipment", base_value: 60, min_price: 24, max_price: 150, rarity: "Common", weight: 2.5, desc: "Tool: Boosts gathering yield by +25%." },
    { id: "cart", name: "Cart", category: "equipment", base_value: 250, min_price: 100, max_price: 625, rarity: "Common", weight: 30.0, desc: "Transportation: Expands courier carrying slots by +8." },
    { id: "gold_ring", name: "Gold Ring", category: "equipment", base_value: 150, min_price: 60, max_price: 375, rarity: "Common", weight: 0.05, desc: "Ring: Grants +3 Attack and +5% Speed." },
    { id: "horse", name: "Horse", category: "equipment", base_value: 300, min_price: 120, max_price: 750, rarity: "Common", weight: 50.0, desc: "Transportation: Increases character speed by +50%." },
    { id: "iron_chestplate", name: "Iron Chestplate", category: "equipment", base_value: 120, min_price: 48, max_price: 300, rarity: "Common", weight: 8.0, desc: "Body Armor: Grants +15 Armor protection." },
    { id: "iron_helmet", name: "Iron Helmet", category: "equipment", base_value: 50, min_price: 20, max_price: 125, rarity: "Common", weight: 2.0, desc: "Head Armor: Grants +5 Armor protection." },
    { id: "iron_sword", name: "Iron Sword", category: "equipment", base_value: 90, min_price: 36, max_price: 225, rarity: "Common", weight: 3.0, desc: "Weapon: Grants +10 Attack power." },
    { id: "leather_backpack", name: "Leather Backpack", category: "equipment", base_value: 45, min_price: 18, max_price: 110, rarity: "Common", weight: 1.0, desc: "Bag: Adds +4 to inventory slot capacity." },
    { id: "leather_gloves", name: "Leather Gloves", category: "equipment", base_value: 35, min_price: 14, max_price: 88, rarity: "Common", weight: 0.5, desc: "Gloves: Grants +2 Armor and +5% Speed." },
    { id: "silver_necklace", name: "Silver Necklace", category: "equipment", base_value: 80, min_price: 32, max_price: 200, rarity: "Common", weight: 0.1, desc: "Necklace: Grants +10% Speed modifier." },

    // --- Skill Items ---
    { id: "book_craftsman", name: "Craftsman Manual", category: "skill_item", base_value: 1000, min_price: 400, max_price: 2500, rarity: "Rare", weight: 0.5, desc: "Unlocks the Craftsman career when read." },
    { id: "book_patreon", name: "Patreon Guide Book", category: "skill_item", base_value: 1000, min_price: 400, max_price: 2500, rarity: "Rare", weight: 0.5, desc: "Unlocks the Patreon career when read." },
    { id: "book_scholar", name: "Scholar Thesis", category: "skill_item", base_value: 1000, min_price: 400, max_price: 2500, rarity: "Rare", weight: 0.5, desc: "Unlocks the Scholar career when read." },
    { id: "book_tailor", name: "Tailor Handbook", category: "skill_item", base_value: 1000, min_price: 400, max_price: 2500, rarity: "Rare", weight: 0.5, desc: "Unlocks the Tailor career when read." }
  ],
  buildings: [
    // --- Patreon ---
    { id: "patreon_bakery_l1", name: "Bakery", profession: "patreon", cost: 150, type: "production", level: 1, desc: "A warm bakery containing a bread baking oven." },
    { id: "patreon_mill_l1", name: "Flour Mill", profession: "patreon", cost: 120, type: "production", level: 1, desc: "Walk-in building with a mill station to grind wheat." },
    { id: "patreon_bakery_l2", name: "Bakery L2", profession: "patreon", cost: 500, type: "production", level: 2, desc: "An upgraded bakery to bake delicious berry cakes and sweet buns." },
    { id: "patreon_bakery_l3", name: "Bakery L3", profession: "patreon", cost: 1200, type: "production", level: 3, desc: "A large bakery to bake gilded cream cakes and royal venison pasties." },
    { id: "patreon_farmstead_l1", name: "Farmstead", profession: "patreon", cost: 600, type: "production", level: 4, desc: "A homestead to grow barley/hops and cure pork." },
    { id: "patreon_tavern_l1", name: "Mead Tavern", profession: "patreon", cost: 400, type: "production", level: 4, desc: "A cozy local tavern to brew ale and entertain patrons." },
    { id: "patreon_inn_l1", name: "Traveler's Inn", profession: "patreon", cost: 400, type: "production", level: 5, desc: "Generates visitor revenue. Offers lodging and kitchen services." },
    { id: "patreon_tavern_l2", name: "Casino", profession: "patreon", cost: 1200, type: "production", level: 6, desc: "A high-stakes casino attracting wealthy patrons." },
    { id: "patreon_inn_l2", name: "Grand Hotel", profession: "patreon", cost: 1600, type: "production", level: 6, desc: "A luxurious hotel with premium rooms and dining." },
    { id: "patreon_distillery_l1", name: "Distillery", profession: "patreon", cost: 1000, type: "production", level: 7, desc: "A facility to ferment wines and distill liquors." },
    { id: "patreon_distillery_l2", name: "Grand Distillery", profession: "patreon", cost: 2500, type: "production", level: 8, desc: "An advanced distillery to brew fine aged schnapps." },
    { id: "patreon_event_hall_l1", name: "Event Hall", profession: "patreon", cost: 2000, type: "production", level: 8, desc: "Hosts grand banquets for massive gold payouts." },

    // --- Craftsman ---
    { id: "craftsman_smelter_l1", name: "Smelter", profession: "craftsman", cost: 140, type: "production", level: 1, desc: "Turn raw iron ore into solid iron ingots." },
    { id: "craftsman_tinker_l1", name: "Tinker Workshop", profession: "craftsman", cost: 160, type: "production", level: 1, desc: "Craft simple gadgets and mechanical parts." },
    { id: "craftsman_tinker_l2", name: "Tinker Factory", profession: "craftsman", cost: 320, type: "production", level: 2, desc: "Automatic workbench assembly." },
    { id: "craftsman_forge_l1", name: "Blacksmith Forge", profession: "craftsman", cost: 400, type: "production", level: 3, desc: "Forge advanced iron tools and hardware." },
    { id: "craftsman_smelter_t2", name: "Blast Furnace", profession: "craftsman", cost: 600, type: "production", level: 3, desc: "T2 Production: Speeds up iron ingot smelting." },
    { id: "craftsman_forge_l2", name: "Blast Furnace Forge", profession: "craftsman", cost: 800, type: "production", level: 4, desc: "Accelerate smelting and increase security." },
    { id: "craftsman_forge_l3", name: "Foundry", profession: "craftsman", cost: 1600, type: "production", level: 5, desc: "Highly secure and fire-proof automated foundry." },
    { id: "craftsman_smelter_t3", name: "Foundry Smelter", profession: "craftsman", cost: 1800, type: "production", level: 5, desc: "T3 Production: Automatic alloy production." },
    { id: "craftsman_workshop_l1", name: "Industrial Workshop", profession: "craftsman", cost: 800, type: "production", level: 5, desc: "Large space for alloy and steel crafting." },
    { id: "craftsman_workshop_l2", name: "Alloy Factory", profession: "craftsman", cost: 1600, type: "production", level: 6, desc: "Automated line for chemical processes." },
    { id: "craftsman_workshop_l3", name: "Steam Workshop", profession: "craftsman", cost: 3200, type: "production", level: 7, desc: "Maximum grade steampunk machinery." },

    // --- Tailor ---
    { id: "tailor_loom_l1", name: "Loom & Table", profession: "tailor", cost: 130, type: "production", level: 1, desc: "Walk-in workshop containing a weaving loom." },
    { id: "tailor_loom_t2", name: "Spinning Jenny", profession: "tailor", cost: 550, type: "production", level: 3, desc: "T2 Production: Spins thread automatically." },
    { id: "tailor_loom_t3", name: "Textile Factory", profession: "tailor", cost: 1600, type: "production", level: 5, desc: "T3 Production: Mass cloth weaving factory." },

    // --- Scholar ---
    { id: "scholar_paper_maker_l1", name: "Paper Maker", profession: "scholar", cost: 150, type: "production", level: 1, desc: "Press and dry raw cotton fibers into paper sheets." },
    { id: "scholar_press_l1", name: "Printing Press", profession: "scholar", cost: 300, type: "production", level: 3, desc: "Press ink onto paper and bind books." },
    { id: "scholar_bank_l1", name: "Provincial Bank", profession: "scholar", cost: 500, type: "production", level: 5, desc: "Safely deposit gold and earn 5% daily interest." },

    // --- Homes & Utility ---
    { id: "cozy_house_l1", name: "Cozy House", profession: "any", cost: 250, type: "home", level: 1, desc: "L1 Personal Home: A cozy house to sleep and store items." },
    { id: "cozy_house_l2", name: "Comfortable House", profession: "any", cost: 500, type: "home", level: 2, desc: "L2 Personal Home: More space and storage room." },
    { id: "cozy_house_l3", name: "Manor House", profession: "any", cost: 1000, type: "home", level: 3, desc: "L3 Personal Home: A large estate with high security." },
    { id: "cozy_house_l4", name: "Grand Estate", profession: "any", cost: 2000, type: "home", level: 4, desc: "L4 Personal Home: A massive, premium mansion." },
    { id: "rental_house_l1", name: "Rental House", profession: "any", cost: 250, type: "renting", level: 1, desc: "L1 Rental: Rent out to local residents for daily income." },
    { id: "rental_house_l2", name: "Comfortable Rental", profession: "any", cost: 500, type: "renting", level: 2, desc: "L2 Rental: More rooms to fetch higher rent." },
    { id: "rental_house_l3", name: "Manor Rental", profession: "any", cost: 1000, type: "renting", level: 3, desc: "L3 Rental: High-class residency with supreme yield." },
    { id: "rental_house_l4", name: "Grand Rental", profession: "any", cost: 2000, type: "renting", level: 4, desc: "L4 Rental: A premium landlord estate." },
    { id: "warehouse_l1", name: "Warehouse", profession: "any", cost: 400, type: "warehouse", level: 1, desc: "Stores large item volumes. Allows setting minimum stock." }
  ],
  recipes: [
    // Craftsman Recipes
    { name: "Smelt Iron Ore", inputs: [{ id: "iron_ore", qty: 3 }], output: { id: "iron_ingot", qty: 1 }, profession: "craftsman", level: 1, building: "craftsman_smelter_l1" },
    { name: "Craft Aging Barrels", inputs: [{ id: "iron_ingot", qty: 1 }], output: { id: "aging_barrel", qty: 1 }, profession: "craftsman", level: 3, building: "craftsman_tinker_l1" },
    { name: "Craft Premium Flasks", inputs: [{ id: "iron_ingot", qty: 1 }], output: { id: "premium_flask", qty: 1 }, profession: "craftsman", level: 2, building: "craftsman_tinker_l1" },
    { name: "Assemble Cargo Cart", inputs: [{ id: "iron_ingot", qty: 2 }, { id: "cloth", qty: 1 }], output: { id: "cart", qty: 1 }, profession: "craftsman", level: 4, building: "craftsman_tinker_l1" },
    
    // Patreon Recipes
    { name: "Grind Wheat", inputs: [{ id: "wheat", qty: 1 }], output: { id: "flour", qty: 1 }, profession: "patreon", level: 1, building: "patreon_mill_l1" },
    { name: "Bake Bread", inputs: [{ id: "flour", qty: 1 }, { id: "water", qty: 1 }], output: { id: "bread", qty: 1 }, profession: "patreon", level: 1, building: "patreon_bakery_l1" },
    { name: "Bake Savory Eggs", inputs: [{ id: "egg", qty: 2 }], output: { id: "savory_baked_eggs", qty: 1 }, profession: "patreon", level: 1, building: "patreon_bakery_l1" },
    { name: "Bake Sweet Apples", inputs: [{ id: "apple", qty: 2 }], output: { id: "baked_apples", qty: 1 }, profession: "patreon", level: 1, building: "patreon_bakery_l1" },
    { name: "Grind Animal Feed", inputs: [{ id: "wheat", qty: 1 }], output: { id: "animal_feed", qty: 1 }, profession: "patreon", level: 1, building: "patreon_mill_l1" },
    { name: "Press Oil", inputs: [{ id: "sunflower", qty: 1 }], output: { id: "oil", qty: 1 }, profession: "patreon", level: 1, building: "patreon_mill_l1" },
    
    { name: "Brew Ale", inputs: [{ id: "barley_and_hops", qty: 2 }, { id: "water", qty: 1 }], output: { id: "ale", qty: 1 }, profession: "patreon", level: 2, building: "patreon_tavern_l1" },
    { name: "Tavern Entertainment", inputs: [], output: { id: "entertainment_ticket", qty: 1 }, profession: "patreon", level: 2, building: "patreon_tavern_l1" },
    
    { name: "Bake Sweet Berry Cake", inputs: [{ id: "flour", qty: 1 }, { id: "egg", qty: 1 }, { id: "berries", qty: 1 }], output: { id: "sweet_berry_cake", qty: 1 }, profession: "patreon", level: 3, building: "patreon_bakery_l2" },
    { name: "Cure Pork", inputs: [{ id: "animal_feed", qty: 3 }], output: { id: "cured_pork", qty: 1 }, profession: "patreon", level: 3, building: "patreon_farmstead_l1" },
    { name: "Grow Barley & Hops", inputs: [{ id: "seed_packet", qty: 1 }], output: { id: "barley_and_hops", qty: 2 }, profession: "patreon", level: 3, building: "patreon_farmstead_l1" },
    
    { name: "Bake Apothecary Sweet Bun", inputs: [{ id: "flour", qty: 1 }, { id: "oil", qty: 1 }, { id: "honey", qty: 1 }], output: { id: "apothecary_sweet_bun", qty: 1 }, profession: "patreon", level: 4, building: "patreon_bakery_l2" },
    { name: "Bathhouse Service", inputs: [{ id: "water", qty: 1 }], output: { id: "bathhouse_ticket", qty: 1 }, profession: "patreon", level: 4, building: "patreon_inn_l1" },
    { name: "Kitchen Service (Baked Eggs)", inputs: [{ id: "savory_baked_eggs", qty: 1 }], output: { id: "kitchen_service_ticket", qty: 1 }, profession: "patreon", level: 4, building: "patreon_inn_l1" },
    
    { name: "Ferment Common Wine", inputs: [{ id: "grapes", qty: 1 }, { id: "water", qty: 1 }], output: { id: "common_wine", qty: 1 }, profession: "patreon", level: 5, building: "patreon_distillery_l1" },
    { name: "Brew Meadhaven", inputs: [{ id: "barley_and_hops", qty: 1 }, { id: "honey", qty: 1 }], output: { id: "meadhaven", qty: 1 }, profession: "patreon", level: 6, building: "patreon_tavern_l1" },
    
    { name: "Distill Smuggler Moonshine", inputs: [{ id: "barley_and_hops", qty: 1 }, { id: "sugar", qty: 1 }, { id: "premium_flask", qty: 1 }], output: { id: "smugglers_moonshine", qty: 1 }, profession: "patreon", level: 7, building: "patreon_distillery_l1" },
    { name: "Hotel Fine Dining", inputs: [{ id: "sweet_berry_cake", qty: 1 }], output: { id: "hotel_dining_ticket", qty: 1 }, profession: "patreon", level: 7, building: "patreon_inn_l2" },
    { name: "Hotel Gilded Dining", inputs: [{ id: "gilded_cream_cake", qty: 1 }], output: { id: "hotel_dining_ticket_gilded", qty: 1 }, profession: "patreon", level: 7, building: "patreon_inn_l2" },
    
    { name: "Bake Gilded Cream Cake", inputs: [{ id: "flour", qty: 1 }, { id: "egg", qty: 1 }, { id: "sugar", qty: 1 }, { id: "milk", qty: 1 }], output: { id: "gilded_cream_cake", qty: 1 }, profession: "patreon", level: 8, building: "patreon_bakery_l3" },
    { name: "Host Noble Event", inputs: [{ id: "savory_baked_eggs", qty: 5 }, { id: "baked_apples", qty: 5 }, { id: "ale", qty: 5 }], output: { id: "noble_event_certificate", qty: 1 }, profession: "patreon", level: 8, building: "patreon_event_hall_l1" },
    { name: "Host Royal Event", inputs: [{ id: "sweet_berry_cake", qty: 5 }, { id: "gilded_cream_cake", qty: 5 }, { id: "common_wine", qty: 5 }, { id: "smugglers_moonshine", qty: 5 }], output: { id: "royal_event_certificate", qty: 1 }, profession: "patreon", level: 8, building: "patreon_event_hall_l1" },
    
    { name: "Bake Royal Venison Pasty", inputs: [{ id: "flour", qty: 1 }, { id: "oil", qty: 1 }, { id: "venison", qty: 1 }], output: { id: "royal_venison_pasty", qty: 1 }, profession: "patreon", level: 9, building: "patreon_bakery_l3" },
    { name: "Distill Fine Aged Schnapps", inputs: [{ id: "barley_and_hops", qty: 1 }, { id: "berries", qty: 1 }, { id: "aging_barrel", qty: 1 }], output: { id: "fine_aged_schnapps", qty: 1 }, profession: "patreon", level: 10, building: "patreon_distillery_l2" },

    // Scholar Recipes
    { name: "Make Paper", inputs: [{ id: "cotton", qty: 2 }], output: { id: "paper", qty: 1 }, profession: "scholar", level: 1, building: "scholar_paper_maker_l1" },
    { name: "Print Book", inputs: [{ id: "paper", qty: 3 }], output: { id: "book", qty: 1 }, profession: "scholar", level: 2, building: "scholar_press_l1" },

    // Tailor Recipes
    { name: "Weave Cloth", inputs: [{ id: "cotton", qty: 3 }], output: { id: "cloth", qty: 1 }, profession: "tailor", level: 1, building: "tailor_loom_l1" }
  ],
  laws: [
    { id: "real_estate_levy_inc", name: "Real Estate Levy Increase", desc: "Increases real estate seasonal property taxes by +30%." },
    { id: "real_estate_levy_dec", name: "Real Estate Levy Decrease", desc: "Decreases real estate seasonal property taxes by -30%." },
    { id: "infrastructure_tariff_inc", name: "Infrastructure Tariff Increase", desc: "Modifies tariffs for trade and transport upward." },
    { id: "infrastructure_tariff_dec", name: "Infrastructure Tariff Decrease", desc: "Modifies tariffs for trade and transport downward." },
    { id: "garrison_allocation_inc", name: "Garrison Allocation Increase", desc: "Modifies provincial security guard patrol levels upward." },
    { id: "garrison_allocation_dec", name: "Garrison Allocation Decrease", desc: "Modifies provincial security guard patrol levels downward." },
    { id: "labor_welfare_mandate", name: "Labor Welfare Mandate", desc: "Forces higher employee minimum wages across all workshops." },
    { id: "hospitality_excise_tax", name: "Hospitality Excise Tax", desc: "Taxes Inkeepers and Taverns (+40% excise tax scale)." },
    { id: "crown_forestry_protection", name: "Crown Forestry Protection", desc: "Penalizes unlicensed timber gathering on overworld paths." },
    { id: "noble_game_preservation", name: "Noble Game Preservation", desc: "Penalizes venison meat hunting without guild license." },
    { id: "metallurgical_monopoly", name: "Metallurgical Monopoly", desc: "Restricts competitor mining operations, monopolizing iron veins." },
    { id: "courier_curfew", name: "Courier Curfew", desc: "Restricts nighttime automated logistics and transport operations." },
    { id: "martial_carriage_ban", name: "Martial Carriage Ban", desc: "Prohibits transport horse and cargo carriage operations on trade routes." },
    { id: "usury_prohibition", name: "Usury Prohibition", desc: "Restricts provincial banking interest accumulation." }
  ],
  mechanics: [
    { id: "quests", name: "Breakthrough Rank Quests", desc: "Upgrade breakthrough milestones for Novice ➔ Journeyman ➔ Expert ➔ Master by paying gold and crafting milestone items at Guild Master NPCs." },
    { id: "conclave", name: "Seasonal Guild Conclave", desc: "Four-day election loop with blind-bidding using Influence points to win Master, Expert, or Journeyman seats." },
    { id: "prosperity", name: "Province Prosperity", desc: "Prosperity levels scaling overnight wall upgrades and dirt road upgrades to cobblestone speeds." },
    { id: "marriage", name: "Marriage & Housing", desc: "Own a cozy personal home to marry a spouse, unlocking spouse employees for all buildings." },
    { id: "couriers", name: "Automated Logistics", desc: "Hired couriers running trade routes with cargo weight capacities to automate supply chains." },
    { id: "focus_trap", name: "Focus Trapping Modal overlays", desc: "Locks UI viewport focus inside modals for slider adjustments." },
    { id: "audits", name: "Bureaucratic Audits", desc: "Inspector summoning to halt competitor production workshops for 12 game hours." }
  ],
  macroNodes: [
    {
      id: "macro_guilds",
      name: "Guild Halls & Offices",
      desc: "Houses Guild Master NPCs for breakthrough milestones, the Materials Steward for wholesale resource purchases, and the Donations Overseer for prosperity gold deposits."
    },
    {
      id: "macro_professions",
      name: "Professions & Experience",
      desc: "Career levels (Novice, Journeyman, Expert, Master). Accumulates experience through production, but is hard-locked at levels 3, 6, and 9 until rank breakthrough quests are completed."
    },
    {
      id: "macro_relationships",
      name: "Relationships & Dynasties",
      desc: "Tracks Affinity levels with townspeople and dynasties. Allows gifting items and proposing marriage, moving the spouse to your house as an employee worker."
    },
    {
      id: "macro_buildings",
      name: "Real Estate & Workshops",
      desc: "Private houses, rental houses (earning daily rent), warehouses (setting logistics storage retain limits), and production workshops snapping to road navigation networks."
    },
    {
      id: "macro_economy",
      name: "Economy & Logistics",
      desc: "Gathers raw materials, refines semi-elaborates, crafts finished goods, and equips tools/weapons/armor. Logistics couriers automate routes snap-panning across warehouses."
    },
    {
      id: "macro_influence",
      name: "Political Influence",
      desc: "Influence Broker points earned through title status and donations. Used in blind-bidding conclave seasonal elections to win office conclave seats."
    },
    {
      id: "macro_prosperity",
      name: "Province Prosperity",
      desc: "Province-wide wealth rating. Scales overnight lot expansion, upgrades dirt roads to paved stone networks (+3% courier speed), and spawns overworld luxury raw materials."
    },
    {
      id: "macro_laws",
      name: "Legislative Laws",
      desc: "Conclave bills including Real Estate levies, minimum wage mandates, carriage bans, curfew restricts, and Wild Game preservation licenses that modify taxes, salaries, and logistics."
    }
  ],
  macroConnections: [
    { from: "macro_guilds", to: "macro_professions", label: "Breakthrough Quests" },
    { from: "macro_guilds", to: "macro_economy", label: "Wholesale Bundles" },
    { from: "macro_guilds", to: "macro_influence", label: "Office Elections" },
    { from: "macro_professions", to: "macro_buildings", label: "Unlocks Tiers" },
    { from: "macro_professions", to: "macro_economy", label: "Unlocks Recipes" },
    { from: "macro_buildings", to: "macro_economy", label: "Houses Workbenches" },
    { from: "macro_relationships", to: "macro_buildings", label: "Spouse Employees" },
    { from: "macro_prosperity", to: "macro_buildings", label: "Limits Lots & Walls" },
    { from: "macro_prosperity", to: "macro_economy", label: "Spawns Luxury Raw" },
    { from: "macro_influence", to: "macro_prosperity", label: "Donations Buff" },
    { from: "macro_influence", to: "macro_laws", label: "Conclave Voting" },
    { from: "macro_laws", to: "macro_buildings", label: "Taxes & Salaries" },
    { from: "macro_laws", to: "macro_economy", label: "Tolls & Curfews" }
  ],
  nodes: [],
  connections: []
};
