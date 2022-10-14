local Entity = Entity

-- 自动同步属性定义
local ValueDef		= T(Entity, "ValueDef")
--语音月卡
ValueDef.soundMoonCard  = {false,       false,      true,      false,        0,    true}
--语音次数
ValueDef.soundTimes     = {false,       false,      true,      false,        0,    true}

-- 判断能否领取免费喇叭的标识
ValueDef.freeSoundFlag = {false,       false,      true,      false,        0,    true}

-- 当前每日免费声音的个数
ValueDef.freeSoundTimes     = {false,       false,      true,      false,        0,    true}

-- 自动生成标签的条件计数
ValueDef.conditionAutoTagsCounts     = {false,       false,      true,      false, {},    true}

function Entity:getSoundTimes()
    return self:getValue("soundTimes") or 0
end
function Entity:useSoundTimes()
    if self:getSoundMoonCardEnable() then
        return
    end

    self:setValue("soundTimes",self:getSoundTimes()-1)
end

function Entity:getFreeSoundFlag()
    return self:getValue("freeSoundFlag") or 0
end

function Entity:setFreeSoundFlag(flag)
    self:setValue("freeSoundFlag", flag)
end


function Entity:updateFreeSoundFlag()
    -- 没有获取过免费喇叭的用户，登录的时候获得免费喇叭
    if self:getFreeSoundFlag() == 0 then
        self:setFreeSoundFlag(1)
        if not self:getSoundMoonCardEnable()  then
            self:initFreeSoundTimes()
        end
    end
end

function Entity:getFreeSoundTimes()
    return self:getValue("freeSoundTimes") or 0
end

function Entity:useFreeSoundTimes()
    self:setValue("freeSoundTimes", self:getFreeSoundTimes() - 1)
end

function Entity:resetFreeSoundTimes()
    self:setValue("freeSoundTimes", 0)
end

function Entity:initFreeSoundTimes()
    self:setValue("freeSoundTimes", World.cfg.chatSetting.freeSoundPerDay)
end



function Entity:getSoundMoonCardMac()
    return self:getValue("soundMoonCard") or 0
end
function Entity:getSoundMoonCardEnable()
    return self:getSoundMoonCardMac()>0
end

function Entity:getCanSendSound()
    return self:getSoundTimes()>0 or self:getSoundMoonCardEnable() or self:getFreeSoundTimes() > 0
end

function Entity:getConditionAutoTagsCounts()
    return self:getValue("conditionAutoTagsCounts") or {}
end

function Entity:setConditionAutoTagsCounts(autoList)
    self:setValue("conditionAutoTagsCounts", autoList)
end

--======================================================================================
-- 队伍的信息，需要业务重载
--======================================================================================
-- 是否加入了队伍
function Entity:isJoinTeam()
    return false
end

-- 我队伍数据
function Entity:getTeamInfo()
    return  {}
end