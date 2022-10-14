
local mt = {}
local inputCallBack = {}
local tempCallBack = nil

function mt:__newindex(k, v)
    table.insert(GM.GMList, k)
    rawset(self, k, v)
    inputCallBack[k] = tempCallBack
    tempCallBack = nil
end

function GM:createGMItem()
    if GM.GMItem ~= nil then
        return GM.GMItem
    end

    GM.GMItem = {}
    GM.GMList = {}
    if not World.isClient then
        GM.BTSGMItem = GM.BTSGMItem or {}
        GM.BTSGMList = GM.BTSGMList or {}
    end
	function GM.GMItem.NewLine()
		table.insert(GM.GMList, "/")
	end
    setmetatable(GM.GMItem, mt)
    return GM.GMItem
end

function GM:call(key)
    local func = GM.GMItem[key]
    if func then
        func(self, key)
		return true
	end
    if not World.isClient then
        func = GM.BTSGMItem[key]
        if func then
            func(self, key)
            return true
        end
    end
    return false
end

local function input(style, callBack, defaultValue)
    tempCallBack = callBack
    return function(self, key)
		local value = defaultValue
		if type(value)=="function" then
			value = value(self)
		end
        if World.isClient then
            Lib.emitEvent(Event.EVENT_SHOW_GM_INPUTBOX, {style = style, key = key, value = value})
        else
            self:sendPacket({pid = "GMInputBox", pack = {style = style, key = key, value = value}})
        end
    end
end

function GM:inputNumber(callBack, defaultValue)
    return input("number", callBack, defaultValue)
end

function GM:inputStr(callBack, defaultValue)
    return input("string", callBack, defaultValue)
end

function GM:inputBoolean(callBack, defaultValue)
    return input("boolean", callBack, defaultValue)
end

function GM:inputBoxCallBack(pack)
    local func = inputCallBack[pack.key]
    if func then
		local value = pack.value
		local style = pack.style
		if not value or #value == 0 then return end
		if style == "number" then
			value = tonumber(value)
		elseif style == "boolean" then
			value = value == "true" and true or false
		end
		print("GM-input:", pack.key, pack.value)
        func(self, value)
    elseif World.isClient then
        self:sendPacket({pid = "GM", typ = "GMInputBoxCallBack", pack = pack})
    end
end

GM.isOpen = World.gameCfg.gm or false
