local BehaviorTree = require("common.behaviortree")
local triggerParser = require "common.trigger_parser"

local Triggers = {}		-- 全部Trigger集合

local TriggerCheck = {}	-- 不同类型的Trigger检查函数

local CTypeID	= {}	-- C++ TriggerType name => id

local TriggerFuncs = {} -- 蓝图函数集合

trigger_exec_type.NORMAL = 1				--普通蓝图
trigger_exec_type.NORMAL_CLIENT = 2				--普通蓝图
trigger_exec_type.FUNCS = 3				--蓝图函数
trigger_exec_type.REGISTER_FUNCTION_SINGLE = 4 --注册触发器
trigger_exec_type.REGISTER_FUNCTION_MULTY = 5	--注册触发事件函数(调用链)

local TRIGGER_EXEC_TYPE = 
{
	SERVER = 1,			--服务端蓝图	
	CLIENT = 2,			--客户端蓝图
	CALL = 3,			--蓝图函数
}

local TriggerExecConfig = 
{
	--[[
		ignoreDoTrigger 调用dotrigger的时候是否执行
		isSingle 是否不支持复数同名
		isReload reload时是否清空
	]]
	[trigger_exec_type.NORMAL] = {execType = TRIGGER_EXEC_TYPE.SERVER,isSingle = true, ignoreDoTrigger = true,isReload = true},
	[trigger_exec_type.NORMAL_CLIENT] = {execType = TRIGGER_EXEC_TYPE.CLIENT, isSingle = true, ignoreDoTrigger = true, isReload = true},
	[trigger_exec_type.FUNCS] = {execType = TRIGGER_EXEC_TYPE.CALL,isSingle = true, ignoreDoTrigger = true, isReload = true},
	--[trigger_exec_type.CUSTOMS_SINGLE] = {execType = TRIGGER_EXEC_TYPE.SERVER,isSingle = true, ignoreDoTrigger = true,isReload = true},
	[trigger_exec_type.REGISTER_FUNCTION_SINGLE] = {execType = TRIGGER_EXEC_TYPE.SERVER,isSingle = true, ignoreDoTrigger = true},
	[trigger_exec_type.REGISTER_FUNCTION_MULTY] = {execType = TRIGGER_EXEC_TYPE.SERVER,isSingle = false, ignoreDoTrigger = true},
}

local TriggerList = {count = {} , forRemove = {}}
local triggerExecIndex 
for	_,triggerExecIndex in pairs(trigger_exec_type) do TriggerList[triggerExecIndex] = {} end


-- 热更新时释放旧Trigger
function Trigger.ReleaseTriggers(cfg)
	if not cfg or not cfg.triggerSet then
		return
	end
	cfg._btsTime = nil
	for triggerExecType,t1 in pairs(cfg.triggerSet) do
		if TriggerExecConfig[triggerExecType].isReload then 
			for triggerType, t2 in pairs(t1) do
				for id, _ in pairs(tl) do
					Trigger.RemoveTrigger(cfg,triggerExecType,triggerType,id)
				end
			end
		end
	end
	TriggerList.forRemove = {}
end

function Trigger.CheckIsLoadTrigger(cfg)
	if IS_EDITOR then --编辑器不读取蓝图
		return false 
	end
	return true
end

local function fileTime(path)
	return lfs.attributes(Root.Instance():getGamePath() .. path, "modification") or 0
end

local function relativePath(cfg, file)
	local head = file:sub(1,1)
	if head=="/" then
		return "plugin/" .. cfg.plugin .. file
	elseif head=="@" then
		return file:sub(2)
	else
		return cfg.dir .. file
    end
end

local function ReadSubDir(path , templateStr,subPathList)
	local fileName
	local fullpPath = Root.Instance():getGamePath()..path
	for fileName in lfs.dir(fullpPath) do
		if fileName ~= "." and fileName ~= ".." then
			if string.find(fileName , templateStr) then
				subPathList = subPathList or {}
				table.insert(subPathList ,  path.."/"..fileName)
			else 
				local filePath = path.."/"..fileName
				local fullFilePath = fullpPath.."/"..fileName
				local fileAttr = lfs.attributes(fullFilePath)
				if fileAttr.mode == "directory" then 
					ReadSubDir(filePath,templateStr,subPathList)
				end
			end
		end 
	end
