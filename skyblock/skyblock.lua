skyblock.players = {}

-- Define the different quest types
local quest_types = skyblock.quest_types;

-- Initializes level/achievements
skyblock.init_level = function(name, level)
    if not skyblock.quests[level] then
        return
    end

    local pdata = skyblock.players[name]
    if not pdata then
        skyblock.players[name] = {
            level = 1,
            data = {},
            completed = 0,
        }
        pdata = skyblock.players[name]
    end

    for _, quest_type in ipairs(skyblock.quest_types) do
        pdata[quest_type] = nil
    end

    pdata.data = {}
    pdata.completed = 0
    pdata.level = level

    local total = 0

    for _, quest_type in ipairs(skyblock.quest_types) do
        if skyblock.quests[level][quest_type] then
            local quest_data = {}
            for item, quest_info in pairs(skyblock.quests[level][quest_type]) do
                quest_data[item] = 0
                if not quest_info.hidden then
                    total = total + 1
                end
            end
            pdata[quest_type] = quest_data
        end
    end
    
    pdata.total = total
end

-- Track the quest progress
local track_quest = function(pos, item, digger, quest_type)
    local name = digger:get_player_name()
    local pdata = skyblock.players[name]

    if not pdata then return end

    local level = pdata.level
    if not skyblock.quests[level] or not skyblock.quests[level][quest_type] then return end

    local quest_data = skyblock.quests[level][quest_type][item]
    if not quest_data then return end

    pdata[quest_type] = pdata[quest_type] or {}
    pdata[quest_type][item] = pdata[quest_type][item] or 0

    local count = pdata[quest_type][item]

    if count < quest_data.count then
        if quest_data.hidden then
            if quest_data.on_progress and quest_data.on_progress(pdata.data) then
                pdata[quest_type][item] = quest_data.count
                return
            end
        end

        count = count + 1
        pdata[quest_type][item] = count

        if quest_data.on_progress and quest_data.on_progress(pdata.data) then
            count = quest_data.count
        end

        if count >= quest_data.count then
            if quest_data.on_completed and not quest_data.on_completed(pos, name) then
                pdata[quest_type][item] = quest_data.count - 1
                return
            end

            minetest.chat_send_all("[Skyblock]: " .. name .. " completed '" .. quest_data.description .. "' on level " .. level)

            local diginv = digger:get_inventory()
            local rewardstack = ItemStack(quest_data.reward)
            if diginv:room_for_item("craft", rewardstack) then
                diginv:add_item("craft", rewardstack)
            else
                minetest.add_item(pos, rewardstack)
            end

            pdata.completed = pdata.completed + 1
            if pdata.completed >= pdata.total then
                skyblock.quests[level].on_completed(name)
            end
        end
    end
end

-- Track when a player digs a block
minetest.register_on_dignode(
    function(pos, oldnode, digger)
        if digger and digger:is_player() then
            track_quest(pos, oldnode.name, digger, "on_dignode")
        end
    end
)

-- Track when a player places a block
minetest.register_on_placenode(
    function(pos, newnode, placer, oldnode)
        if placer and placer:is_player() then
            track_quest(pos, newnode.name, placer, "on_placenode")
        end
    end
)

-- Track when a player crafts an item
minetest.register_on_craft(
    function(itemstack, player, old_craft_grid, craft_inv)
        if player and player:is_player() then
            track_quest(player:get_pos(), itemstack:get_name(), player, "on_craft")
        end
    end
)

-- Saving and loading player/skyblock data
local function mkdir(path)
    if minetest.mkdir then
        minetest.mkdir(path)
    else
        os.execute('mkdir "' .. path .. '"')
    end
end

local filepath = minetest.get_worldpath()..'/skyblock';
mkdir(filepath)

