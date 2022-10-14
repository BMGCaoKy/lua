--- game_manager.lua
--- 场景的管理器
---
---@type util
local util = require "common.util.util"
---@type setting
local setting = require "common.setting"
---@type ModMeta
local PartCfg = setting:mod("part")
---@type LuaTimer
local LuaTimer = T(Lib, "LuaTimer")

local BM = Blockman.Instance()

---@alias GameManager IGameManager | singleton | EditState | CreateState | MultipleSelectionState | CaptureScreenState | HoldDownState | EnvironmentState
---@class IGameManager : Stateful
local GameManager = T(MobileEditor, "GameManager")
GameManager:addState("Edit", require "common.state.game.edit_state")
GameManager:addState("Create", require "common.state.game.create_state")
GameManager:addState("MultipleSelection", require "common.state.game.multiple_selection_state")
GameManager:addState("CaptureScreen", require "common.state.game.capture_screen_state")
GameManager:addState("HoldDown", require "common.state.game.hold_down_state")
GameManager:addState("Environment", require "common.state.game.environment_state")

---@type engine_scene
local IScene = require "common.engine.engine_scene"
---@type engine_instance
local IInstance = require "common.engine.engine_instance"
---@type BaseNode
local BaseNode = require "common.node.base_node"
---@type CommandManager
local CommandManager = T(MobileEditor,"CommandManager")
---@type ConfigManager
local ConfigManager = T(MobileEditor,"ConfigManager")

function GameManager:initialize()
    self.time = os.time()
    self.root = nil
    self.createModId = nil
    self.isTouchBegin = false
    self.isTouchMove = false
    self.touchBeginId = nil
    self.touchEndId = nil
    self.touchBeginPos = nil

    self.clickCount = 0
    self.clickDelay = 0.5
    self.clickTime = 0

    self.pressTime = 0
    self.pressDelay = 1.0

    ---@type BaseNode[]
    self.selectedNodes = {}
    ---@type BaseNode[]
    self.nodes = {}
    self.floor = nil
    self.birthId = nil

    self.colorId = 1
    self.textureId = 1

    self:subscribeEvents()
    self:initUpdateTimer()
end

function GameManager:finalize()

end

