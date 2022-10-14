
local Trades = L("Trades", {})
local NextTradeId = L("NextTradeId", 1)
local ReqSession = L("RequestSession", {})
local item_manager = require "item.item_manager"

local TradeCfg = World.cfg.tradeCfg
local ReqOverTime = TradeCfg and TradeCfg.reqOverTime or 10

local function allocTradeId()
    local id = NextTradeId
    NextTradeId = id + 1
    return id
end

function Trade.getTrade(id)
    return Trades[id]
end

local function getTradableItems(player, itemTrayType, itemFilters)
    local itemList = {}
    for _, element in pairs(player:tray():query_trays(itemTrayType)) do
        local tray = element.tray
        local items = tray and tray:query_items(function(item)
			for k, v in pairs(itemFilters or {}) do
				if item:cfg()[k] ~= v then
					return false
				end
			end
			return true
        end)
        for _, item in pairs(items) do
            local t = itemList[item:tid()]
            if not t then
                t = {}
                itemList[item:tid()] = t
            end
            t[item:slot()] = item
        end
    end
	return itemList
end

local function newTrader(player, itemTrayType, itemFilters)
    local trader = {
        player = player,
        items = getTradableItems(player, itemTrayType, itemFilters), -- [trayId][slot] = item
        selected = {}, --  {trayId, slot} = true
        confirmed = false,
    }
    return trader
end

