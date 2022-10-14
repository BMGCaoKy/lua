local IInstance = require "we.engine.engine_instance"
local IWorld = require "we.engine.engine_world"
local Meta = require "we.gamedata.meta.meta"
local Utils = require "we.view.scene.utils"
local Map = require "we.view.scene.map"
local VN = require "we.gamedata.vnode"
local precision = 0.01

local function check_precision(a,b)
    for _,k in ipairs({"x","y","z"}) do
        if a[k] > b[k] then
            if precision < (a[k] - b[k]) then
                return true
            end
        else
            if precision < (b[k] - a[k]) then
                return true
            end
        end
    end
    return false
end

local function add_pos(a,b)
	return {
        x = a.x + b.x,
        y = a.y + b.y,
        z = a.z + b.z
    }
end

local function sub_pos(a,b)
	return {
        x = a.x - b.x,
        y = a.y - b.y,
        z = a.z - b.z
    }
end

local function assign_vec3(a,b)
    a.x = b.x
    a.y = b.y
    a.z = b.z
end

local router = {
    ["^xform/pos"] = function(bind_obj, event, oval)
        IInstance:set(bind_obj.engin_obj, "position", Utils.seri_prop("Vector3", bind_obj.getPosition()))
    end,

    ["^xform/rotate"] = function(bind_obj, event, oval)
        local vnode = bind_obj.vnode
        local rotate = Utils.seri_prop("Vector3", vnode["xform"]["rotate"])
        IInstance:set(bind_obj.engin_obj, "rotation", rotate)
    end,

    ["^xform/scale"] = function(bind_obj, event, oval)
        local vnode = bind_obj.vnode
        IInstance:set(bind_obj.engin_obj, "scale", Utils.seri_prop("Vector3", vnode["xform"]["scale"]))
    end,
}

local gizmo_sync = {
    ["move"] = function(bind_map)
        for _,bind_obj in pairs(bind_map) do
            local position = Utils.deseri_prop("Vector3", IInstance:get(bind_obj.engin_obj,"position"))
            bind_obj.setPosition(position)
        end
    end,
    ["rotate"] = function(bind_map)
        for _,bind_obj in pairs(bind_map) do
            local rotation = Utils.deseri_prop("Vector3", IInstance:get(bind_obj.engin_obj,"rotation"))
            if check_precision(bind_obj.rotation,rotation) then
                assign_vec3(bind_obj.rotation,rotation)
            end
        end
    end,
    ["scale"] = function(bind_map)
        for _,bind_obj in pairs(bind_map) do
            local scale = Utils.deseri_prop("Vector3", IInstance:get(bind_obj.engin_obj,"scale"))
            if check_precision(bind_obj.scale,scale) then
                assign_vec3(bind_obj.scale,scale)
            end
        end
    end
}

local M = {}

function M:init()
    self._bind_map = setmetatable({},{__mode = "kv"})
end

function M:check_gizmo(operation)
    local sync = gizmo_sync[operation] or function() end
    sync(self._bind_map)
end

function M:notify(bind_vnode,path, event, index,...)
    local obj = self._bind_map[bind_vnode]
    if not obj then return end
    local captures = nil
    for pattern, processor in pairs(router) do
        captures = table.pack(string.find(path, pattern))
        if #captures > 0 then
				local args = {}
				for i = 3, #captures do
					table.insert(args, math.tointeger(captures[i]) or captures[i])
				end
				for _, arg in ipairs({...}) do
					table.insert(args, arg)
				end

				processor(obj, event,table.unpack(args),path)
				break
			end
    end
end

function M:create_bind_object(inst)
    local vnode = inst:vnode()
    local bind_obj = {obj=inst}
    local bind_engine = inst:node()
    if vnode.xform then
        bind_obj.pos = vnode.xform.pos or {x = 0,y = 0,z = 0}
        bind_obj.rotation = vnode.xform.rotate
        bind_obj.scale = vnode.xform.scale
    else
        bind_obj.pos = vnode.position or {x = 0,y = 0,z = 0}
        bind_obj.rotation = vnode.rotation
        bind_obj.scale = vnode.scale
    end

    bind_obj.getPosition = function()
	    return bind_obj.pos
    end

    bind_obj.setPosition = function(pos)
        if check_precision(bind_obj.pos,pos) then
            assign_vec3(bind_obj.pos,pos)
        end
    end

    local parent = inst:parent()
    -- bind_obj.is_xform = function() return true end
    if vnode.is_relative and parent then
        local parent_vnode = parent:vnode()
        if parent_vnode.position then
            bind_obj.parent_pos = parent_vnode.position
        elseif parent_vnode.xform.pos then
            bind_obj.parent_pos = parent_vnode.pos
        end
        if bind_obj.parent_pos then
            bind_obj.parent_vnode = parent_vnode
            bind_obj.getPosition = function()
                 return add_pos(bind_obj.pos,bind_obj.parent_pos)
            end
            bind_obj.setPosition = function(offset)
                local pos = sub_pos(offset,bind_obj.parent_pos)
                if check_precision(bind_obj.pos,pos) then
                    assign_vec3(bind_obj.pos,pos)
                end
            end
            -- bind_obj.is_xform = function()
            --     return false == bind_obj.parent_vnode["selected"]
            -- end
        end
    end
    
    if not bind_engine.getAnchorPoint then
        bind_engine.getAnchorPoint = function(self)
            return bind_obj.getPosition()
        end
    end

    if not bind_engine.getRotation then
        bind_engine.getRotation = function(self)
            return bind_obj.rotation
        end
    end

    if not bind_engine.getScale then
        bind_engine.getScale = function(self)
            return bind_obj.scale
        end
    end
    local meta_obj = Meta:meta("Instance_EmptyNode"):ctor({
        position = bind_obj.getPosition(),
        rotation = bind_obj.rotation,
        scale = vnode.scale or {x = 1,y = 1,z = 1}
    })

    meta_obj.id = tostring(IWorld:gen_instance_id())
    local engin_obj = IWorld:create_instance(Utils.export_inst(meta_obj),false)
    if bind_obj.parent_pos then
        IInstance:set_parent(engin_obj, parent:node())
    else
        local parent_node =IWorld:get_scene_root_node()
        IInstance:set_parent(engin_obj, parent_node)
    end

    IInstance:set_select(engin_obj, true)
    bind_obj.engin_obj = engin_obj
    bind_obj.id = meta_obj.id
    bind_obj.vnode = vnode

    self._bind_map[vnode] =  bind_obj
    inst:setBindNotify(function(...)
	    self:notify(...)
    end)
end

function M:remove(inst)
    local vnode = inst:vnode()
    if self._bind_map[vnode] then
        IWorld:remove_instance(self._bind_map[vnode].engin_obj)
        self._bind_map[vnode] = nil
    end
end

function M:bind_object(null_vnode)
    return self._bind_map[null_vnode]
end

return M