end 

function Trigger.LoadTriggersCommon(cfg,pathList,isDir,triggerExecType)
	if not cfg or not pathList then return end
	if not Trigger.CheckIsLoadTrigger(cfg) then return false end
	cfg.triggerSet = cfg.triggerSet or {}
	if type(pathList) == "table" then 
		cfg._btsTime = cfg._btsTime or {}
		local subPathList = {}
		if isDir then 
			for k,v in pairs(pathList) do 
				ReadSubDir(v,[[bts]],subPathList)
			end 
		else 
			subPathList = pathList
		end
		for _, fileName in ipairs(subPathList) do
			local path = relativePath(cfg, fileName)
			local time = fileTime(path)
			cfg._btsTime[path] = time or false
			if time then
				local triggers, msg = triggerParser.parse(Root.Instance():getGamePath() .. path)
				if not triggers then
					--error(string.format("triggerParser parse file: '%s' error: %s", path, msg))
				else
					cfg.triggers = triggers
					for i,trigger in pairs(triggers) do 
						if TriggerExecConfig[triggerExecType].execType == TRIGGER_EXEC_TYPE.CALL then
							Trigger.addTrigger(nil,triggerExecType,trigger.type,trigger)
						else 
							if triggerExecType == trigger_exec_type.NORMAL then
								trigger.cType = CTypeID[trigger.type]
							end
							BehaviorTree.InitNodes(trigger.actions, string.format("%s - [%d]%s", cfg.displayName, i, trigger.type))
							Trigger.addTrigger(cfg,triggerExecType,trigger.type,trigger)
						end
					end
				end
			end
		end
	end

	if	not cfg.triggerSet or not next(cfg.triggerSet) or 
		cfg.worldIndex then 
			return
	end

	if not World.cfgSet then
		World.cfgSet = {}
	end
	World.cfgSet[cfg] = cfg
	cfg.worldIndex = true
end


function Trigger.LoadTriggers(cfg)			-- 兼容旧的bts继承方式
	if not Trigger.CheckIsLoadTrigger(cfg) then 
		return 
	end

	if not cfg.triggers then
		return
	end

	

	local triggerSet = {}
	for i, trigger in pairs(cfg.triggers) do
		trigger.cType = CTypeID[trigger.type]
		BehaviorTree.InitNodes(trigger.actions, string.format("%s - [%d]%s", cfg.displayName, i, trigger.type))
		trigger.id = Trigger.addTrigger(cfg,trigger_exec_type.NORMAL,trigger.type,trigger)
	end
	if	not cfg.triggerSet or 
		not next(cfg.triggerSet) or  
		cfg.worldIndex then 
			return
	end

	if cfg.worldIndex then
		World.cfgSet[cfg] = nil
	end

	if not World.cfgSet then
		World.cfgSet = {}
	end
	World.cfgSet[cfg] = cfg
	cfg.worldIndex = true
end

local function v2s(v)
	local t = type(v)
	if t=="table" and not v.__name and v.x and v.y and v.z then
		Lib.tov3(v)
		return tostring(v)
	elseif t=="string" then
		return '"'..v..'"'
	else
		return tostring(v)
	end
end

