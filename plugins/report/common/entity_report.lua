---
--- Generated by PluginCreator
--- hand_bag entity_common
--- DateTime:2021-06-17
---

local ValueDef = T(Entity, "ValueDef")
-- key				            = {isCpp,	client,	toSelf,	toOther,	init,	               saveDB}
--ValueDef.xxx 					= {false,   false,  true,   false,      0,                      true}
local Entity = Entity


ValueDef.loginTs 				= {false,   false,  true,   false,      0,                     false}
ValueDef.isNeedReportDialog     = {false,   false,  true,   false,      false,                 false}

function Entity:updateLoginTs()
    self:setValue("loginTs", os.time())
end

function Entity:getLoginTs()
    return self:getValue("loginTs")
end

function Entity:setIsNeedReportDialog(value)
    self:setValue("isNeedReportDialog", value)
end

function Entity:getIsNeedReportDialog()
    return self:getValue("isNeedReportDialog")
end