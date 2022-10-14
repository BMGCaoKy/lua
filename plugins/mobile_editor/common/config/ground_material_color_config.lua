--- ground_material_color_config.lua
--- 地面材质颜色配置
local class = require "common.3rd.middleclass.middleclass"
---@class GroundMaterialColorConfig : middleclass
local GroundMaterialColorConfig = class('GroundMaterialColorConfig')

function GroundMaterialColorConfig:initialize()
    Lib.logDebug("GroundMaterialColorConfig:initialize")
    ---@type GroundMaterialColorData[]
    self.settings = {}
    self:load()
end

function GroundMaterialColorConfig:load()
    local config = Lib.read_csv_file(Root.Instance():getGamePath() .. "config/mobile_editor_ground_material_color.csv", 2)
    for _, vConfig in pairs(config) do
        ---@class GroundMaterialColorData
        local data = {}
        data.id = tonumber(vConfig.n_id)
        data.icon = vConfig.s_icon
        local color = Lib.splitString(tostring(vConfig.s_color), "#", true)
        data.color = color
        table.insert(self.settings, data)
    end
end

---@return GroundMaterialColorData
function GroundMaterialColorConfig:getConfig(index)
    for i, data in ipairs(self.settings) do
        if i == index then
            return data
        end
    end
    return nil
end

function GroundMaterialColorConfig:getConfigs()
    return self.settings
end

return GroundMaterialColorConfig