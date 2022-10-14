local Status = {
    UNRECEIVED = 0,
    RECEIVED = 1,
    CURRENT = 2,
    MISS = 3,
}

local today = tonumber(Lib.getYearDayStr(os.time()))

local function giftGroupIndex(data, cfg)--奖品随机
	if cfg.randomItem then
		data.gift_group_index = math.random(1, #cfg.sign_in_items)
	else
		data.gift_group_index = nil
	end
end
--刷新 逻辑
local function checkRepeat(data, cfg)
    local today = tonumber(Lib.getYearDayStr(os.time()))
    if data.finishKey == today or data.iscompleted == true then
        return
    end
    local toWeek = tonumber(Lib.getYearWeekStr(os.time()))
    local toMonth = tonumber(Lib.getYearMonthStr(os.time()))
    if tostring(cfg.repeatType) == "weekly" then
        if toWeek ~= data.repeatKey then
            data.start_date = today
            data.finishKey = 0
            data.repeatKey = toWeek
            data.finish_data = {}
			giftGroupIndex(data, cfg)
        end
    elseif tostring(cfg.repeatType) == "monthly" then
        if toMonth ~= data.repeatKey then
            data.start_date = today
            data.finishKey = 0
            data.repeatKey = toMonth
            data.finish_data = {}
			giftGroupIndex(data, cfg)
        end
    elseif tostring(cfg.repeatType) == "lastItemFinish" then
        if data.finish_data[#data.finish_data] == #cfg.sign_in_items then
            data.start_date = today
            data.finishKey = 0
            data.finish_data = {}
			giftGroupIndex(data, cfg)
        end
    elseif tostring(cfg.repeatType) == "repeatDay" then
        if today - data.start_date >= tonumber(cfg.repeatDay) then
            data.start_date = today
            data.finishKey = 0
            data.finish_data = {}
			giftGroupIndex(data, cfg)
        end
    end
end

local function getSignInData(player)
    local signInData = player:data("signInData")
    --初始话空值
    for _, cfg in pairs(Player.SignIns) do
        if not signInData[cfg._name] then
            local repeatKey = 0
            local start_date = -1
            if cfg.startType == "personal" then
                start_date = tonumber(Lib.getYearDayStr(os.time()))
            elseif cfg.unifiedDate then
                start_date = tonumber(cfg.unifiedDate)
            end
            if cfg.repeatType == "weekly" then
                repeatKey = tonumber(Lib.getYearWeekStr(os.time()))
            end
            if cfg.repeatType == "monthly" then
                repeatKey = tonumber(Lib.getYearMonthStr(os.time()))
            end
            local data = {
                start_date = start_date,
                repeatKey = repeatKey,
                finishKey = 0,
                finish_data = {}
            }
			giftGroupIndex(data, cfg)
            signInData[cfg._name] = data
        end
    end
    return signInData
end

--change to UI data
local function getUiData(name,data)
	local today = tonumber(Lib.getYearDayStr(os.time()))
    for _, cfg in pairs(Player.SignIns) do
        if tostring(cfg._name) == tostring(name) and data.start_date ~= -1 and data.start_date <= today then
            checkRepeat(data, cfg)
            local group = {}
            if cfg.canMiss and tonumber(cfg.canMiss) == 1 then
                for _ = 1, math.min(today - tonumber(data.start_date), #cfg.sign_in_items - 1) do
                    table.insert(group, Status.MISS)
                end
                table.insert(group, Status.CURRENT)
                for _, itemIndex in pairs(data.finish_data) do
                    group[itemIndex] = Status.RECEIVED
                end
            else
                local lastIndex = data.finish_data[1] or 0
                for itemIndex = 1, lastIndex do
                    group[itemIndex] = Status.RECEIVED
                end
                if data.finishKey ~= today  then
                    group[lastIndex + 1] = Status.CURRENT
                end
            end
            return group
        end
    end
end

local function getSignInCfg(name)
	 for _, cfg in pairs(Player.SignIns) do
        if cfg._name == name then
            return cfg
        end
    end
end

--开始一个新签到
local function startSignIn(player, name)
	local signInData = player:data("signInData")
	local data = signInData[name]
	local nextDay = Lib.getNextDayTime()
	data.start_date = tonumber(Lib.getYearDayStr(nextDay))
	local cfg = getSignInCfg(name)
	if cfg.repeatType == "weekly" then
        data.repeatKey = tonumber(Lib.getYearWeekStr(nextDay))
    elseif cfg.repeatType == "monthly" then
        data.repeatKey = tonumber(Lib.getYearMonthStr(nextDay))
    end
end
--补签

--领取奖励
function Player:getSignInReward(name,index)
    today = tonumber(Lib.getYearDayStr(os.time()))
    local SignInData = getSignInData(self)
	local data = SignInData[name]
    local UIData = getUiData(name ,data or {})
	local groupCfg = getSignInCfg(name)
    if not groupCfg then
        return false, "SignIn.notFind"
    end
    local item = groupCfg.sign_in_items[index]
	if groupCfg.randomItem then
		local groupIndex = data.gift_group_index
		local groupItem = groupCfg.sign_in_items[groupIndex]
		item = groupItem[index]
	else
		item = groupCfg.sign_in_items[index]
	end	
    if not item then
        return false, "SignIn.notFind"
    end
    if UIData[index] ~= Status.CURRENT then
        return false, "SignIn.notCurrent"
    end
	if data.start_date == -1 or data.start_date > today then
		return false, "SignIn.notStart"
	end
	if data.iscompleted == true then
		return false, "SignIn.iscompleted"
	end
	local args = {
		tipType = groupCfg.rewardType or 4,
		check = true,
		reward = item.reward,
		cfg = groupCfg
	}
    if not self:reward(args) then
        self:sendTip(1, "SignIn.inventoryFull", 40)
        return false, "SignIn.inventoryFull"
    end
    -- record
    if groupCfg.canMiss and tonumber(groupCfg.canMiss) == 1 then
        table.insert(data.finish_data , index)
    else
        data.finish_data[1] = index
    end
	if groupCfg.repeatType == "never" and index == #groupCfg.sign_in_items then
		data.iscompleted = true
		if groupCfg.nextSign then
			startSignIn(self, groupCfg.nextSign)
		end
	end
    data.finishKey = today
    -- todo reward...
	args.check = nil
    self:reward(args)
	return true , "SignIn.success"
end

function Player:getSignInList(name)
    today = tonumber(Lib.getYearDayStr(os.time()))
    local SignInData = getSignInData(self)
	local data = SignInData[name]
    return getUiData(name,data or {}) or {}, data
end

local function checkSignInData(data)
	local today = tonumber(Lib.getYearDayStr(os.time()))
	if data.start_date  == -1 or data.start_date  > today then
		return false
	end
	if data.iscompleted and data.finishKey < today then
		return false
	end
	return true
end

function Player:checkSignIn()
	for _, cfg in ipairs(Player.SignIns) do
		local uiData, signdata = self:getSignInList(cfg._name)
		if not (signdata and checkSignInData(signdata)) then
			goto continue
		end
		local items = cfg.sign_in_items
		if cfg.randomItem then
			local itemIndex = signdata.start_date 
			items = cfg.sign_in_items[itemIndex]
		end
		for index, item in ipairs(items) do
			if uiData[index] == Status.CURRENT then
				self:sendPacket({
					pid = "OpenSignIn",
					name = cfg._name
				})
				return true
			end
		end
		:: continue ::
	end
end