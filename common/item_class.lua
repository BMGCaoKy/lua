local setting = require "common.setting"

local M = {}

function M:init(cfg)
	self._cfg = assert(cfg)
end

function M:cfg()
	return self._cfg
end

function M:id()
	return self._cfg.id
end

function M:full_name()
	return self._cfg.fullName
end

function M:block_name()
	local cfg = self._cfg
	if not cfg.isBlock then
		return nil
	end
	return setting:id2name("block", self._block_id)
end

function M:isShowCount()
	return not self._cfg.isHideCount
end

function M:can_combine()
	return not self._cfg.disable_combine
end

function M:tray_type()
	if not self._cfg._tray and self._cfg.imposeTray then
		self._cfg._tray = {}
		for _, type in ipairs(self._cfg.imposeTray or {}) do
			self._cfg._tray[type] = true
		end
	end
	if not self._cfg._tray then
		self._cfg._tray = {
			[Define.TRAY_TYPE.BAG] = true
		}
		
		for _, type in ipairs(self._cfg.tray or {}) do
			self._cfg._tray[type] = true
		end
	end

	return self._cfg._tray
end

function M:desc()
	return self._cfg.desc
end

function M:stack_count_max()
	return self._cfg.stack_count_max or 1
end

function M:can_use()
	return self._cfg.canUse
end

function M:can_charge()
	return self._cfg.canCharge
end

function M:icon_array()
	return self._cfg.iconArray
end

function M:consume_item()
	return self._cfg.consumeItem
end

function M:use_time()
	return self._cfg.useTime
end

function M:container()
	return self._cfg.container
end

function M:icon()
	if not self._cfg.icon_path then
		repeat
			if type(self._cfg.icon) ~= "string" then
				break
			end

			self._cfg.icon_path = ResLoader:loadImage(self._cfg, self._cfg.icon)
		until(true)
	end

	return self._cfg.icon_path
end

function M:createModelFromMesh(act, mesh)
	self._cfg._model[act] = ModelManager.Instance():createModelFromMesh(mesh)
	if self._cfg.matItem_first then
		self:setModelMatItem(self._cfg._model[act], self._cfg.matItem_first,1)
	end
	if self._cfg.matItem_third then
		self:setModelMatItem(self._cfg._model[act], self._cfg.matItem_third,3)
	end
end

function M:modelIcon()
	if not self._cfg.model_icon_path then
		repeat
			if type(self._cfg.icon) ~= "string" then
				break
			end

			self._cfg.model_icon_path = ResLoader:addTextureAtlas(self._cfg, self._cfg.icon)
		until(true)
	end
	return self._cfg.model_icon_path
end

function M:model(act, reload)
	act = act or "default"
	if not self._cfg._model or reload then
		self._cfg._model = {}
		if self._cfg.mesh and self._cfg.mesh ~= "" then
			if type(self._cfg.mesh) == "string" then
				self:createModelFromMesh("default", self._cfg.mesh)
			else
				assert(type(self._cfg.mesh) == "table")
				for act, mesh in pairs(self._cfg.mesh) do
					self:createModelFromMesh(act, mesh)
				end
			end
		else
			local icon = self:modelIcon()
			if icon and not self._cfg.isBlock then
				self._cfg._model["default"] = ModelManager.Instance():createModelFromPicture(self:modelIcon(), {1, 1, 1, 1})
				if self._cfg.matItem_first then
					self:setModelMatItem(self._cfg._model[act], self._cfg.matItem_first,1)
				end
				if self._cfg.matItem_third then
					self:setModelMatItem(self._cfg._model[act], self._cfg.matItem_third,3)
				end
			end
		end
	end
	if self._cfg.isSwings ~= nil then
		ModelManager.Instance():setSwing(self._cfg._model[act], self._cfg.isSwings)
	end
	return self._cfg._model[act]
end

