local monster = L("monster", {})
local setting = require "common.setting"
local data_state = require "editor.dataState"
local map_setting = require "editor.map_setting"
local data_state = require "editor.dataState"
local network_mgr = require "network_mgr"
local entitySetting = require "editor.setting.entity_setting"
local global_setting = require "editor.setting.global_setting"
local itemSetting = require "editor.setting.item_setting"

local SET_Y_OFFECT = 0.01

local edit_setting = Clientsetting.getSetting()

local showShopMap = {}
local monsterPicPath = {}

local Timer
local function getIcon(type, fullName)
	local cfg, icon
	if type == "item" or type == "entity" then
		cfg = setting:fetch(type, fullName)
		icon = type == "item" and itemSetting:getCfgByKey(fullName, "icon") or nil
	elseif type == "block" then
		local item = Item.CreateItem("/block", 1, function(_item)
			_item:set_block(fullName)
		end)
		return item and item:block_icon(setting:name2id("block", fullName))
	end
	return cfg and ResLoader:loadImage(cfg, icon or cfg.icon or "vectorIcon.png") or icon
end

local function getTipIcon(derive)
	if not derive or not derive.dropItem then
		return
	end
	local dropItem =  derive.dropItem
	if not dropItem or not dropItem[1] then
		return
	end
	return getIcon(dropItem[1][1], dropItem[1][4])
end

local function setHeadTextByEntity(entity, derive)
	local picPath = getTipIcon(derive)
	local picbg
	if not picPath then
		picPath = ""
		picbg = "plugin/myplugin/entity/startpoint/wenhao_tip.png"
	end

    monsterPicPath[entity.objID] = {picPath = picPath, picbg = picbg}

    if edit_setting["dropBubble"] ~= 0 then
        return
    end
    local close = entity:cfg().hideHeadText or showShopMap[entity.objID]
    entity:showHeadPic(picPath, picbg, close)
end

function monster.switchMonsterShowBubble(entity_obj, id)
    local isShow = edit_setting["dropBubble"] ~= 0
    local entity = entity_obj:getEntityById(id)  
    local picCfg = monsterPicPath[entity.objID]
    entity:showHeadPic(picCfg.picPath, picCfg.picbg, isShow)
end


function Entity:clearMonsterList()
    monsterPicPath = {}
end

local function updateHpHeadText(entity)
    local newCfg = EditorModule:getCfg("entity", entity:cfg().fullName)
    if newCfg.hideHp then
        entity:setEditorModHideHp(newCfg.hideHp > 0 and "true" or "false")
    end
end

local function setAiRoute(entity_obj, entityId, derive, mderive)
	if not derive or not derive.tmpAiData then
		return
	end
	local route = derive.tmpAiData.route
	if not route or #route <= 1 then
		route = nil
	end
	entity_obj:deriveSetData(entityId, "aiData", {
		route = route 
    })
    if mderive.aiData then
        mderive.aiData = derive.aiData
        mderive.aiData.route = route
    end
	local tmpAiData =  derive.tmpAiData
	if tmpAiData and tmpAiData.route and #tmpAiData.route <= 1 then
		tmpAiData.route = nil
	end
	entity_obj:deriveSetData(entityId, "tmpAiData", derive.tmpAiData)
end

