-- Ensure the quests table is initialized
skyblock.quests = {}

-- Helper function for inventory check
local function has_required_items(player_name, item, count)
    local player = minetest.get_player_by_name(player_name)
    if not player then return false end

    local inv = player:get_inventory()
    if not inv:contains_item("main", ItemStack(item .. " " .. count)) then
        minetest.chat_send_player(player_name, "[Skyblock]: You need " .. count .. " " .. item .. " in your inventory. Try again!")
        return false
    end
    return true
end

-- Helper function for tutorial messages (specific to level 1)
local function send_tutorial_message(player_name, text)
    local pdata = skyblock.players[player_name]
    if pdata and pdata.level == 1 then
        skyblock.tutorial.change_text(player_name, text)
    end
end

-- Generalized quest completion logic
local function register_quest(quest_type, item, quest_data, level)
    -- Ensure the level and quest_type tables exist
    if not skyblock.quests[level] then
        skyblock.quests[level] = {
            on_dignode = {},
            on_placenode = {},
            on_craft = {},
        }
    end

    if not skyblock.quests[level][quest_type] then
        skyblock.quests[level][quest_type] = {}
    end

    -- Register the quest data for the specific item
    skyblock.quests[level][quest_type][item] = {
        reward = quest_data.reward,
        count = quest_data.count,
        description = quest_data.description,
        on_completed = quest_data.on_completed or function(pos, name)
            -- Ensure the default completion logic is correct
            if quest_data.inventory_requirement and not has_required_items(name, item, quest_data.inventory_requirement) then
                return false
            end
            if quest_data.tutorial_message then
                send_tutorial_message(name, quest_data.tutorial_message)
            end
            return true
        end,
    }
end


-- Define quests for level 1
skyblock.quests[1] = {
    on_dignode = {},
    on_placenode = {},
    on_craft = {},

    -- Level completion logic
    on_completed = function(name)
        minetest.chat_send_all("[Skyblock]: " .. name .. " completed level 1!")
        
        local player = minetest.get_player_by_name(name)
        local inv = player:get_inventory()
        inv:add_item("craft", ItemStack("basic_protect:protector"))
        minetest.chat_send_player(name, "[Skyblock]: Congratulations on completing level 1! You have received a protector as a reward. When you place it, it goes 4 blocks below the centre of your island.")
        
        skyblock.init_level(name, 2) -- Start level 2

        local pdata = skyblock.players[name]
        local id = pdata.id
        local pos = skyblock.get_island_pos(id)
        local meta = minetest.get_meta(pos)
        meta:set_string("infotext", "ISLAND " .. id .. ": " .. name) -- This island now belongs to the player

        skyblock.save_data(false) -- Adds island ID to a queue so that the island saves.
    end,
}

-- Register quests for level 1 with tutorial messages
register_quest("on_dignode", "default:dirt", {
    reward = "default:leaves 6",
    count = 1,
    description = "Dig 1 dirt",
    tutorial_message = "You can craft tree saplings now. Open the craft guide and search for the sapling recipe. Plant trees, wait a minute, and make more saplings from leaves."
}, 1)

register_quest("on_dignode", "default:tree", {
    reward = "default:water_source",
    count = 16,
    description = "Dig 16 trees",
    tutorial_message = "Keep making more composters and more dirt.\nKeep water for later."
}, 1)

register_quest("on_placenode", "default:dirt", {
    reward = "default:stick 5",
    count = 1,
    description = "Place 1 dirt",
    tutorial_message = "Use dirt to grow trees. You can craft a composter using wood planks to make more dirt."
}, 1)

register_quest("on_craft", "compost:wood_barrel", {
    reward = "default:lava_source",
    count = 16,
    description = "Hold 32 dirt in hand and craft 16 composters",
    tutorial_message = "Lava and flowing water create pumice. Use pumice to craft gravel and stone. Keep water away from lava sources!",
    on_completed = function(pos, name)
        -- Check if the player has 32 dirt in their inventory
        if not has_required_items(name, "default:dirt", 32) then
            return false
        end
        return true
    end,
}, 1)

register_quest("on_craft", "default:sapling", {
    reward = "default:axe_wood",
    count = 5,
    description = "Craft 5 saplings",
    tutorial_message = "Use axes to cut trees and gather wood. Craft composters to make more dirt for expanding your island."
}, 1)

register_quest("on_craft", "default:furnace", {
    reward = "default:axe_steel",
    count = 4,
    description = "Craft 4 furnaces",
}, 1)

