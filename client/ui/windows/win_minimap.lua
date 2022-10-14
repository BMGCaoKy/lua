local mapSize = 100
local miniMapSize = 210
local mapCenter = { x = 0, y = 0, z = 0 }
local isMini = true

-- local locationsTable = { key = { image = nil, text = nil, objectid = nil, pos = nil, rotate = nil, isOverShow = false, isRotate = true } }
local locationsTable = { }
local rotateOffset = 0
local positionOffset = {x=-5,y=60}

function M:rotate(pos, deg)
	local ret = {}
	local rad = math.rad(deg)
	ret.x = math.cos(rad)*pos.x + math.sin(rad)*pos.z
	ret.z = -math.sin(rad)*pos.x + math.cos(rad)*pos.z
	return ret
end

function M:SetMapPos(window, pos)
	if not pos then
		return
	end

    local mapwidth = self.m_mapimage:GetWidth()[2]
    local mapheight = self.m_mapimage:GetHeight()[2]

	local rotate_pos = self:rotate( {x= pos.x-mapCenter.x, z=pos.z-mapCenter.z}, -rotateOffset)
    local minimappos = { }
	minimappos.x =(rotate_pos.x + mapSize / 2) / mapSize
	minimappos.y =(rotate_pos.z + mapSize / 2) / mapSize

    window:SetArea( { 0, mapwidth - minimappos.x * mapwidth - 12 }, { 0, mapheight - minimappos.y * mapheight - 12 }, { 0, 24 }, { 0, 24 })
end

function M:getScenePos(x, y)
    local mapwidth = self.m_mapimage:GetWidth()[2]
    local mapheight = self.m_mapimage:GetHeight()[2]

	return {x = mapSize / 2 - (x / mapwidth) * mapSize, y = mapSize / 2 - (y / mapheight) * mapSize}
end

function M:maximize()
    local layout = self:root()
    layout:SetProperty("VerticalAlignment", "Centre")
    layout:SetProperty("HorizontalAlignment", "Centre")
    layout:SetArea( { 0, 0 }, { - 0.05, 0 }, { 0, 512 }, { 0, 512 })

    self.m_background:SetArea( { 0, 0 }, { 0, 0 }, { 0, 512 }, { 0, 512 })
    self.m_clip:SetArea( { 0, 24 }, { 0, 24 }, { 0, 464 }, { 0, 464 })
    self.m_mapimage:SetArea( { 0, 0 }, { 0, 0 }, { 0, 464 }, { 0, 464 })

    isMini = false
end

function M:setMapName(name)
    self.m_mapname:SetText(name)
end

function M:setMapSize(size)
    mapSize = size
end

function M:setMapCenter(center)
    mapCenter = center
end

function M:setMapImage(file)
    self.m_mapimage:SetImage(file)
end

function M:minimize()
    local config = World.CurMap.cfg.miniMap
    positionOffset = config.positionOffset or {x=-5,y=60}
    miniMapSize = config.miniMapSize or 210
    local layout = self:root()
    layout:SetProperty("VerticalAlignment", "Top")
    layout:SetProperty("HorizontalAlignment", "Right")
    layout:SetArea( { 0, positionOffset.x }, { 0, positionOffset.y }, { 0, 250 }, { 0, 300 })

    self.m_background:SetArea( { 0, 0 }, { 0, 0 }, { 0, miniMapSize + 40 }, { 0, miniMapSize + 40 })
    self.m_clip:SetArea( { 0, 20 }, { 0, 20 }, { 0, miniMapSize }, { 0, miniMapSize })
    self.m_mapimage:SetArea( { 0, 0 }, { 0, 0 }, { 0, 1024 }, { 0, 1024 })

    isMini = true
end

function M:load()
    local config = World.CurMap.cfg.miniMap
    if not config then
        print(" try load mini map but not config.")
        return
    end
	rotateOffset = config.rotateOffset or 0
	--[[
    "miniMap": {
		"mapName": " ",
		"mapFile": "map.png",
		"mapCenter": {
        "x": 0,
        "y": 0,
        "z": 0
		},
		"mapSize": 600
	}
	]]--
    self.m_pos:SetVisible(not config.hideCoord)
    self.m_background:SetImage(config.hideBg and "" or "set:main_page.json image:map_bg.png")
    self:setMapName(Lang:toText(config.MapName or config.mapName))
    self:setMapSize(config.MapSize or config.mapSize)
	self:setMapCenter(config.mapCenter or {x=0,y=0,z=0})
	
    self:setMapImage("map/"..World.CurMap.name.."/" .. (config.MapFile or config.mapFile))
