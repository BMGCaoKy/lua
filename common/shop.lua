local tonumber = tonumber

function Shop:initShop()
    self.shops = {}
    self.groups = {}
    self.buyResults = {}
    self.config = Lib.readGameCsv("shop.csv") or {}
    for index, shop in ipairs(self.config) do
        local type = tonumber(shop.type)
        local group = {
            goods = {},
            icon = shop.icon,
            type = type,
            name = shop.name
        }
        if self.groups[type] then
            group = self.groups[type]
        end
        shop.index = index
        shop.num = tonumber(shop.num)
        shop.coinId = tonumber(shop.coinId)
        local coinId = tonumber(shop.coinId)
        if shop.coinName and not tonumber(shop.coinId) then--new
            shop.coinId = Coin:getCoinIdByName(shop.coinName)
        end
        if not shop.itemType then--new
            if shop.blockName and shop.blockName ~= "" then
                shop.itemType = "Block"
                shop.itemName = shop.blockName
            else
                shop.itemType = "Item"
            end
        end
        shop.price = tonumber(shop.price)
        shop.limit = tonumber(shop.limit)
        shop.limitType = tonumber(shop.limitType)
        shop.hideNum = tonumber(shop.hideNum) or 0
        shop.limitMax = tonumber(shop.limit)
        shop.stackLimit = tonumber(shop.stackLimit) or 1
        shop.showPrice = shop.showPrice == "TRUE"
        shop.priceAbbr = shop.priceAbbr == "TRUE"
		shop.sort = tonumber(shop.sort)
        shop.checkCond = {
            funcName = shop.funcName or "",
            p1 = shop.p1,
            p2 = shop.p2
        }
        group.goods[#group.goods + 1] = shop
        self.groups[type] = group
        self.shops[index] = shop
    end
end

function Shop.Reload()
    Shop:initShop()
end

local function init()
    Shop:initShop()
end

init()