function GameManager:subscribeEvents()
    Lib.subscribeEvent(Event.EVENT_ENTER_PLAY_MODE, function()
        CGame.instance:restartGame(CGame.Instance():getGameRootDir(), World.GameName, 1, false)
    end)

    Lib.subscribeEvent(Event.EVENT_ENTER_EDIT_MODE, function()
        CGame.instance:restartGame(CGame.Instance():getGameRootDir(), World.GameName, 1, true)
    end)

    Lib.subscribeEvent(Event.EVENT_TOUCH_BEGIN, function(id, curX, curY, prevX, prevY)
        if self:getCurrentState() == "Create" then
            self:touchBegin(curX, curY)
        elseif self:getCurrentState() == "Edit" then
            self:touchBegin(curX, curY)
        elseif self:getCurrentState() == "MultipleSelection" then
            self:touchBegin(curX, curY)
        elseif self:getCurrentState() == "CaptureScreen" then
            self:touchBegin(curX, curY)
        elseif self:getCurrentState() == "Environment" then
            self:touchBegin(curX, curY)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_TOUCH_MOVE, function(id, curX, curY, prevX, prevY)
        if self:getCurrentState() == "Create" then
            self:touchMove(curX, curY, prevX, prevY)
        elseif self:getCurrentState() == "Edit" then
            self:touchMove(curX, curY, prevX, prevY)
        elseif self:getCurrentState() == "MultipleSelection" then
            self:touchMove(curX, curY, prevX, prevY)
        elseif self:getCurrentState() == "HoldDown" then
            self:touchMove(curX, curY, prevX, prevY)
        elseif self:getCurrentState() == "CaptureScreen" then
            self:touchMove(curX, curY, prevX, prevY)
        elseif self:getCurrentState() == "Environment" then
            self:touchMove(curX, curY, prevX, prevY)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_TOUCH_END, function(id, curX, curY, prevX, prevY)
        if self:getCurrentState() == "Create" then
            self:touchEnd(curX, curY)
        elseif self:getCurrentState() == "Edit" then
            self:touchEnd(curX, curY)
        elseif self:getCurrentState() == "MultipleSelection" then
            self:touchEnd(curX, curY)
        elseif self:getCurrentState() == "HoldDown" then
            self:touchEnd(curX, curY)
        elseif self:getCurrentState() == "CaptureScreen" then
            self:touchEnd(curX, curY)
        elseif self:getCurrentState() == "Environment" then
            self:touchEnd(curX, curY)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_TOUCH_CANCEL, function(id, curX, curY, prevX, prevY)
        --Lib.logDebug("EVENT_TOUCH_CANCEL id and x and y = ", id, curX, curY)
        if self:getCurrentState() == "Create" then
            self:touchEnd(curX, curY)
        elseif self:getCurrentState() == "Edit" then
            self:touchEnd(curX, curY)
        elseif self:getCurrentState() == "MultipleSelection" then
            self:touchEnd(curX, curY)
        elseif self:getCurrentState() == "HoldDown" then
            self:touchEnd(curX, curY)
        elseif self:getCurrentState() == "CaptureScreen" then
            self:touchEnd(curX, curY)
        elseif self:getCurrentState() == "Environment" then
            self:touchEnd(curX, curY)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_ENTER_CAPTURE_STATE, function()
        self:pushState("CaptureScreen")
    end)

    Lib.subscribeEvent(Event.EVENT_EXIT_CAPTURE_STATE, function()
        self:popState("CaptureScreen")
    end)

    Lib.subscribeEvent(Event.EVENT_ENTER_ENVIRONMENT_STATE, function()
        self:pushState("Environment")
    end)

    Lib.subscribeEvent(Event.EVENT_EXIT_ENVIRONMENT_STATE, function()
        self:popState("Environment")
    end)

    Lib.subscribeEvent(Event.EVENT_TOUCH_DOWN_NODE, function(cfgId)
        --Lib.logDebug("EVENT_TOUCH_DOWN_NODE cfgId = ", cfgId)
        if cfgId then
            self:pushState("Create", cfgId)
        else
            self:popState("Create")
        end
    end)

    Lib.subscribeEvent(Event.EVENT_TOUCH_MOVE_NODE, function(x, y)
        if self:getCurrentState() == "Create" then
            local TargetManager = T(MobileEditor,"TargetManager")
            local targets = TargetManager:instance():getTargets()
            if Lib.getTableSize(targets) > 0 then
                self:touchMove(x, y)
            else
                self:touchBegin(x, y)
            end
        end
    end)

    Lib.subscribeEvent(Event.EVENT_TOUCH_END_NODE, function(x, y)
        if self:getCurrentState() == "Create" then
            self:popState("Create")
            ---@type TargetManager
            local TargetManager = T(MobileEditor,"TargetManager")
            local targets = TargetManager:instance():getTargets()
            if Lib.getTableSize(targets) > 0 then
                local node = self:getNode(targets[1])
                if node then
                    Lib.emitEvent(Event.EVENT_UPDATE_COMMAND, {
                        pos = node:getPosition(),
                    })
                    Lib.emitEvent(Event.EVENT_SELECT_TARGET)
                end
            end
        end
    end)

    Lib.subscribeEvent(Event.EVENT_DELETE_NODE, function(id)
        self:destroyNode(id)
    end)

    Lib.subscribeEvent(Event.EVENT_ENABLE_MULTIPLE, function(multiple)
        if multiple == true then
            self:pushState("MultipleSelection")
        else
            self:popState("MultipleSelection")
        end
    end)

    Lib.subscribeEvent(Event.EVENT_NEW_NODE, function(cfg, pos)
        ---Lib.logDebug("EVENT_NEW_NODE cfg and pos = ", cfg, pos)
        local node = self:createNode(cfg)
        if node then
            if pos then
                node:setPosition(pos)
            end
            Lib.emitEvent(Event.EVENT_ADD_TARGET, node:getId())
        end
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_GAME_PAUSE", Event.EVENT_GAME_PAUSE, function()
        Player.CurPlayer:stopGameBgm()
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_GAME_RESUME", Event.EVENT_GAME_RESUME, function()
        Player.CurPlayer:playGameBgm()
    end)

    Lib.subscribeEvent(Event.EVENT_UPDATE_NODE, function(id, object, reset)
        self:updateNode(id, object, reset)
    end)
end

function GameManager:setColorAndTexture(colorId, textureId)
    self.colorId = colorId
    self.textureId = textureId
end