--    config.icons = config.Icons or config.icons or {}
--    for key, value in pairs(config.icons) do
--        self:SetIcon(value.key, value.icon, value.text, value.pos)
--    end
    self:minimize()
end

function M:init()
    WinBase.init(self, "MiniMap.json")

    self.m_background = self:child("main_layout-background")
    self.m_background:SetImage("set:main_page.json image:map_bg.png")

    self.m_mapimage = self:child("main_layout-map_image")

    self.m_clip = self:child("main_layout-clip")

    self.m_mapname = self:child("main_layout-mapname")
    self.m_mapname:SetText("")

    self.m_pos = self:child("main_layout-pos")
    self.m_pos:SetText("")

    self:subscribe(self.m_background, UIEvent.EventWindowClick, function(_, x, y)
		if Blockman.instance:isKeyPressing("key.ctrl") then
			local winPos = CoordConverter.screenToWindow1(self.m_mapimage, {x = x, y = y})
			local scenePos = self:getScenePos(winPos.x, winPos.y)
			local pos = Lib.v3(math.floor(scenePos.x), 0, math.floor(scenePos.y))
			local map = World.CurMap
			for y1 = math.floor(Me:getPosition().y), 255 do
				pos.y = y1
				if map:getBlockConfigId(pos)==0 then
					for y2 = y1, 0, -1 do
						pos.y = y2
						if map:getBlockConfigId(pos)~=0 then
							Me:doGM("move", Lib.v3(scenePos.x, y2+1.1, scenePos.y))
							break
						end
					end
					break
				end
			end
		elseif isMini == true then
            self:maximize()
        else
            self:minimize()
        end
    end)

	self:load()

    local offset = self.m_clip:GetWidth()[2] / 2


    local function tick()
        local pos = Me:getPosition()

		local rotate_pos = self:rotate( {x= pos.x-mapCenter.x, z=pos.z-mapCenter.z}, -rotateOffset)

        local minimappos = { }
		minimappos.x =(rotate_pos.x + mapSize / 2) / mapSize
		minimappos.y =(rotate_pos.z + mapSize / 2) / mapSize

        local mapwidth = self.m_mapimage:GetWidth()[2]
        local mapheight = self.m_mapimage:GetHeight()[2]

        if isMini == true then
            self.m_mapimage:SetArea( { 0, minimappos.x * mapwidth + offset - mapwidth }, { 0, minimappos.y * mapheight + offset - mapwidth }, { 0, mapwidth }, { 0, mapheight })
        end

        self.m_pos:SetText("" .. string.format("X=%.2f", pos.x) .. "    " .. string.format("Y=%.2f", pos.z))

        for k, v in pairs(locationsTable) do
            --            if(v.arrow)then
            --                   local d= {v.pos.x- pos.x,v.pos.z-pos.z}
            --            end

            if v.rotate then
                v.image:SetProperty("Rotate", v.rotate + rotateOffset)
            else
                v.image:SetProperty("Rotate", 0 + rotateOffset)
            end
            local entity = World.CurWorld:getEntity(v.objectID)
            if entity and entity:getPosition() then
                self:SetMapPos(v.image, entity:getPosition())
                if v.text then
                    v.text:SetArea( { 0, v.image:GetXPosition()[2] - v.textOffset }, { 0, v.image:GetYPosition()[2] + 36 }, { 0, 100 }, { 0, 50 })
                    v.text:SetProperty("Visible", 1)
                end
                if v.isRotate and entity:getRotationYaw() then
                    v.image:SetProperty("Rotate", entity:getRotationYaw() + rotateOffset)
                end
                v.image:SetProperty("Visible", 1)
            else
                if v.objectID ~= nil then
                    v.image:SetProperty("Visible", 0)
                    if v.text then
                        v.text:SetProperty("Visible", 0)
                    end
                else
                    self:SetMapPos(v.image, v.pos)
                    if v.text then
                        v.text:SetArea( { 0, v.image:GetXPosition()[2] - v.textOffset }, { 0, v.image:GetYPosition()[2] + 36 }, { 0, 100 }, { 0, 50 })
                    end
                end
            end
        end
        return true;
    end
    World.Timer(1, tick)

	
	Lib.subscribeEvent(Event.EVENT_MAP_RELOAD, function()
        self:load()
    end )

    Lib.subscribeEvent(Event.EVENT_MAP_MAXIMIZE, function()
        self:maximize()
    end )
    Lib.subscribeEvent(Event.EVENT_MAP_MINIMIZE, function()
        self:minimize()
    end )
    Lib.subscribeEvent(Event.EVENT_MAP_SETICON, function(key, icon, text, pos, rotate, objectID, isRotate,isOverShow)
        self:SetIcon(key, icon, text, pos, rotate, objectID, isRotate,isOverShow)
    end )
    Lib.subscribeEvent(Event.EVENT_MAP_REMOVEICON, function(key)
        self:removeIcon(key)
    end )
