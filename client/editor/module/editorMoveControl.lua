local editorMoveControl = L("editorMoveControl", Lib.derive(EditorModule.baseDerive))
local bm = Blockman.Instance()
local moveParams = L("moveParams", {})
local THIRD_MOVE = 3
local FRIST_MOVE = 1
local function axisValue(forward, back)
	local value = 0.0;
	if bm:isKeyPressing(forward) then
		value = value + 1
	end
	if bm:isKeyPressing(back) then
		value = value - 1
	end
	return value
end

local function isInBlock(entity)
    local function hasCollision(map, pos)
        local blockCfg = map:getBlock(pos)
        local collisionBoxes = blockCfg.collisionBoxes
        if not collisionBoxes then
            return true
        end
        
        if #collisionBoxes == 0 then
            return true
        end 
        local min = collisionBoxes[1].min
        local max = collisionBoxes[1].max

        local v = Lib.tov3(max) - Lib.tov3(min)
        if v:len() > 0 then
            return true
        end
        return false
    end

    local BoundingBox = entity:getBoundingBox()
    local minx, maxx = BoundingBox[2].x, BoundingBox[3].x
    local miny, maxy = BoundingBox[2].y, BoundingBox[3].y
    local minz, maxz = BoundingBox[2].z, BoundingBox[3].z
    minx = math.floor(minx)
    minz = math.floor(minz)
    miny = math.floor(miny)

    maxx = math.ceil(maxx)
    maxy = math.ceil(maxy)
    maxz = math.ceil(maxz)

    local map = entity.map
    for x = minx, maxx  do
        for y = miny, maxy do
            for z = minz, maxz do
                local id = 0
                id = y >= 0 and map:getBlockConfigId({x = x, y = y, z = z}) or id
                if id ~= 0 and hasCollision(map, {x = x, y = y, z = z}) then
                    return true
                end
            end
        end
    end
    return false
end

function editorMoveControl:enableFly(enableFly)
    local player = Player.CurPlayer
    if self.flyBuff then
        player:removeClientBuff(self.flyBuff)
        self.flyBuff = nil
    end
    -- rise one block
    if enableFly then
        bm:control().enable = false
        self.flyBuff = player:addClientBuff("/fly")
		if not moveParams.enableFly then
			local nextPos = player:getPosition() + Lib.v3(0, 1, 0)
			player:setMove(0, nextPos, player:getRotationYaw(), player:getRotationPitch(), 1, 0)
			player.onGround = false
		end
    else
        bm:control().enable = true
    end
    moveParams.enableFly = enableFly
end

function editorMoveControl:isEnableFly()
    return moveParams.enableFly and true or false
end

function editorMoveControl:isThirdView()
    self.curMoveWay = self.curMoveWay or THIRD_MOVE
    return self.curMoveWay == THIRD_MOVE
end

local function canSwitchMoveWay(self, enableFly)
    local curEnableFly = self:isEnableFly()
    if not curEnableFly or enableFly then
        return true
    end
    local player = Player.CurPlayer
    if isInBlock(player) then
        -- 飘字
        self:showTips("can_not_stop_fly")
        return false
    end
    return true
end

function editorMoveControl:switchThirdMoveWay(enableFly)
    if not canSwitchMoveWay(self, enableFly) then
        return
    end
    EditorModule:getViewControl():fixedBodyView(true)
    self.curMoveWay = THIRD_MOVE
    World.CurWorld.isHideActor = false
    bm.isEditorFirstView = false
    self:enableFly(enableFly)
    bm:setPersonView(1)
end

function editorMoveControl:switchFristMoveWay(enableFly)
    if not canSwitchMoveWay(self, enableFly) then
        return
    end
    EditorModule:getViewControl():fixedBodyView(true)
    self.curMoveWay = FRIST_MOVE
    World.CurWorld.isHideActor = true
    bm.isEditorFirstView = true
    self:enableFly(enableFly)
    bm:setPersonView(0)
end

function editorMoveControl:enterOldEditorMoveWay()
    self.lastMoveWay = self.curMoveWay
    self:switchFristMoveWay(true)
    bm.isEditorFirstView = false
    self.enterOldEditorMoveWayFlag = true
end

function editorMoveControl:leaveOldEditorMoveWay()
    if not self.enterOldEditorMoveWayFlag then
        self.lastMoveWay = self.curMoveWay
    end 
    if self.lastMoveWay == THIRD_MOVE then
        self:switchThirdMoveWay(true)
    else
        self:switchFristMoveWay(true)
    end
    self.enterOldEditorMoveWayFlag = false
end

function editorMoveControl:jump()
    local player = Player.CurPlayer
    local onGround = player.onGround
    if onGround or player:isSwimming() then
        bm:control().enable = true
        bm:control():jump()
    end
end

function editorMoveControl:changeWalkStyle(movingStyle)
    local function changeStyle(style)
        local player = Player.CurPlayer
        local worldCfgViewBobbing = World.cfg.viewBobbing
        if player and player.movingStyle ~= style then
            player:setValue("movingStyle", style)
            bm.gameSettings.viewBobbing = worldCfgViewBobbing or false
        end
    end
    local style = 0
    local styleMap = {
        normal = 0,
        sneak = 1,
        sprint = 2
    }
    style = styleMap[movingStyle] or 0
    self.info("change style is", style, movingStyle)
    changeStyle(style)
end

function editorMoveControl:updateMove()
    local poleForwar = bm.gameSettings.poleForward
	local poleStrafe = bm.gameSettings.poleStrafe
	local forward = axisValue("key.forward", "key.back") + poleForwar
    local left = axisValue("key.left", "key.right") + axisValue("key.top.left", "key.top.right") + poleStrafe
    local up = axisValue("key.rise", "key.descend")
    local control = bm:control()
    if self:isEnableFly() then
        return false
    else
        control:setVerticalSpeed(up)
    end
    if math.abs(forward) > 0 or math.abs(left)> 0 then
        bm:control().enable = true
    else
        Player.CurPlayer.isMoving = false
        if Player.CurPlayer.onGround then
            World.Timer(2, function()   --两帧后人物动作执行完成再取消奔跑状态
                if Player.CurPlayer.onGround then
                    bm:control().enable = false
                end
            end)
        end
    end

    control:setMove(forward, left)
    return true
end

RETURN(editorMoveControl)
