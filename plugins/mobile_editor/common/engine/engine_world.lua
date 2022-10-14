--- engine_world.lua
local Core = require "editor.core"
---@type Instance
local Instance = Instance
local CW = World.CurWorld
---@class engine_world
local M = {}

function M:enter_map(name, id, pos)
    CW:loadCurMap({
        id = id,
        name = name,
        static = true
    }, pos)

    local manager = CW:getSceneManager()
    local scene = manager:getOrCreateScene(CW.CurMap.obj)
    manager:setCurScene(scene)
end

function M:leave_map()

end

function M:close_map(name)
    local map = CW:getOrCreateStaticMap(name)
    if map then
        map:close()
    end
end

function M:create_instance(cfg, beyond)
    local manager = CW:getSceneManager()
    local scene = manager:getOrCreateScene(CW.CurMap.obj)
    cfg.scene = scene
    local inst = Instance.newInstance(cfg, CW.CurMap)
    if inst and not beyond then
        inst:setParent(scene:getRoot())
    end

    return inst
end

function M:remove_instance(inst)
    if inst then
        return inst:destroy()
    end
end

function M:get_instance(id)
    return Instance.getByInstanceId(id)
end


function M:gen_instance_id()
    return Core.gen_instance_id()
end

return M