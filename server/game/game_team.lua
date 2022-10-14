local TeamList = T(Game, "TeamList")
local TeamCount = T(Game, "TeamCount", 0)
local allTeamInfos = T(Game, "allTeamInfos")
local NextTeamId = T(Game, "NextTeamId", 1)
local TeamBase = T(Game, "TeamBase")
TeamBase.__index = TeamBase

function Game.TryCreateTeam(player, additionalInfo)
    if player:getValue("teamId") ~= 0 then
        return false, "aready_join_team"
    end
    local team = Game.CreateTeam(nil, additionalInfo)
    local ret, msg = Game.TryJoinTeamByPlayer(player, team.id)
    if not ret then
        return ret, msg
    end
    return team.id
end

function Game.CreateTeam(id, additionalInfo)
	if id then
		assert(type(id) == "number" and id > 0, tostring(id))
		assert(not TeamList[id], tostring(id))
	else
		id = NextTeamId
	end
	if id >= NextTeamId then
		NextTeamId = id + 1
	end
	TeamCount = TeamCount + 1
    local time = World.Now()
	local team = {
		id = id,
		entityList = {},
		playerCount = 0,
		buffList = {},
		showText = nil,
		state = nil,
        additionalInfo = additionalInfo,
        createTime = time
	}
	local cfg = nil
	for _, tb in ipairs(World.cfg.team or {}) do
		if tb.id==id then
			cfg = tb
			break
		end
	end
	if cfg then
		for k, v in pairs(cfg) do
			if team[k]==nil then
				team[k] = v
			end
		end
	end
	team.vars = Vars.MakeVars("team", cfg)
	for k, v in pairs((cfg or {}).vars or {}) do	-- 临时兼容旧写法
		team.vars[k] = v
	end
	TeamList[id] = setmetatable(team, TeamBase)
	Game.UpdateTeamInfo(id)
	WorldServer.BroadcastPacket({
		pid = "CreateTeam",
		id = id,
        additionalInfo = additionalInfo,
        createTime = time,
		state = team.state or "TEAM_INIT",
	})
	return team
end

function Game.UpdateTeamAdditionalInfo(teamId, additionalInfo)
    local team = Game.GetTeam(teamId)
    if not team or not additionalInfo then
        return
    end
    local time = World.Now()
    team.additionalInfo = additionalInfo
    team.createTime = time
    Game.UpdateTeamInfo(teamId)
    WorldServer.BroadcastPacket({
		pid = "UpdateTeamAdditionalInfo",
		id = teamId,
        additionalInfo = additionalInfo,
        createTime = time
	})
end

function Game.GetTeamAdditionalInfo(teamId)
    local team = Game.GetTeam(teamId)
    return team and team.additionalInfo
end

function Game.TryJoinTeamBySystem(player)
	local worldCfg = World.cfg
    if not worldCfg.team or not worldCfg.automatch then
		local teamID = player:data("main").team
		if not teamID then
			return false
		end
		local team = Game.GetTeam(teamID, true)
		team:joinEntity(player)
		return true
	end
    local minTeam, memberLimit, teamInfo = nil, nil, nil
	for _, info in ipairs(worldCfg.team) do
        local team = Game.GetTeam(info.id, true)
        local limit = info.memberLimit
        if not limit then
            if not minTeam or team.playerCount < minTeam.playerCount then
                minTeam = team
                teamInfo = info
            end
        elseif limit > team.playerCount then
            if not minTeam or team.playerCount/limit < minTeam.playerCount/assert(memberLimit) then
                minTeam = team
                memberLimit = limit
                teamInfo = info
            end
        end
    end
    if not minTeam then
		return false
	end
    minTeam:joinEntity(player)
    if minTeam.initPos then
        player:setPos(minTeam.initPos)
    end
    if teamInfo.actorName then
		local actorName
        if not teamInfo.ignorePlayerSkin then
            local attrInfo = player:getPlayerAttrInfo()
			local temp_actor = player:data("main") == 2 and player:cfg().actorGirlName or player:cfg().actorName
			if not player:cfg().ignorePlayerSkin then 
				player:changeSkin(attrInfo.skin)
			end 
			if player:data("main").sex==2 then
				actorName = (temp_actor ~= nil and temp_actor ~= "" and temp_actor) or "girl.actor"
			else
				actorName = (temp_actor ~= nil and temp_actor ~= "" and temp_actor) or "boy.actor"
			end
            player:changeActor(actorName)
        else
            player:changeActor(teamInfo.actorName, true)
        end
    end
	return true
