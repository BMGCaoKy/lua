local setting = require "common.setting"
local vectorBlock = L("vectorBlock", {})
local data_state = require "editor.dataState"

local edit_setting = Clientsetting.getSetting()

local vectirPicPath = {}

local function getIcon(type, fullName)
	local cfg
	if type == "item" or type == "entity" then
		cfg = setting:fetch(type, fullName)
	elseif type == "block" then
		local item = Item.CreateItem("/block", 1, function(_item)
			 _item:set_block(fullName)
		 end)
		 return item and item:block_icon(setting:name2id("block", fullName))
	end
	return cfg and ResLoader:loadImage(cfg, cfg.icon or "vectorIcon.png") or nil
end

local function getTipIcon(derive)
	if not derive or not derive.fullName  then
		return
	end
	return getIcon(derive.type, derive.fullName)
end

local function setHeadText(entity, derive)
	local picPath = getTipIcon(derive)
	local picbg
	if not picPath then
		picPath = ""
		picbg = "plugin/myplugin/entity/startpoint/wenhao_tip.png"
	end

	vectirPicPath[entity.objID] = {picPath = picPath, picbg = picbg}

	if edit_setting["dropBubble"] ~= 0 then
		return
	end
	entity:showHeadPic(picPath, picbg)
end

function vectorBlock.switchVectorBlockShowBubble(entity_obj, id)
    local isShow = edit_setting["dropBubble"] ~= 0
    local entity = entity_obj:getEntityById(id)
    local picCfg = vectirPicPath[entity.objID]
    entity:showHeadPic(picCfg.picPath, picCfg.picbg, isShow)
end

function Entity:clearVectorList()
    vectirPicPath = {}
end

function vectorBlock.replaceTable(entity_obj, id, derive, obj)
	for k, _ in pairs(derive or {}) do
		derive[k] = nil
	end
	for k, v in pairs(obj or {}) do
		derive[k] = v
	end
	local entity = entity_obj:getEntityById(id)
	setHeadText(entity, derive)
end

function vectorBlock.changeStyle(entity_obj, id, derive, obj, fullName)
	local entity = entity_obj:getEntityById(id)
	entity_obj:setCfgById(id, fullName)
	local cfg = setting:fetch("entity", fullName)
	entity:changeActor(cfg.actorName)
end

function vectorBlock.add(entity_obj, id, derive, pos, _table)
	local flag = true
	local yaw = Blockman.Instance():viewerRenderYaw()
    if _table.dropobjects then
        vectorBlock.replaceTable(entity_obj, id, derive, _table.dropobjects)
        flag = false
    end
	local entity = entity_obj:getEntityById(id)
	local cfg = entity:cfg()
	if cfg._name:find("vectorBlockLong") then
		yaw = (math.floor( ((yaw + 45) % 360 + 360) / 90)) % 4 
		local pos = entity_obj:getPosById(id)
		if cfg._name == "vectorBlockLong" and yaw == 1 then
			pos.x = pos.x - 1
			entity:setPosition(pos)
		elseif cfg._name == "vectorBlockLong" and yaw == 3 then
			pos.x = pos.x + 1
			entity:setPosition(pos)
		end
		yaw = yaw % 2 == 0 and 0 or 90
	else
		yaw = 0
	end
	--local box = cfg.boundingVolume and cfg.boundingVolume.params or {1, 1.8, 1}
	--local box = cfg.boundingVolume.params
	--if yaw == 90 then
	--	entity:setBoundingVolume({
	--		boundingVolume = {
	--		type = "Box",
	--		params =  {
	--			box[3],box[2],box[1]
	--		}
	--	}})
	--	data = {pos = {
	--		x = pos.x + (box[3] % 2 == 0 and 0.5 or 0),
	--		y = pos.y,
	--		z = pos.z + (box[1] % 2 == 0 and 0.5 or 0)
	--	}}
	--else
	--	data = {pos = {
	--		x = pos.x + (box[1] % 2 == 0 and 0.5 or 0),
	--		y = pos.y,
	--		z = pos.z + (box[3] % 2 == 0 and 0.5 or 0)
	--	}}
	--end
	entity_obj:setYawById(id, yaw)
    setHeadText(entity, derive)
    if flag then
        vectorBlock.click(entity_obj, id)
    end
end

local Timer
function vectorBlock.openUI(entity_obj, id, derive, obj, fullName)
    if Timer then
        Timer()
        Timer = nil
    end
	local entity = entity_obj:getEntityById(id)
	local cfg = entity:cfg()
	local pos = entity_obj:getPosById(id)
    local entity = entity_obj:getEntityById(id)
        Lib.emitEvent(Event.EVENT_ENTITY_SETTING, id, pos)
        Timer = UILib.uiFollowObject(UI:getWnd("mapEditEntitySetting"):root(), entity.objID, {
            anchor = {
                x = -0.4,
                y = 0.5
            },
			offset = {
				x = 0,
				y = 0,
				z = 0
			},
            minScale = 0.7,
            maxScale = 1.2,
            autoScale = true,
            canAroundYaw = false
    })
end

function vectorBlock.click(entity_obj, id)
	local entity = entity_obj:getEntityById(id)
	local cfg = entity:cfg()
	local derive = entity_obj:getDataById(id)
    vectorBlock.openUI(entity_obj, id, derive)
end

function vectorBlock.getType()
    return "vectorBlock"
end

function vectorBlock.load(entity_obj, id, pos)
    local timerFunc = function()
        local entity = entity_obj:getEntityById(id)
        if not entity then
            return
        end
        local derive  = entity_obj:getDataById(id)
		setHeadText(entity, derive)
    end
    World.Timer(10, timerFunc)
end

RETURN(vectorBlock)