-- Define quests for level 2
skyblock.quests[2] = {
    on_dignode = {},
    on_placenode = {},
    on_craft = {},

    on_completed = function(name)
        minetest.chat_send_all("[Skyblock]: " .. name .. " completed level 2!")

        local player = minetest.get_player_by_name(name)
        local inv = players:get_inventory()
        inv:add_item("craft", ItemStack("default:water_source"))
        minetest.chat_send_player(name, "[Skyblock]: Congratulations on completing level 2! You have received another water source as a reward. Place it diagonally to another water to make an infinite water source.")

        skyblock.init_level(name, 3) -- Start level 3

        local privs = core.get_player_privs(name)
        privs.fast = true
        privs.robot = true
        core.set_player_privs(name, privs)
        minetest.auth_reload()
        minetest.chat_send_player(name, "[Skyblock]: You now have fast and robot privs (up to 6 robots) as a reward!")
    end,
}

-- Register quests for level 2
register_quest("on_placenode", "default:stone", {
    reward = "default:iron_lump",
    count = 100,
    description = "Place 100 stone"
}, 2)

register_quest("on_placenode", "default:dirt", {
    reward = "default:papyrus",
    count = 1,
    description = "Place 1 dirt after you dug 100 dirt",
    on_completed = function(pos, name)
        local player = minetest.get_player_by_name(name)
        local pdata = skyblock.players[name]
        local step = pdata["on_dignode"]["default:dirt"]

        if step < 100 and step > 10 then -- Allow up to 10 dirt digs before warning
            pdata["on_dignode"]["default:dirt"] = 0
            minetest.chat_send_player(name, "[Skyblock]: Nice try - what do you think this is? Your dig dirt quest has been reset.")
            return false
        elseif step < 100 then
            return false
        end
        minetest.chat_send_player(name, "[Skyblock]: Plant papyrus on dirt or sand, 3 blocks near water to grow more.")
        return true
    end,
}, 2)

register_quest("on_dignode", "basic_protect:protector", {
    reward = "default:pick_steel",
    count = 1,
    description = "Place and dig a protector"
}, 2)

register_quest("on_dignode", "default:jungletree", {
    reward = "default:stone_with_copper",
    count = 100,
    description = "Dig 100 jungletree"
}, 2)

register_quest("on_dignode", "default:dirt", {
    reward = "default:coal_lump",
    count = 100,
    description = "Dig 100 dirt without placing it",
    on_completed = function(pos, name)
        minetest.chat_send_player(name, "[Skyblock]: To make more coal, first craft stone_with_coal and then smelt it.")
        return true
    end,
}, 2)

register_quest("on_craft", "default:stone_with_coal", {
    reward = "basic_robot:spawner",
    count = 50,
    description = "Craft 100 stone with coal",
    on_completed = function(pos, name)
        minetest.chat_send_player(name, "[Skyblock]: You can use robots to automate tasks (programming skills required) or use the alchemy lab.")
        local player = minetest.get_player_by_name(name)
        local inv = player:get_inventory()
        inv:add_item("craft", ItemStack("alchemy:lab"))
        return true
    end,
}, 2)

register_quest("on_craft", "basic_machines:iron_dust_00", {
    reward = "default:jungleleaves 6",
    count = 50,
    description = "Craft 100 iron dust"
}, 2)

-- Define quests for level 3
skyblock.quests[3] = {
    on_dignode = {},
    on_placenode = {},
    on_craft = {},

    on_completed = function(name)
        minetest.chat_send_all("[Skyblock]: " .. name .. " completed level 3!")

        skyblock.init_level(name, 4) -- Start level 4
    end,
}

-- Register quests for level 3
register_quest("on_craft", "default:bookshelf", {
    reward = "farming:rhubarb_3 3",
    count = 10,
    description = "Craft 10 bookshelves",
    on_completed = function(pos, name)
        minetest.chat_send_player(name, "[Skyblock]: Place rhubarb seed on a matured composter. Be sure to insert fertilizer first. Fix any weeds by punching them before 5 minutes elapse.")
        return true
    end,
}, 3)

register_quest("on_craft", "farming:rhubarb_pie", {
    reward = "default:diamond",
    count = 50,
    description = "Craft 10 rhubarb pies"
}, 3)

register_quest("on_craft", "default:brick", {
    reward = "moreores:mineral_silver",
    count = 100,
    description = "Craft 100 bricks"
}, 3)

register_quest("on_craft", "basic_machines:copper_dust_00", {
    reward = "default:gold_lump",
    count = 50,
    description = "Craft 100 copper dust"
}, 3)

register_quest("on_craft", "basic_machines:mese_dust_00", {
    reward = "default:grass_1",
    count = 25,
    description = "Craft 50 mese dust",
    on_completed = function(pos, name)
        minetest.chat_send_player(name, "[Skyblock]: Place grass on dirt and wait. It will turn into green dirt, which will spread and grow more grass and flowers. You can get seeds by digging grass.")
        return true
    end,
}, 3)

