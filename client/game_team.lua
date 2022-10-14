local DEFAULT_COLOR = "NONE"
local teamFailIcon = {}
local TEAM_COLOR = {
    NONE = "00000000",
    YELLOW = "FFFFFF00",
    RED = "FFFF0000",
    GREEN = "FF33FF00",
    BLUE = "FF0000FF",
}
local teamName = T(Game, "teamName", World.cfg.teamName or {
    NONE = "",
    YELLOW = "team.name.yellow",
    RED = "team.name.red",
    GREEN = "team.name.green",
    BLUE = "team.name.blue",
})

local teamColor = T(Game, "teamColor", {"RED", "YELLOW", "GREEN", "BLUE",})

local teamImages = L("teamImages", {})
local mainTeamImageFrames = L("mainTeamImageFrames", {})
local mainTeamImageBgs = L("mainTeamImageBgs", {})
local teamCfgName = L("teamCfgName", {})

local teamEditName = {}
local teamEditIcon = {}
local teamAllIcon = {
    teamIcon = {},
    teamBedIcon = {},
    teamEggIcon = {},
}

local function initIcon()
    -- 用于拼接新旧图片资源
    local colors = {"yellow", "red", "green", "blue", "gray"}
    local oldIcons = {teamIcon = "new_gui_material",teamBedIcon = "bed_icon",teamEggIcon = "egg_icon",}
    local iconPrefix = {teamIcon = "team_", teamBedIcon = "bed_", teamEggIcon = "egg_"}
    for k, teamIcons in pairs(teamAllIcon) do
        local oldIcon = string.format("set:%s.json image:", oldIcons[k])
        local imagePrefix = World.cfg.useNewUI and "cegui_new_gameUI/icon_" or oldIcon
        teamIcons["NONE"] = ""
        for i = 1, #colors do
            if k == "teamIcon" and colors[i] == "gray" then
                break
            end
            local upperColors = string.upper(colors[i]);
            teamIcons[upperColors] = string.format("%s%s%s", imagePrefix ,iconPrefix[k] ,colors[i])
        end
    end
end

function Game.InitTeamCfg()
    initIcon()
    teamColor[0] = "NONE"
    local teamsCfg = World.cfg.team
    if not teamsCfg or not next(teamsCfg) then
        return
    end

    local mainTeamImageFrame = World.cfg.mainTeamImageFrame
    local mainTeamImageBg = World.cfg.mainTeamImageBg
    for _, cfg in ipairs(teamsCfg) do
        local id = cfg.id
        local color = cfg.color or teamColor[id]
        if color then
            assert(TEAM_COLOR[color], "undefined color! " .. color .. id)
            teamColor[id] = color
        end
        teamImages[id] = cfg.image
        mainTeamImageFrames[id] = cfg.mainTeamImageFrame or mainTeamImageFrame
        mainTeamImageBgs[id] = cfg.mainTeamImageBg or mainTeamImageBg

        -- name和icon可以用于自定义队伍名和图标
        local name = cfg.name
        teamCfgName[id] = name
        if name and color then
            teamEditName[color] = name
        end

        local icon = cfg.icon
        if icon then
            teamEditIcon[color] = icon
        end

        local bed = cfg.bed
        local needBed = bed and bed.enable
        if not needBed then
            teamAllIcon.teamIcon[id] = teamAllIcon.teamIcon[cfg.color]
            teamFailIcon[id] = teamAllIcon.teamIcon[cfg.color]
        else
            local fullName = bed.entity
            if string.find(fullName, "bed") then
                teamAllIcon.teamIcon[id] = teamAllIcon.teamBedIcon[color]
                teamFailIcon[id] = teamAllIcon.teamBedIcon["GRAY"]
            else
                teamAllIcon.teamIcon[id] = teamAllIcon.teamEggIcon[color]
                teamFailIcon[id] = teamAllIcon.teamEggIcon["GRAY"]
            end
        end
    end
end

function Game.GetTeamColor(teamID)
    return teamColor[teamID]
end

function Game.GetTeamName(teamID)
    local color = teamColor[teamID]
    return teamCfgName[teamID] or teamEditName[color] or teamName[color]
end

function Game.GetTeamColorValue(teamID)
    return TEAM_COLOR[teamColor[teamID]]
end

function Game.GetTeamIcon(teamID)
    local color = teamColor[teamID]
    return teamEditIcon[color] or teamAllIcon.teamIcon[color]
end

function Game.GetTeamImage(teamID)
    return teamImages[teamID]
end

function Game.GetMainTeamImageFrame(teamID)
    return mainTeamImageFrames[teamID]
end

function Game.GetMainTeamImageBg(teamID)
    return mainTeamImageBgs[teamID]
end

function Game.GetMyTeamIcon(teamID)
    local myTeamIcon = (teamAllIcon.teamIcon[teamColor[teamID]] or "") .. "_me"
    return myTeamIcon
end

function Game.GetMyTeamBg(teamID)
    local myTeamBg = (teamAllIcon.teamIcon[teamColor[teamID]] or "") .. "_bg"
    return myTeamBg
end

function Game.GetTeamFailIcon(teamID)
    return teamFailIcon[teamID]
end