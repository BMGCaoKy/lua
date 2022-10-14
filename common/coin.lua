function Coin:InitCoin()
    self.coinMapping = {}
    --self.coinCfg = {}
    self.coinCfg = Lib.readGameJson("coin.json") or {}
    for i, coin in ipairs(self.coinCfg) do
        assert(coin.coinName ~= "golds" and coin.coinName ~= "gDiamonds", string.format("This type of currency cannot be defined: %s", coin.coinName))
        coin.coinId = i + 2 -- see Coin:coinNameByCoinId(coinId)
        self.coinMapping[coin.coinName] = coin
    end
end

function Coin:GetCoinMapping()
    return Coin.coinMapping
end

function Coin:GetCoinCfg()
    return Coin.coinCfg
end

function Coin:GetCoinItemByCoinName(coinName)
    local temp = self.coinMapping[coinName]
    if not temp then
        return
    end
    return temp.item and temp.item.name
end

--can get id of item coin
function Coin:getCoinIdByName(coinName)
    local ret = self:getCoinId(coinName)
    if not ret then
        local cfg = self.coinMapping[coinName]
        ret = cfg and cfg.coinId
    end
    return ret
end

function Coin:getCoinId(coinName)
    if coinName == "gDiamonds" then
        return 0
    elseif coinName == "golds" then
        return 2
    else
        local coinCfg = Coin:GetCoinCfg()
        if coinCfg and type(coinCfg) == "table" then
            for i, v in pairs(coinCfg) do
                if v.coinName == coinName then
                    return v.coinId
                end
            end
            return false
        end
    end
    return false
end

function Coin:coinNameByCoinId(coinId)
    if coinId == 0 then
        return "gDiamonds"
    elseif coinId == 2 then
        return "golds"
    else
        local currency = Coin:GetCoinCfg()[coinId - 2]
        if currency then
            return currency.coinName
        end
    end
    return ""
end

function Coin:getCoin(coinName)
    return self.coinMapping[coinName]
end

local function init()
    Coin:InitCoin()
end

function Coin.Reload()
    init()
end

init()