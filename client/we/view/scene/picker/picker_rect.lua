local Def = require "we.def"
local Input = require "we.view.scene.input"
local Receptor = require "we.view.scene.receptor.receptor"
local Map = require "we.view.scene.map"
local State = require "we.view.scene.state"
local GameConfig = require "we.gameconfig"

local IWorld = require "we.engine.engine_world"
local IScene = require "we.engine.engine_scene"

local Base = require "we.view.scene.picker.picker_base"
local PartAlignment = require "we.view.scene.logic.part_alignment"

local M = Lib.derive(Base)

function M:init(mode)
	Base.init(self, mode)

	self._from = nil
	self._record = {}
	self._map_id = {}
end

function M:on_bind()

end

function M:on_unbind()
	Receptor:unbind()
end

function M:on_mouse_press(x, y, button)
	if button == Input.MOUSE_BUTTON_TYPE.BUTTON_MIDDLE then
		return
	end

	local receptor = Receptor:binding()

	if button == Input.MOUSE_BUTTON_TYPE.BUTTON_RIGHT then
		if receptor and receptor:ephemerid() and receptor:type() == "instance" then
			receptor:show_dialog(false) 
		end
		return 
	end

	self:on_select_obj(x,y,button)

	-- not hit
	if State:enable() then	-- 临时禁止黑框
		self._from = {x = x, y = y}
		State:set_rect_pick_state(true)
	end
end

local filter_class = {
	EffectPart = true,
	AudioNode = true
}

local function  check_select_obj(obj)
	if obj._vnode["useForCollision"] then
		return obj
	end
	local parent = obj._parent
	while parent do
		if "Model" == parent:class() then
			obj = parent
		end
		parent = parent:parent()
	end

	local cls = obj:class()
	if not filter_class[cls] and not obj:locked() and obj:enabled()  then
		return obj
	end
	return nil
end

function M:on_mouse_move(x, y)
	if not Input:check_mouse_press(Input.MOUSE_BUTTON_TYPE.BUTTON_LEFT) then
		return
	end

	if not self._from then
		return
	end

	local receptor = Receptor:binding()
	if receptor and not receptor:accept(Def.SCENE_NODE_TYPE.OBJECT) then
		return
	end

	if not receptor then
		receptor = Receptor:bind("instance")
	end

	State:set_rect_pick_region(self._from, {x = x, y = y})

	local rect = {
		left = math.min(self._from.x, x), 
		top = math.min(self._from.y, y),
		right = math.max(self._from.x, x),
		bottom = math.max(self._from.y, y)
	}

	local nodes = IScene:pick_rect(rect, false)
	local set = {}
	local diff = {}
	for _, node in ipairs(nodes) do
		set[node:getInstanceID()] = node
		diff[node:getInstanceID()] = node
	end

	local map_id = {}
	local select_list = {}
	local old_list = {}
	for id,obj  in pairs(self._map_id) do
		old_list[obj] = true
		if set[id] then
			map_id[id] = obj
			select_list[obj] = true
		end
	end

	for id, node in pairs(self._record) do
		diff[id] = not diff[id] and node or nil
	end

	local roots = {}
	local remove_list = {}
	for id,node in pairs(diff) do
		local obj = Map:query_instance(node)
		assert(obj)
		local obj_select = check_select_obj(obj)
		if obj_select then
			if select_list[obj_select] then
				map_id[id] = obj_select
			else
				if old_list[obj_select] then
					if not remove_list[obj_select] then
						roots[id] = obj_select:node()
						remove_list[obj_select] = true
					end
				else
					roots[id] = obj_select:node()
					select_list[obj_select]  = true
					map_id[id] = obj_select
				end
			end
		end
	end

	for _,node in pairs(roots) do
		receptor:attach(node,true)
	end

	self._record = set
	self._map_id = map_id
	return true
end

function M:on_mouse_release(x, y, button, is_click)
	if button == Input.MOUSE_BUTTON_TYPE.BUTTON_MIDDLE then
		return
	elseif button == Input.MOUSE_BUTTON_TYPE.BUTTON_RIGHT then
		if not is_click then
			return
		end

		self:on_select_obj(x,y,button,is_click)
	end

	if not GameConfig:disable_block() then
		local node = IScene:pick_point({x = x, y = y}, Def.SCENE_NODE_TYPE.BLOCK)
		local receptor = Receptor:binding()
		if not receptor then
			if node then
				receptor = Receptor:bind("block")
			end
		end

		if receptor and receptor:accept(Def.SCENE_NODE_TYPE.BLOCK) then
			receptor:attach(node.pos, true)	
		end
	end

	self:on_lost_focus()
	return true
end

function M:on_hover_unlock(x,y,button)
	local node,type=IScene:pick_point({x=x,y=y},Def.SCENE_NODE_TYPE.OBJECT)
	local receptor = Receptor:binding()
	local node, type = IScene:pick_point({x = x, y = y}, Def.SCENE_NODE_TYPE.OBJECT)
	local obj = node ~= nil and Map:query_instance(node) or nil 
	local receptor = Receptor:binding()
	if not receptor then
		receptor = Receptor:bind("instance")	-- instance can select on press
	end
	if node then
		receptor:hover_unlock(obj)
	end
	Receptor:unbind("instance")
end


function M:on_lost_focus()
	if self._from then
		self._from = nil
		self._record = {}
		State:set_rect_pick_state(false)
	end
end

function M:on_select_obj(x,y,button,is_click)
	--check parent receptor
	local function check_receptor(set, obj)
		if not obj then
			return false
		elseif set[obj] then
			return true
		else
			return check_receptor(set, obj:parent())
		end
	end

	local receptor = Receptor:binding()
	local node, type = IScene:pick_point({x = x, y = y}, Def.SCENE_NODE_TYPE.OBJECT)
	local obj = node ~= nil and Map:query_instance(node) or nil
	if receptor and receptor:ephemerid() then
		if button == Input.MOUSE_BUTTON_TYPE.BUTTON_RIGHT and check_receptor(receptor._set, obj) then
			receptor:show_dialog(true)
			receptor:on_mouse_release(x, y, button, is_click)
			return
		elseif not Input:check_key_press(Input.KEY_CODE.Key_Control) then
			Receptor:unbind()
			receptor = nil
		end
	end

	repeat
		if not obj then
			break
		end

		if obj then
			PartAlignment:set_object_to_align_target(obj)
		else
			break	
		end

		local locked = obj:locked() or not obj:enabled()
		if locked then
			break
		end
		
		if not receptor then
			receptor = Receptor:bind("instance")	-- instance can select on press
		end
		assert(receptor)

		local tgt_obj = obj:find_toppest_model_ancestor() or obj
		if tgt_obj then
			receptor:attach(tgt_obj:node(),true)
		end

		if receptor:type() == "instance" and button == Input.MOUSE_BUTTON_TYPE.BUTTON_LEFT then
			receptor:hold()
		elseif button == Input.MOUSE_BUTTON_TYPE.BUTTON_RIGHT then
			receptor:show_dialog(true)
			receptor:on_mouse_release(x, y, button, is_click)
		end

		return true
	until(true)
end

return M
