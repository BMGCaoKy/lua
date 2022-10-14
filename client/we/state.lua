local def = require "we.def"

local M = {}

function M:init()
	self._focus = nil
	self._brush = nil
	self._clipboard = nil
	self._editmode = def.EMOVE
	self._overtype = false
	self._shift_is_touch = false
	Lib.subscribeEvent(Event.EVENT_SHIFT_TOUCH, function (shift_is_touch)
		self._shift_is_touch = shift_is_touch
	end)
	self._oldbrush = nil

end

--------------------------------------------------------------------
-- focus
function M:focus_class()
	return self._focus and self._focus.class
end

function M:focus_obj()
	return self._focus and self._focus._table
end

--[[ TBLOCK: obj = {
	min,
	max,
	id
}
TENTITY: 
		obj = {
			id = 
		}
		
TREGION: 
		obj = {
			name
		}
		
TCHUNK: {pos = {x = 0,y = 0,z = 0}, data = chunk}
TFRAME: 
		obj = {
				min = {
					x = 1,
					y = 1,
					z = 1
				},
				max = {
					x = 1,
					y = 1,
					z = 1
				}
		}
]]--
function M:set_focus(_table, class, b )
	--只有上一个或者当前选中的是entity,才能申请获取地图.
	if self._focus and self._focus.class == def.TENTITY then
		local Map = require "we.map"
		local old_entity = Map:curr_map():entity(self._focus._table.id)
		--当因删掉entiry而切换时，old_entity为空
		if old_entity then
			old_entity._obj:setEdge(false, {1.0, 0, 0, 1.0})
		end
	end
	--如果当前选中的是entity，显示轮廓.
	if class == def.TENTITY then
		local Map = require "we.map"
		Map:curr_map():entity(_table.id)._obj:setEdge(true, {1.0, 209.0/255, 26.0/255, 1.0})
	end

	self._focus = nil

	if _table and class then
		self._focus = {
			_table = _table,
			class = class
		}
		if b == nil then
			self:set_brush(nil)
			--engine:clear_property_dock()
		end
	end

	Lib.emitEvent(Event.EVENT_EDITOR_STATE_CHANGE_FOCUS)
	return true
end

--------------------------------------------------------------------
-- brush
function M:brush_lastclass()
	return self._lastbrush and self._lastbrush.class
end

function M:brush_lastobj()
	return self._lastbrush and self._lastbrush._table
end

function M:brush_class()
	return self._brush and self._brush.class
end

function M:brush_obj()
	return self._brush and self._brush._table
end

-- TBLOCK: block tid
-- TENTITY: entity tid
--[[ TREGION: 
		obj = {
				min = {
					x = 1,
					y = 1,
					z = 1
				},
				max = {
					x = 1,
					y = 1,
					z = 1
				}
				]]
-- TCHUNK: chunk
--[[ TFRAME: 
		obj = {
				min = {
					x = 1,
					y = 1,
					z = 1
				},
				max = {
					x = 1,
					y = 1,
					z = 1
				}
		}
]]
function M:set_brush(_table, class,b)
	self._brush = nil
	if _table and class then
		self._brush = {
			_table = _table,
			class = class
		}
		self._lastbrush = {
			_table = _table,
			class = class
		}
		if b == nil then
			self:set_focus(nil)
		end
	end

	Lib.emitEvent(Event.EVENT_EDITOR_STATE_CHANGE_BRUSH)
	return true
end

function M:brush()
	return self.brush
end


--------------------------------------------------------------------
-- overtype
function M:overtype()
	return self._overtype
end

function M:set_overtype(overtype)
	self._overtype = overtype and true or false
end

--------------------------------------------------------------------
-- _alt_is_touch
function M:shift_is_touch()
	return self._shift_is_touch
end
--------------------------------------------------------------------
-- clipboard
function M:clipboard_class()
	return self._clipboard and self._clipboard.class
end

function M:clipboard_obj()
	return self._clipboard and self._clipboard.obj
end

function M:set_clipboard(obj, class)
	if not obj or not class then
		self._clipboard = nil
		return true
	end

	self._clipboard = {
		obj = obj,
		class = class
	}

	return true
end

--------------------------------------------------------------------
-- editmode
function M:get_editmode()
	return self._editmode
end

function M:set_editmode(editm)
	if not editm then
		self._editmode = def.EMOVE
		return true
	end
	self._editmode = editm
	Lib.emitEvent(Event.EVENT_EDITOR_STATE_CHANGE_FOCUS)
	return
end

function M:set_oldbrush()
	self._oldbrush = {
		_table = self._brush and self._brush._table or nil,
		class = self._brush and self._brush.class or nil
	}
end

function M:use_oldbrush()
	self:set_brush(self._oldbrush._table,self._oldbrush.class)
end


M:init()

return M
