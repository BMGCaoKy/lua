local M = require "common.item_class"
local setting = require "common.setting"

function M:block_model(block_id)
    assert(block_id and block_id > 0, block_id)
    if not self._cfg._block_model then
        self._cfg._block_model = {}
    end
    local tb = {scale = 1, rotateY = 0, rotateX = 0, rotateZ = 0, translate = {x = 0, y = 0, z = 0}}
    if not self._cfg._block_model[block_id] then
        local cfg = Block.GetNameCfg(setting:id2name("block", block_id))
		local model
		local icon = cfg.icon1 or cfg.icon
		if icon then
			local icon_name = ResLoader:loadImage(cfg, icon)
			model = ModelManager.Instance():createModelFromPicture(icon_name, {1, 1, 1, 1})
		else
			model = ModelManager.Instance():createModelFromBlock(block_id)
        end
        self._cfg._block_model[block_id] = model
        if cfg.quads and not icon then
			self:setModelMatItem(model, tb, 1)
		else
			if cfg.matItem_first then
				self:setModelMatItem(model, cfg.matItem_first, 1)
			end
        end
    end
    return self._cfg._block_model[block_id]
end

local models = {}
function ResLoader:loadModel(cfg, model)
	local modId
	if type(model)=="table" then
		modId = model.mesh and models[model.mesh] or (model.icon and models[model.icon])
	else
		modId = models[model]
	end
	if modId then
		return modId
	end
	local m_cfg = type(model) == "table" and model
	local mesh = m_cfg and m_cfg.mesh or model
	local icon = m_cfg and m_cfg.icon or model

	if mesh then
        modId = ModelManager.Instance():createModelFromMesh(mesh)
		ModelManager.Instance():setBrightnessScale(modId, 2.0)
		models[mesh] = modId
	else
		modId = ModelManager.Instance():createModelFromPicture(icon, {1, 1, 1, 1})
		models[icon] = modId
	end

	local mat_f = m_cfg and m_cfg.matItem_first or cfg.matItem_first
	local mat_t = m_cfg and m_cfg.matItem_third or cfg.matItem_third
	local isSwings = m_cfg and m_cfg.isSwings or cfg.isSwings
	if mat_f then
		ResLoader:setModelMatItem(modId, mat_f,1 )
	end
	if mat_t then
		ResLoader:setModelMatItem(modId, mat_t,3)
	end
	if isSwings ~= nil then
		ModelManager.Instance():setSwing(modId, isSwings)
	end
	return modId
end
