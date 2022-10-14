require "common.shop.entity_shop"
require "common.shop.shop"
require "shop.base"
require "shop.money_shop"

local lastBuyTime = 0

function Shop.DoBuy(shopName, packet)
	local cfg = Shop.Cfg(shopName)
	packet = packet or {}
	if not cfg:canBuy(packet) then
		Lib.logDebug("no auth to buy")
		if cfg.canNotBuyUIName then
			UI:openWnd(cfg.uiParams.canNotBuyUIName, cfg)
		end
		return
	end

	if lastBuyTime > 0 and World.Now() - lastBuyTime < 5 * 20 then
		--上一次的购买还没有返回，要先等待回包
		Me:showMsgTip({"tip_lang_buy_waiting_last_end"})
		return false
	end
	if cfg.debug then
		print("client Shop.DoBuy -", Me.name, cfg.fullName)
	end
	packet.pid = "BuyShop"
	packet.name = cfg.fullName
	packet.fromID = Me and Me.objID
	--检查输出 start
	assert(packet.name, "shop name is null")
	assert(cfg.fullName, "shop fullName is null")
	assert(packet.name == cfg.fullName, string.format("%s:%s", packet.name, cfg.fullName))
	assert(Shop.Cfg(packet.name) == cfg, "cfg !=")
	lastBuyTime = World.Now()
	Player.CurPlayer:sendPacket(packet)
end

function Shop.Buy(shopName, packet)
	local cfg = Shop.Cfg(shopName)
	if cfg.uiParams and cfg.uiParams.confirmUIName then
		UI:openWnd(cfg.uiParams.confirmUIName, shopName, packet)
	else
		Shop.DoBuy(shopName, packet)
	end
end

function Shop.BuySuccess(packet)
	lastBuyTime = 0
	local cfg = Shop.Cfg(packet.name)
	--if not cfg.shieldBuySuccessTip then
	--	Me:showMsgTip({"tip_lang_buy_success", cfg:getShowInfo().rewards[1] and cfg:getShowInfo().rewards[1].name})
	--end
	for k, v in pairs(cfg.buySuccessCallBack or {}) do
		if k == "openWnd" then
			UI:openWnd(v.name, table.unpack(v.args or {}))
		end
	end
	if cfg.showBuySuccessTip or cfg.price.gDiamonds then
--		UI:openWnd("buySuccTip"):onShowTip("tip_lang_buy_success")
	end
	Lib.emitEvent(Event.EVENT_BUY_SUCCESS, packet)
end

RETURN()