register_quest("on_placenode", "basic_machines:battery_0", {
    reward = "basic_machines:grinder",
    count = 1,
    description = "Place a battery"
}, 3)

register_quest("on_placenode", "darkage:silt", {
    reward = "moreores:mineral_mithril",
    count = 1,
    description = "Place 1 silt while having 100 silt in your inventory",
    on_completed = function(pos, name)
        local player = minetest.get_player_by_name(name)
        local inv = player:get_inventory()

        if not inv:contains_item("main", ItemStack("darkage:silt 100")) then
            minetest.chat_send_player(player_name, "[Skyblock]: You need 100 silt blocks in your inventory. Try again!")
            return false
        end
        return true
    end,
}, 3)

register_quest("on_placenode", "default:mossycobble", {
    reward = "moreores:mineral_tin",
    count = 1,
    description = "Place 1 mossy cobble while having 100 mossy cobble in your inventory",
    on_completed = function(pos, name)
        local player = minetest.get_player_by_name(name)
        local inv = player:get_inventory()

        if not inv:contains_item("main", ItemStack("default:mossycobble 100")) then
            minetest.chat_send_player(name, "[Skyblock]: You need 100 mossy cobble blocks in your inventory. Try again!")
            return false
        end
        return true
    end,
}, 3)

register_quest("on_placenode", "default:steelblock", {
    reward = "farming:cocoa_beans 9",
    count = 1,
    description = "Place 1 steel block while having 4 steel blocks in your inventory",
    on_completed = function(pos, name)
        local player = minetest.get_player_by_name(name)
        local inv = player:get_inventory()

        if not inv:contains_item("main", ItemStack("default:steelblock 4")) then
            minetest.chat_send_player(name, "[Skyblock]: You need 4 steel blocks in your inventory. Try again!")
            return false
        end
        return true
    end,
}, 3)

register_quest("on_placenode", "default:goldblock", {
    reward = "default:mese_crystal",
    count = 1,
    description = "Place 1 gold block while having 4 gold blocks in your inventory",
    on_completed = function(pos, name)
        local player = minetest.get_player_by_name(name)
        local inv = player:get_inventory()

        if not inv:contains_item("main", ItemStack("default:goldblock 4")) then
            minetest.chat_send_player(name, "[Skyblock]: You need 4 gold blocks in your inventory. Try again!")
            return false
        end
        return true
    end,
}, 3)

-- Define quests for level 4
skyblock.quests[4] = {
    on_dignode = {},
    on_placenode = {},
    on_craft = {},

    on_completed = function(name)
        minetest.chat_send_all("[Skyblock]: " .. name .. " completed level 4!")

        skyblock.init_level(name, 5) -- Start level 5
    end,
}

-- Register quests for level 4
register_quest("on_placenode", "basic_machines:mover", {
    reward = "farming:corn",
    count = 1,
    description = "Place a mover"
}, 4)

register_quest("on_placenode", "basic_machines:generator", {
    reward = "farming:grapes",
    count = 1,
    description = "Place a generator"
}, 4)

register_quest("on_placenode", "basic_machines:clockgen", {
    reward = "farming:blueberries",
    count = 1,
    description = "Place a clock generator"
}, 4)

register_quest("on_placenode", "basic_machines:autocrafter", {
    reward = "farming:beans",
    count = 1,
    description = "Place an autocrafter"
}, 4)

register_quest("on_placenode", "basic_machines:enviro", {
    reward = "farming:tomato",
    count = 1,
    description = "Place an environment block"
}, 4)

register_quest("on_placenode", "default:diamondblock", {
    reward = "default:pine_leaves",
    count = 1,
    description = "Place 1 diamond block while having 3167 diamond blocks in your inventory",
    on_completed = function(pos, name)
        local player = minetest.get_player_by_name(name)
        local inv = player:get_inventory()

        if not inv:contains_item("main", ItemStack("default:diamondblock 3167")) then
            minetest.chat_send_player(name, "[Skyblock]: You need 3167 diamond blocks in your inventory. Try again!")
            return false
        end
        return true
    end,
}, 4)

register_quest("on_placenode", "default:mese", {
    reward = "default:acacia_leaves",
    count = 1,
    description = "Place 1 mese block while having 1000 mese blocks in your inventory",
    on_completed = function(pos, name)
        local player = minetest.get_player_by_name(name)
        local inv = player:get_inventory()

        if not inv:contains_item("main", ItemStack("default:mese 1000")) then
            minetest.chat_send_player(name, "[Skyblock]: You need 1000 mese blocks in your inventory. Try again!")
            return false
        end
        return true
    end,
}, 4)

