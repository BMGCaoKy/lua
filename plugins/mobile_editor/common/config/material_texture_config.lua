--- material_texture_config.lua
--- 材质贴图配置
local class = require "common.3rd.middleclass.middleclass"
---@class MaterialTextureConfig : middleclass
local MaterialTextureConfig = class('MaterialTextureConfig')

function MaterialTextureConfig:initialize()
    Lib.logDebug("MaterialTextureConfig:initialize")
    ---@type MaterialTextureData[]
    self.settings = {}
    self:load()
end

function MaterialTextureConfig:load()
    local config = Lib.read_csv_file(Root.Instance():getGamePath() .. "config/mobile_editor_material_texture.csv", 2)
    for _, vConfig in pairs(config) do
        ---@class MaterialTextureData
        local data = {}
        data.id = tonumber(vConfig.n_id)
        data.name = tostring(vConfig.s_name)
        data.path = tostring(vConfig.s_path)
        data.icon = tostring(vConfig.s_icon)
        data.attribute = tonumber(vConfig.n_attribute) or 0
        table.insert(self.settings, data)
        --材质填充
        SceneLib.addAdditionalMaterial(data.path)
    end
end

---@return MaterialTextureData
function MaterialTextureConfig:getConfig(index)
    for i, data in ipairs(self.settings) do
        if i == index then
            return data
        end
    end
    return nil
end

function MaterialTextureConfig:getConfigs()
    return self.settings
end

return MaterialTextureConfig