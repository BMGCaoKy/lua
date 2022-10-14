
local SECTION_VALUE = "value"

local function load_file(path)
	local file = assert(io.open(path, 'r'), 'Error loading file : ' .. path)
	local value_data = {}
	local attr_data = {}
	local temp_data
	for line in file:lines() do
		-- 匹配[section]
		local section = line:match('^%[([^%[%]]+)%]$')
		if section then
			if section == SECTION_VALUE then
				temp_data = value_data
			else
				attr_data[section] = attr_data[section] or {}
				temp_data = attr_data[section]
			end
			goto continue
		end
		-- 匹配key=value
		local param, value = line:match('^([%w|_%.]+)%s-=%s-(.+)$')
		if param and value then
			temp_data[param] = value
		end
		::continue::
	end
	file:close()
	return value_data, attr_data
end

return function(meta_set, path)
	-- 读取配置文件
	local value_data, attr_data = load_file(path)
	-- 更新meta
	for key,value in pairs(value_data) do
		local keys = Lib.split(key, '.')
		assert(#keys > 1)
		local meta = meta_set._meta_set[keys[1]]
		assert(meta)
		-- 类型转换
		if '"' == string.sub(value, 1, 1) then
			value = string.sub(value, 2, string.len(value)-1)
		elseif tonumber(value) then
			value = tonumber(value)
		elseif value == 'true' then
			value = true
		elseif value == 'false' then
			value = false
		end
		meta:set_value(keys[2], value)
	end
	for section,list in pairs(attr_data) do
		for key,value in pairs(list) do
			local keys = Lib.split(key, '.')
			assert(#keys > 1)
			local meta = meta_set._meta_set[keys[1]]
			assert(meta)
			meta:set_attribute(keys[2], section, value)
		end
	end
end
