require "common.shop.entity_shop"
require "common.shop.shop"
require "shop.money_shop"

local ShopBase = Shop.GetType("Base")

function ShopBase:doPay(packet, from, rewardCallBack)
	local costPrice = self.price
	if self.specialPrice and self:checkPriceEnough(self.specialPrice, from) then
		costPrice = self.specialPrice
	end
	--扣钱，如果有金魔方，因为是异步，需要放最后，发奖在金魔方的回调里面
	local diamondsCount = 0
	for coinName, priceCount in pairs(costPrice) do
		local result = false
		if coinName == "gDiamonds" then
			diamondsCount = priceCount
		else
			if not from:payCurrency(coinName, priceCount, false, false, self.rewardParams.reason or self.fullName) then
				--加消息给客户端
				from:noticeNotEnoughMoney(coinName, self.fullName)
				return false
			end
		end
	end
	local result = false
	if diamondsCount > 0 then
		from:consumeDiamonds("gDiamonds", diamondsCount, function(ret)
			if ret then
				Lib.logDebug("consume diamonds success")
				rewardCallBack(packet, from)
				return true
			else
				Lib.logDebug("consume diamonds error")
				--加消息给客户端
				from:noticeNotEnoughMoney("gDiamonds", self.fullName)
			end
		end, packet.name)
	else
		rewardCallBack(packet, from)
		Lib.logDebug("cost money success, reward now")
	end
	return result
end

function ShopBase:successNotice(packet, from)
	if self.reportType then
		from:reportByType(self.reportType, Lib.getNameByFullName(self.fullName))
	end
	if self.limit and self.limit.num then
		from:recordShop(self.fullName)
	end
	from:sendPacket({
		pid = "BuySuccess",
		name = packet.name
	})
end

function Shop.BuyByClient(packet, from)
	local cfg = Shop.Cfg(packet.name, from)
	--验钱,然后再看特定逻辑
	if not cfg:canBuy(packet, from) then
		return
	end
	if not cfg:buy(packet, from) then
		return
	end
end

RETURN()
