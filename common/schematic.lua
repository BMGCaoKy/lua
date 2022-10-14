
---@type setting
local setting = require "common.setting"
---@type setting
local CfgMod = setting:mod("schematic")


--- @class Schematic
local Schematic = Lib.class("Schematic")

function Schematic:ctor()
    self:reset()
end

function Schematic:init(fullName)
    self.fullName = fullName
    local cfg = CfgMod:get(self.fullName)
    self.height = cfg.height
    self.width = cfg.width
    self.length = cfg.length

    local path = Root.Instance():getGamePath() .. cfg.dir .. "blocks"
    local bd = Lib.read_file(path)
    assert(bd)
    for y = 0, self.height - 1 do
        for z = 0, self.length - 1 do
            for x = 0, self.width - 1 do
                local index = (y * self.length + z) * self.width + x + 1
                local blockId = bd:byte(index)
                if blockId ~= 0 then
                    local pos = Lib.v3(x, y, z)
                    --Lib.logDebug("Schematic:init index and blockId and pos  = ", index, blockId, Lib.v2s(pos))
                    table.insert(self.blocks, {
                        index = index,
                        id = blockId,
                        pos = pos
                    })
                    self.count = self.count + 1
                end
            end
        end
    end
end

function Schematic:getWidth()
    return self.width
end

function Schematic:getHeight()
    return self.height
end

function Schematic:getLength()
    return self.length
end

function Schematic:getCount()
    return self.count
end

function Schematic:getBlock(index)
    return self.blocks[index]
end

function Schematic:getBlocks()
    return self.blocks
end

function Schematic:reset()
    self.width = 0
    self.height = 0
    self.length = 0
    self.count = 0
    self.blocks = {}

end

function Schematic:serialize()
    local data = {}
    data.width = self.width
    data.height = self.height
    data.length = self.length
    data.count = self.count
    data.blocks = self.blocks
    return data
end

function Schematic:deserialize(data)
    if data then
        self.width = data.width
        self.height = data.height
        self.length = data.length
        self.count = data.count
        self.blocks = data.blocks
    end
end

return Schematic