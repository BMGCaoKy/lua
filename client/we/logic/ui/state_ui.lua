local TreeSet = require "we.gamedata.vtree"
local VN = require "we.gamedata.vnode"
local Signal = require "we.signal"
local Bunch_UI = require "we.logic.ui.bunch_ui"
local Constraint = require "we.view.scene.logic.constraint"
local Def = require "we.def"

local M = {}

function M:init()
	local tree = assert(TreeSet:create("EDIT_STATE_LAYOUT", {}, "TREE_ID_LAYOUT_STATE"))
	self._root = tree:root()	

	Signal:subscribe(Bunch_UI, Bunch_UI.SIGNAL.ON_TREE_CHANGED, function(tid, clear)
		self:focus_tree(tid, clear)
	end)
end

function M:focus(vnode)
	if not vnode then
		self._root["focus"] = { tree = "", path = ""}
	else
		local tree = VN.tree(vnode)
		local path = VN.path(vnode)

		self._root["focus"] = { tree = tree:id(), path = path}
	end
end

function M:focus_tree(id, clear)
	self._root["focus"] = { tree = id, path = "", clear = clear}
end

function M:pb_type()
	return self._root["pb_type"]
end

return M
