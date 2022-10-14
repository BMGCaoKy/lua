local cmd = require "editor.cmd"
local entity_obj = require "editor.entity_obj"
local data_state = require "editor.dataState"
local engine = require "editor.engine"

local hight = 0
local guideClickNum = 1
local routeType = false


local function settingPos(entityId)
    Lib.emitEvent(Event.EVENT_ENTITY_SET_POS, entityId)
    Lib.emitEvent(Event.EVENT_OPEN_INVENTORY, false)
    data_state.is_can_place = false
    UI:closeWnd("mapEditEntitySetting")
end

local function settingPath(entityId)
    UI:closeWnd("mapEditEntitySetting")
    local entityType = entity_obj:Cmd("getType", entityId)
    if entityType == "monster" and not routeType then
        UI:openWnd("EntityPathSelect", entityId)
    else
        UI:openWnd("aiControl", entityId)
    end
end

local function settingEntity(entityId)
    local entityType = entity_obj:Cmd("getType", entityId)
    UI:openWnd("mapEditChangeStyle", entityId, entityType == "moveBlock")
end

local function settingDropItem(entityId)
    local entityType = entity_obj:Cmd("getType", entityId)
    local params = {
			entityId = entityId,
            blockVector = entityType == "vectorBlock"
		}
    Lib.emitEvent(Event.EVENT_VECTOR_SET_VALUE, true, params)
    UI:closeWnd("mapEditEntitySetting")
end

local function settingDel(entityId)
    Lib.emitEvent(Event.EVENT_EDIT_ENTITY_DEL_TIP, entityId)
end

local function setting(entityId)
	entity_obj:Cmd("openSettingUI", entityId)
end

local function shopSetting(entityId)
	entity_obj:Cmd("shopSetting", entityId)
end

local function fetchBtn(self, entityId, info, enable)
    local btn = GUIWindowManager.instance:LoadWindowFromJSON("btn_edit.json")
    btn:SetArea({0, 0}, {hight / 314, 0 }, { 1, 0}, { 58 / 314, 0})
    btn:child("Btn-Item-Icon"):SetImage(info.icon)--todo
    btn:child("Btn-Item-ImageTextLayout-TextImage"):SetImage(info.image)
	btn:child("Btn-Item-ImageTextLayout-TextImage"):SetArea({0, 0}, {0,  0}, {info.size[1] / 72 * 0.75, 0 }, {info.size[2] / 72 * 1.2, 0})
	if enable then
		self:subscribe(btn:child("Btn-Item"), UIEvent.EventButtonClick, function()
			if info.func then
				info.func(entityId)
			end
            UI:closeWnd(self)
		end)
	end
    self.menu_1:AddChildWindow(btn)
    btn:SetAutoSize(true)
	btn:SetEnabledRecursivly(enable)
    hight = hight + 58 + 6
    --self.menu:AddItem(btn)
    return btn
end

function M:initData()
    if World.Lang == "zh_CN" then
        self.itemNameImageList = { 
			["changMonsterModle"] 	= {["icon"] = "set:map_edit_objectset.json image:icon_refresh_setting"	,	["image"] = "image/cn_Change.png", 		["size"] = {71,18  },	func = settingEntity	},
			["changBlockModle"]  	= {["icon"] = "set:map_edit_objectset.json image:icon_refresh_setting"	,  	["image"] = "image/cn_Change_move.png", 		["size"] = {71,18  },	func = settingEntity	},
			["setDropItem"] 		= {["icon"] = "set:map_edit_objectset.json image:icon_drop_setting"		,	["image"] = "image/cn_Droppings.png",	["size"] = { 89,18 },	func = settingDropItem	},
			["setAIRoute"] 			= {["icon"] = "set:map_edit_objectset.json image:icon_path_setting"	,	["image"] = "image/cn_Route.png",		["size"] = { 71,18 },	func = settingPath		},
			["setPosition"] 		= {["icon"] = "set:map_edit_objectset.json image:icon_pos_setting"		,	["image"] = "image/cn_Position.png",	["size"] = { 72,18 },	func = settingPos		},
			["delete"]     			= {["icon"] = "set:map_edit_objectset.json image:icon_del_setting"			,	["image"] = "image/cn_Delete.png",		["size"] = { 37,18 },	func = settingDel		},
			["setting"]     		= {["icon"] = "image/icon_quality_setting.png"			,	["image"] = "image/cn_setting.png",		["size"] = { 37,18 },	func = setting		},
			["shopSetting"]     	= {["icon"] = "image/icon_setasstore_setting.png"			,	["image"] = "image/cn_setasstore.png",		["size"] = { 71,18 },	func = shopSetting		},
			}
			
    else
        self.itemNameImageList = { 
			["changMonsterModle"]  	= {["icon"] = "set:map_edit_objectset.json image:icon_refresh_setting"	,  	["image"] = "image/en_Change.png", 		["size"] = {65,21},		func = settingEntity	},
			["changBlockModle"]    	= {["icon"] = "set:map_edit_objectset.json image:icon_refresh_setting"	,  	["image"] = "image/en_Change.png", 		["size"] = {65,21},		func = settingEntity	},
			["setDropItem"] 		= {["icon"] = "set:map_edit_objectset.json image:icon_drop_setting"		,  	["image"] = "image/en_Droppings.png", 	["size"] = {89,20},		func = settingDropItem	},
			["setAIRoute"] 			= {["icon"] = "set:map_edit_objectset.json image:icon_path_setting"	,  	["image"] = "image/en_Route.png", 		["size"] = {48,15},		func = settingPath		},
			["setPosition"] 		= {["icon"] = "set:map_edit_objectset.json image:icon_pos_setting"		,  	["image"] = "image/en_Position.png", 	["size"] = {67,15},		func = settingPos		},
			["delete"]     			= {["icon"] = "set:map_edit_objectset.json image:icon_del_setting"			,  	["image"] = "image/en_Delete.png", 		["size"] = {54,16},		func = settingDel		},
			["setting"]     		= {["icon"] = "image/icon_quality_setting.png"			,  	["image"] = "image/en_setting.png", 		["size"] = {58,21},		func = setting		},
			["shopSetting"]     	= {["icon"] = "image/icon_setasstore_setting.png"			,  	["image"] = "image/en_setasstore.png", 		["size"] = {90,13},		func = shopSetting		}
        }
	end
	local wShowFollowImageData = World.cfg.showFollowImageData 
	for k, v in pairs(wShowFollowImageData or {}) do
		self.itemNameImageList[k] = v
	end
