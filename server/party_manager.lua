local self = PartyManager
local PARTY_LIST_SHOW_ITEM_COUNT = World.cfg.partyListShowItemCount or 20
local TIP_TIME = World.cfg.partyTipTime or 20

local TIP_KEY = {
    [2040] = "tip.user.party.not.close",
    [2041] = "tip.user.no.party",
    [2042] = "tip.user.party.reach.capacity",
    [2043] = "tip.user.no.right.update",
    [2047] = "tip.user.like.already",
    [2050] = "tip.user.already.in.party",
    [2051] = "tip.user.already.in.other.party",
    [2048] = "tip.user.not.in.party",
}

function PartyManager.Init()
	self.lastUpdatePartyListTime = 0
end

function PartyManager.SendPartyTip(userId, code)
	local player = Game.GetPlayerByUserId(userId)
	local textKey = TIP_KEY[code]
	if not player or not textKey then
		return
	end

	player:sendTip(2, textKey, TIP_TIME)
end

function PartyManager.SetPartyQuality(userId, isGood)
    isGood = isGood and 1 or 0
	AsyncProcess.UpdateParty(userId, {isGood = isGood})
end

function PartyManager.SetPartyCapacity(userId, maxPlayerNum)
	AsyncProcess.UpdateParty(userId, {maxPlayerNum = maxPlayerNum})
end

function PartyManager.SetPartyImage(userId, image)
	AsyncProcess.UpdateParty(userId, {partyImage = image})
end

local function checkBalance(player, coinId, price)
    local coinName = coinId < 3 and "gDiamonds" or "green_currency"
    local currency = player:getCurrency(coinName)
    return currency and currency.count >= price
end

function PartyManager.CheckCreateParty(userId, time)
    local coinId = World.cfg.party.coinId
    local player = assert(Game.GetPlayerByUserId(userId))
    local remainCount = World.cfg.party.freePartyCount - player.vars.useFreePartyCount
    local minTime = 0
    for _, k in pairs(World.cfg.party.prices) do
        if minTime == 0 then
            minTime = k.time
        end
        minTime = math.min(k.time, minTime)
    end

    if remainCount > 0 and minTime == time then
        return true , 0
    else
        local price = 0
        for _, v in pairs(World.cfg.party.prices) do
            if v.time == time then
                price = v.price
                break
            end
        end
        if(checkBalance(player, coinId, price)) then
            return true, price
        else
            return false, 0
        end
    end
end

function PartyManager.RenewParty(userId, packet)
    local price = 0
    local time = packet.time;
    for _, v in pairs(World.cfg.party.prices) do
        if v.time == time then
            price = v.price
            break
        end
    end
    local coinId = World.cfg.party.coinId
    local player = assert(Game.GetPlayerByUserId(userId))
    if(checkBalance(player, coinId, price)) then
        if coinId < 3 then
            Lib.payMoney(player, 1000111, coinId, price, function (isSucceed)
                if isSucceed then
                    Trigger.CheckTriggers(player:cfg(), "RENEW_PARTY_SUCCESS", { obj1 = player, time = time })
                    player:sendTip(2, "party_renew_succeed", TIP_TIME)
                else
                    player:sendTip(2, "party_renew_error", TIP_TIME)
                end
            end)
        else
            if player:payCurrency("green_currency", price, false, false, "renew_party") then
                Trigger.CheckTriggers(player:cfg(), "RENEW_PARTY_SUCCESS", {obj1 = player, time = time})
                player:sendTip(2, "party_renew_succeed", TIP_TIME)
            else
                player:sendTip(2, "party_renew_error", TIP_TIME)
            end
        end
    else
        player:sendPacket(coinId < 3 and {pid = "ShowRecharge"} or { pid = "ShowGoldShop", show = true })
        return false, 0
    end

end