function M:block_model(block_id)
	assert(block_id and block_id > 0, block_id)
	if not self._cfg._block_model then
		self._cfg._block_model = {}
	end
	if not self._cfg._block_model[block_id] then
		local cfg = Block.GetNameCfg(setting:id2name("block", block_id))
		local model
		if cfg.icon then
			model = ModelManager.Instance():createModelFromPicture(self:block_icon(block_id), {1, 1, 1, 1})
		else
			model = ModelManager.Instance():createModelFromBlock(block_id)
		end
		self._cfg._block_model[block_id] = model
		if cfg.matItem_first then
			self:setModelMatItem(model, cfg.matItem_first, 1)
		end
		if cfg.matItem_third then
			self:setModelMatItem(model, cfg.matItem_third, 3)
		end
	end

	return self._cfg._block_model[block_id]
end

function M:block_icon(block_id)
	assert(block_id and block_id > 0, block_id)
	if not self._cfg._block_icon then
		self._cfg._block_icon = {}
	end

	if not self._cfg._block_icon[block_id] then
		local cfg = Block.GetIdCfg(block_id)
		local icon_name
		if cfg.icon then
			icon_name = ResLoader:loadImage(cfg, cfg.icon)
		else
			icon_name = ObjectPicture.Instance():buildBlockPicture(block_id)
		end
		self._cfg._block_icon[block_id] = icon_name
	end

	return self._cfg._block_icon[block_id]
end

function M:is_block()
	return self._cfg.isBlock
end

function M:can_attack()
	return self._cfg.canAttack
end

function M:use_buff()
	return self._cfg.useBuff
end

function M:equip_buff()
	return self._cfg.equip_buff
end

function M:canUpgrade()
    return self._cfg.canUpgrade
end

function M:maxLevel()
    local upgradeList = self._cfg.upgradeList or {}
    return #upgradeList
end

function M:levelCfg(level)
    local upgradeList = self._cfg.upgradeList or {}
    return upgradeList[level]
end

function M:equip_levelBuff(level)
    local levelCfg = self:levelCfg(level) or {}
    return levelCfg.level_buff
end

function M:equip_skin()
	return self._cfg.equip_skin
end

function M:equip_levelSkin(level)
    local levelCfg = self:levelCfg(level) or {}
    return levelCfg.equip_skin
end

function M:equip_skill()
	return self._cfg.equip_skill
end

function M:equip_cond()
	return self._cfg.equip_cond
end

function M:need_save()
	local cfg = self._cfg
	if cfg.isBlock then
		cfg = Block.GetIdCfg(self._block_id)
	end
	return cfg.needSave
end

function M:save_vars()
	return self._cfg.saveVars
end

function M:sync_vars()
	return self._cfg.syncVars
end

function M:trap()
	return self._cfg.trap
end

function M:skill_list()
	local cfg = self._cfg
	local skillList = {}
	if cfg.isBlock then
		table.insert(skillList, "/place")
	end
	if cfg.canUse then
		table.insert(skillList, "/useitem")
	end

	if cfg.isSchematic then
		table.insert(skillList, "/build")
	end

	local skill = cfg.skill
	if skill and type(skill) == "table" then
		for _,s in pairs(skill) do
			table.insert(skillList, s)
		end
	elseif skill then
		table.insert(skillList, skill)
	end
	return skillList
end

function M:can_drop()
	local cfg = self._cfg
	if cfg.isBlock then
		cfg = Block.GetIdCfg(self._block_id)
	end
	return cfg.candrop
end

function M:die_remove()
	local cfg = self._cfg
	if cfg.isBlock then
		cfg = Block.GetIdCfg(self._block_id)
	end
	return cfg.dieRemove
end

function M:setModelMatItem(id , mat, view)
	local rotateX = mat.rotateX and math.rad(mat.rotateX) or 0
	local rotateY = mat.rotateY and math.rad(mat.rotateY) or 0
	local rotateZ = mat.rotateZ and math.rad(mat.rotateZ) or 0
	local scale = mat.scale or 1
	local translate = mat.translate or { x = 0, y = 0, z = 0 }
	if view == 1 then
		ModelManager.Instance():setModelMatItemFirst(id, scale, translate, rotateX, rotateY, rotateZ)
	elseif view == 3 then
		ModelManager.Instance():setModelMatItemThird(id, scale, translate, rotateX, rotateY, rotateZ)
	end
end

return M
