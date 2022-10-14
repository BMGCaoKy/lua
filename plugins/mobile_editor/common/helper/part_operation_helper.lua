--- part_operation_helper.lua
--- 零件操作
local class = require "common.3rd.middleclass.middleclass"
---@class PartOperationHelper : middleclass
local PartOperationHelper = class('PartOperationHelper')

function PartOperationHelper:initialize()
    Lib.logDebug("PartOperationHelper:initialize")
end

function PartOperationHelper.static.partCopy(list)

end

function PartOperationHelper.static.partPaste(list)

end

function PartOperationHelper.static.partRepetition(list)

end

return PartOperationHelper