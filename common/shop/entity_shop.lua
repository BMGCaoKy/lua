
local ValueDef		= T(Entity, "ValueDef")

-- key		                = {isCpp,	client,	toSelf,	toOther,	init,	saveDB}
ValueDef.authList           = {false,   false,  true,    false,      {},     true}
ValueDef.recordShopTimes    = {false,   false,  true,    false,      {},     true}

function Entity:setAuthInfo(authKey, authTime)
    local tmp = self:getValue("authList")
    if tmp[authKey] == -1 then
        Lib.logError("set auth error, already forever", authKey)
    end
    if authTime == -1 then
        tmp[authKey] = -1
    else
        local start = math.max(tmp[authKey] or 0, os.time())
        tmp[authKey] = start + authTime
    end
    self:setValue("authList", tmp)
end

function Entity:checkAuth(mark, freeList)
    if not mark then
        return false
    end
    for _, freeKey in pairs(freeList or {}) do
        if mark == freeKey then
            return true
        end
    end
    local tmp = self:getValue("authList")
    if not tmp[mark] then
        return false
    end
    if tmp[mark] == -1 or tmp[mark] > os.time() then
        return true
    end
    return false
end

function Entity:checkAuthRemainingTime(mark)
    if not mark then
        return 0
    end
    local tmp = self:getValue("authList")
    if not tmp[mark] then
        return 0
    end
    if tmp[mark] == -1 then
        return -1
    end
    return math.max(0, tmp[mark] - os.time())
end

function Entity:getRecordShop(shopName)
    local currentRecord = self:getValue("recordShopTimes")
    Lib.logDebug("get record shop", shopName, Lib.v2s(currentRecord))
    return currentRecord[shopName] or {num=0, ts=0}
end

function Entity:resetRecordShop(shopName)
    local currentRecord = self:getValue("recordShopTimes")
    currentRecord[shopName] = nil
    Lib.logInfo("reset record shop", shopName, Lib.v2s(currentRecord))
    self:setValue("recordShopTimes", currentRecord)
end

function Entity:recordShop(shopName)
    local currentRecord = self:getValue("recordShopTimes")
    currentRecord[shopName] = {
        num = currentRecord[shopName] and currentRecord[shopName].num and currentRecord[shopName].num + 1 or 1,
        ts = os.time()
    }
    Lib.logInfo("update record shop", Lib.v2s(currentRecord))
    self:setValue("recordShopTimes", currentRecord)
end