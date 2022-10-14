local Log = require "we.log"

local M = {}

function M:init(conf, meta_set)
	self._conf = conf
	self._meta_set = assert(meta_set)

	self._processor = nil
end

function M:specifier()
	return self._conf.specifier
end

function M:name()
	return self._conf.name
end

function M:meta_set()
	return self._meta_set
end

function M:set_processor(processor)
	self._processor = processor
end

function M:process(val, info)
	info = info or {}
	val = self:process_(val, info)

	if self._processor then
		val = self._processor(val, info)
	end

	return val
end

function M:attribute(name)
	return self._conf["attribute"] and self._conf["attribute"][name]
end

function M:attrs()
	return self._conf["attribute"]
end

function M:set_attribute(id, key, value)
	if self._conf.member and self._conf.member[id] then
		self._conf.member[id].attribute[key] = value
		return true
	end

	if self._conf.base then
		local meta = self._meta_set:meta(self._conf.base.type)
		return meta:set_attribute(id, key, value)
	end
	Log("Meta", string.format("set_attribute fail: %s.%s not find!", id, key))
	return false
end

function M:set_value(id, value)
	if self._conf.member and self._conf.member[id] then
		self._conf.member[id].value = value
		return true
	end

	if self._conf.base then
		local meta = self._meta_set:meta(self._conf.base.type)
		return meta:set_value(id, value)
	end
	Log("Meta", string.format("set_value fail: %s.%s not find!", self:name(), id))
	return false
end

----------------------------------------------------------
-- virtual function
function M:ctor(val, arg, attrs)
	assert(false)
end

function M:process_(val, info)
	return val
end

function M:verify(val, strict)
	assert(false)
end

function M:info()
	return nil
end

function M:diff(val_d, val_s)
	if val_d ~= val_s then
		return val_d
	else
		return nil
	end
end

return M
