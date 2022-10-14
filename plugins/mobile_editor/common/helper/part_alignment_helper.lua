--- part_alignment_helper.lua
--- 零件对其
local class = require "common.3rd.middleclass.middleclass"
---@class PartAlignmentHelper : middleclass
local PartAlignmentHelper = class('PartAlignmentHelper')

function PartAlignmentHelper:initialize()
    Lib.logDebug("PartAlignment:initialize")
end

return PartAlignmentHelper