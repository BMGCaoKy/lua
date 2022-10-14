local gameState = L("gameState")
local stateStartTs = L("startTs")
local tsDiff = L("tsDiff")
local canJoinMidway = L("canJoinMidway")
local JOIN_TYPE = {"allow" , "forbit" , "none"}

function Game.IsWaitingState()
    return gameState == "GAME_INIT" or gameState == "GAME_REWAIT" or gameState == "GAME_READY"
end

function Game.GetState()
    return gameState
end

--客户端计算服务器时间方法：os.time() - Game.GetCSTimeDiff()
--游戏状态已执行时间：os.time() - Game.GetCSTimeDiff() - Game.GetStateStartTs()
--倒计时：World.cfg.playTime - os.time() + Game.GetCSTimeDiff() + Game.GetStateStartTs()
function Game.GetStateStartTs()
    return stateStartTs
end

function Game.GetCSTimeDiff()
    return tsDiff
end

local StateToEvent =
{
    GAME_START = "OnGameStageStart",
    GAME_OVER = "OnGameStageEnd",
}
function Game.SetState(state, startTs)
    if state == "GAME_START" then
        Lib.emitEvent(Event.EVENT_GAME_WAIT_GO)
    end
    if state == "GAME_GO" then
        Lib.emitEvent(Event.EVENT_GAME_START)
    end
    gameState = state
    if startTs then
        stateStartTs = startTs
        tsDiff = os.time() - stateStartTs
    end
    Lib.emitEvent(Event.EVENT_GAME_SET_STATE, state)
    if StateToEvent[state] then
        Event:EmitEvent(StateToEvent[state])
    end
end

function Game.SetCanJoinMidway(value)
    if type(value) == "number" then 
        canJoinMidway = JOIN_TYPE[value]
    else 
       canJoinMidway = value
    end
end

function Game.GetCanJoinMidway()
    return canJoinMidway
end


function Game.CheckCanJoinMidway()
   local value = Game.GetCanJoinMidway() 
   if value then 
        if value == "allow" then return true 
        elseif value == "forbit" then return false 
        else return World.cfg.canJoinMidway == true end
   else 
        return World.cfg.canJoinMidway == true 
   end
   
end


RETURN()