local tray_class_base = require "tray.class.tray_class_base"

local M = Lib.derive(tray_class_base)

function M:init(type, capacity, system)
	tray_class_base.init(self, type, capacity, Define.TRAY_CLASS_BAG, system)

	return true
end

function M:check_drop(item)
	return  true
end

return M