end

function Game.GetTeamLimit()
    if Game.teamLimit then
        return Game.teamLimit
    end
    local count = 0
    for i,v in pairs(World.cfg.team or {}) do
        count = count + (v.memberLimit or 0)
    end
    Game.teamLimit = count > 0 and count or math.huge
    return Game.teamLimit
end

function Game.TryJoinTeamByPlayer(player, teamId)
    local team = Game.GetTeam(teamId)
    if not team then
        return false, "team_not_exist"
    end
    local limit = World.cfg.teamMemberLimit
    if limit and team.playerCount >= limit then
        return false, "team_full"
    end
    local oldTeamId = player:getValue("teamId")
    local context = {obj1 = player, teamId = teamId, oldTeamId = oldTeamId, canJoin = true, errMsg = ""}
    Trigger.CheckTriggers(player:cfg(), "TRY_JOIN_TEAM", context)
    if not context.canJoin then
        return false, context.errMsg
    end
    local oldTeam = Game.GetTeam(oldTeamId)
    if oldTeam then
        oldTeam:leaveEntity(player)
    end
    team:joinEntity(player)
    return true
end

function Game.GetTeam(id, create)
    local team = TeamList[id]
	if not team and create then
		team = Game.CreateTeam(id)
	end
	return team
end

function Game.GetTeamPlayers(id)
    local team = TeamList[id]
	if not team then
		return
	end
	local playerList = {}
	for objID, entity in pairs(team.entityList) do
		if entity:isValid() and entity.isPlayer then
			playerList[objID] = entity
		end
	end
	return playerList
end

function Game.GetAllTeamsInfo()
	return allTeamInfos
end

function Game.UpdateTeamInfo(id)
	local team = TeamList[id]
	if not team then
		return
	end

    local playerList = {}
	for objId, entity in pairs(team.entityList) do
		if entity.isPlayer then
			playerList[objId] = true
		end
    end
	allTeamInfos[id] = {
        id = team.id,
		playerCount = team.playerCount,
		state = team.state or "TEAM_INIT",
        createTime = team.createTime,
        additionalInfo = team.additionalInfo,
        leaderId = team.leaderId,
        playerList = playerList,
		entityList = {}
	}
end

function Game.RemoveTeamInfo(id)
	allTeamInfos[id] = nil
end

function TeamBase:joinEntity(entity)
	local oldTeamId = entity:getValue("teamId")
    local time = World.Now()
	assert(oldTeamId==0, tostring(oldTeamId))
	entity:setValue("teamId", self.id)
    entity:setValue("joinTeamTime", time)
	if entity.isPlayer then
		Game.UpdatePlayerInfo(entity)
		for _, pet in pairs(entity:data("pet")) do
			pet:setValue("teamId", 0)	-- 强制客户端刷新血条颜色, 宠物teamId永远为0
		end
        self.leaderId = self.leaderId or entity.objID
		self.playerCount = self.playerCount + 1
	end
	local objID = entity.objID
	self.entityList[objID] = entity
	for id, buff in pairs(self.buffList) do
		buff.addList[objID] = entity:addBuff(buff.name)
	end
	if entity.isPlayer then
		WorldServer.BroadcastPacket({
			pid = "SetPlayerTeam",
			objId = entity.objID,
			teamId = self.id,
            joinTeamTime = time,
            leaderId = self.leaderId
		})
	end
    Trigger.CheckTriggers(entity:cfg(), "JOIN_TEAM", {obj1 = entity, teamId = self.id})
	entity:EmitEvent("OnJoinTeam", self.id)
    Game.UpdateTeamInfo(self.id)