function load_player_data(name)
    local file, err = io.open(filepath .. '/' .. name, 'rb')
    local pdata = {}
    if not err then
        local pdatastring = file:read("*a")
        file:close()
        pdata = minetest.deserialize(pdatastring) or {}
    else
        print('[Skyblock]: problem loading player data for ' .. name .. " from file")
    end

    pdata.stats = pdata.stats or {}
    pdata.stats.time_played = pdata.stats.time_played or 0
    pdata.stats.last_login = minetest.get_gametime()
    skyblock.players[name] = pdata

    local level = pdata.level
    if not level or not skyblock.quests[level] then return end

    for quest_type, quests in pairs(skyblock.quests[level]) do
        if quest_types[quest_type] then
            if not pdata[quest_type] then pdata[quest_type] = {} end
            local qdata = pdata[quest_type]
            for item, quest_info in pairs(quests) do
                if not qdata[item] then qdata[item] = 0
                end
            end
        end
    end

    return pdata
end

function save_player_data(name)
    local file, err = io.open(filepath .. '/' .. name, 'wb')
    if err then return nil end
    local pdata = skyblock.players[name]
    if not pdata then return end

    local t = minetest.get_gametime()
    pdata.stats.time_played = pdata.stats.time_played + (t - pdata.stats.last_login)
    local pdatastring = minetest.serialize(pdata)
    file:write(pdatastring)
    file:close()
end

