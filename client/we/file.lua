local cjson = require "cjson"
local misc = require "misc"

local M = {}

local function read_file(path)
	local file, errmsg = io.open(path)
	assert(file, errmsg)
	local content = file:read("a")
	file:close()

	-- remove BOM
	local c1, c2, c3 = string.byte(content, 1, 3)
	if (c1 == 0xEF and c2 == 0xBB and c3 == 0xBF) then	-- UTF-8
		content = string.sub(content, 4)
	elseif (c1 == 0xFF and c2 == 0xFE) then	-- UTF-16(LE)
		content = string.sub(content, 3)
	end

	return content
end

local function write_file(path, content)
	local file, errmsg = io.open(path, "w+b")
	assert(file, errmsg)
	file:write(content)
	file:close()	
end

local function read_json(path)
	return read_file(path)
end

local function write_json(path, json)
	return write_file(path, json)
end

local function read_csv(path)
	local items, header = Lib.read_csv_file(path)
	for _, item in ipairs(items) do
		for k, v in pairs(item) do
			item[k] = tonumber(v) and tonumber(v) or v
		end
	end

	return cjson.encode({
		items = items,
		header = header
	})
end

local function write_csv(path, json)
	local tb = cjson.decode(json)
	local header = tb.header
	local items = tb.items

	local function to_array(item)
		local ret = {}
		for _, key in pairs(header) do
			table.insert(ret, item[key])
		end

		return ret
	end

	local out = misc.csv_encode(header) .. "\r\n"
	for i, v in ipairs(items) do
		local line = to_array(v)
		out = out .. misc.csv_encode(line) .. "\r\n"
	end

	misc.write_utf16(path, out)
end

local function read_bts(path)

end

local function write_bts(path, json)

end

function M.read_csv(path, separated)
	local items, header = Lib.read_csv_file(path)
	for _, item in ipairs(items) do
		for k, v in pairs(item) do
			item[k] = tonumber(v) and tonumber(v) or v
		end
	end

	return items, header
end

function M.write_csv(path, items, header, separated)
	local function to_array(item)
		local ret = {}
		for _, key in pairs(header) do
			table.insert(ret, item[key])
		end

		return ret
	end

	local out = misc.csv_encode(header) .. "\r\n"
	for i, v in ipairs(items) do
		local line = to_array(v)
		out = out .. misc.csv_encode(line) .. "\r\n"
	end

	misc.write_utf16(path, out)
end

function M:read(path)
	local fmt = string.match(path, "^.*%.(%g+)$")
	if fmt == "bts" then
		return read_bts(path)
	elseif fmt == "csv" then
		return read_csv(path)
	end
	
	assert(fmt == "json", path)
	return read_json(path)
end

function M:write(path, json)
	local fmt = string.match(path, "^.*%.(%g+)$")
	if fmt == "bts" then
		return write_bts(path, json)
	elseif fmt == "csv" then
		return write_csv(path, json)
	end

	assert(fmt == "json", path)
	return write_json(path, json)
end

return M
