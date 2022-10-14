local shopSetting = L("stageSetting", {})
local fullName = "commodity.csv"
local path = Root.Instance():getGamePath() .. fullName

function shopSetting:fetch()
    if not self._cacheData then
        self._cacheData = Lib.copy(self:fetchImp())
    end
    return self._cacheData
end

function shopSetting:fetchImp()
    if not self._data then
        self._data, self.header = Lib.read_csv_file(path)
    end
    return self._data
end

function shopSetting:saveCache()
    if not self._isSaveCacheData then
        return
    end
    self.isSave = true
    self._data = Lib.copy(self._cacheData)
end

function shopSetting:save()
    self:saveCache()
    if not self.isSave then
        return
    end
    local dataLen = self._data and #self._data or 0
    for i = 1, dataLen do
        self._data[i].index = i
    end

    local data = {items = self._data or {}, header = self.header}

    if self._data ~= nil then
        Lib.write_csv(path, data)
    end
    self.isSave = false
end

function shopSetting:getData()
    local data = self:fetch()
    return data
end

function shopSetting:getTemplateItem()
    local ret = {index = 1, type = 1, tipDesc = "wool.intro", itemName = "/block", blockName = "myplugin/wool_4", num = 1, coinName = "iron_ingot", price = 1, limitType = 1, limit = -1}
    return ret
end

function shopSetting:getDataByType(type)
    local data = self:fetch()
    local ret = {}
    for i, val in pairs(data) do
        if not type or tonumber(val.type) == type then
            ret = val
            break
        end
    end
    return ret
end

function shopSetting:getValByType(idx)
    local data = self:fetch()
    local ret = {}
    for i, val in pairs(data) do
        if tonumber(val.type) == idx then
            ret[#ret + 1] = val
        end
    end
    return ret
end

function shopSetting:delValByIdx(idx)
--    self._data = self._data or {}
--    self._data[idx] = nil
    local data = self:fetch() or {}
    data[idx] = nil
end

function shopSetting:saveKey(idx, val, isSave)
    local data = self:fetch() or {}
    data[idx] = val
    self._isSaveCacheData = true
    if isSave then
        self._data = self._data or {}
        self._data[idx] = val
    end
end

function shopSetting:saveValByType(shopType, tb, isSave)
    local data = self:fetch() or {}
    self._data = self._data or {}
    for i = #data, 1, -1 do
        if tonumber(data[i].type) == shopType then
            table.remove(data, i)
        end
    end
    for key, val in pairs(tb or {}) do
        table.insert(data, val)
    end
    self._isSaveCacheData = true
--    if isSave then
--        self:save()
--    end
end

function shopSetting:clearData()
    self._cacheData = nil
end

function shopSetting:updateValByItemName(params)
    -- print("----- params ", Lib.v2s(params))
    self._cacheData = self:fetch()
    if not self._cacheData then
        return
    end
    for _, data in pairs(self._cacheData) do
        if data.itemName == params.fullName then
            data.tipDesc = params.propDesc
            self._isSaveCacheData = true
            break
        end
    end
end

do
    Lib.subscribeEvent(Event.EVENT_SETTING_BASE_PROP_UPDATE, function(params)
        shopSetting:updateValByItemName(params)
    end)

end

RETURN(shopSetting)
