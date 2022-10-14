-- 5.1与5.3的语法差异部分
require "common.compat.compat53.init"

compat = compat or {}

compat.init = function()
	compat.isLua51 = (_VERSION:sub(-3) == "5.1")
	print("compat.isLua51:", compat.isLua51)
end

compat.getEnv = function()
	if compat.isLua51 then
		do return getfenv(1) end
	else
		return _ENV
	end
end

compat.init()
