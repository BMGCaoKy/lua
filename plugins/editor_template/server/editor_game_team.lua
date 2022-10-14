
local teamBedFullName = {}
local defenceWallFullName = {}
local defenceTowerFullName = {}

local teamColor = T(Game, "teamColor", {})
local TEAM_COLOR = {
    NONE = "[colour='00000000']",
    YELLOW = "[colour='FFFFFF00']",
    RED = "[colour='FFFF0000']",
    GREEN = "[colour='FF33FF00']",
    BLUE = "[colour='FF0000FF']",
}
do--InitBedFullName, teamColor
    teamColor[0] = "NONE"
    defenceWallFullName[0] = "myplugin/protectwall_0"
    defenceTowerFullName[0] = "myplugin/castle_0"
    local teamsCfg = World.cfg.team
    if not teamsCfg or not next(teamsCfg) then
        goto continue1
    end
    for id, cfg in ipairs(teamsCfg) do
        local color = cfg.color
        if color then
            assert(TEAM_COLOR[color], "undefined color! " .. color .. id)
            teamColor[id] = color
            defenceWallFullName[id] = string.format("myplugin/protectwall_%s", string.lower(color))
            defenceTowerFullName[id] = string.format("myplugin/castle_%s", string.lower(color))
        end
        local bed = cfg.bed
        local needBed = bed and bed.enable
        if not needBed then
            goto continue
        end

        local fullName = bed.entity
        if string.find(fullName, "bed") then
            teamBedFullName[id] = string.format("myplugin/bed_%s", string.lower(color))
        else
            teamBedFullName[id] = string.format("myplugin/egg_%s", string.lower(color))
        end
        ::continue::
    end
    ::continue1::
end

function Game.GetTeamBedFullName(teamID)
    return teamBedFullName[teamID]
end

function Game.GetDefenceWallFullName(teamID)
    return defenceWallFullName[teamID]
end

function Game.GetDefenceTowerFullName(teamID)
    return defenceTowerFullName[teamID]
end

function Game.GetTeamColorName(teamID)
    return teamColor[teamID]
end

function Game.GetTeamColor(teamID)
    return string.format("%s", TEAM_COLOR[teamColor[teamID]])
end