end

function TeamBase:getFirstPlayer()
    local firstPlayer
    for _, entity in pairs(self.entityList) do
        if entity.isPlayer then
            firstPlayer = firstPlayer or entity
            local t1 = entity:getValue("joinTeamTime")
            local t2 = firstPlayer:getValue("joinTeamTime")
            firstPlayer = t1 < t2 and entity or firstPlayer
        end
    end
    return firstPlayer
end

function TeamBase:leaveEntity(entity)
	local oldTeamId = entity:getValue("teamId")
	assert(oldTeamId==self.id, tostring(oldTeamId))
	entity:setValue("teamId", 0)
    entity:setValue("joinTeamTime", 0)
    local objID = entity.objID
	self.entityList[objID] = nil
	if entity.isPlayer then
		Game.UpdatePlayerInfo(entity)
		for _, pet in pairs(entity:data("pet")) do
			pet:setValue("teamId", 0)	-- 强制客户端刷新血条颜色, 宠物teamId永远为0
		end
		self.playerCount = self.playerCount - 1
        if self.leaderId == entity.objID then
            local firstPlayer = self:getFirstPlayer()
            self.leaderId = firstPlayer and firstPlayer.objID or nil
        end
	end
	for id, buff in pairs(self.buffList) do
		local eb = buff.addList[objID]
		if eb then
			entity:removeBuff(eb)
			buff.addList[objID] = nil
		end
	end

	if entity.isPlayer then
		WorldServer.BroadcastPacket({
			pid = "SetPlayerTeam",
			objId = entity.objID,
			teamId = 0,
            oldTeamLeaderId = self.leaderId
		})
	end
    Trigger.CheckTriggers(entity:cfg(), "LEAVE_TEAM", {obj1 = entity, teamId = self.id})
	entity:EmitEvent("OnLeaveTeam", self.id)
    if self.playerCount == 0 and World.cfg.destroyTeamWhenEmpty then
        self:dismiss()
    end
    Game.UpdateTeamInfo(self.id)
end

function TeamBase:addBuff(name, time,from)
	local id = #self.buffList + 1
	local addList = {}
    local buff = {
        name = name,
        id = id,
		ownerTeam = self,
		addList = addList,
		from = from,
    }
    if time then
        buff.endTime = World.Now() + time
        buff.timer = World.Timer(time, TeamBase.removeBuff, self, buff)
    end
    self.buffList[id] = buff
    for _, entity in pairs(self.entityList) do
		addList[entity.objID] = entity:addBuff(name,time,from)
	end
    return buff
end

function TeamBase:removeBuff(buff)
    local id = assert(buff.id, "already removed?")
    if buff.timer then
        buff.timer()
        buff.timer = nil
    end
    self.buffList[id] = nil
    for _, eb in pairs(buff.addList) do
		eb.owner:removeBuff(eb)
	end
    buff.id = nil
end

function TeamBase:getTypeBuff(key, value)
	for id, buff in pairs(self.buffList) do
		local cfg = Entity.BuffCfg(buff.name)
		if cfg[key] == value then
			return buff
		end
	end
end

function TeamBase:removeTypeBuff(key, value)
	for id, buff in pairs(self.buffList) do
		local cfg = Entity.BuffCfg(buff.name)
		if cfg[key] == value then
			self:removeBuff(buff)
		end
	end
end

function TeamBase:dismiss()
    for _, entity in pairs(self.entityList) do
		self:leaveEntity(entity)
	end
	TeamList[self.id] = nil
	Game.RemoveTeamInfo(self.id)
	WorldServer.BroadcastPacket({
		pid = "DismissTeam",
		id = self.id,
	})
end

function TeamBase:getEntityList()
	return self.entityList
end

function TeamBase:broadcastPacket(packet)
	for _, entity in pairs(self.entityList) do
		if entity.isPlayer then
			entity:sendPacket(packet)
		end
    end
end
