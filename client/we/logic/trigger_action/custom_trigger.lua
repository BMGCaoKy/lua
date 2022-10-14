local Module = require "we.gamedata.module.module"

local M = {}

local custom_list = {}

function M:init(m,i)
	self.con_list = {}
	local module = Module:module(m)
	assert(module,m)
	self.item = module:item(i)
	assert(self.item,i)
	local triggers = self.item:val()["triggers"]
	if triggers then
		for _,v in pairs(triggers.list) do
			if v.custom then
				table.insert(custom_list,v.type)
			else
				table.insert(self.con_list,v.type)
			end
		end
	end
end

function M:custom_list()
	return custom_list
end

function M:constant_list()
	return self.con_list
end

function M:name(index)
	local def = "optionIsSelected"
	for _,v in pairs(custom_list) do
		while true do
			if def..tostring(index) == v then
				index = index + 1
				return M:name(index)
			end
			break
		end
	end
	table.insert(custom_list,index)
	return def..index
end

function M:insert()
	local trigger_name = self:name(1)
	local rawval = {
		custom = true,
		type = trigger_name
	}
	self.item:data():insert("triggers/list", nil, nil, rawval)
	return trigger_name
end

function M:params(type)
	local ret = {}
	table.insert(ret, {value = "T_Int", attrs = {Type = "T_Int"}})
	table.insert(ret, {value = "T_IntArray", attrs = {Type = "T_IntArray"}})
	table.insert(ret, {value = "T_Double", attrs = {Type = "T_Double"}})
	table.insert(ret, {value = "T_DoubleArray", attrs = {Type = "T_DoubleArray"}})
	table.insert(ret, {value = "T_Bool", attrs = {Type = "T_Bool"}})
	table.insert(ret, {value = "T_BoolArray", attrs = {Type = "T_BoolArray"}})
	table.insert(ret, {value = "T_String", attrs = {Type = "T_Bool"}})
	table.insert(ret, {value = "T_StringArray", attrs = {Type = "T_StringArray"}})
	table.insert(ret, {value = "T_Color", attrs = {Type = "T_Color"}})
	table.insert(ret, {value = "T_Var", attrs = {Type = "T_Var"}})
	if type == "Trigger_Custom" then
		table.insert(ret, {value = "T_Entity", attrs = {Type = "T_Entity"}})
		table.insert(ret, {value = "T_EntityArray", attrs = {Type = "T_EntityArray"}})
		table.insert(ret, {value = "T_Vector3", attrs = {Type = "T_Vector3"}})
		table.insert(ret, {value = "T_Vector3Array", attrs = {Type = "T_Vector3Array"}})
		table.insert(ret, {value = "T_ScenePos", attrs = {Type = "T_ScenePos"}})
		table.insert(ret, {value = "T_ScenePosArray", attrs = {Type = "T_ScenePosArray"}})
		table.insert(ret, {value = "T_Part", attrs = {Type = "T_Part"}})
		table.insert(ret, {value = "T_MeshPart", attrs = {Type = "T_MeshPart"}})
		table.insert(ret, {value = "T_PartOperation", attrs = {Type = "T_PartOperation"}})
		table.insert(ret, {value = "T_Map", attrs = {Type = "T_Map"}})
		table.insert(ret, {value = "T_MapStr", attrs = {Type = "T_MapStr"}})
		table.insert(ret, {value = "T_BinaryOperCompute", attrs = {Type = "T_BinaryOperCompute"}})
		table.insert(ret, {value = "T_Condition", attrs = {Type = "T_Condition"}})
		table.insert(ret, {value = "T_SkillEntry", attrs = {Type = "T_SkillEntry"}})
		table.insert(ret, {value = "T_ItemEntry", attrs = {Type = "T_ItemEntry"}})
		table.insert(ret, {value = "T_BuffEntry", attrs = {Type = "T_BuffEntry"}})
	elseif type == "Trigger_Custom_Client" then
		table.insert(ret, {value = "T_UDim2", attrs = {Type = "T_UDim2"}})
		table.insert(ret, {value = "T_UDim2Array", attrs = {Type = "T_UDim2Array"}})
		table.insert(ret, {value = "T_Widget", attrs = {Type = "T_Widget"}})
		table.insert(ret, {value = "T_WidgetArray", attrs = {Type = "T_WidgetArray"}})
		table.insert(ret, {value = "T_Layout", attrs = {Type = "T_Layout"}})
		table.insert(ret, {value = "T_LayoutArray", attrs = {Type = "T_LayoutArray"}})
	end

	return ret
end
return M