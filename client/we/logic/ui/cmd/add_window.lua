local Meta = require "we.gamedata.meta.meta"
local Recorder = require "we.gamedata.recorder"
local UIRequest = require "we.proto.request_ui"

local M = {}

function M:init(item,path,index,type,pos)
	self._item = item:layout_item()
	self._path = path
	self._type = type
	self._index = index

	local meta = Meta:meta(type)
	local name = meta:info()["value"]["name"]
	
	self._additional = {}
	self._additional_path = nil

	local initFunc = self["init" .. type]
	if initFunc then
		initFunc(self)
	end

	self._data = {
		name = item:verify_window_name(path,name),
		gui_type = type,
		id = {
			value = GenUuid()
		},
		pos = {
			UDim_X = {
				Scale = 0,
				Offect = pos.x
			},
			UDim_Y = {
				Scale = 0,
				Offect = pos.y
			}
		}
	}
	self:recorder()
end

function M:recorder()
	Recorder:start()
	self._item:data():insert(self._path,self._index,self._type,self._data)
	for index,data in ipairs(self._additional) do
		self._item:data():insert(data.path, index, data.child_type, data.data)
	end
	Recorder:stop()
	local id = self._data.id.value
	UIRequest.request_add_widgets({id})
end

function M:initCustomHorizontalSlider()
	local path = self._path
	local index = self._index

	local child_path = path .. "/" .. tostring(index) .. "/children"
	local child_type = "StaticImage"

	table.insert(self._additional,{path = child_path, child_type = child_type,
		data = {
			name = "Background",
			gui_type = child_type,
			Image = {selector = "asset/Texture/Gui/slider_bg.png", asset = "asset/Texture/Gui/slider_bg.png", name = "slider_bg.png"},
			size = {UDim_X = {Scale = 0, Offect = 256}, UDim_Y = {Scale = 0, Offect = 16}},
			VerticalAlignment = "Centre",
			WindowTouchThroughMode = "MousePassThroughOpen",
		}
	})
	table.insert(self._additional,{path = child_path, child_type = child_type,
		data = {
			name = "Fill",
			gui_type = child_type,
			Image = {selector = "asset/Texture/Gui/slider_top_h.png", asset = "asset/Texture/Gui/slider_top_h.png", name = "slider_top_h.png"},
			size = {UDim_X = {Scale = 0, Offect = 256}, UDim_Y = {Scale = 0, Offect = 16}},
			VerticalAlignment = "Centre",
			WindowTouchThroughMode = "MousePassThroughOpen",
		}
	})
	local child_type = "SliderThumb"
	table.insert(self._additional,{path = child_path, child_type = child_type,
		data = {
			name = "Handle",
			gui_type = child_type,
			size = {UDim_X = {Scale = 0, Offect = 32}, UDim_Y = {Scale = 0, Offect = 32}},
			VerticalAlignment = "Centre",
		}
	})
end

function M:initCustomVerticalSlider()
	local path = self._path
	local index = self._index

	local child_path = path .. "/" .. tostring(index) .. "/children"
	local child_type = "StaticImage"

	table.insert(self._additional,{path = child_path, child_type = child_type,
		data = {
			name = "Background",
			gui_type = child_type,
			Image = {selector = "asset/Texture/Gui/slider_bg.png", asset = "asset/Texture/Gui/slider_bg.png", name = "slider_bg.png"},
			size = {UDim_X = {Scale = 0, Offect = 16}, UDim_Y = {Scale = 0, Offect = 256}},
			HorizontalAlignment = "Centre",
			WindowTouchThroughMode = "MousePassThroughOpen",
		}
	})
	table.insert(self._additional,{path = child_path, child_type = child_type,
		data = {
			name = "Fill",
			gui_type = child_type,
			Image = {selector = "asset/Texture/Gui/slider_top_v.png", asset = "asset/Texture/Gui/slider_top_v.png", name = "slider_top_v.png"},
			size = {UDim_X = {Scale = 0, Offect = 16}, UDim_Y = {Scale = 0, Offect = 256}},
			HorizontalAlignment = "Centre",
			WindowTouchThroughMode = "MousePassThroughOpen",
			FillType = "Vertical",
			FillPosition = "Bottom_Vertical",
		}
	})
	local child_type = "VSliderThumb"
	table.insert(self._additional,{path = child_path, child_type = child_type,
		data = {
			name = "Handle",
			gui_type = child_type,
			size = {UDim_X = {Scale = 0, Offect = 32}, UDim_Y = {Scale = 0, Offect = 32}},
			HorizontalAlignment = "Centre",
		}
	})
end

return M