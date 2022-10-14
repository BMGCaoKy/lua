local Misc = require "misc"
local Core = require "editor.core"
local SeriBts = require "we.gamedata.seri_bts"
local ext = {
	json = function(data)
		return true, Lib.toJson(data)
	end,

	csv = function(data, header)
		header = header or {}
		if #header == 0 then
			local keys = {}
			for _, item in ipairs(data) do
				for k in pairs(item) do
					keys[k] = true
				end
			end
			for k in pairs(keys) do
				table.insert(header, k)
			end
			table.sort(header)
		end

		local function to_array(item)
			local ret = {}
			for _, key in pairs(header) do
				table.insert(ret, item[key])
			end
			return ret
		end

		local out_tb = {}
		table.insert(out_tb, Misc.csv_encode(header))
		for _, v in ipairs(data) do
			local line = to_array(v)
			table.insert(out_tb, Misc.csv_encode(line))
		end
		table.insert(out_tb, "")
		local out = table.concat(out_tb, "\r\n")
		return true, Core.to_utf16(out)
	end,

	bts = function(triggers)
		
		if not triggers then
			return true
		end
		
		local loader = loadfile(
			package.searchpath("we.gamedata.export.dumper", package.path),
			"bt",
			setmetatable({}, {__index = _G})
		)

		local ret = SeriBts:transform(triggers)

		local dumper = loader()
		local r1, r2 = pcall(dumper, ret)
		if not r1 then
			return false, r2
		end

		return true, r2
	end,

	xml = function(data,tableName,level)
		return true, Lib.toXml(data,tableName,level)
	end
}

return function(format, data, path, dump, ...)
	local processor = assert(ext[format], string.format("not suppert that format %s", tostring(format)))
	local ok, content = processor(data, ...)
	if not ok then
		print(string.format("data processor error %s\n%s", path, content))
		return
	end

	if not content then
		return
	end
	
	if dump then
		local dir = string.match(path, "^(.*)/[^/]+$")
		Lib.mkPath(dir)
		os.remove(path)
		local file = io.open(path, "w+b", true)
		assert(file, tostring(path))
		file:write(content)
		file:close()
		if DataLink:useDataLink() then
			DataLink:modify(path)
		end
	else
		if DataLink:useDataLink() then
			local dir = string.match(path, "^(.*)/[^/]+$")
			Lib.mkPath(dir)
			os.remove(path)
			local file = io.open(path, "w+b", true)
			file:write(content)
			file:close()
			DataLink:modify(path)
		else
			VFS:add(path, content)
		end
	end
	
	return content ~= "" and Core.md5(content) or ""
end
