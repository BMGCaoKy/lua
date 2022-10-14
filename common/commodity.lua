function Commodity:initCommodities()
    self.commodities = {}
    self.grouds = {}
    self.cfg = Lib.readGameCsv("commodity.csv") or {}
    for i, c_item in pairs(self.cfg) do
        local item = {}
        local grouds = {}
        local type = tonumber(c_item.type)
        grouds.type = type
        if c_item.icon == "#" then
            grouds.icon = ""
        else
            grouds.icon = c_item.icon
        end
        if c_item.name == "#" then
            grouds.name = ""
        else
            grouds.name = c_item.name
        end
        grouds.commoditys = {}
        if self.grouds[type] ~= nil then
            grouds = self.grouds[type]
        end
        item.index = i
        item.desc = c_item.desc
        item.tipDesc = c_item.tipDesc or ""
        if c_item.image == "#" then
            item.image = ""
        else
            item.image = c_item.image
        end
        if c_item.itemName == "#" then
            item.itemName = ""
        else
            item.itemName = c_item.itemName
        end
        item.meta = c_item.meta
        item.blockName = c_item.blockName
        item.num = tonumber(c_item.num)
        item.coinName = tostring(c_item.coinName)
        item.price = tonumber(c_item.price)
        item.limitType = tonumber(c_item.limitType)
        item.limit = tonumber(c_item.limit)
        item.checkCond = {
            funcName = c_item.funcName or "",
            p1 = c_item.p1 or "",
            p2 = c_item.p2 or ""
        }

        grouds.commoditys[#grouds.commoditys + 1] = item
        self.grouds[type] = grouds
        self.commodities[i] = item
    end
end

function Commodity.Reload()
    Commodity:initCommodities()
end

function Commodity:GetCommodity(index)
    return assert(self.commodities[index], index)
end

local function init()
    Commodity:initCommodities()
end

init()