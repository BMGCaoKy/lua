local self = SingleShop

SingleShop.types = {
	COMMODITY = "commodity",
	SHOP = "shop",
	SINGLESHOP = "singleShop",
}

SingleShop.cfgs = {
	commodity = {},
	shop = {},
	singleShop = {},
}

SingleShop.typeGoods = {
	commodity = {},
	shop = {},
	singleShop = {},
}

SingleShop.goods = {
	commodity = {},
	shop = {},
	singleShop = {},
}

SingleShop.groups = {
	commodity = {},
	shop = {},
	singleShop = {},
}

local worldCfg = World.cfg

self.groupCfgKey = {
	commodity = "merchantGroup",
	shop = "shopGroup",
	singleShop = "singleShopGroup",
}


local function initGroups(shopType)
	local cfg = worldCfg[self.groupCfgKey[shopType]]
	if cfg then
		self.groups[shopType] = cfg
		return
	end
	local ret = {
		showTitle = "default_" .. shopType .. "_title",
		typeIndex = {},
	}
	self.groups[shopType]["__" .. shopType .. "__"] = ret
	return ret
end

local function addTypeIndex(group, typeIndex, typeKey, typeIcon)
	local types = group.typeIndex
	for _, item in pairs(types) do
		if item[1] == typeIndex then
			return
		end
	end
	if typeIcon == "#" then
		typeIcon = nil
	elseif typeIcon and typeIcon~="" and typeIcon:sub(1,5) == "asset" then --old
		typeIcon = string.gsub(typeIcon, "asset", "@")
	end
	types[#types + 1] = {
		typeIndex,
		typeKey,
		typeIcon,
	}
end

local function initGoods(csvName, shopType)
	local cfg = Lib.readGameCsv(csvName) or {}
	local defaultGroup = initGroups(shopType)
	if not cfg or not next(cfg) then
		return
	end

	SingleShop.cfgs[shopType] = cfg
	for i, curItem in pairs(cfg) do
		local item = {}
		local typeGoods = {}
		local type = tonumber(curItem.type)
		if defaultGroup then
			addTypeIndex(defaultGroup, type, curItem.name, curItem.icon)
		end
		typeGoods.type = type
		typeGoods.commoditys = {}
		if self.typeGoods[shopType][type] ~= nil then
			typeGoods = self.typeGoods[shopType][type]
		end
		item.index = i
		item.desc = curItem.desc -- user-defined item name
		item.tipDesc = curItem.tipDesc or "" -- user-defined item tip
		if curItem.detail then--old
			item.tipDesc = curItem.detail-- user-defined item tip
		end
		if curItem.image == "#" then
			item.image = ""
		else
			item.image = curItem.image
		end
		if curItem.itemName == "#" then
			item.itemName = ""
		else
			item.itemName = curItem.itemName
		end
		item.blockName = curItem.blockName
		if curItem.itemType then--old
			if curItem.itemType == "Block" then
				item.blockName = curItem.itemName
				item.itemName = "/block"
			end
		elseif curItem.meta then--old
			if curItem.meta ~= "" then
				item.blockName = curItem.meta
			end
		end
		item.num = tonumber(curItem.num)
		item.coinName = tostring(curItem.coinName)
		if curItem.coinId then--old
			item.coinName = Coin:coinNameByCoinId(tonumber(curItem.coinId))
		end
		item.price = tonumber(curItem.price)

		if not curItem.limitType then
			item.limitType = -1
		else
			item.limitType = tonumber(curItem.limitType)
		end

		if not curItem.limit then
			item.limit = -1
		else
			item.limit = tonumber(curItem.limit)
		end

		item.buy_sound = curItem.buy_sound
		typeGoods.commoditys[#typeGoods.commoditys + 1] = item
		self.typeGoods[shopType][type] = typeGoods
		self.goods[shopType][i] = item
	end
end

function SingleShop:GetCommodity(index)
	return assert(self.goods[index], index)
end

--todo: to be deleted
function SingleShop:readCommodity()
	initGoods("commodity.csv", "commodity")
end

--todo: to be deleted
function SingleShop:getCommodityGoods()
	return self.goods["commodity"]
end

--todo: to be deleted
function SingleShop:getCommodityTypeGoods()
	return self.typeGoods["shop"]
end

--todo: to be deleted
function SingleShop:readShop()
	initGoods("shop.csv", "shop")
end

--todo: to be deleted
function SingleShop:getShopGoods()
	return self.goods["shop"]
end

--todo: to be deleted
function SingleShop:getShopTypeGoods()
	return self.typeGoods["shop"]
end


function SingleShop:readSingleShop()
	initGoods("singleShop.csv", "singleShop")
end

function SingleShop:getGoods()
	return self.goods["singleShop"]
end

function SingleShop:getTypeGoods()
	return self.typeGoods["singleShop"]
end

function SingleShop:initSingleShop()
	self:readCommodity()--todo: to be deleted
	self:readShop()--todo: to be deleted

	self:readSingleShop()
end

function SingleShop:setLimit(shopType, shopGroup, index)
	if not shopType then
		shopType = "singleShop"
	end
	if not shopGroup then
		shopGroup = "__" .. shopType .. "__"
	end
	Lib.emitEvent(Event.EVENT_SHOP_GOOD_IS_LIMIT, shopType, shopGroup, index)
end

local function init()
	self:initSingleShop()
end

init()