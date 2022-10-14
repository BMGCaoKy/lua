--- ground_material_texture_config.lua
--- 地面材质贴图配置
local class = require "common.3rd.middleclass.middleclass"
---@class GroundMaterialTextureConfig : middleclass
local GroundMaterialTextureConfig = class('GroundMaterialTextureConfig')

function GroundMaterialTextureConfig:initialize()
    Lib.logDebug("GroundMaterialTextureConfig:initialize")
    ---@type GroundMaterialTextureData[]
    self.settings = {}
    self:load()
end

function GroundMaterialTextureConfig:load()
    local config = Lib.read_csv_file(Root.Instance():getGamePath() .. "config/mobile_editor_ground_material_texture.csv", 2)
    for _, vConfig in pairs(config) do
        ---@class GroundMaterialTextureData
        local data = {}
        data.id = tonumber(vConfig.n_id)
        data.path = tostring(vConfig.s_path)
        data.icon = tostring(vConfig.s_icon)
        table.insert(self.settings, data)
        SceneLib.addAdditionalMaterial(data.path)
    end
end

---@return GroundMaterialTextureData
function GroundMaterialTextureConfig:getConfig(index)
    for i, data in ipairs(self.settings) do
        if i == index then
            return data
        end
    end
    return nil
end

function GroundMaterialTextureConfig:getConfigs()
    return self.settings
end

return GroundMaterialTextureConfig