function GameManager:initUpdateTimer()
    if self.updateTimer then
        LuaTimer:cancel(self.updateTimer)
    end
    self.updateTimer = LuaTimer:schedule(function()
        Lib.emitEvent(Event.EVENT_SAVE_MAP_CHANGE)
    end, 0, 60000)
end

function GameManager:createMod(id, hitPos, normal)
    --Lib.logDebug("createMod hitPos and normal = ", hitPos, normal)
    local config = ConfigManager:instance():getConfig("modConfig", id)
    if config then
        local cfg = PartCfg:get("myplugin/" .. config.cfgName)
        if cfg then
            local snapPos
            if config.type == "geometry" then
                snapPos = util:snap(hitPos, Define.MOD_INTERVAL.GEOMETRY)
            else
                snapPos = util:snap(hitPos, Define.MOD_INTERVAL.PROP)
            end
            if config.cfgName == "birth" then
                ---@type CommandBirthNew
                local CommandBirthNew = require "common.command.command_birth_new"
                CommandManager:instance():register(CommandBirthNew:new(nil, cfg, snapPos, normal, id))
            else
                ---@type CommandNew
                local CommandNew = require "common.command.command_new"
                CommandManager:instance():register(CommandNew:new(nil, cfg, snapPos, normal, id, self.colorId, self.textureId))
            end
            if config.type == "geometry" then
                Plugins.CallTargetPluginFunc("report", "report", "editor_part_use", { part_id = config.id })
            else
                Plugins.CallTargetPluginFunc("report", "report", "editor_model_use", { model_id = config.id })
            end
        end
    end
end

function GameManager:createNode(cfg)
    if cfg then
        local node = BaseNode:new(cfg)
        node:gotoState('Place')
        self.nodes[node:getId()] = node
        return node
    end
    return nil
end

function GameManager:destroyNode(id)
    local node = self.nodes[id]
    if node then
        node:destroy()
        self.nodes[id] = nil
    else
        Lib.logError("destroyNode node is nil = ", id)
    end
end

function GameManager:updateNode(id, object, reset)
    if object then
        local className = IInstance:getClassName(object)
        if className then
            local node = BaseNode:new(nil, false)
            node:setObject(object)
            node:setNodeType(util:getNodeType(className))
            node:gotoState('Place')
            if reset then
                node:resetMaterialColor()
            end
            self.nodes[id] = node
        end
    else
        self.nodes[id] = nil
    end
end

function GameManager:all(targets, func)
    local list = {}
    for i = 1, #targets do
        local id = targets[i]
        local node = self:getNode(id)
        if node then
            if func(node) then
                table.insert(list, node:getObject())
            else
                return nil
            end
        end
    end
    return list
end

---@param targets number[]
---@param func fun(node : BaseNode)
function GameManager:filter(targets, func, includeChildren)
    local function listChildren(object, list)
        local count = object:getChildrenCount()
        for i = 1, count do
            local child = object:getChildAt(i - 1)
            if child then
                table.insert(list, child)
            end
            listChildren(child, list)
        end
    end

    local list = {}
    for i = 1, #targets do
        local id = targets[i]
        local node = self:getNode(id)
        if node then
            if not func or func(node) then
                table.insert(list, node:getObject())
            end
            if includeChildren then
                listChildren(node:getObject(), list)
            end
        else
            Lib.logWarning("can not find node, node id:" .. id)
        end
    end
    return list
end

---@param targets number[]
function GameManager:getNodes(targets)
    if targets and Lib.getTableSize(targets) > 0 then
        local nodes = {}
        for i = 1, #targets do
            local node = self:getNode(targets[i])
            if node then
                table.insert(nodes, node)
            end
        end
        return nodes
    else
        return self.nodes
    end
end

function GameManager:getNode(id)
    return self.nodes[id]
end

function GameManager:load()
    local manager = World.CurWorld:getSceneManager()
    local scene = manager:getCurScene()
    self.root = scene:getRoot()
    local count = self.root:getChildrenCount()
    for i = 1, count do
        local child = self.root:getChildAt(i - 1)
        if child then
            local className = IInstance:getClassName(child)
            if className then
                local node = BaseNode:new(nil, false)
                node:setObject(child)
                node:loadAttributes()

                node:setNodeType(util:getNodeType(className))
                node:gotoState('Place')
                self.nodes[child:getInstanceID()] = node
                if node:get("name") == "floor" then
                    self.floor = node
                elseif node:get("name") == "birth" then
                    self.birthId = node:getId()
                end
            end
        end
    end

    Lib.logDebug("node size = ", Lib.getTableSize(self.nodes))
