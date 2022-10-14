local IScene = require "we.engine.engine_scene"
local Base = require "we.view.scene.selector.selector_base"
local TreeSet = require "we.gamedata.vtree"
local VN = require "we.gamedata.vnode"
local IWorld = require "we.engine.engine_world"
local Input = require "we.view.scene.input"
local Receptor = require "we.view.scene.receptor.receptor"
local State = require "we.view.scene.state"
local Gizmo = require "we.view.scene.gizmo"
local SceneRegion = require "we.view.scene.logic.scene_region"
local Signal = require "we.signal"

local M = Lib.derive(Base)

function M:init()
	self._tree_id = nil
	self._path = nil
	self._region = nil
end

function M:on_bind()

end

function M:on_unbind(clear)
	if clear then
		SceneRegion:delete()
	end
end

function M:select(data)
	local datas = Lib.splitString(data,"|")
	self._tree_id = datas[1]
	self._path = datas[2]
	if not self._region then
		self._region = SceneRegion:create_region()
		Signal:subscribe(SceneRegion, SceneRegion.SIGNAL.DESTROY, function()
			self._region = nil
		end)
	end
end

function M:on_mouse_move(x, y)
	if not self._region then
		return
	end
	IScene:drag_parts({ self._region }, x, y)
end

function M:on_mouse_release(x, y, button, is_click)
	if not self._region then
		return
	end
	if button ~= Input.MOUSE_BUTTON_TYPE.BUTTON_LEFT then
		return
	end
	
	local tree = TreeSet:tree(self._tree_id)
	assert(tree,self._tree_id)
	local node = tree:node(self._path)
	assert(node,self._path)
	SceneRegion:set_data(node)

	local receptor = Receptor:binding()
	if receptor and receptor:type() ~= "scene_region" then
		Receptor:unbind()
	end
	receptor = Receptor:bind("SCENE_REGION")
	receptor:attach(self._region, false, true, false)
	State:gizmo()["type"] = Gizmo.TYPE.SCALE

	Signal:publish(self, self.SIGNAL.SELECT_FINISH)
end

return M