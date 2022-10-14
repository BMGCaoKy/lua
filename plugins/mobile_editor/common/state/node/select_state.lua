--- select_state.lua
---@type setting
local setting = require "common.setting"
---@type ModMeta
local PartCfg = setting:mod("part")
---@class SelectState : BaseNode
local SelectState = {}

function SelectState:enteredState()
    --Lib.logDebug("SelectState:enteredState")
    self:setSelection(true)
end

function SelectState:exitedState()
    --Lib.logDebug("SelectState:exitedState")

end

return SelectState