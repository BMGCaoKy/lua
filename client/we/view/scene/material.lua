local TreeSet = require "we.gamedata.vtree"
local VN = require "we.gamedata.vnode"
local Signal = require "we.signal"
local Map = require "we.view.scene.map"
local Def = require "we.def"
local Bunch = require "we.view.scene.bunch"
local Meta = require "we.gamedata.meta.meta"

local M={}

function M:init(fileName)
	if self._isEdit then
		Bunch:detach(self._vnode)
		Bunch.isEdit=false
	end
	local id=GenUuid()
	local rawval=Meta:meta("CustomMaterialData"):ctor()
	local tree = assert(TreeSet:create("CustomMaterialData", {},id))
	self._vnode=VN.new("CustomMaterialData", rawval,tree)
	local func=function(path, event, index, ...)
		path=table.concat(path,"/")
		if event==Def.NODE_EVENT.ON_ASSIGN then
			path=path=="" and index or path .."/" ..index
		end
		print(path)
	end
	self._router = Signal:subscribe(self._vnode, Def.NODE_EVENT.ON_MODIFY, func)
	Bunch:attach(self._vnode)
	self._isEdit=true
end


local router={

}

return M