local function doTrigger(triggerExecType, triggerType, id, context)
	local trigger = Trigger.GetExecTrigger(nil,triggerExecType,triggerType,id)
	if not trigger then 
		return 
	end
	context = context or {}
	if not context.map and context.obj1 then
		context.map = context.obj1.map
	end

	if type(trigger) == "function" then 
		local ok, ret = pcall(trigger, context)
		if not ok then
			perror(ret)
		end
		return ok
	else 
		Profiler:begin("Trigger:"..trigger.type)
		local func = TriggerCheck[trigger.type]
		if func and not func(trigger, context) then
			return
		end
		local debug = trigger.debug
		if debug == nil then
			debug = World.gameCfg.debugTrigger or false
		end
		if debug then
			local txt = {}
			for k, v in pairs(context) do
				txt[#txt+1] = string.format("@%s:%s", k, v2s(v))
			end
			print("Trigger:", trigger.type.." ( "..table.concat(txt,", ").." )")
		end
		context.debug = debug
		local ok = BehaviorTree.Run(trigger.actions, context)
		Profiler:finish("Trigger:"..trigger.type)
		return ok
	end
end

function Trigger.doTrigger(triggerSet, name, context,triggerExecType)
	triggerExecType = triggerExecType or trigger_exec_type.NORMAL
	if not triggerSet or not triggerSet[triggerExecType] then
		return
	end
	local ids = triggerSet[triggerExecType][name]
	if not ids then
		return
	end
	local ok = false
	for id, _ in pairs(ids) do
		ok = doTrigger(triggerExecType,name,id, context) and ok
	end
end

function Trigger.doTriggerCfg(cfg, name, context, ignoreCheckTrigger,setTriggerExecType)
	if not cfg or not cfg.triggerSet then
		return false
	end
	local ok = false
	for triggerExecType,execList in pairs(cfg.triggerSet) do 
		if not setTriggerExecType or (setTriggerExecType == triggerExecType) then 
			if execList[name] and (not ignoreCheckTrigger and TriggerExecConfig[triggerExecType].ignoreDoTrigger or ignoreCheckTrigger)  then 
				ok = Trigger.doTrigger(cfg.triggerSet, name, context,triggerExecType) and ok
			end 
		end
	end
	return ok
end

function Trigger.RegisterHandler(cfg, name, handler)
	assert(cfg, "need module config")
	Trigger.addTrigger(cfg,trigger_exec_type.REGISTER_FUNCTION_SINGLE,name, handler, true)
end

local NextTriggerIndexMap = T(Trigger, "NextTriggerIndexMap")
function Trigger.addHandler(cfg, name, handler)
	assert(cfg, "need module config")
	local idx = Trigger.addTrigger(cfg,trigger_exec_type.REGISTER_FUNCTION_MULTY,name, handler)
	
	return function ()
		Trigger.RemoveTrigger(cfg,trigger_exec_type.REGISTER_FUNCTION_MULTY,name,idx)
	end
end

local Handlers = T(Trigger, "Handlers")
local function handleTrigger(name, context)
	Plugins.CallPluginFunc(name, context)
	local handler = Handlers[name]
	if not handler then
		return
	end
	local ok, msg = xpcall(handler, traceback, context)
	if not ok then
		perror("handle trigger error", name, msg)
		Lib.sendErrMsgToChat(context.obj1, msg)
	end
end

function Trigger.CheckTriggers(cfg, name, context)
	if  IS_EDITOR then
		return
	end
	if cfg then
		context.dir = cfg.dir
	end
	handleTrigger(name, context)
	if not Trigger.doTriggerCfg(cfg, name, context) then
		Trigger.doTriggerCfg(World.cfg, name, context)
	end
end

function Trigger.CheckTriggersOnly(cfg, name, context)
	handleTrigger(name, context)
	Trigger.doTriggerCfg(cfg, name, context)
end

function Trigger.ExeFuncs(name,context)
	if not name then 
		return 
	end
	local func = Trigger.GetExecTrigger(nil,trigger_exec_type.FUNCS,name)--TriggerFuncs[name] 
	if not func then return end 

	local ok,returnRet = BehaviorTree.Run(func.actions, context)
	return ok and returnRet or nil
end

function Trigger.GetExecTrigger(cfg, triggerExecType , triggerType, idx)
	local execCfg = TriggerExecConfig[triggerExecType]

	if not cfg  then
		if not idx then 
			return TriggerList[triggerExecType][triggerType]
		end 
		return TriggerList[triggerExecType][idx]
	end

	if cfg.triggerSet and cfg.triggerSet[triggerExecType] and cfg.triggerSet[triggerExecType][triggerType] and cfg.triggerSet[triggerExecType][triggerType][idx] then 
		if TriggerList[triggerExecType][cfg.triggerSet[triggerExecType][triggerType][idx]] then 
			return TriggerList[triggerExecType][cfg.triggerSet[triggerExecType][triggerType][idx]]
		end
	end
	
	return nil
end

function Trigger.RemoveTrigger(cfg,triggerExecType,triggerType,id)
	if not triggerExecType or not triggerType or not id then 
		return 
	end
	if id then 
		if TriggerList[triggerExecType] and TriggerList[triggerExecType][id] then 
			TriggerList[triggerExecType][id] = nil
			TriggerList.forRemove[id] = id
		end 
		if cfg and cfg.triggerSet and cfg.triggerSet[triggerExecType] and cfg.triggerSet[triggerExecType][triggerType] then
			cfg.triggerSet[triggerExecType][triggerType][id] = nil		
		end
	else 
		if cfg and cfg.triggerSet and cfg.triggerSet[triggerExecType] and cfg.triggerSet[triggerExecType][triggerType] then 
			local tempID
			for tempID , _ in pairs(cfg.triggerSet[triggerExecType][triggerType]) do 
				if TriggerList[triggerExecType] and TriggerList[triggerExecType][tempID] then 
					TriggerList[triggerExecType][tempID] = nil
				end 
				cfg.triggerSet[triggerExecType][triggerType][tempID] = nil
			end
		end 
	end
end

function Trigger.addTrigger(cfg, triggerExecType,triggerType, trigger)
	if not triggerExecType or not triggerType then 
		return 
	end

	TriggerList[triggerExecType] = TriggerList[triggerExecType] or {}
	TriggerList.count[triggerExecType] = TriggerList.count[triggerExecType] or 0
	local isSingle = TriggerExecConfig[triggerExecType].isSingle

	if not cfg then 
		TriggerList[triggerExecType][triggerType] = trigger
		return 
	end

	local idx
	if isSingle and  cfg.triggerSet and cfg.triggerSet[triggerExecType] and cfg.triggerSet[triggerExecType][triggerType] and next(cfg.triggerSet[triggerExecType][triggerType]) then 
		idx  = next(cfg.triggerSet[triggerExecType][triggerType])
		TriggerList[triggerExecType][idx] = trigger
		return idx
	else  
		local isAdd = false
		for _,removeId in pairs(TriggerList.forRemove) do
			isAdd = true
			TriggerList[triggerExecType][removeId] = trigger
			TriggerList.forRemove[removeId] = nil
			idx = removeId
			break
		end
		if not isAdd then
			TriggerList[triggerExecType][TriggerList.count[triggerExecType] + 1] = trigger
			TriggerList.count[triggerExecType]= TriggerList.count[triggerExecType] + 1
			idx = TriggerList.count[triggerExecType]
		end
	end
	Trigger.AddToTrigger(cfg, triggerExecType, triggerType, idx)
	return idx
end

function Trigger.AddToTrigger(cfg, triggerExecType, triggerType, idx)
	cfg.triggerSet = cfg.triggerSet or {}
	cfg.triggerSet[triggerExecType] = cfg.triggerSet[triggerExecType] or {}
	cfg.triggerSet[triggerExecType][triggerType] = cfg.triggerSet[triggerExecType][triggerType]  or {}

	cfg.triggerSet[triggerExecType][triggerType][idx] = true
end

function handle_trigger(id, obj1, obj2, param, pos)
	local context = {
		obj1 = obj1,
		obj2 = obj2,
		pos = pos,
		param = param,
	}
	doTrigger(trigger_exec_type.NORMAL,nil,id, context)
end


local function init()
	for id, name in pairs(Trigger.GetTypes()) do
		CTypeID[name] = id
	end
end

init()

-- Trigger条件检查

function TriggerCheck:BLOCK_BREAK_BY(context)
	return context.item:template():id() == self.params.item
end