end

function M:init()
    WinBase.init(self, "entitySetting_edit.json")

    self.menu = self:child("Edit-Entity-Menu")
    self.menu:SetInterval(6)
    self.menu_1 = self:child("Edit-Entity-Menu_1")
    self.close = self:child("Edit-Entity-Close")
	self._root:SetArea({0, 0}, {0, 0 }, { 0, 180}, { 0, 439})
	self:initData()
	self:subscribe(self.close, UIEvent.EventButtonClick, function()
		UI:closeWnd("mapEditEntitySetting")
        if guideClickNum == 1 then
            Lib.emitEvent(Event.EVENT_NOVICE_GUIDE,5)
            guideClickNum = guideClickNum + 1
        elseif guideClickNum == 2 then
            Lib.emitEvent(Event.EVENT_NOVICE_GUIDE,7)
            guideClickNum = guideClickNum + 1
        end
    end)

    Lib.subscribeEvent(Event.EVENT_CLOSE_POP_WIN, function()
        UI:closeWnd("mapEditEntitySetting")
    end)
    self:root():setBelongWhitelist(true)
end

function M:showSettingUi()
	local oldShowListCfgTab = {
		[1] = {"changMonsterModle", "setDropItem", "setAIRoute", "setPosition", "delete"},
		[2] = {"changBlockModle", "setAIRoute", "setPosition", "delete"},
		[3] = {"setDropItem"},
		[4] = {"setAIRoute"},
		[5] = {"changMonsterModle", "setDropItem", "setPosition", "delete"},
	}
    local settinCfg = entity_obj:getCfgById(self._entityId)
	local cfg = Entity.GetCfg(settinCfg)
	local uiShowList = cfg.uiShowList
	if not uiShowList then
		local uiType = cfg and tonumber(cfg.uiType) or 1
		uiShowList = oldShowListCfgTab[uiType]
	end
	routeType = cfg.route
	for k, value in pairs(uiShowList or {}) do

		local info = self.itemNameImageList[value]
		local enable = true
		if value == "setting" and cfg.entityDerive == "monster" and  entity_obj:Cmd("getShopGroup", self._entityId) then
			enable = false
		end
		if info then
			fetchBtn(self, self._entityId, info, enable)    
		end
	end
end


function M:setRenderBox()
	if self._entityId then
		local entity = entity_obj:getEntityById(self._entityId)
		local boundingBox = entity:getBoundingBox()
		local cfg = entity_obj:getCfgById(self._entityId)
		local objectBox = Entity.GetCfg(cfg).objectBox
        local pos = entity:getPosition()
		local entityType = entity_obj:Cmd("getType", self._entityId)
		local increment = {x = 0, y = 0, z = 0}
		if entityType == "moveBlock" then
			increment = Lib.v3add(increment, {x = 0.02, y = 0.02, z = 0.02})
		end
		local minPos = Lib.v3cut(boundingBox[2], increment)
		local maxPos = Lib.v3add(boundingBox[3], increment)
        if objectBox then
		    minPos = Lib.v3add(pos, {x = objectBox[1] / 2, y = objectBox[2], z = objectBox[3] / 2})
            maxPos = Lib.v3add(pos, {x = -objectBox[1] / 2, y = 0, z = -objectBox[3] / 2})  
        end
		self.widget_obj = engine:new_widget_frame(minPos , maxPos, true)
        self.widget_obj:set_depth(1) 
        self.widget_obj:set_mark(0)
		self.widget_obj:set_show_block(0)
        local color = 0x93F23F
        if Entity.GetCfg(cfg).boundBoxColor then
            color = string.format("%#x", Entity.GetCfg(cfg).boundBoxColor)
        end
        self.widget_obj:set_color(color)
	end
end

function M:onOpen(id)
    hight = 0
	self._entityId = id
    self.menu_1:CleanupChildren()
    self:showSettingUi()
	self:setRenderBox()
    Blockman.instance.gameSettings.isPopWindow = true
end

function M:onClose()
	if self.widget_obj then
		engine:del_widget_frame(self.widget_obj)
	end
--	local entity = entity_obj:getEntityById(self._entityId)
--    if entity then
--        entity:setRenderBox(false)
--    end
    Blockman.instance.gameSettings.isPopWindow = false
end

function M:onReload(reloadArg)

end

return M