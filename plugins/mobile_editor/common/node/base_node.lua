--- base_node.lua
--- 场景中基础节点，是所有节点的父类
local class = require "common.3rd.middleclass.middleclass"
local stateful = require "common.3rd.stateful.stateful"
---@type engine_scene
local IScene = require "common.engine.engine_scene"
---@type engine_instance
local IInstance = require "common.engine.engine_instance"
---@type engine_world
local IWorld = require "common.engine.engine_world"
---@type ConfigManager
local ConfigManager = T(MobileEditor, "ConfigManager")
---@type util
local util = require "common.util.util"
---@type PlaceState
local PlaceState = require "common.state.node.place_state"
---@type SelectState
local SelectState = require "common.state.node.select_state"
---@class BaseNode : Stateful
local BaseNode = class('BaseNode'):include(stateful)

BaseNode:addState("Place", PlaceState)
BaseNode:addState("Select", SelectState)

function BaseNode:initialize(cfg)
    if cfg then
        self.nodeType = util:getNodeType(cfg.class)
        ---@type Instance
        self.object = IWorld:create_instance(cfg)
        self.object:setSelectable(true)

        if cfg.class == "Model" then
            if cfg.children then
                --- 递归出所有model下面的对象(Part, PartOperation, MeshPart ...)
                local children = {}
                util:extractModel(self.object, children)

                --- 遍历这些对象并赋予对应的自定义属性
                for i = 1, #children do
                    local child = children[i]
                    if child then
                        local id = child:getInstanceID()
                        local config = util:parseModelConfig(cfg, id)
                        if config then
                            child.attributes = config.attributes
                        end
                    end
                end
            end
        else
            Lib.logDebug("BaseNode:initialize cfg.attributes = ", cfg.attributes)
            self.object.attributes = cfg.attributes
        end
    end
end

function BaseNode:destroy()
    if self.object ~= nil then
        IWorld:remove_instance(self.object)
        self.object = nil
    end
end

function BaseNode:loadAttributes()
    if self.object:isA("Model") then
        local children = {}
        util:extractModel(self.object, children)
        for i = 1, #children do
            local child = children[i]
            if child then
                if child.attributes and Lib.getTableSize(child.attributes) == 0 then
                    local color = IInstance:get(child, "materialColor")
                    child.attributes["color"] = color
                end
            end
        end
    elseif self.object:isA("Part") or self.object:isA("PartOperation") then
        if self.object.attributes and Lib.getTableSize(self.object.attributes) == 0 then
            local color = IInstance:get(self.object, "materialColor")
            self.object.attributes["color"] = color
        end
    end
end

function BaseNode:setParent(parent)
    self.object:setParent(parent)
end

function BaseNode:getParent()
    return self.object:getParent()
end

function BaseNode:setObject(object)
    self.object = object
end

function BaseNode:getObject()
    return self.object
end

function BaseNode:setModCfgId(id)
    self.modCfgId = id
end

function BaseNode:getModCfgId()
    return self.modCfgId
end

function BaseNode:setNodeType(type)
    self.nodeType = type
end

function BaseNode:getNodeType()
    return self.nodeType
end

function BaseNode:getId()
    assert(self.object ~= nil, "object is nil")
    return self.object:getInstanceID()
end

function BaseNode:isA(className)
    assert(self.object ~= nil, "object is nil")
    return self.object:isA(className)
end

function BaseNode:contains(className)
    assert(self.object ~= nil, "object is nil")
    return util:contains(self.object, className)
end

function BaseNode:getPosition()
    assert(self.object ~= nil, "object is nil")
    return self.object:getPosition()
end

function BaseNode:setPosition(pos)
    assert(self.object ~= nil, "object is nil")
    self.object:setPosition(pos)
end

function BaseNode:setRotation(rotation)
    assert(self.object ~= nil, "object is nil")
    self.object:setRotation(rotation)
end

function BaseNode:getRotation()
    assert(self.object ~= nil, "object is nil")
    return IInstance:rotation(self.object)
end

function BaseNode:getSize()
    assert(self.object ~= nil, "object is nil")
    return IInstance:size(self.object)
end

function BaseNode:setSelection(status)
    assert(self.object ~= nil, "object is nil")
    IInstance:set_select(self.object, status)
end

function BaseNode:setHover(status)
    assert(self.object ~= nil, "object is nil")
    IInstance:set_hover(self.object, status)
end

function BaseNode:checkAbility(type)
    local name = IInstance:get(self.object, "name")
    local ability
    if name == "birth" then
        ability = Define.ABILITY.TRANSLATE | Define.ABILITY.AABB | Define.ABILITY.FOCUS | Define.ABILITY.SELECTABLE
    else
        ability = Define.CLASS_ABILITY[self.nodeType]
    end
    return ability and (ability & type > 0) or false
end


function BaseNode:resetMaterialColor()
    util:resetColorAttribute(self.object)
end

function BaseNode:setMaterialColor(color)
    self:set("materialColor", color)
    self:setAttribute("color", color)
end

function BaseNode:getMaterialColor()
    local colors = {}
    if self.object:isA("Part") or self.object:isA("PartOperation") then
        colors[self.object:getInstanceID()] = self.object.attributes["color"]
    elseif self.object:isA("Model") then
        local children = {}
        util:extractModel(self.object, children)

        for i = 1, #children do
            local child = children[i]
            if child and child.attributes then
                colors[child:getInstanceID()] = child.attributes["color"]
            end
        end
    end

    return colors
end

function BaseNode:setMaterialTextureIndex(textureIndex)
    local data = ConfigManager:instance().materialTextureConfig:getConfig(textureIndex)
    if data then
        self:setAttribute("textureIndex", textureIndex)
        self:set("materialTexture", data.path)

        if data.attribute == Define.MATERIAL_ATTRIBUTE.WATER then
            self:set("name", "swimming_area")
            self:set("materialAlpha", "0.43")
            self:set("restitution", "0.3")
            self:set("useCollide", "false")
        elseif data.attribute == Define.MATERIAL_ATTRIBUTE.GLASS then
            self:set("name", "")
            self:set("materialAlpha", "0.5")
            self:set("restitution", "0.0")
            self:set("useCollide", "true")
        else
            self:set("name", "")
            self:set("materialAlpha", "1.0")
            self:set("restitution", "0.0")
            self:set("useCollide", "true")
        end
    end
end

function BaseNode:getMaterialTextureIndex()
    if self.object:isA("Part") or self.object:isA("PartOperation") then
        return self.object.attributes["textureIndex"]
    elseif self.object:isA("Model") then
        local children = {}
        util:extractModel(self.object, children)

        local attributes = {}
        for i = 1, #children do
            local child = children[i]
            if child and child.attributes then
                attributes[child:getInstanceID()] = child.attributes["textureIndex"]
            end
        end

        return attributes
    end

end



function BaseNode:set(key, value)
    util:setProperty(self.object, key, value)
end

function BaseNode:get(key)
    return IInstance:get(self.object, key)
end

function BaseNode:setAttribute(key, value)
   util:setAttribute(self.object, key, value)
end


return BaseNode