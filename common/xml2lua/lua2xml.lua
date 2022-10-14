
---Converts a Lua table to a XML String representation.
--@param data Table to be converted to XML
--@param root_name Name of the table variable given to this function,
--                 to be used as the root tag.
--@param indent_style 
--@param level Only used internally, when the function is called recursively to print indentation
--
--@return a String representing the table content in XML
local function toXml(data, root_name, indent_style, level)
	assert(type(root_name) == "string", root_name)
	indent_style = indent_style or "\t"
	level = level or 0
	local xmltb = {}
	table.insert(xmltb, string.rep(indent_style, level) .. "<" .. root_name)
	
	--attr
	if type(data) == "table" and data._attr then
		for k, v in pairs(data._attr) do
			v = type(v) == "number" and tostring(v) or v
			assert(type(v) == "string", k)
			table.insert(xmltb, string.format(' %s="%s"', k, v))
		end
	end

	local isTree = function(tb)
		for k in pairs(tb) do
			if type(k) == "string" and k ~= "_attr" then
				return true
			end
		end
	end

	if type(data) == "table" then
		--有attr的简单值
		if not isTree(data) then
			data = data[1]
			goto SinpleValue
		end
		--真正的table
		table.insert(xmltb, ">\n")
		for k, v in pairs(data) do
			if type(v) == "table" and #v > 0 then
				for _, v2 in ipairs(v) do
					table.insert(xmltb, toXml(v2, k, indent_style, level + 1))
					table.insert(xmltb, "\n")
				end
			elseif k ~= "_attr" then
				table.insert(xmltb, toXml(v, k, indent_style, level + 1))
				table.insert(xmltb, "\n")
			end
		end
		local indent = string.rep(indent_style, level)
		table.insert(xmltb, string.format("%s</%s>", indent, root_name))
		goto Concat
	end
	::SinpleValue::
	if type(data) == "string" then
		table.insert(xmltb, data)
	elseif type(data) == "number" then
		table.insert(xmltb, data)
	elseif type(data) == "nil" then
		table.insert(xmltb, "")
	elseif type(data) == "boolean" then
		table.insert(xmltb, data and "true" or "false")
	end
	table.insert(xmltb, "/>")
	::Concat::
	return table.concat(xmltb)
end

return toXml