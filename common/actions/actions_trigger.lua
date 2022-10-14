local BehaviorTree = require("common.behaviortree")
local setting = require "common.setting"
local Actions = BehaviorTree.Actions

function Actions.UnRegisterCustomsTrigger(node, params, context)
	local cfg = params.cfgForExecXXX
	local name = params.triggerNameForExecXXX
	if ActionsLib.isInvalidInstance(cfg,"cfg") then 
		return 
	end
	Trigger.RemoveTrigger(cfg,trigger_exec_type.CUSTOMS_SINGLE,name,nil)
end

--只触发单位、ui、零件等局部的自定义事件
function Actions.DoCustomTriggerCfg(node, params, context)
	local obj = params.cfgForExecXXX
	local name = params.triggerNameForExecXXX
	if ActionsLib.isInvalidInstance(obj,"cfg") then 
		return 
	end
	Trigger.doTriggerCfg(obj and obj._cfg or nil, name, params)
end

--只触发蓝图全局事件
function Actions.DoCustomTriggerCfgGlobal(nodex, params, context)
	local name = params.triggerNameForExecXXX
	Trigger.CheckTriggers(nil, name, params)
end

function Actions.GetCustomTriggerInstance(node, params, context)
	return context and context.cfgForExecXXX or nil
end

function Actions.GetCustomTriggerParams(node, params, context)
	local key = params.key 
	if not key or not context then 
		return nil
	end 
	if type(context) ~= "table" then 
		return nil
	end 
	return context[params.key]
end