local function setting(entity_obj, id, isHideUi)
    if Timer then
        Timer()
        Timer = nil
    end
    if not isHideUi then
        local entity = entity_obj:getEntityById(id)
		local pos = entity_obj:getPosById(id)
        Lib.emitEvent(Event.EVENT_ENTITY_SETTING, id, pos)
        local anchor = {
            x = -0.4,
            y = 0.8
        }
        if entity:cfg()._name:find("wolf_fangs") then
            anchor = {
                x = -0.4,
                y = 0.5
            }
        end

        Timer = UILib.uiFollowObject(UI:getWnd("mapEditEntitySetting"):root(), entity.objID, {
            anchor = anchor,
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
    Blockman.Instance():saveMainPlayer(Player.CurPlayer)
    
    if Clientsetting.isKeyGuide("isNewAcc") then
        Lib.emitEvent(Event.EVENT_NOVICE_GUIDE, 4)
        Lib.emitEvent(Event.EVENT_EDIT_OPEN_GUIDE_WND, 3)
    end
end

local function setShopHeadUi(entity, showTitle, showShopMapVal, picPath, picbg, close)
    showShopMap[entity.objID] = showShopMapVal
    entity:setHeadText(0,0,showTitle or "")
    entity:showHeadPic(picPath, picbg, close)
    entity:updateShowName()
end

local function switchShopNameOrBubble(entity)
    local merchantGroupName = entitySetting:getCfg(entity:cfg().fullName).shopGroupName
    local showCfg = merchantGroupName and global_setting:getMerchantGroup()[merchantGroupName]
    if not showCfg then
        local data =  monsterPicPath[entity.objID] or {}
        local close = edit_setting["dropBubble"] ~= 0 or entity:cfg().hideHeadText
        setShopHeadUi(entity, nil, nil, data.picPath, data.picbg, close)
    else
        setShopHeadUi(entity, showCfg.showTitle, true)
    end
end

local function addEffect(entity, id)
    local cfg = entity:cfg()
    if not cfg.attackEffect then
        return
    end
    local path =  ResLoader:filePathJoint(entity:cfg(), cfg.attackEffect)    
    local name = string.format("obj_%d_%d", entity.objID, id)
    entity:addEffect(name, path, false, {x = 0, y = 0.1, z = 0}, 0, {x = 3, y = 3, z = 3})
end

function monster.del(entity_obj, id)
    local entity = entity_obj:getEntityById(id)
	SceneUIManager.RemoveEntityHeadUI(entity.objID)
end

function monster.add(entity_obj, id, derive, pos, _table)
    local flag = false
    if _table.dropobjects then
        monster.set(entity_obj, id, "dropItem", {{
            _table.dropobjects.type,
            _table.dropobjects.count,
            1,
            _table.dropobjects.fullName,
        }})
        flag = true
    end
	setting(entity_obj, id, flag)
	
    local entity = entity_obj:getEntityById(id)
    local newPos = pos
	newPos.y = newPos.y + SET_Y_OFFECT 
    local data = {pos = newPos}
    entity_obj:setPosById(id, data)
    setHeadTextByEntity(entity, derive)
    switchShopNameOrBubble(entity)
    updateHpHeadText(entity)
    --addEffect(entity, id)
end

function monster.click(entity_obj, id)
    if Clientsetting.isKeyGuide("isNewAcc") then
        Lib.emitEvent(Event.EVENT_NOVICE_GUIDE, 4, true)
		Clientsetting.setlocalGuideInfo("isNewAcc", false)
        local retry = 1
        World.Timer(5, function() 
            local respone = network_mgr:set_client_cache("isNewAcc", "1")
            if respone.ok or retry > 5 then
				if respone.ok then
					Clientsetting.setGuideInfo("isNewAcc", false)
				end
                return false
            end
            retry = retry + 1
            return true
        end)
        
    end
    setting(entity_obj, id)
end

function monster.set(entity_obj, id, key, value)
    local derive_obj = entity_obj:getDataById(id)
    derive_obj[key] = value
end



function monster.load(entity_obj, id, pos)
    local entity = entity_obj:getEntityById(id)
    local derive = entity_obj:getDataById(id)
    local timerFunc = function()
        if not entity then
            return
        end
        setHeadTextByEntity(entity, derive)
    end
    World.Timer(10, timerFunc)
    switchShopNameOrBubble(entity)
    updateHpHeadText(entity)
end

function monster.setPos(entity_obj, id, derive, data)
    local route = derive.aiData and derive.aiData.route
    if route and #route > 0 then
        route[1] = data.pos
    end
end

function monster.getAiRouteCount(entity_obj, id, derive)
    return derive.aiData and derive.aiData.route and #derive.aiData.route or 0
end

function monster.getAiRadius(entity_obj, id, derive)
    return derive.tmpAiData and derive.tmpAiData.homeSize or 5
end

function monster.saveAiRadius(entity_obj, id, derive, radius)
	if not radius then
		radius = derive.tmpAiData and derive.tmpAiData.homeSize
	end
	if radius and radius > 0 then
		derive.aiData = {
			homeSize = radius 
		}
	elseif radius and radius == 0 then
		derive.aiData = {
			routePath = 2,
			stand = true
		}
	end
	
    if derive.tmpAiData then
       derive.tmpAiData.homeSize = radius
    else
       derive.tmpAiData = {
           homeSize = radius 
       }
	end
	if not derive.aiData then
		derive.aiData = {}
	end
end

function monster.getType()
    return "monster"
end

function monster.changeEntity(entity_obj, id, derive, cfg)
	local pos = entity_obj:getPosById(id)
	local entityObject = EntityClient.CreateClientEntity({cfgName = cfg, pos = {
		x = pos.x,
		y = pos.y - SET_Y_OFFECT,
		z = pos.z
	}})
	entity_obj:setEntityById(id, entityObject)
	setHeadTextByEntity(entityObject, derive)
	setting(entity_obj, id)
	--addEffect(entityObject, id)
end

function monster.replaceTable(entity_obj, id, derive, obj)
	local replaceObj = (obj and obj.dropItem) or (obj and #obj > 0 and obj or nil)
	derive.dropItem = replaceObj
	local entity = entity_obj:getEntityById(id)
	setHeadTextByEntity(entity, derive)
	setAiRoute(entity_obj, id, obj, derive)
end

function monster.setDropItem(entity_obj, id, derive, value)
	derive.dropItem = value
	local entity = entity_obj:getEntityById(id)
	setHeadTextByEntity(entity, derive)
end

function monster.getDropItem(entity_obj, id, derive)
	return Lib.copy(derive.dropItem)
end

function monster.getShopGroup(entity_obj, id, derive)
	local entity = entity_obj:getEntityById(id)
	return entitySetting:getCfg(entity:cfg().fullName).shopGroupName
end

function monster.setShopGroup(entity_obj, id, derive, value)
	local entity = entity_obj:getEntityById(id)
	setHeadTextByEntity(entity, derive)
	switchShopNameOrBubble(entity)
end

function monster.shopSetting(entity_obj, id, derive)
	local entity = entity_obj:getEntityById(id)
	UI:openWnd("shopBinding", entity:cfg().fullName)
end

function monster.openSettingUI(entity_obj, id, derive)
	local entity = entity_obj:getEntityById(id)
	local cfg = entity:cfg()
	local fullName = entity_obj:getCfgById(id)
	local tabList = Lib.copy(cfg.settingUI and cfg.settingUI.tabList) or {}
	table.insert(tabList, {
		leftName = "gui.editor.drop.object",
		wndName = "DropSetting"
    })
    local item = EditorModule:createItem("entity", fullName)
	UI:openWnd("mapEditTabSetting2", {
		data = {
			fullName = fullName,
            id = id,
            item = item
		},
		labelName = tabList,
		fullName = fullName
	})
end

function monster.getPathMode(entity_obj, id, derive)
	return derive.aiData and derive.aiData.routePath or 0
end

local modleName = {
    [0] = "patrolRadius",
    [1] = "fixedRoute",
    [2] = "stand",
}

function monster.setRouteModle(entity_obj, id, derive, modle, value)
    if type(modle) == "number" then
        modle = modleName[modle]
    end
	if modle == "patrolRadius"  then
		monster.saveAiRadius(entity_obj, id, derive, value)
		derive.aiData.routePath = 0
	elseif modle == "fixedRoute" then
        local tmpDerive = Lib.copy(entity_obj:getDataById(id))
        local route = tmpDerive and tmpDerive.tmpAiData and tmpDerive.tmpAiData.route or {}
        entity_obj:deriveSetData(id, "aiData", {
			route = route,
			routePath = 1, 
        })
	elseif modle == "stand" then
		derive.aiData = {
			stand = true ,
			routePath = 2 
		}
	end
end

RETURN(monster)
