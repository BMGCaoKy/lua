local setting = require "common.setting"
local frontSightInstance = L("frontSightInstance", {})
local saveCurrenFrontSight = L("saveCurrenFrontSight",{})
local fInstance = T(FrontSight, "fInstance")
fInstance.__index = fInstance

function FrontSight.Create(skill, name)
    local frontSightCfg = setting:fetch("frontsight", name)
    local from = skill.fullName
    if not frontSightCfg or not from then
        return
    end
    local instance = {
        cfg = frontSightCfg,
        from = from,
        currenDiffuse = frontSightCfg.minDiffuse,
        setDiffuseTime = nil
    }
    if not frontSightInstance[from] then
        frontSightInstance[from] = instance
        setmetatable(instance, fInstance)
        FrontSight.Show()
    end
end

function FrontSight.Show()
    local showOn = {}
    for i,v in pairs(frontSightInstance)do
        showOn[#showOn +1] = {showLevel = v.cfg.showLevel,instance = v}
    end
    table.sort(showOn, function(a, b)
        return a.showLevel > b.showLevel
    end)
    if showOn[1] then
        showOn[1].instance:show()
    end
end

function fInstance:show()
    if not self.from then
        print("frontSight instance not from!!!")
        return false
    end
    Lib.emitEvent(Event.CREATE_FRONTSIGHT, self)
    saveCurrenFrontSight = self
end

function fInstance:setDiffuse(diffuse)
    if not self.cfg.maxDiffuse or diffuse > self.cfg.maxDiffuse or diffuse <= 0 then
        return
    end
    self.currenDiffuse = diffuse
    self.setDiffuseTime = World.Now()
end

function fInstance:getDiffuse()
    local cfg = self.cfg
    local shrinkVal = cfg.shrinkVal
    local minDiffuse = cfg.minDiffuse
    local maxDiffuse = cfg.maxDiffuse
    local currenTime = World.Now()
    if not self.setDiffuseTime then
        return cfg.minDiffuse
    end
    local time = (currenTime - self.setDiffuseTime)/20
    local currenDiffuse = math.floor(shrinkVal * time)
    if currenDiffuse >= minDiffuse and currenDiffuse <= maxDiffuse then
        return currenDiffuse
    else
        return minDiffuse
    end
end

function FrontSight.Destroy(skill)
    local from = skill.fullName
    if frontSightInstance[from] then
        Lib.emitEvent(Event.DESTROY_FRONTSIGHT)
        frontSightInstance[from] = nil
        FrontSight.Show()
    end
end

function FrontSight.Diffuse(diffuseVal,type)
    if next(frontSightInstance)==nil then
        return
    end
    if type==1 then
        for i,v in pairs(frontSightInstance)do
            v:setDiffuse(diffuseVal)
        end
        saveCurrenFrontSight:setDiffuse(diffuseVal)
    end
    if type==2 then
        for i,v in pairs(frontSightInstance)do
            v:setDiffuse(v.cfg.moveDiffuse)
        end
        saveCurrenFrontSight:setDiffuse(saveCurrenFrontSight.cfg.moveDiffuse)
    end
    Lib.emitEvent(Event.DIFFUSE_FRONTSIGHT, diffuseVal)
end

function FrontSight.randomPointByRrange()
    local currenDiffuse = saveCurrenFrontSight:getDiffuse()
    local rand_x = math.random(-currenDiffuse,currenDiffuse)
    local rand_y = math.random(-currenDiffuse,currenDiffuse)
    local distance = math.sqrt((-rand_x)*(-rand_x) + (-rand_y)*(-rand_y))
    if distance <= currenDiffuse then
        local scrreenpPos = {}
        scrreenpPos.x = rand_x
        scrreenpPos.y = rand_y
        return scrreenpPos
    else
        return FrontSight.randomPointByRrange()
    end
end

function FrontSight.checkHit(player)
	if next(frontSightInstance)==nil then
        return
    end
	local friend = false
	local hitType = nil
    local canAttackTarget = false
	local screenPos = {x=0, y=0}
	local ri = Root.Instance()
	local offsetY = 0

	if World.cfg.cameraCfg then
		local cameraCfg = World.cfg.cameraCfg
		for i,v in pairs(cameraCfg.viewModeConfig)do
			if v.offset then
				offsetY = v.offset.y
				break
			end
		end
	end
    screenPos.x = screenPos.x + ri:getRealWidth() / 2
    screenPos.y = (screenPos.y + ri:getRealHeight() / 2) + (offsetY * 50)

    local skillName = saveCurrenFrontSight.from
    local cfg = setting:fetch("skill", skillName)
	local hit = Blockman.instance:getRayTraceResult(screenPos, cfg.rayLenth, false, false, false, {})
	if hit then
		hitType = hit.type
	end
	if hitType=="ENTITY" then
		local entity = player.world:getEntity(hit.objID)
		if player:getValue("teamId") == entity:getValue("teamId") and player:getValue("teamId") ~= 0 then
			friend = true
		end
        canAttackTarget = Me:canAttack(entity)
        if cfg.autoCastWhenAimTarget and canAttackTarget then
            Skill.Cast(skillName)
        end
	end
	local hitObj = {
		_type = hitType or "MISS",
		friend = friend,
        canAttackTarget = canAttackTarget
	}
	Lib.emitEvent(Event.CHECK_HIT, hitObj)
end
