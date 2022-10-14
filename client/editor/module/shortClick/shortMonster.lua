local shortMonster = L("shortMonster", Lib.derive(EditorModule.baseDerive))
local bm = Blockman.Instance()

local function createEntity(self, item)
    local fullName = item:full_name()
    local pos = Player.CurPlayer:getPosition()
    local yaw = Player.CurPlayer:getRotationYaw()
    local index = math.floor(((yaw + 360) % 360 + 45) / 90)
    yaw = 90 * index + 180
    local entity = EntityClient.CreateClientEntity({
        cfgName = fullName,
        pos = pos,
        ry= yaw
    })
    entity:setAlpha(0.6, -1)
    return entity
end

local function controlEntity(entity)
    bm:setMainPlayer(entity)
    Player.CurPlayer = entity
end

function shortMonster:click(item)
    -- EditorModule:getUIControl():closeMainUI()
    -- EditorModule:getViewControl():fixedBodyView()
    -- local entity = createEntity(self, item)
    -- controlEntity(entity)

    -- World.Timer(200, function()
    --     EditorModule:getUIControl():openMainUI()
    --     local pos = Player.CurPlayer:getPosition()
    --     local mainPlayer = bm:getEditorPlayer()
    --     Player.CurPlayer = mainPlayer
    --     controlEntity(mainPlayer)
    --     mainPlayer:setPosition(pos)
    -- end)
end

RETURN(shortMonster)
