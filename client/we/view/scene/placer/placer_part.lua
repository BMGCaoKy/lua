local Def = require "we.def"
local Signal = require "we.signal"
local UserData = require "we.user_data"

local Meta = require "we.gamedata.meta.meta"
local VN = require "we.gamedata.vnode"

local Input = require "we.view.scene.input"
local Map = require "we.view.scene.map"
local State = require "we.view.scene.state"
local Part = require "we.view.scene.logic.part"
local Utils = require "we.view.scene.utils"
local Receptor = require "we.view.scene.receptor.receptor"
local Placer = require "we.view.scene.placer.placer"

local IWorld = require "we.engine.engine_world"
local IScene = require "we.engine.engine_scene"
local IInstance = require "we.engine.engine_instance"
local Module = require "we.gamedata.module.module"
local GameSetting = require "we.gamesetting"

local BM = Blockman.Instance()

local Base = require "we.view.scene.placer.placer_base"
local M = Lib.derive(Base)

function M:init(mode)
	Base.init(self, mode)

	self._item = nil
	self._name = nil
	self._node = nil
	self._material_texture = "part_suliao.tga"
	self._material_color = { r = 255, g = 255, b = 255, a = 255 }

	local part_place_settings_node = State:part_place_settings()
	Signal:subscribe(part_place_settings_node, Def.NODE_EVENT.ON_MODIFY, function(path, event, index, ...)
		local part_place_settings_value = VN.value(part_place_settings_node)
		local function set(setting_index)
			local setting = part_place_settings_value[setting_index]
			if setting["key"] == self._name then
				self._material_texture = setting["texture"]
				self._material_color = setting["color"]
				UserData:set_value("part_place_settings", part_place_settings_value)
			end
			if self._node then
				IInstance:set(self._node, "materialTexture", self._material_texture)
				local color_temp = string.format("r:%s g:%s b:%s", self._material_color.r / 255, self._material_color.g / 255, self._material_color.b / 255)
				IInstance:set(self._node, "materialColor", color_temp)
			end
			
		end
		if event == Def.NODE_EVENT.ON_ASSIGN then
			set(path[1])
		else
			set(index)
		end
	end)
end


function M:on_bind()
	DebugDraw.instance:setDrawTouchPartFaceEffectEnabled(true)
end

function M:on_unbind()
	self:reset()
	DebugDraw.instance:setDrawTouchPartFaceEffectEnabled(false)
	local manager = World.CurWorld:getSceneManager()
	manager:clearTouchFaceInfo()
end

function M:reset()
	if self._node then
		IWorld:remove_instance(self._node)
		self._node = nil
	end
	self._name = nil
end

local name2shape = {
	["cube"]						= "1",
	["sphere"]						= "2",
	["cylinder"]					= "3",
	["cone"]						= "4"
}

function M:select(name, material_texture, color)
	if self._name == name then
		return
	end
	self:reset()

	self._name = name
	if not self._name or self._name == "" then
		return
	end

	for _, vnode in ipairs(State:part_place_setting()) do
		local key = assert(vnode["key"], tostring(vnode["key"]))
		if key == name then
			self._material_texture = vnode["texture"]
			self._material_color = VN.value(vnode["color"])
			break
		end
	end

	self._item = assert(name2shape[name], tostring(name))
	if not self._node then
		self._node = IWorld:create_instance({
			class = "Part"
		})
	end
	local color_temp = string.format("r:%s g:%s b:%s", self._material_color.r / 255, self._material_color.g / 255, self._material_color.b / 255)

	IInstance:set_shape(self._node, self._item)
	IInstance:set(self._node, "materialColor", color_temp)
	IInstance:set_selectable(self._node, false)
	IInstance:set(self._node, "materialTexture", self._material_texture)
end

function M:on_mouse_move(x, y)
	if not self._node then
		return
	end

	IScene:drag_parts({self._node}, x, y)

	return true
end

function M:on_mouse_press(x, y, button)
	if not self._node then
		return
	end

	return true
end

function M:on_mouse_release(x, y, button, is_click)
	if not self._node then
		return
	end

	local collisionEditing,collisionid=State:get_custom_collision_editing()
	if button == Input.MOUSE_BUTTON_TYPE.BUTTON_LEFT then
		local props = Part:material_property(self._material_texture)
		local btsKey = GenUuid()
		local cfg=Meta:meta("Instance_Part"):ctor({
				position = IInstance:position(self._node),
				rotation = IInstance:rotation(self._node),
				shape = self._item,
				massCenter = IInstance:position(self._node),
				material = { texture = self._material_texture, color = self._material_color, offset = { x = 1, y = 1 }, alpha = 1 },
				density = props[1],
				restitution = props[2],
				friction = props[3],
				btsKey = btsKey,
				useAnchor = GameSetting:get_useAnchor(),
				batchType = GameSetting:get_batchType()
			})
		local obj = {}
		if collisionEditing  then
            local parent=Map:query_instance(tostring(collisionid))
            if not parent then
                return false
            end
			cfg.useForCollision=true
            obj=parent:new_child(cfg)
		else
			obj = Map:new_instance(cfg)
		end
		local module_part = Module:module("part")
		module_part:new_item(btsKey)
		Receptor:select("instance", {obj:node()})
	end

	return true
end

function M:place(x, y)
	local props = Part:material_property(self._material_texture)

	local btsKey = GenUuid()
	local ins = Map:new_instance(
		Meta:meta("Instance_Part"):ctor({
			position = IInstance:position(self._node),
			rotation = IInstance:rotation(self._node),
			shape = self._item,
			massCenter = IInstance:position(self._node),
			material = { texture = self._material_texture, color = self._material_color, offset = { x = 1, y = 1 }, alpha = 1 },
			density = props[1],
			restitution = props[2],
			friction = props[3],
			btsKey = btsKey,
			useAnchor = GameSetting:get_useAnchor(),
			batchType = GameSetting:get_batchType()
		})
	)
	local module_part = Module:module("part")
	module_part:new_item(btsKey)

	IScene:drag_parts({ ins:node() }, x, y)
	local bool = self:on_Terrain(x, y)
	--local pos = IInstance:position(ins:node())
	if bool == false then
		local rayLength = 25
		local pos = BM:getScreenToScenePos({x=x , y=y}, rayLength)
		ins:node():setPosition(pos)
	end
	local size = ins:node():getSize()
	ins:vnode()["size"] = size
	Receptor:select("instance", {ins:node()})
	Placer:unbind()
end

return M