function PartyManager.TryCreateParty(userId, packet)
	local player = assert(Game.GetPlayerByUserId(userId))
	local content = {
        obj1 = player,
        canCreate = true,
        tip = "tip.user.create.party.failed",
	}
    local partyInfo = player:data("partyInfo")
    if packet then
        partyInfo.keepTime = packet and packet.time or 0
        partyInfo.partyName = packet and packet.partyName
    end
	--Trigger.CheckTriggers(player:cfg(), "TRY_CREATE_PARTY", content)
	if not content.canCreate then
		player:sendTip(2, content.tip, TIP_TIME)
		return
	end

    local mapKey = {
        keepTime = partyInfo.keepTime or 0
    }

    local canCreate, price = PartyManager.CheckCreateParty(userId,mapKey.keepTime or 0)
    if not canCreate then
        player:sendPacket(World.cfg.party.coinId < 3 and {pid = "ShowRecharge"} or { pid = "ShowGoldShop", show = true })
        return
    end

    local userCache = UserInfoCache.GetCache(player.platformUserId)
	local language = userCache and userCache.language or 'en'
	AsyncProcess.CreateParty(userId, language, partyInfo.partyName, partyInfo.likeNum, partyInfo.maxPlayerNum,
            partyInfo.reachPlayerNum, partyInfo.lowerRate, partyInfo.partyImage, mapKey)
end

function PartyManager.OnCreateParty(userId, partyId, mapKey)
	local player = Game.GetPlayerByUserId(userId)
	if not player then
		AsyncProcess.CloseParty(userId)
		return
	end
    Trigger.CheckTriggers(player:cfg(), "CREATE_PARTY_SUCCESS", {obj1 = player, partyId = partyId})
end

function PartyManager.PayPartyCost(userId, time)
    local player = Game.GetPlayerByUserId(userId)
    local canCreate, price = PartyManager.CheckCreateParty(userId,time or 0)
    if canCreate then
        if price == 0 then
            player.vars.useFreePartyCount = player.vars.useFreePartyCount + 1
            Trigger.CheckTriggers(player:cfg(), "PAY_PARTY_RESULT", {obj1 = player, time = time, isSucceed = true})
        else
            local coinId = World.cfg.party.coinId
            if coinId < 3 then
                Lib.payMoney(player, 10000, coinId, price, function (isSucceed)
                    Trigger.CheckTriggers(player:cfg(), "PAY_PARTY_RESULT", { obj1 = player, time = time, isSucceed = isSucceed })
                end)
            else
                local isSucceed = player:payCurrency("green_currency", price, false, false, "create_party")
                Trigger.CheckTriggers(player:cfg(), "PAY_PARTY_RESULT", {obj1 = player, time = time, isSucceed = isSucceed})
            end
        end
    else
        Trigger.CheckTriggers(player:cfg(), "PAY_PARTY_RESULT", {obj1 = player, time = time, isSucceed = false})
    end
end

function PartyManager.CloseParty(userId)
	AsyncProcess.CloseParty(userId)
end

function PartyManager.OnCloseParty(userId)
	local player = Game.GetPlayerByUserId(userId)
	if not player then
		return
	end
	Trigger.CheckTriggers(player:cfg(), "CLOSE_PARTY_SUCCESS", {obj1 = player})
end

function PartyManager.LeaveParty(userId, targetUserId)
    AsyncProcess.LeaveParty(userId, targetUserId)
end

function PartyManager.OnLeaveParty(userId, targetUserId)
    local player = Game.GetPlayerByUserId(userId)
    if not player then
        return
    end
    local content = {
        obj1 = player,
    }
    Trigger.CheckTriggers(player:cfg(), "LEAVE_PARTY_SUCCESS", content)
end

function PartyManager.LikeParty(userId, targetUserId)
    AsyncProcess.LikeParty(userId, targetUserId)
end