local function sendStartTrade(player, target, trade)
	local data = trade:getTraderData(player)
	local items = data and data.items
	local itemData = {}
	for tid, trays in pairs(items) do
		local tray = player:tray():fetch_tray(tid)
		for slot, item in pairs(trays) do
			local seriItem = tray:fetch_item(slot)
			itemData[#itemData + 1] = {tid = tid, slot = slot, seriData = item and item_manager:seri_item(seriItem)}
		end
	end
	player:sendPacket({
		pid = "StartTrade",
		tradeID = trade.id,
		targetUid = target.platformUserId,
		tradeItem = itemData,
		maxImum = trade.maxImum or 6
	})
end

function Trade.create(player1, player2, itemTrayType, itemFilters, maxImum)
    local id = allocTradeId()
	player1.tradingID = id
	player2.tradingID = id
    local trade = {
		trayType = itemTrayType,
		maxImum = maxImum or World.cfg.tradeMaximum or 6,
        id = id,
        traders = {
            [player1.objID] = newTrader(player1, itemTrayType, itemFilters),
            [player2.objID] = newTrader(player2, itemTrayType, itemFilters),
        }
    }
    Trades[id] = Lib.derive(Trade, trade)
	local newTrade = Trades[id]
	sendStartTrade(player1, player2, newTrade)
	sendStartTrade(player2, player1, newTrade)
    return newTrade
end

function Trade.requestTrade(player, target, itemTrayType, itemFilters, maxImum)
	local msg
	if target.tradingID then
		msg = "gui.target.trading"
	elseif target.reqTrading then
		msg = "gui.target.requseting"
	elseif player.reqTrading then
		msg = "gui.player.requseting"
	end
	if msg then
		player:sendPacket({ pid = "ShowTip", tipType = 2, keepTime = 20, textKey = msg})
		return
	end
	target.reqTrading = true
	player.reqTrading = true
	local id = #ReqSession + 1
	ReqSession[id] = {player = player, target = target,  itemTrayType = itemTrayType, itemFilters = itemFilters, maxImum = maxImum}
	target:sendPacket({
		pid = "RequestTrade",
		objID = player.objID,
		playerName = player.name,
		sessionId = id
	})
	World.Timer(ReqOverTime * 20, function()
		target.reqTrading = false
		player.reqTrading = false
		ReqSession[id] = nil
	end)
end

function Trade.acceptTrade(player, sessionId)
	local session = ReqSession[sessionId]
	if not session or player.objID ~= (session.target and session.target.objID) then
		player:sendPacket{pid = "ShowTip",  tipType = 2, keepTime = 20, textKey = "gui.trade.inexistence.overtime"}
		return false
	end
	local player1 = session.player
	local player2 = session.target
	if not (player1 and player2 and player1:isValid() and player2:isValid()) then
		return false
	end
	player1.reqTrading = false
	player2.reqTrading = false
	Trade.create(player1, player2, session.itemTrayType, session.itemFilters, session.maxImum)
	return true
end

function Trade.RefuseTrade(player, sessionId)
	local session = ReqSession[sessionId]
	local requester = session and session.player
	local targetID = session and session.target and session.target.objID
	if requester and targetID == player.objID then
		requester.reqTrading = false
		player.reqTrading = false
		requester:sendPacket({pid = "TradeRefused", tipType = 2, keepTime = 20, textKey = "gui_trade_refuse"})
	end
end

function Trade.playerLogout(player)
	local id = player.tradingID
	local trade = id and Trade.getTrade(id)
	if trade then
		trade:close("logout")
	end
end

function Trade:getTraderData(trader)
    return self.traders[trader.objID]
end

function Trade:clearData()
	local timer = self.finishTimer
	if timer then
        timer()
        self.finishTimer = nil
    end
	for traderId, trader in pairs(self.traders) do
		local player = trader.player
		if player and player:isValid() then
			player.tradingID = nil
		end
	end
    Trades[self.id] = nil
end

function Trade:getTraders()
	local ret = {}
	for traderId, trader in pairs(self.traders) do
		local player = trader.player
		ret[#ret + 1] = player
	end
	return ret
end

function Trade:close(reason)
    self:broadcast({
        pid = "TradeClose",
        tradeId = self.id,
        reason = reason,
    })
	local players = self:getTraders()
	Trigger.CheckTriggers(nil, "TRADE_CLOSE", {obj1 = players[1], obj2 = players[2], reason = reason})
	self:clearData()
end

function Trade:broadcast(packet, excludeTraderId)
    for traderId, trader in pairs(self.traders) do
        if traderId ~= excludeTraderId then
			trader.player:sendPacket(packet)
        end
    end
end

function Trade:getSelectItems(player)
	local selected = {}
	local trader = self:getTraderData(player)
	for tid,tids in pairs(trader.selected) do
		for slot,dat in pairs(tids) do
			selected[#selected + 1] = trader.items[tid] and trader.items[tid][slot]
		end
	end
	return selected
end

function Trade:checkCapacity(objID, add)
	local cap = {}
	local count = {}
	local index, idx, idy = 1, 1, 2
	for traderId, trader in pairs(self.traders) do
		local player = trader.player
		local items = self:getSelectItems(player)
		cap[index] = player:data("tray"):check_available_capacity(self.trayType)
		count[index] = #items
		idx = (objID and traderId == objID) and index or idx
		idy = (objID and traderId ~= objID) and index or idy
		index = index + 1
	end
	add = add or 0
	return count[idx] + add > self.maxImum or cap[idx] + count[idx] + add < count[idy] or cap[idy] + count[idy] < count[idx] -- More than capacity
end

function Trade:playerAddItem(player, tid, slot)
    local trader = self.traders[player.objID]
    assert(trader)
    local item = (trader.items[tid] or {})[slot]
    if not item or self:checkCapacity(player.objID, 1) then
        return false, item and "cap.full" or "item.not.exist"
    end
    local selected = trader.selected
    if not selected[tid] then
		selected[tid] = {}
	end
	selected[tid][slot] = true
	local tray = player:tray():fetch_tray(item:tid())
	local seriItem = tray:fetch_item(item:slot())
    self:broadcast({
        pid = "TradeItemChange",
        tradeID = self.id,
        operation = "add",
        data = {
            tid = tid,
			slot = slot,
            itemData = item_manager:seri_item(seriItem)
        }
    }, player.objID)
	Trigger.CheckTriggers(nil, "TRADE_CHANGE_ITEM", {isAdd = true, obj1 = player, tradeID = self.id, item = item})
	return true
end

function Trade:playerDelItem(player, tid, slot)
    local trader = self.traders[player.objID]
    assert(trader)
    local selected = trader.selected
    local item = (trader.items[tid] or {})[slot]
    if not item then
        return false
    end
	if not selected[tid] then
		selected[tid] = {}
	end
	selected[tid][slot] = nil
    self:broadcast({
        pid = "TradeItemChange",
        tradeID = self.id,
        operation = "sub",
        data = {
			tid = tid,
			slot = slot
		}
    }, player.objID)
	Trigger.CheckTriggers(nil, "TRADE_CHANGE_ITEM", {isAdd = false, obj1 = player, tradeID = self.id, item = item})
	return true
end

function Trade:resetTrade()
	for _, trader in pairs(self.traders) do
		trader.confirmed = false
	end
	self:broadcast({pid = "TradeReset", tradeID = self.id})
end

function Trade:playerConfirm(player, isConfrim)
    local trader = self.traders[player.objID]
    assert(trader, player.objID)
    trader.confirmed = isConfrim
    self:broadcast({ pid = "TradePlayerConfirm", tradeID = self.id, objID = player.objID , isConfrim = isConfrim}, player.objID)

	local timer = self.finishTimer
	if not isConfrim and timer then
		timer()
		self.finishTimer = nil
		self:broadcast({pid = "ShowTip",  tipType = 2, keepTime = 20, textKey = "gui.trade.stop"})
		return
	end

    for _, trader in pairs(self.traders) do
        if not trader.confirmed then
            return
        end
    end
	--BTS接口检测能否交易
	local object = {}
	local items = {}
	for traderId, trader in pairs(self.traders) do
		object[#object + 1] = trader.player
		items[#items + 1] = self:getSelectItems(trader.player)
	end
	local context = {resetTrade = false, obj1 = object[1], obj2 = object[2], items1 = items[1], items2 = items[2], trayType = self.trayType}
	Trigger.CheckTriggers(nil, "TRADE_CONFIRM", context)
	if context.resetTrade then
		self:resetTrade()
		return
	end
    -- 所有人都准备好了，倒计时开始
    self.finishTimer = World.Timer(TradeCfg.WaitingTime or 20 * 4, self.finish, self)
end

function Trade:playerCancel(player)
    assert(self.traders[player.objID], player.objID)
    -- 有一方取消，所有人都取消
    for _, trader in pairs(self.traders) do
        trader.confirmed = false
    end
	self:clearData()
    self:broadcast({ pid = "TradePlayerCancel", traderId = self.id, objID = player.objID}, player.objID)
	local players = self:getTraders()
	Trigger.CheckTriggers(nil, "TRADE_CANCEL", {obj1 = players[1], obj2 = players[2], initiator = player})
end

local function getTraySlot(entity, item, trayType)
	if item then
		local tray = entity:data("tray"):fetch_tray(item:tid())
		return tray, item:slot()	
	end
	local trayArray = entity:tray():query_trays(trayType)
	for _, element in pairs(trayArray) do
		local tray = element.tray
		local slot = tray:find_free()
		if slot then
			return tray, slot
		end
	end
end

function Trade.swapTradeItem(player1, player2, tray1, slot1, tray2, slot2)
	if not Tray:check_switch(tray1, slot1, tray2, slot2) then
		return false
	end
	local item1 = tray1._slots[slot1]	
	local item2 = tray2._slots[slot2]
	local fullName1 = item1 and item1:full_name()
	local fullName2 = item2 and item2:full_name()
	local related = {}
	local resFunc = function(player, fullName, add)
		if fullName then
			local args = { type = "item", name = fullName, reason = "trade", count = add}
			player:resLog(args, related)
		end
	end
	resFunc(player1, fullName1, -1)
	resFunc(player2, fullName1, 1)
	resFunc(player1, fullName2, 1)
	resFunc(player2, fullName2, -1)
	Tray:switch(tray1, slot1, tray2, slot2)
	player1:syncSkillMap()
	player2:syncSkillMap()

	local sequence = GameAnalytics.NewSequence()
	GameAnalytics.ItemFlow(player1, "", fullName1, 1, false, "trade", player2.platformUserId, sequence)
	GameAnalytics.ItemFlow(player1, "", fullName2, 1, true, "trade", player2.platformUserId, sequence)
	GameAnalytics.ItemFlow(player2, "", fullName1, 1, true, "trade", player1.platformUserId, sequence)
	GameAnalytics.ItemFlow(player2, "", fullName2, 1, false, "trade", player1.platformUserId, sequence)

	return true
end

function Trade:finish()
    for _, trader in pairs(self.traders) do
        assert(trader.confirmed)
		if not trader.player or not trader.player:isValid() then
			self:close("break")
			return
		end
    end
	if self:checkCapacity(nil, 0) then
		self:close("moreCap")
		return
	end
	local player = {}
	local items = {}
	for traderId, trader in pairs(self.traders) do
		player[#player + 1] = trader.player
		items[#items + 1] = self:getSelectItems(trader.player)
	end
	local player1, player2 = player[1], player[2]
	local context = {obj1 = player1, obj2 = player2, items1 = items[1], items2 = items[2], tradeID = self.id, needswap = true}
	Trigger.CheckTriggers(nil, "DOFINISH_TRADE", context)
	if not context.needswap then
		self:broadcast({pid = "TradeSucceed", tradeID = self.id})
		self:clearData()
		return
	end
	local maxLen = math.max(#items[1], #items[2])
	local trays1 = player1:data("tray")
	local trays2 = player2:data("tray")
	local record = {}
	for index = 1, maxLen do
		local item1, item2 = items[1][index], items[2][index]
		local tray1, slot1 = getTraySlot(player1, item1, self.trayType)
		local tray2, slot2 = getTraySlot(player2, item2, self.trayType)
		Trade.swapTradeItem(player1, player2, tray1, slot1, tray2, slot2)
		record[#record + 1] = {tray1 = tray1, slot1 = slot1, tray2 = tray2, slot2 = slot2}
	end
	local sold = {{},{}}
	for _, data in pairs(record) do
		local item1 = data.tray1._slots[data.slot1]	
		local item2 = data.tray2._slots[data.slot2]
		table.insert(sold[1], item1)
		table.insert(sold[2], item2)
	end
	self:broadcast({pid = "TradeSucceed", tradeID = self.id})
	Trigger.CheckTriggers(nil, "TRADE_SUCCEED", {obj1 = player1, obj2 = player2, sold1 = sold[1], sold2 = sold[2]})
	self:clearData()
end

RETURN()