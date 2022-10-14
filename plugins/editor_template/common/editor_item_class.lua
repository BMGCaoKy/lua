local M = require "common.item_class"

function M:block_cfg()
    if self.isBlock then
        return Block.GetIdCfg(self._block_id)
    end
    return self._cfg
end

function M:model(act)
	act = act or "default"
	if not self._cfg._model then
		self._cfg._model = {}
		if self._cfg.mesh then
			if type(self._cfg.mesh) == "string" then
				self._cfg._model["default"] = ModelManager.Instance():createModelFromMesh(self._cfg.mesh)
				if self._cfg.matItem_first then
					self:setModelMatItem(self._cfg._model[act], self._cfg.matItem_first,1)
				end
				if self._cfg.matItem_third then
					self:setModelMatItem(self._cfg._model[act], self._cfg.matItem_third,3)
				end
				ModelManager.Instance():setBrightnessScale(self._cfg._model[act], self._cfg.brightnessScale or 2.0)
			else
				assert(type(self._cfg.mesh) == "table")
				for act, mesh in pairs(self._cfg.mesh) do
					self._cfg._model[act] = ModelManager.Instance():createModelFromMesh(mesh)
					if self._cfg.matItem_first then
						self:setModelMatItem(self._cfg._model[act], self._cfg.matItem_first,1)
					end
					if self._cfg.matItem_third then
						self:setModelMatItem(self._cfg._model[act], self._cfg.matItem_third,3)
					end

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