--     Lib.emitEvent(Event.EVENT_MAP_MAXIMIZE)

end





function M:SetIcon(key, icon, text, pos, rotate, objectID, isRotate,isOverShow)

    if (icon == nil and text == nil) then
        return
    end

    if locationsTable[key] == nil then
        locationsTable[key] = { }
    end

    locationsTable[key].objectID = objectID
    locationsTable[key].pos = pos
    locationsTable[key].rotate = rotate
    locationsTable[key].isRotate = isRotate

    --    if isOverShow then
    --        local arrow = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "arrow" .. key)
    --        arrow:SetImage("map/map001/frame1.png")
    --        self.m_clip:AddChildWindow(arrow)
    --        locationsTable[key].arrow = arrow
    --    end

    local mapwidth = self.m_mapimage:GetWidth()[2]
    local mapheight = self.m_mapimage:GetHeight()[2]

    if icon and locationsTable[key].image == nil then
        local image = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "StaticImage" .. key)
        self.m_mapimage:AddChildWindow(image)
        locationsTable[key].image = image
    end

    if text and locationsTable[key].text == nil then
        local text = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "StaticText" .. key)
        self.m_mapimage:AddChildWindow(text)
        locationsTable[key].text = text
    end

    if icon then
        locationsTable[key].image:SetImage(icon)
    end

    if text then
        locationsTable[key].text:SetText(text)
    end

    if rotate then
        locationsTable[key].image:SetProperty("Rotate", rotate + rotateOffset)
    else
        locationsTable[key].image:SetProperty("Rotate", 0 + rotateOffset)
    end
    locationsTable[key].textOffset = 0
    local entity = World.CurWorld:getEntity(objectID)
    if entity then
        self:SetMapPos(locationsTable[key].image, entity:getPosition())

        if text and locationsTable[key].text then
            locationsTable[key].textOffset = #text * 3
            locationsTable[key].text:SetArea( { 0, locationsTable[key].image:GetXPosition()[2] - locationsTable[key].textOffset }, { 0, locationsTable[key].image:GetYPosition()[2] + 36 }, { 0, 100 }, { 0, 50 })
        end

        if isRotate and entity:getRotationYaw() then
            locationsTable[key].image:SetProperty("Rotate", entity:getRotationYaw() + rotateOffset)
        end
    else
        self:SetMapPos(locationsTable[key].image, pos)

        if text and locationsTable[key].text then
            locationsTable[key].textOffset = #text * 3
            locationsTable[key].text:SetArea( { 0, locationsTable[key].image:GetXPosition()[2] - locationsTable[key].textOffset }, { 0, locationsTable[key].image:GetYPosition()[2] + 36 }, { 0, 100 }, { 0, 50 })
        end
    end

end

function M:removeIcon(key)
    if locationsTable[key] then
        if locationsTable[key].image then
            self.m_mapimage:RemoveChildWindow1(locationsTable[key].image)
        end
        if locationsTable[key].text then
            self.m_mapimage:RemoveChildWindow1(locationsTable[key].text)
        end
        locationsTable[key] = nil
    end
end

return M