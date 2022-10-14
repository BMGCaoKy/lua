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
	if self._processor then
		return self._processor(val, info)
	end

	return self:process_(val, info)
end

function M:attribute(name)
	return self._conf["attribute"] and self._conf["attribute"][name]
end

----------------------------------------------------------
-- virtual function
function M:ctor(val, arg, attrs)
	assert(false)
end

function M:process_(val, info)
	assert(type(val) ~= "table")
	return val
end

function M:verify(val, strict)
	assert(false)
end

function M:info()
	return nil
end

return M
