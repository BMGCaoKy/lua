local ModuleBase = require "we.gamedata.module.class.module_base"
local Meta = require "we.gamedata.meta.meta"
local GameRequest = require "we.proto.request_game"

local Lang = require "we.gamedata.lang"
local M = Lib.derive(ModuleBase)

local MODULE_NAME = "bluefunc"
local ITEM_TYPE = "BluefuncCfg"

function M:init(name)
	assert(name == MODULE_NAME, 
		string.format("[ERROR] module name not match %s:%s", MODULE_NAME, name)
	)

	ModuleBase.init(self, MODULE_NAME, ITEM_TYPE)
end

function M:copy_item(id, newId)
	local item = self:item(id)
	assert(item)
	local rawval = item:val()  --item:obj()
	do
		 for _, lists in ipairs(rawval.triggers.list) do
			if #lists ==0 then
				lists = {lists}
			end
			for _, list in ipairs(lists) do
				if #list ==0 then
					list = {list}
				end
				for _, actions in ipairs(list) do 
					for _, action in ipairs(actions.actions) do
						for _, component in ipairs(action.components) do
							local ret = GameRequest.request_copy_blue_function_script(component.script_name)
							if ret.ok then
								component.script_name = ret.fileName
							end
						end
					end
				end
			end
		 end
		
		Meta:meta("Text"):set_processor(function(val)
			local key = Lang:copy_text(val.value)
			return { value = key }
		end)
		local meta = Meta:meta(self._item_type)
		rawval = meta:process(rawval)
		Meta:meta("Text"):set_processor(nil)
	end
	--Component item and region need copy folder
	self:copy_item_folder(id, newId)

	return self:new_item(newId, rawval)
end
return M
