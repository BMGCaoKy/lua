--执行用户自定义脚本
function ExecUserScript.chunk(playerCfg,player,scripts_dir)
	if World.cfg.disableExecUserScript or ExecUserScript.IS_EDITOR   then
		return
	end
  	repeat
		local scripts = playerCfg[scripts_dir]
		if not scripts then
			break
		end
		assert(type(scripts) == "table")

		for _, script in ipairs(scripts) do
			local  path_game = Root.Instance():getGamePath()
			script = script:gsub([[/]],[[.]])
			local path, chunk = loadLua(script, Lib.combinePath(path_game..playerCfg.dir, "?.lua"))
			if path then
				local ret, errmsg = load(chunk, "@"..path, "bt", setmetatable({this = player}, {__index = _G}))
				assert(ret, errmsg)()
			else
				print(string.format("miss script %s:%s", playerCfg.dir, script))
			end
		end
  until(true)

end