local setting = require "common.setting"
local reportCfg = setting:fetch("ui_config", "myplugin/reportCfg") or {}

function Player:getRangeBoundary(array, num)
    local size = #array

    table.sort(array, function(a, b)
        return a < b
    end)

    for index, value in pairs(array) do
        local _value = value
        if type(num) == "table" and num.IsBigInteger then
            _value = BigInteger.Create(value)
        end
        if index == size then
            return value
        end

        if num <= _value then
            return value
        end
    end

    return 0
end

function Player:reportByType(t, res)
    if not reportCfg[t] or not reportCfg[t].key then
        Lib.logError("no report cfg", t)
        return
    end
    if not res then
        res = 0
    end
    local cfg = reportCfg[t]

    local toReport = function(val, prefix)
        if cfg.range then
            val =  self:getRangeBoundary(cfg.range, val)
        end
        if cfg.prefixByFunc and type(self[cfg.prefixByFunc]) == "function" then
            val = tostring(self[cfg.prefixByFunc](self)).."_"..val
        end
        if prefix and type(prefix) == "string" then
            val = prefix.."_"..val
        end
        print("data report : ", t, val)
        GameAnalytics.Design(self.platformUserId, 0, {cfg.key, val})
    end

    if type(res) == "table" and not res.IsBigInteger then
        for prefix, val in pairs(res) do
            toReport(val, prefix)
        end
    elseif type(res) == "number" or res.IsBigInteger then
        toReport(res)
    elseif type(res) == "string" then
        toReport(res)
    end
end