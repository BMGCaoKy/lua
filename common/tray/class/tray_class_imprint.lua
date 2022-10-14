local tray_class_equip = require "common.tray.class.tray_class_equip"
local tray_class_base = require "tray.class.tray_class_base"
local M = Lib.derive(tray_class_equip)

function M:init(type, capacity, system)
	tray_class_base.init(self, type, capacity, Define.TRAY_CLASS_IMPRINT, system)
	return true
end

function M:check_replace()
    return false
end

return M