require "common.missile"

-- Create供公共代码调用，故写在Missile上
function Missile.Create(cfgName, params)
	local world = World.CurWorld
	local cfg = Missile.GetCfg(cfgName)
	local mm = ModelManager.Instance()
	local model = 0
	if cfg.modelMesh and cfg.modelMesh~="" then
		model = mm:createModelFromMesh(cfg.modelMesh)
	elseif cfg.modelBlock and cfg.modelBlock~="" then
		local id = Block.GetNameCfgId(cfg.modelBlock)
		model = mm:createModelFromBlock(id)
	elseif cfg.modelPicture and cfg.modelPicture~="" then
		local path = ResLoader:loadImage(cfg, cfg.modelPicture)
		model = mm:createModelFromPicture(path, {1, 1, 1, 1})
	end
	local missile = MissileClient.CreateMissile(model, cfg.id, world)
	missile:initCommon(params)
	return missile
end

function MissileClient:castEffect(effect)
	if not effect then
		return
	end
	if not effect.path then
		local cfg = self:cfg()
        effect.path = ResLoader:filePathJoint(cfg, effect.effect)
	end
	if not effect.isFixedPosition then
		self:playEffect1(effect.path, effect.once, effect.time or -1, effect.pos, effect.yaw or 0, effect.pitch or 0, effect.roll or 0, effect.scale or {x = 1, y = 1, z = 1})
	else
		Blockman.instance:playEffectByPos(effect.effect, self:getPosition(), 0, effect.time or 500, effect.scale or {x = 1, y = 1, z = 1})
	end
end

function MissileClient:onHitEntity()
    local cfg = self:cfg()
    local target = self:lastHitEntity()
    local pos = self:getPosition()
    local eyePos = target:getEyePos()
    local headHit = pos.y <= eyePos.y + 0.3 and pos.y >= eyePos.y - 0.3
    local headEffect = cfg.hitHeadEffect
    local hitEffect = cfg.hitEntityEffect or cfg.hitEffect
    local effect = headHit and headEffect or hitEffect
    self:castEffect(effect)
    self:playSound(cfg.hitEntitySound or cfg.hitSound, cfg, true)
    local from = World.CurWorld:getEntity(self.params.fromID)
    if from and from:isControl() then
        Lib.emitEvent(Event.EVENT_ON_HIT_ENTITY, {target = target, headHit = headHit})
    end
    Missile.onHitEntity(self)
end

function MissileClient:onHitPart()
	-- 击中零件的客户端表现
end