function PartyManager.OnLikeParty(userId, targetUserId, data)
    local target = Game.GetPlayerByUserId(targetUserId)
    if not target then
        return
    end
    Trigger.CheckTriggers(target:cfg(), "PARTY_BE_LIKED", {obj1 = target, partyInfo = data})
    WorldServer.BroadcastPacket({
        pid = "RefreshPartyInfo",
        partyData = data,
    })
end

function PartyManager.RequestPartyInfo(userId)
	AsyncProcess.GetPartyInfo(userId)
end

function PartyManager.OnGetPartyInfo(userId, data)
	local player = Game.GetPlayerByUserId(userId)
	if not player then
		return
	end
    player:sendPacket({
        pid = "RefreshPartyInfo",
        partyData = data,
	})
end

function PartyManager.RequestPartyList(userId)
	if os.time() - self.lastUpdatePartyListTime < 2 then
		self.OnGetPartyList(userId, self.lastPartyList)
		return
	end
    local player = Game.GetPlayerByUserId(userId)
    if player then
        local userCache = UserInfoCache.GetCache(userId)
        local language = userCache and userCache.language or 'en'
        AsyncProcess.GetPartyList(userId, language, PARTY_LIST_SHOW_ITEM_COUNT)
    end
end

function PartyManager.OnGetPartyList(userId, data)
	self.lastPartyList = data
	local player = Game.GetPlayerByUserId(userId)
	if not player then
		return
	end
	player:sendPacket({
		pid = "RefreshPartyList",
		data = data,
	})
end

function PartyManager.GetCreatePartyViewInfo(userId, partyName)
	local player = assert(Game.GetPlayerByUserId(userId))
	local content = {
        obj1 = player,
        partyImage = "",
        likeNum = 0,
        maxPlayerNum = 50,
        reachPlayerNum = 50,
        lowerRate = 50, --rate = lowerRate/100
    }

    --local tryContent = { obj1 = player, canCreate = true, }
    --Trigger.CheckTriggers(player:cfg(), "TRY_CREATE_PARTY", tryContent)
    Trigger.CheckTriggers(player:cfg(), "UPDATE_CREATE_PARTY_VIEW_INFO", content)
    local maxPlayerNum, partyImage = content.maxPlayerNum, content.partyImage
    local remainCount = World.cfg.party.freePartyCount - player.vars.useFreePartyCount

    player:setData("partyInfo", {
        maxPlayerNum = maxPlayerNum,
        partyImage = partyImage,
        likeNum = content.likeNum,
        reachPlayerNum = content.reachPlayerNum,
        lowerRate = content.lowerRate,
        partyName = partyName or player.name,
        remainCount = remainCount
    })
	return {
		partyImage = partyImage,
		maxPlayerNum = maxPlayerNum,
		from = player.name,
		partyName = "gui.party.default.name",
        canCreate = true,
        remainCount = remainCount
	}
end

function PartyManager.TryJoinParty(userId, targetUserId, partyId)
    local player = assert(Game.GetPlayerByUserId(userId))
    local content = {
        obj1 = player,
        canJoin = true,
        targetUserId = targetUserId,
        tip = "tip.user.join.party.failed",
        partyId = partyId,
    }
    Trigger.CheckTriggers(player:cfg(), "TRY_JOIN_PARTY", content)
    if not content.canJoin then
        player:sendTip(2, content.tip, TIP_TIME)
        return
    end
    AsyncProcess.JoinParty(userId, targetUserId)
end

function PartyManager.JoinPartyResult(userId, targetUserId, failedCode)
    local player = Game.GetPlayerByUserId(userId)
    if not player then
        if not failedCode then
            AsyncProcess.LeaveParty(userId, targetUserId)
        end
        return
    end
    local content = {obj1 = player, targetUserId = targetUserId}
    if failedCode then
        self.SendPartyTip(userId, failedCode)
        Trigger.CheckTriggers(player:cfg(), "JOIN_PARTY_FAILED", content)
    else
        Trigger.CheckTriggers(player:cfg(), "JOIN_PARTY_SUCCESS", content)
    end
end