register_quest("on_placenode", "default:goldblock", {
    reward = "default:cactus",
    count = 1,
    description = "Place 1 gold blokc while having 1000 gold blocks in your inventory",
    on_completed = function(pos, name)
        local player = minetest.get_player_by_name(name)
        local inv = player:get_inventory()

        if not inv:contains_item("main", ItemStack("default:goldblock 1000")) then
            minetest.chat_send_player(name, "[Skyblock]: You need 1000 gold blocks in your inventory. Try again!")
            return false
        end
        return true
    end,
}, 4)

register_quest("on_craft", "basic_robot:spawner", {
    reward = "farming:cocoa_beans",
    count = 1,
    description = "Craft a robot spawner"
}, 4)

-- Define quests for level 5
skyblock.quests[5] = {
    on_dignode = {},
    on_placenode = {},
    on_craft = {},

    on_completed = function(name)
        minetest.chat_send_all("[Skyblock]: " .. name .. " completed level 5!")

        skyblock.init_level(name, 6) -- Start level 6

        local privs = core.get_player_privs(name)
        privs.fly = true,
        core.set_player_privs(name, privs)
        minetest.auth_reload()
        minetest.chat_send_player(name, "[Skyblock]: You now have fly privs as a reward! You can now fly around.")
    end,
}

-- Register quests for level 5
register_quest("on_dignode", "moreblocks:dirt_compressed", {
    reward = "gloopblocks:evil_block 3",
    count = 3167,
    description = "Dig 3167 compressed dirt blocks"
}, 5)

register_quest("on_dignode", "default:obsidian", {
    reward = "default:acacia_sapling",
    count = 1000,
    description = "Dig 1000 obsidian"
}, 5)

register_quest("on_placenode", "basic_materials:concrete_block", {
    reward = "default:aspen_sapling",
    count = 1,
    description = "Place 1 concrete block while having 3167 concrete blocks in your inventory",
    on_completed = function(pos, name)
        local player = minetest.get_player_by_name(name)
        local inv = player:get_inventory()

        if not inv:contains_item("main", ItemStack("basic_materials:concrete_block 3167")) then
            minetest.chat_send_player(name, "[Skyblock]: You need 3167 concrete blocks in your inventory. Try again!")
            return false
        end
        return true
    end,
}, 5)

register_quest("on_craft", "moreblocks:cactus_brick", {
    reward = "default:emergent_jungle_sapling",
    count = 1,
    description = "Place 1 cactus brick while having 3167 cactus bricks in your inventory",
    on_completed = function(pos, name)
        local player = minetest.get_player_by_name(name)
        local inv = player:get_inventory()

        if not inv:contains_item("main", ItemStack("moreblocks:cactus_brick")) then
            minetest.chat_send_player(name, "[Skyblock]: You need 3167 cactus bricks in your inventory. Try again!")
            return false
        end
        return true
    end,
}, 5)

register_quest("on_craft", "moreores:mithril_block", {
    reward = "currency:shop",
    count = 1,
    description = "Place 1 mithril block while having 3167 mithril blocks in your inventory",
    on_completed = function(pos, name)
        local player = minetest.get_player_by_name(name)
        local inv = player:get_inventory()

        if not inv:contains_item("main", ItemStack("moreores:mithril_block 3167")) then
            minetest.chat_send_player(name, "[Skyblock]: You need 3167 mithril blocks in your inventory. Try again!")
            return false
        end
        return true
    end,
}, 5)

register_quest("on_craft", "moreores:silver_block", {
    reward = "currency:minegeld_100",
    count = 1,
    description = "Place 1 silver block while having 3167 silver blocks in your inventory",
    on_completed = function(pos, name)
        local player = minetest.get_player_by_name(name)
        local inv = player:get_inventory()

        if not inv:contains_item("main", ItemStack("moreores:silver_block 3167")) then
            minetest.chat_send_player(name, "[Skyblock]: You need 3167 silver blocks in your inventory. Try again!")
            return false
        end
        return true
    end,
}, 5)

register_quest("on_craft", "moreblocks:copperpatina", {
    reward = "default:cactus",
    count = 1000,
    description = "Craft 1000 copper patina blocks"
}, 5)

register_quest("on_craft", "gloopblocks:rainbow_block_horizontal", {
    reward = "maptools:infinitefuel",
    count = 4950,
    description = "Craft 4950 rainbow horizontal blocks"
}, 5)

register_quest("on_craft", "basic_robot:spawner", {
    reward = "farming:cocoa_beans",
    count = 1,
    description = "Craft a robot spawner"
}, 5)

register_quest("on_craft", "moreblocks:iron_checker", {
    reward = "homedecor:wardrobe",
    count = 1584,
    description = "Craft 1584 iron checker blocks"
}, 5)

-- Define quests for level 6
skyblock.quests[6] = {}

--Supported quest types
skyblock.quest_types = {
    on_dignode = true, 
    on_placenode = true, 
    on_craft = true
};
