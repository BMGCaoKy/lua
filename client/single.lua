local config = Lib.read_json_file("gameconfig.json")
if config then
	local serverIp = config.serverIp
	if serverIp and serverIp ~= "localhost" and serverIp ~= "127.0.0.1" then
		print("server on remote, disable single game!")
		Blockman.instance.singleGame = false
		return
	end
end

local filename = "server.lock"
os.remove(filename)
local f = io.open(filename, "r")
if f then	-- 文件存在
	f:close()
	print("server is running, disable single game!")
	Blockman.instance.singleGame = false
	return
end

-- on osx, check if the server process is running
if os.execute("pgrep GameServer") then
  print("find server process, disable single game!")
  Blockman.instance.singleGame = false
end

local misc = require "misc"
local dataState = {}

function start_single()
    local worldCfg = World.cfg
	local playerCfgTmp =  World.CurWorld.isEditor and worldCfg.editorPlayerCfg or worldCfg.playerCfg or "myplugin/player1"
    local playerCfg = Entity.GetCfg(playerCfgTmp)
	local packet = {
		pid = "GameInfo",
		cfgName = playerCfg.fullName,
		objID = 1,
		map = {
			id = 1,
			name = worldCfg.initPos.map or worldCfg.defaultMap or "map001",
			static = true
		},
		pos = worldCfg.initPos,
		isTimeStopped = false,
		worldTime = 1,
		maxPlayer = 8,
		skin = {},
	}
	dataState = require "editor.dataState"

	dataState.now_map_name = worldCfg.initPos.map or worldCfg.defaultMap or "map001"
	if World.CurWorld.isEditor then
		World.CurWorld.isHideActor = true
		local testMap = worldCfg.testMap
		local editMapName = testMap or Stage.GetFirstStageCfg("myplugin/main", true).map or "map001"
		dataState.now_map_name = editMapName
		packet.map.name = editMapName
		packet.map.id = World.CurWorld:getOrCreateStaticMap(editMapName).id
		packet.actorName = "editor_boy.actor"
	end

	handle_packet(misc.data_encode(packet))

	packet = {
		pid = "tray_load",
		data = {},
	}
	handle_packet(misc.data_encode(packet))
	packet = {
		pid = "SkillMap",
		map = {},
	}
	handle_packet(misc.data_encode(packet))

	if World.CurWorld.isEditor then
		--Player.CurPlayer:addSkill("myplugin/map_frontsight")
		EditorModule:emitEvent("enterGame")
	end

	Lib.emitEvent(Event.EVENT_SINGLE_START_FINISH)
    local gmBaseUI = GUIManager:Instance():isEnabled() and UI:getWnd("actionControl") or UI:getWnd("main")
    if gmBaseUI then
        gmBaseUI:showGM(World.gameCfg.gm or false)
    end
end

function Player:addSkill(name)
	local packet = {
		pid = "SkillMap",
		map = {},
	}
	if name then
		packet.map[name] = {objID = 1}
	end
    for _, name in ipairs(self:cfg().skills or self:cfg().skillInfos or {}) do
        packet.map[name] = {objID = 1}
    end
    for _, cfg in ipairs(self:cfg().skillList or self:cfg().skillInfoList or {}) do
        packet.map[cfg.fullName] = {objID = 1}
    end
	handle_packet(misc.data_encode(packet))
end

function Player:doGM(typ, param)
	print("GM:", typ, param)
	if typ=="move" then
		self:setPos(param)
	end
end

function EntityClient:addBuff(name, time)
    local id = #self:data("buff") + 1
	local buff = self:addClientBuff(name, id)
    if time then
        buff.timer = self:timer(time, EntityClient.removeBuff, self, buff)
    end
	return buff
end

function EntityClient:removeBuff(buff)
	if buff.timer then
		buff.timer()
		buff.timer = nil
	end
	if buff.id then
		self:removeClientBuff(buff)
	end
end
