local EmptyCfg = {}

local function _setError(tb, key)
	error("don't set config: " .. key)
end

function Vars.MakeVars(typ, cfg)
	cfg = cfg or EmptyCfg[typ]
	if not cfg then
		cfg = {}
		EmptyCfg[typ] = cfg
	end
	cfg._varCfg = cfg._varCfg or {}
	local varCfg = cfg._varCfg[typ]
	if not varCfg then
		local varsDef = World.cfg.vars
		local worldCfgVars = (varsDef and varsDef[typ]) or {} 
		varsDef = {}
		if World.isClient then
			for k, v in ipairs(worldCfgVars) do
				if v.run_type == "client" then
					table.insert(varsDef, v)
				end
			end
		else
			for k, v in ipairs(worldCfgVars) do
				if v.run_type ~= "client" then
					table.insert(varsDef, v)
				end
			end
		end
		varCfg = {
			_typ = typ,
			_defs = varsDef,
			vars = setmetatable({}, {__index=cfg, __newindex=_setError}),
		}
		cfg._varCfg[typ] = varCfg
	end
	local vars = {cfg=varCfg}
	for _, def in ipairs(varCfg._defs) do
		vars[def.key] = Lib.copy(def.value)
	end
	return vars
end

function Vars.SaveVars(vars)
	local data = {}
	for _, def in ipairs(vars.cfg._defs) do
		if def.save then
			local value = vars[def.key]
			if value~=def.value then
				data[def.key] = value
			end
		end
	end
	return data
end

function Vars.LoadVars(vars, data)
	for _, def in ipairs(vars.cfg._defs) do
		local value = data[def.key]
		if value~=nil then
			vars[def.key] = value
		end
	end
end

RETURN()