function save_data(is_shutdown)
    local file, err = io.open(filepath .. '/_SKYBLOCK_', 'wb')
    if err then return nil end

    local ids = skyblock.id_queue
    if is_shutdown then
        for _, player in ipairs(minetest.get_connected_players()) do
            local name = player:get_player_name()
            local pdata = skyblock.players[name] or {}
            if pdata then
                if pdata.level ~= 1 then
                    save_player_data(name)
                else
                    ids[#ids + 1] = pdata.id
                end
            end
        end
    end

    local pdatastring = minetest.serialize({skyblock.max_id, skyblock.id_queue})
    file:write(pdatastring)
    file:close()
end
skyblock.save_data = save_data;

-- Skyblock island management
skyblock.max_id = -1;
skyblock.id_queue = {};

function load_data(name)
    local file, err = io.open(filepath .. '/_SKYBLOCK_', 'rb')
    if err then return nil end
    local pdatastrin = file:read("*a")
    file:close()
    local data = minetest.deserialize(pdatastring) or {};
    skyblock.max_id = data[1] or -1;
    skyblock.id_queue = data[2] or {};
end

-- When server starts
load_data()

-- When server shutsdown
minetest.register_on_shutdown(function() save_data(true) end)

-- Manage player data when joining
minetest.register_on_joinplayer(
    function(player)
        local name = player:get_player_name()
        local pdata = skyblock.players[name]

        if pdata then return end
        load_player_data(name)
        pdata = skyblock.players[name]

        if pdata.level then
            minetest.chat_send_all(minetest.colorize("LawnGreen", "[Skyblock]: Welcome back " .. name .. " from island " .. (pdata.id or "?")))
            return
        else
            skyblock.init_level(name, 1)
            pdata = skyblock.players[name]
            minetest.chat_send_player(name, "[Skyblock]: Welcome to Skyblock! Open your inventory and check the quests.")
        end

        local id = -1
        local ids = skyblock.id_queue

        if #ids == 0 then
            skyblock.max_id = skyblock.max_id + 1
            id = skyblock.max_id

            if id >= 0 then
                local pos = skyblock.get_island_pos(id)
                minetest.chat_send_all(minetest.colorize("LawnGreen", "[Skyblock]: Spawning new island " .. id .. " for " .. name .. " at " .. pos.x .. ", " .. pos.y .. ", " .. pos.z))
                pdata.id = id
                skyblock.spawn_island(pos, name)
                player:set_pos({ x = pos.x, y = pos.y + 4, z = pos.z })
            else
                minetest.chat_send_all("[Skyblock]: Error: skyblock.max_id is < 0")
                return
            end
        else
            id = ids[#ids]
            ids[#ids] = nil
            local pos = skyblock.get_island_pos(id)
            minetest.chat_send_all(minetest.colorize("LawnGreen", "[Skyblock]: Reusing island " .. id .. " for " .. name .. " at " .. pos.x .. ", " .. pos.y .. ", " .. pos.z .. ", "))
            pdata.id = id
            player:set_pos({ x = pos.x, y = pos.y + 4, z = pos.z })

            minetest.after(5, 
            function() 
                skyblock.delete_island(pos, true) 
                skyblock.spawn_island(pos, name) 
            end)
        end
    end
)

-- Temporary island
skyblock.temporary = {};

-- Manage player data when leaving
minetest.register_on_leaveplayer(
    function(plauer, timed_out)
        local name = player:get_player_name()
        local pdata = skyblock.players[name]

        if not pdata then return end

        if pdata.level == 1 then
            skyblock.temporary[name] = { pdata.id, minetest.get_gametime() }
        else
            save_player_data(name)
            skyblock.players[name] = nil
        end
    end
)

-- Respawning players if they go outside of the boundaries
local respawn_player = function(player)
    local name = player:get_player_name()
    local pdata = skyblock.players[name]
    local pos = skyblock.get_island_pos(pdata.id)
    if not pos then 
        minetest.chat_send_all("[Skyblock]: Error: spawnpos for " .. name " nonexistent") 
        return
    end

    if pdata.level == 1 then
        skyblock.init_level(name, 1)

        if not minetest.find_node_near(pos, 5, "default:dirt") then
            skyblock.spawn_island(pos, name)
        end

        skyblock.tutorial.change_text(name, "You died!\nYour quests have been reset.\nStart digging dirt again to progress!")
    end

    pos.y = pos.y + 4
    player:setpos(pos)
end

minetest.register_on_respawnplayer(
    function(player)
        respawn_player(player)
        return true
    end
)

local timer = 0
local temptimer = 0

minetest.register_globalstep(
    function(dtime)
        timer = timer + dtime
        if timer > 1 then
            timer = 0
            local current_time  minetest.get_gametime()
            local bottom = skyblock.bottom

            for _, player in ipairs(minetest.get_connected_players()) do
                local pos = player:getpos()
                if pos.y < bottom then
                    local name player:get_player_name()
                    local pdata = skyblock.players[name]

                    if pdata and current_time - pdata.stats.last_login > 10 then
                        player:get_inventory():set_list("main", {})
                        player:get_inventory():set_list("craft", {})
                    end

                    respawn_player(player)
                end
            end

            temptimer = temptimer + 1
            if temptimer > 60 then
                temptimer = 0

                for name, tdata in pairs(skyblock.temporary) do
                    if current_time - tdata[2] > 90 then
                        local player = minetest.get_player_by_name(name)
                        if not player then
                            local ids = skyblock.id_queue
                            ids[#ids + 1] = tdata[1]

                            skyblock.players[name] = nil
                            minetest.chat_send_all("[Skyblock]: " .. name .. "'s island has been recycled.")
                        end

                        skyblock.temporary[name] = nil
                    end
                end
            end
        end
    end
)

-- GUI STUFF using sfinv
local get_quest_form = function(name) -- quest gui formspec
	local pdata = skyblock.players[name];
	if not pdata then return end
	local level = pdata.level;
	local formspec = "size[8,8]";		
	
	local form  = 
		"size[8,8]"..
		"label[0,0;".. minetest.colorize("yellow","SKYBLOCK QUESTS - LEVEL " .. level .. "]")..
		"label[-0.25,0.5;________________________________________________________________________________]";
	local y = 0;
	for qtype,quest in pairs(skyblock.quests[level]) do
		if quest_types[qtype] and quest then
			for item, qdef in pairs(quest) do
				if qdef.count and qdef.description and pdata[qtype] then
					y=y+1;
					local tex;
					local def = minetest.registered_items[item] or {};
					tex =  def.inventory_image or "bubble.png";
					
					if not string.find(tex,".png") then
						if def.tiles then
							tex = def.tiles[1] or def.tiles
						end
					end
					
					local count = pdata[qtype][item] or -1;
					local tcount = qdef.count or -1;
					local desc = qdef.description or "ERROR!";
					if count>=tcount then 
						desc = minetest.colorize("aqua", desc) 
					--else 
						--desc = minetest.colorize("Yellow", desc) 
					end
					
					form = form .. 
					"label[0,".. (0.75*y+0.25) .. ";".. desc .. "]"..
					"image[6,".. 0.75*y+0.2 .. ";0.75,0.75;".. tex .. "]"..
					"label[7,".. (0.75*y+0.25) .. ";" .. count .. "/" .. tcount .. "]"
				end
			end
		end
	end
	return form
end

local get_stats_form = function(name)
	local pdata = skyblock.players[name];
	if not pdata then return end
	local stats = pdata.stats;
	local t = minetest.get_gametime();
	t = stats.time_played + t-stats.last_login -- s
	local t_ = {math.floor(t/3600),math.floor((t-math.floor(t/3600)*3600)/60)};
	t=t-t_[1]*3600-t_[2]*60;
	local form  = 
		"size[8,8]"..
		"label[0,0..;".. minetest.colorize("yellow","STATISTICS for " .. name) .. "]"..
		"label[-0.25,0.5;________________________________________________________________________________]"..
		"label[0,1.;".."play time        : " ..  t_[1] .. " hour " .. t_[2] .. " min " .. t .. "s]"..
		"label[0,1.5;"..   "blocks digged : " ..  (stats.on_dignode or 0) .. "]" ..
		"label[0,2;".. "blocks placed : " ..  (stats.on_placenode or 0) .. "]" ..
		"label[0,2.5;"..   "items crafted  : " ..  (stats.on_craft or 0) .. "]"
    return form
 end

 if sfinv then
	sfinv.register_page("sfinv:skyblock", {
		title = "Quests",
		get = function(self, player, context)
			local content = get_quest_form(player:get_player_name());

            local tmp = {
                "size[8,8.6]",
                "bgcolor[#090909BB;true]" .. default.gui_bg .. default.gui_bg_img,
                sfinv.get_nav_fs(player, context, context.nav_titles, context.nav_idx),
                content,
                "button[6,0.;2,1;skyblock_update;REFRESH]"
            }
            return table.concat(tmp, "")
        end,
		on_player_receive_fields = function(self, player, context, fields)
			if fields.skyblock_update then 
				local fs = sfinv.get_formspec(player, context or sfinv.get_or_create_context(player))
				player:set_inventory_formspec(fs)
			end
		end,
	})

	sfinv.register_page("sfinv:skystats", {
		title = "Stats",
		get = function(self, player, context)
			local name = player:get_player_name()
			local content = get_stats_form(name) or "label[0,0;No stats available.]"

			local formspec = table.concat({
				"size[8,8.6]",
				"bgcolor[#080808BB;true]" .. default.gui_bg .. default.gui_bg_img,
				sfinv.get_nav_fs(player, context, context.nav_titles, context.nav_idx),
				content,
				"button[6,0.;2,1;skystats_update;REFRESH]"
			}, "")

			return formspec
		end,
		on_player_receive_fields = function(self, player, context, fields)
			if fields.skystats_update then 
				local fs = sfinv.get_formspec(player, context or sfinv.get_or_create_context(player))
				player:set_inventory_formspec(fs)
			end
		end,
	})
end


-- Commands for quests/stats
minetest.register_chatcommand('quest', {
	description = 'Show quests for current level',
	privs = {},
	params = "",
	func = function(name, param)
		if param and param~= "" then
			local form = get_quest_form(param);
			if form then minetest.show_formspec(name, "skyblock_quests",form) end
		else
			minetest.show_formspec(name, "skyblock_quests",get_quest_form(name))
		end
	end,
})

minetest.register_chatcommand('stats', {
	description = 'Show stats for skyblock player',
	privs = {},
	params = "",
	func = function(name, param)
		if param and param ~= "" then
			local form = get_stats_form(param);
			if form then
				minetest.show_formspec(name, "skyblock_stats", form)
			else
				minetest.chat_send_player(name, "No stats found for " .. param)
			end
		else
			local form = get_stats_form(name);
			if form then
				minetest.show_formspec(name, "skyblock_stats", form)
			else
				minetest.chat_send_player(name, "No stats found for " .. name)
			end
		end
	end,
})
