local worldStaticTb = {
    GetMapByID = {
        get = function()
            return function(_, id)
                return World:getMapById(id)
            end
        end
    },
    IsClient = { 
        get = function()
            return World.isClient
        end
    },
}

if not World.isClient then -- TODO: 放到server端增加
    worldStaticTb.DefaultMap = {
        get = function()
            return World.CurWorld:getOrCreateStaticMap(World.cfg.defaultMap)
        end
    }
    worldStaticTb.CreateDynamicMap = {
        get = function()
            return function(_, mapName, destroyWhenEmpty)
                return World.CurWorld:createDynamicMap(mapName, destroyWhenEmpty)
            end
        end
    }
    worldStaticTb.GetStaticMap = {
        get = function()
            return function(_, mapName)
                return World.CurWorld:getOrCreateStaticMap(mapName)
            end
        end
    }
end

APIProxy.OverrideAPI(World, nil, worldStaticTb)