end

function GameManager:getBirthId()
    return self.birthId
end

function GameManager:setBirthId(birthId)
    self.birthId = birthId
end

---@param targets number[]
function GameManager:getCenter(targets)
    local nodes = {}
    for i = 1, #targets do
        local id = targets[i]
        local node = self:getNode(id)
        if node then
            table.insert(nodes, node)
        end
    end

    return util:getCenter(nodes)
end

function GameManager:getFloorBound()
    local bounds = {
        min = {
            x = -64,
            y = 31,
            z = -64
        },
        max = {
            x = 64,
            y = 64,
            z = 64
        }
    }
    if World.CurMap.cfg and World.CurMap.cfg.floorBound and next(World.CurMap.cfg.floorBound) then
        local bound1 = World.CurMap.cfg.floorBound[1]
        local bound2 = World.CurMap.cfg.floorBound[2]
        bounds = {
            min = {
                x = math.min(bound1.x, bound2.x),
                y = math.min(bound1.y, bound2.y),
                z = math.min(bound1.z, bound2.z),
            },
            max = {
                x = math.max(bound1.x, bound2.x),
                y = math.max(bound1.y, bound2.y),
                z = math.max(bound1.z, bound2.z),
            }
        }
    end
    return bounds
end

function GameManager:panCamera(curX, curY, prevX, prevY)
    local prevResult = BM:getScreenIntersectPlane(Lib.v2(prevX, prevY), Lib.v3(0, 1, 0), Lib.v3(0, 31, 0))
    local curResult = BM:getScreenIntersectPlane(Lib.v2(curX, curY), Lib.v3(0, 1, 0), Lib.v3(0, 31, 0))
    local delta = prevResult.intersect - curResult.intersect
    local clampDelta = Lib.v3(util:clamp(delta.x, -1, 1), util:clamp(delta.y, -1, 1), util:clamp(delta.z, -1, 1))
    Lib.emitEvent(Event.EVENT_PAN_CAMERA, clampDelta)
end

-- 本地测试用
local lastKeyState = L("lastKeyState", {})
local bm = Blockman.Instance()

local function checkNewState(key, new)
    if lastKeyState[key] == new then
        return false
    end
    lastKeyState[key] = new
    return true
end

local function isKeyNewDown(key)
    local state = bm:isKeyPressing(key)
    return checkNewState(key, state) and state
end

function GameManager:tick()
    --- todo: 根据需求暂时屏蔽框选状态
    --[[if self.isTouchBegin == true and self.isTouchMove == false then
        if (Lib.getTime() -  self.pressTime) > self.pressDelay * 1000 then
            if self:getCurrentState() == "MultipleSelection" then
                self:pushState("HoldDown")
            end
        end
    end]]--

    -- 本地测试用
    if isKeyNewDown("key.left") then
        local screenCenterPos = Lib.v2(GUISystem.Instance():GetScreenWidth() * 0.5, GUISystem.Instance():GetScreenHeight() * 0.5)
        local centerResult = BM:getScreenIntersectPlane(GUISystem.Instance():AdaptPosition(screenCenterPos), Lib.v3(0, 1, 0), Lib.v3(0, 31, 0))
        Lib.emitEvent(Event.EVENT_TURN_CAMERA, centerResult.intersect, Lib.v3(0, 1, 0), -5)
    end

    if isKeyNewDown("key.right") then
        local screenCenterPos = Lib.v2(GUISystem.Instance():GetScreenWidth() * 0.5, GUISystem.Instance():GetScreenHeight() * 0.5)
        local centerResult = BM:getScreenIntersectPlane(GUISystem.Instance():AdaptPosition(screenCenterPos), Lib.v3(0, 1, 0), Lib.v3(0, 31, 0))
        Lib.emitEvent(Event.EVENT_TURN_CAMERA, centerResult.intersect, Lib.v3(0, 1, 0), 5)
    end

    if isKeyNewDown("key.forward") then
        Lib.emitEvent(Event.EVENT_PITCH_CAMERA, 5)
    end

    if isKeyNewDown("key.back") then
        Lib.emitEvent(Event.EVENT_PITCH_CAMERA, -5)
    end
end

function GameManager:mobile_init_loginTs()
    return self.time
end

return GameManager