require "common.gm"
local GMItem = GM:createGMItem()

GMItem["资源/加方块套装"] = function(self)
	self:addItem("/block", 10, function(item)	item:set_block("myplugin/wool_0")end, "gm")
	self:addItem("/block", 10, function(item)	item:set_block("myplugin/end_stone")end, "gm")
	self:addItem("/block", 10, function(item)	item:set_block("myplugin/obsidian")end, "gm")
	self:addItem("/block", 10, function(item)	item:set_block("myplugin/ladder")end, "gm")
	self:addItem("/block", 10, function(item)	item:set_block("myplugin/glass_light_gray")end, "gm")
	self:addItem("/block", 10, function(item)	item:set_block("myplugin/double_oak_wood_slab")end, "gm")
end

GMItem["资源/加工具套装"] = function(self)
	self:addItem("myplugin/shear",1,nil, "gm")
	self:addItem("myplugin/wood_axe",1,nil, "gm")
	self:addItem("myplugin/wood_pickaxe",1,nil, "gm")
	self:addItem("myplugin/iron_axe",1,nil, "gm")
	self:addItem("myplugin/iron_pickaxe",1,nil, "gm")
	self:addItem("myplugin/gold_axe",1,nil, "gm")
	self:addItem("myplugin/gold_pickaxe",1,nil, "gm")
	self:addItem("myplugin/diamond_axe",1,nil, "gm")
	self:addItem("myplugin/diamond_pickaxe",1,nil, "gm")
end

GMItem["资源/生成100个掉落物"] = function(self)
	local fullName = "myplugin/tnt"
	for i = 1, 100 do
		local pos = {x = 37 + math.random(-1, 1), y = 4, z = 33 + math.random(-1, 1)}
		local item = Item.CreateItem(fullName, 1)
		DropItemServer.Create({map = nil, pos = pos, item = item})
	end
end

--------------------- test
local listCallBack = {}
local setting = require "common.setting"
function GM:listCallBack(tb)
    local func = listCallBack[tb.typ]
    func(self, tb)
end

function listCallBack:vars(tb)
    local typ = type(self.vars[tb.name])
    local value = tb.value
	if typ=="boolean" then
		value = value=="true"
	elseif typ=="number" then
		value = tonumber(value)
	elseif typ~="string" then
		return
	end
    self.vars[key] = value
end

local function listResource(typ, defaultValue, includeItems, callBack)
	listCallBack[typ] = callBack
    return function(self)
		local excludeSet = {}
		for _, v in ipairs(includeItems or {}) do
			excludeSet[v] = true
		end
		local list = {}
		for name, item in pairs(setting:fetch(typ)) do
			if excludeSet[name] then
				list[#list+1] = {
					name = name,
					typ = typ,
					default = defaultValue,
				}
			end
		end
        self:sendPacket({pid = "GMSubList", list = list})
    end
end

local RedisHandler = require "redishandler"

GMItem["排行榜/清除全部"] = function(self)
	local key = Rank.getRankKey(2, 1)
	RedisHandler:ZExpireat(key, os.time())
	RedisHandler:trySendZExpire(true)
	Rank.RequestRankData(2)
end

GMItem["资源/加buff_2000000"] = listResource("buff", 2000, {
		"myplugin/fire1",
		"myplugin/fire_self_1",
		"myplugin/damage1",
		"myplugin/damage_self_1",
		"myplugin/deArmour1",
		"myplugin/deArmour_self_1",
		"myplugin/deDamage1",
		"myplugin/deDamage_self_1",
		"myplugin/maxHp1",
		"myplugin/maxHp_self_1",
		"myplugin/moveSpeed1",
		"myplugin/moveSpeed_self_1",
		"myplugin/jumpSpeed1",
		"myplugin/jumpSpeed_self_1",
		"myplugin/reduceTime1",
		"myplugin/reduceTime_self_1",
		"myplugin/boost_create",
		"myplugin/boost_create2",
		"myplugin/hot_spring_buff",
		"myplugin/pressing_self_1",
		"myplugin/pressing1"
	}, function(self, tb)
    self:addBuff(tb.name, tonumber(tb.value))
end)
--------------------- test

return GMItem