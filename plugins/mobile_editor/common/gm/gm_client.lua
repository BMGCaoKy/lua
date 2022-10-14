local GMItem = GM:createGMItem()



local show_collision = false
GMItem["ME/显示碰撞体"] = function()
    show_collision = not show_collision
    local debugDraw = DebugDraw.instance
    if show_collision and not debugDraw:isEnabled() then
        debugDraw:setEnabled(show_collision)
    end
    debugDraw:setDrawColliderEnabled(show_collision)
    debugDraw:setDrawAuraEnabled(show_collision)
    debugDraw:setDrawRegionEnabled(show_collision)
end


GMItem["ME/测试cegui"] = function(self)
    local guiMgr = L("guiMgr", GUIManager:Instance())
    local root = guiMgr:getRootWindow()

    local instanceName = "mobile_editor_tool_bar"
    if root:isChildName(instanceName) then
        Lib.logDebug("already exist  ", instanceName)

    end
end

GMItem["ME/scene存档1"] = function(self)

    Lib.emitEvent(Event.EVENT_SAVE_MAP_CHANGE)
end


GMItem["ME/显示实时阴影"] = function()
    Blockman.Instance().gameSettings:setEnableRealtimeShadow(0.0013)
end

GMItem["ME/关闭实时阴影"] = function()
    Blockman.Instance().gameSettings:setEnableRealtimeShadow(-0.0013)
end

GMItem["ME/阴影bias +"] = function()
    local val = Blockman.Instance().gameSettings:getEnableRealtimeShadow()
    Lib.logDebug("+ getEnableRealtimeShadow val = ", val)
    val = val + 0.00001
    Blockman.Instance().gameSettings:setEnableRealtimeShadow(val)
end
GMItem["ME/阴影bias -"] = function()
    local val = Blockman.Instance().gameSettings:getEnableRealtimeShadow()
    val = val - 0.00001
    Lib.logDebug("- getEnableRealtimeShadow val = ", val)
    Blockman.Instance().gameSettings:setEnableRealtimeShadow(val)
end

GMItem["ME/测试1"] = function(self)
    local manager = World.CurWorld:getSceneManager()
    local path = "map/map001/setting.json"
    local obj = Lib.readGameJson(path)
    local scene = manager:getCurScene()
    local root = scene:getRoot()
    local count = root:getChildrenCount()
    Lib.logDebug("scene children count = ", count)
    local sceneTable = {}
    for i = 1, count do
        local child = root:getChildAt(i - 1)
        if child  and child.name ~= "floor" then
            Lib.logDebug("child = ", child)
            local data = {}
            local className = nil
            if child:isA("Part") then
                className = "Part"
            elseif child:isA("MeshPart") then
                className = "MeshPart"
            elseif child:isA("Model") then
                className = "Model"
            end

            if className then
                data.class = className
                local properties = {}
                child:getAllPropertiesAsTable(properties)
                data.properties = properties
                data.properties.id = child:getInstanceID() .. ""
                table.insert(sceneTable, data)
            end
        end
    end

    Lib.logDebug("sceneTable = ", sceneTable)
    --obj.scene = sceneTable
    --Lib.saveGameJson(path, obj)
end



GMItem["ME/测试effect"] = function(self)
    local self = Me
    local manager = World.CurWorld:getSceneManager()
    local scene = manager:getOrCreateScene(self.map.obj)
    local pos = self:getFrontPos(1, true, true) + Lib.v3(0, 0, 5)

    local effect = EffectNode.Load("asset/effect/g2052_rain_big.effect")
    effect:start()
    effect:setWorldPosition(pos)
end

GMItem["ME/测试model"] = function(self)
    local manager = World.CurWorld:getSceneManager()
    local scene = manager:getOrCreateScene(World.CurWorld.CurMap.obj)
    manager:setCurScene(scene)
    local pos = Lib.v3(0, 32, 0)
    local part = Instance.Create("Model")
    part:setPosition(pos)
    part:setParent(scene:getRoot())

    local part1 = Instance.Create("Part")
    part1:setParent(part)
    part1:setPosition(pos)
    part1:setMaterialPath("part_zhuankuai.tga")
    part1:setShape(4)

    local part2 = Instance.Create("Part")
    part2:setParent(part)
    part2:setPosition(pos + Lib.v3(1, 1, 0))
    part2:setMaterialPath("part_zhuankuai.tga")
    part2:setShape(1)
end

GMItem["ME/测试part"] = function(self)
    local manager = World.CurWorld:getSceneManager()
    local scene = manager:getOrCreateScene(World.CurWorld.CurMap.obj)
    local pos = Lib.v3(0, 32, 0)
    local part = Instance.Create("Part")
    part:setPosition(pos)
    part:setShape(2)
    part:setMaterialPath("part_zhuankuai.tga")
    part:setParent(scene:getRoot())

end


GMItem["ME/打模板"] = function(self)
    local gameRootPath = CGame.Instance():getGameRootDir()
    Lib.logDebug("gameRootPath = ", gameRootPath) -- e:game_config
    local gameName = World.GameName
    Lib.logDebug("gameName = ", gameName)
    local gameType = "g2054"
    local inputPath = gameRootPath
    local outputPath = gameRootPath

    CGame.instance:onProcessGameFolderMobileEditor(inputPath, gameType, 0, outputPath)

end




return GMItem