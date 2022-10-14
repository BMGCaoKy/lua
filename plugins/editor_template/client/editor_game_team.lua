local teamBedIcon =  World.cfg.teamIcon or {
    NONE = "",
    GRAY = "gui_teamIcon/bed_gray.png",
    YELLOW = "gui_teamIcon/bed_yellow.png",
    RED = "gui_teamIcon/bed_red.png",
    GREEN = "gui_teamIcon/bed_green.png",
    BLUE = "gui_teamIcon/bed_blue.png",
}
local teamEggIcon = {
    NONE = "",
    GRAY = "gui_teamIcon/egg_gray",
    YELLOW = "gui_teamIcon/egg_yellow",
    RED = "gui_teamIcon/egg_red",
    GREEN = "gui_teamIcon/egg_green",
    BLUE = "gui_teamIcon/egg_blue",
}
local teamIcon = {
    NONE = "",
    YELLOW = "cegui_new_gameUI/icon_team_yellow",
    RED = "cegui_new_gameUI/icon_team_red",
    GREEN = "cegui_new_gameUI/icon_team_green",
    BLUE = "cegui_new_gameUI/icon_team_blue"
}
local teamBg = {
    NONE = "",
    YELLOW = "cegui_new_gameUI/icon_team_yellow_bg",
    RED = "cegui_new_gameUI/icon_team_red_bg",
    GREEN = "cegui_new_gameUI/icon_team_green_bg",
    BLUE = "cegui_new_gameUI/icon_team_blue_bg"
}

do --InitTeamIcon
    local teamsCfg = World.cfg.team
    if not teamsCfg or not next(teamsCfg) then
        return
    end
    for id, cfg in ipairs(teamsCfg) do
        local bed = cfg.bed
        local needBed = bed and bed.enable
        if not needBed then
            teamIcon[id] = teamIcon[cfg.color]
            teamBg[id] = teamBg[cfg.color]
        else
            local color = cfg.color
            local fullName = bed.entity
            if string.find(fullName, "bed") then
                teamIcon[id] = teamBedIcon[color]
            else
                teamIcon[id] = teamEggIcon[color]
            end
        end
    end
end

function Game.GetTeamIcon(teamID)
    return teamIcon[teamID]
end


