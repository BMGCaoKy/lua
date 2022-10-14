Store.itemStatus = {
    NOT_FOR_SALE = -2,
    PRIVILEGE = -1,
    NOT_BUY = 0,
    NOT_USE = 1,
    IN_USE = 2,
}

function Store:initStore()
    self.stores = {}
    self.buyResults = {}
    local config = Lib.readGameCsv("store.csv") or {}
    for _ , item in ipairs(config) do
        local storeId = tonumber(item.storeId)
        local isCoexist = tonumber(item.isCoexist) == 1
        local store = self.stores[storeId]
        if not store then
            store = {
                items = {},
                id = storeId,
                name = item.name,
                icon = item.icon,
                isCoexist = isCoexist
            }
        end

        item.isCoexist = isCoexist
        item.meta = tonumber(item.meta)
        item.index = tonumber(item.index)
        item.price = tonumber(item.price)
        item.status = tonumber(item.status)
        item.coinId = tonumber(item.coinId)
        item.storeId = tonumber(item.storeId)
        item.shopIndex = tonumber(item.shopIndex or 0)
        item.itemName = item.itemName
        item.itemType = item.itemType
        item.dir = item.dir
        item.remainTime = 0
        table.insert(store.items, item)
        self.stores[storeId] = store
    end
end

function Store.Reload()
    Store:initStore()
end

function Store:getStores()
    return self.stores
end

function Store:getStoreById(id)
    return assert(self.stores[id], "getStoreById storeId:" .. id)
end

function Store:getStoreItem(id, index)
    local store = self:getStoreById(id)
    for _, v in pairs(store.items) do
        if v.index == index then
            return v
        end
    end

    assert(false, "getStoreItem storeId:" .. id .. " itemIndex:" .. index)
    return nil
end

local function init()
    Store:initStore()
end

init()