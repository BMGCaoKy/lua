local setting = require "common.setting"

local CfgMod = setting:mod("shop")

-- 不同类型技能的定义（技能config的metatable、基类）
local ShopType = L("ShopType", {})

local ShopBase = ShopType.Base
if not ShopBase then	-- 此对象会被client/server的定义覆盖，这里不可以热更新
	ShopBase = {}
	ShopBase.__index = ShopBase
	ShopType.Base = ShopBase

	function ShopBase:preCheckCanBuy(packet, from)   --满足条件才有资格
		packet = packet or {}
		local compFunc = {
			['=='] = function(a, b) return a == b end,
			['>='] = function(a, b) return a >= b end,
			['>'] = function(a, b) return a > b end,
			['<='] = function(a, b) return a <= b end,
			['<'] = function(a, b) return a < b end,
			['~='] = function(a, b) return a ~= b end,
			['!='] = function(a, b) return a ~= b end
		}
		for _, condition in pairs(self.preCondition or {}) do
			local func = from[condition.valueKey]
			local value = ((func and type(func) == "function") and {func(from, self)} or {from:getValue(condition.valueKey)})[1]
			local opFunc = compFunc[condition.compType]
			if value == nil or type(opFunc) ~= "function" or not opFunc(value, condition.value) then
				Lib.logDebug("check value", condition.valueKey, value, condition.compType, "false")
				if condition.failTips then
					from:showMsgTip(condition.failTips)
				end

				return false
			end
			Lib.logDebug("check value", condition.valueKey, value, condition.compType, "true")
		end
		return true
	end
	function ShopBase:canBuy(packet, from)	-- C/S通用的基本释放条件检查
		if not World.cfg.openShop then
			return false
		end
		packet = packet or {}
		if not self:preCheckCanBuy(packet, from) then
			Lib.logDebug("pre condition check error, break", packet.reason)
			return false
		end
		if not self:checkRecordLimit(from) then
			Lib.logDebug("record error, can't buy")
			return false
		end
		if self.specialPrice and self:checkPriceEnough(self.specialPrice, from) then
			return true
		end
		return self:checkPriceEnough(self.price, from, true)
	end
	function ShopBase:buy(packet, from)
	end
	--每日/每月/新手等礼包单独处理，因为非常通用
	function ShopBase:checkRecordLimit(from)
		if self.limit and self.limit.num then
			if from:getRecordShop(self.fullName).num >= self.limit.num then
				Lib.logDebug("record limit", from:getRecordShop(self.fullName).num, self.limit.num)
				return false
			end
		end
		return true
	end
	function ShopBase:checkPriceEnough(price, from, needNotice)
		if not self.price then
			--价格是0就要配空数组，不能啥都没，省的忘了
			Lib.logFatal("price must modified!")
		end
		local wallet = from:data("wallet")
		for coinName, priceCount in pairs(price) do
			if not wallet[coinName] or wallet[coinName].count < priceCount then
				if needNotice then
					from:noticeNotEnoughMoney(coinName, self.fullName)
				end
				Lib.logDebug("check price, no enough")
				return false
			end
		end
		return true
	end
end

function Shop.Cfg(name, from)
	local cfg = CfgMod:get(name)
	if not cfg then
		Lib.logError(from and string.format("%s:%s:%s", name, from.name, from.platformUserId) or name)
	end
	return cfg
end

---@param typ string
function Shop.GetType(typ)
	local st = ShopType[typ]
	if not st then
		st = {}
		st.__index = st
		ShopType[typ] = setmetatable(st, ShopType.Base)
	end
	return st
end

local function init()
	local systemShop = World.cfg.systemShop or {
	}
	for _, cfg in ipairs(systemShop) do
		CfgMod:set(cfg)
	end
end

function CfgMod:onLoad(cfg, reload)
	setmetatable(cfg, Shop.GetType(cfg.type))
end

init()

RETURN()
