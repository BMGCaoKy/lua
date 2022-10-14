--[[
  "chatSetting": {
   "?maxHistory": "离线好友历史消息保存最近几条,默認為10",
    "maxHistory": 12,
    "?infoButtons": "玩家详情页交互按钮配置",
    "infoButtons": [
      {
        "name" : "ui.chat.player_private",
        "image" : "set:chat.json image:btn_9_adddot",
        "clickEvent" : {
          "isClient" : true,
          "name" : "EVENT_OPEN_PRIVATE_CHAT"
        }
      },
      {
        "name" : "ui.chat.team",
        "image" : "set:chat.json image:btn_9_adddot",
        "clickEvent" : {
          "isClient" : true,
          "name" : "EVENT_OPEN_TEAM"
        }
      },
      {
        "name" : "ui.chat.pk",
        "image" : "set:chat.json image:btn_9_adddot",
        "clickEvent" : {
          "isClient" : true,
          "name" : "EVENT_OPEN_PK"
        }
      },
      {
        "name" : "ui.chat.gift",
        "image" : "set:chat.json image:btn_9_adddot",
        "clickEvent" : {
          "isClient" : true,
          "name" : "EVENT_OPEN_GIFT"
        }
      },
      {
        "name" : "ui.chat.apprentice",
        "image" : "set:chat.json image:btn_9_adddot",
        "clickEvent" : {
          "isClient" : true,
          "name" : "EVENT_OPEN_APPRENTICE"
        }
      },
      {
        "name" : "ui.chat.master",
        "image" : "set:chat.json image:btn_9_adddot",
        "clickEvent" : {
          "isClient" : true,
          "name" : "EVENT_OPEN_MASTER"
        }
      },
      {
        "name" : "ui.chat.invite",
        "image" : "set:chat.json image:btn_9_adddot",
        "clickEvent" : {
          "isClient" : true,
          "name" : "EVENT_INVITE_GAME"
        }
      },
      {
        "name" : "ui.chat.information",
        "image" : "set:chat.json image:btn_9_adddot",
        "clickEvent" : {
          "isClient" : true,
          "name" : "EVENT_OPEN_PLAYER_INFORMATION"
        }
      }

    ],
    "?refreshFriendTime": "好友列表数据刷新时间，单位秒",
    "refreshFriendTime": 60,
    "?chatBar": "独立聊天入口，默认关闭",
    "chatBar": true,
    "?chatBarPos": "聊天入口位置，左上对齐，绝对坐标[x, y]",
    "chatBarPos": [ 0, 0 ],
    "?chatLevel": "聊天界面层级",
    "chatLevel": 50,
    "?chatTabList": "订阅的聊天tab标签页列表，具体类型见Define.Page",
    "chatTabList": [ 5,1,7,6,4,8,3 ],
    "?miniMsgShowList": "小聊天窗口需要显示的标签消息",
    "miniMsgShowList": [ 5,1,7,6,4,8,3],
    "?chatBarRedShow": "chatBar聊天按钮需要显示红点的标签",
    "chatBarRedShow": [6],
    "?emojiTabList": "订阅的表情tab标签页列表，1表情2物品3宠物4快捷短语",
    "emojiTabList": [ 1, 4, 2, 3 ],
    "?alignment": "聊天小窗布局方式：horizontalAlignment:0(left),1center,2right,verticalAlignment:00top,1center,2bottom",
    "alignment": {
      "horizontalAlignment": 1,
      "verticalAlignment": 2,
      "offset": [
        0,
        0,
        0,
        -19
      ],
      "miniSize": [ 353, 119, 204 ],
      "?barOffset": "聊天小窗bar位置，前面四个是小小窗的位置，最后一个是小窗展开时的Y坐标",
      "barOffset": [
        0,
        -311,
        0,
        -24,
        -24
      ]
    },
    "?chtBarHeight": "聊天小窗文本单行聊天高度，不填默认30",
    "chtBarHeight": 30,
    "?miniContentSpacing": "聊天小窗文本行距默认是0，可以是负数",
    "miniContentSpacing": -5,
    "?chatFont": "聊天小窗文本聊天字体，默认HT16",
    "chatFont": "HT16",
    "?chatFontColor": "聊天小窗文字颜色（不填则为黑色）",
    "chatFontColor": "000000",
    "?miniFontColorUsePre": "聊天小窗文本颜色是否使用频道前缀颜色一致，如果一致下面填的颜色会失效",
    "miniFontColorUsePre": true,
    "?mainNickFontColor": "聊天主窗普通人文字颜色（不填则为黑色）",
    "mainNickFontColor": "2951E4",
    "?mainSelfFontColor": "聊天主窗自己文字颜色（不填则为黑色）",
    "mainSelfFontColor": "FFFFFF",
    "?miniNiceNameColor": "聊天小窗普通人名文字颜色（不填则为红色）",
    "miniNiceNameColor": "BEDFE6",
    "?miniSelfNameColor": "聊天小窗自己名文字颜色（不填则为红色）",
    "miniSelfNameColor": "BEDFE6",
    "?chatHeadColor": "玩家在此房间第一次发言时，玩家名字颜色，此后该玩家在本房间发言，其名字颜色均为该颜色（包括括号与冒号，[名字]:）",
    "chatHeadColor": ["FFA500", "0000FF", "FFC0CB", "800080", "FF0000", "008000"],
    "?isOpenChatHeadColor": "是否开放chatHeadColor这个名字颜色变化功能",
    "isOpenChatHeadColor": false,
    "?chatMainSelfVoiceColor": "聊天主界面自己语音小天线颜色、语音时长颜色",
    "chatMainSelfVoiceColor": "8e4e16",
    "?chatMainOtherVoiceColor": "聊天主界面他人语音小天线颜色、语音时长颜色",
    "chatMainOtherVoiceColor": "8e4e16",
    "?chatMiniVoiceColor": "聊天小窗语音小天线颜色、语音时长颜色",
    "chatMiniVoiceColor": "8e4e16",
    "?chatTypeColor": "各频道聊天前缀颜色",
    "chatTypeColor": [ "d39655", "00ff00", "7e62bb", "d3c655", "cc6868", "6bb54b", "6bb54b", "6bb54b", "6bb54b" ],
    "?voicePlayNRes": "语音按钮点击播放的资源",
    "voicePlayNormalRes": "set:chat.json image:ipt_9_normal",
    "voicePlayPushRes": "set:chat.json image:ipt_9_hover",
    "?tabIcon": "顺序为世界，家族，私聊,当前,系统,队伍,职业,好友,附近的人",
    "tabIcon": [
      {
        "tabName": "ui.chat.chatMsgType1",
        "nameSColor": "DFE6F3",
        "nameNColor": "111111",
        "normal": "",
        "select": "set:chat.json image:chb_9_select",
        "point": "set:chat.json image:img_9_reddot"
      },
      {
        "tabName": "ui.chat.chatMsgType2",
        "nameSColor": "DFE6F3",
        "nameNColor": "111111",
        "normal": "",
        "select": "set:chat.json image:chb_9_select",
        "point": "set:chat.json image:img_9_reddot"
      },
      {
        "tabName": "ui.chat.chatMsgType3",
        "nameSColor": "DFE6F3",
        "nameNColor": "111111",
        "normal": "",
        "select": "set:chat.json image:chb_9_select",
        "point": "set:chat.json image:img_9_reddot"
      },
      {
        "tabName": "ui.chat.chatMsgType4",
        "nameSColor": "DFE6F3",
        "nameNColor": "111111",
        "normal": "",
        "select": "set:chat.json image:chb_9_select",
        "point": "set:chat.json image:img_9_reddot"
      },
      {
        "tabName": "ui.chat.chatMsgType5",
        "nameSColor": "DFE6F3",
        "nameNColor": "111111",
        "normal": "",
        "select": "set:chat.json image:chb_9_select",
        "point": "set:chat.json image:img_9_reddot"
      },
      {
        "tabName": "ui.chat.chatMsgType6",
        "nameSColor": "DFE6F3",
        "nameNColor": "111111",
        "normal": "",
        "select": "set:chat.json image:chb_9_select",
        "point": "set:chat.json image:img_9_reddot"
      },
      {
        "tabName": "ui.chat.chatMsgType7",
        "nameSColor": "DFE6F3",
        "nameNColor": "111111",
        "normal": "",
        "select": "set:chat.json image:chb_9_select",
        "point": "set:chat.json image:img_9_reddot"
      },
      {
        "tabName": "ui.chat.chatMsgType8",
        "nameSColor": "DFE6F3",
        "nameNColor": "111111",
        "normal": "",
        "select": "set:chat.json image:chb_9_select",
        "point": "set:chat.json image:img_9_reddot"
      },
      {
        "tabName": "ui.chat.chatMsgType9",
        "nameSColor": "DFE6F3",
        "nameNColor": "111111",
        "normal": "",
        "select": "set:chat.json image:chb_9_select",
        "point": "set:chat.json image:img_9_reddot"
      }
    ],
    "?maxChatsCnt": "单位：条，聊天队列最大数",
    "maxChatsCnt": 200,
    "?hideWaitTime": "单位：s，丢失焦点后的隐藏时间",
    "hideWaitTime": 10,
    "?voiceMaxTime": "单位：s，最长语音时间，默认59s",
    "voiceMaxTime": 59,
    "?voiceLastTime": "单位：s，语音倒计时开始时间，默认10s",
    "voiceLastTime": 10,
    "?maxMsgSize": "单位：条，文字聊天最大长度，中文算2，不填默认150条",
    "maxMsgSize": 150,
    "?duration": "发送语音间隔事件",
    "duration": 1,
    "?freeSoundPerDay": "每日免费语音次数",
    "freeSoundPerDay": 5,
    "infoSetting": {
      "?lvKey": "playerLevel"
    },
    "?emojiSendLimit": "表情发送限制,例:15秒内发3次表情后，进入30秒cd",
    "emojiSendLimit":{
      "limitTime": 15,
      "limitTimes": 3,
      "cdTime": 30
    },
    "?chatBubbleSetting": "聊天头顶气泡配置:停留时间（毫秒），每行字数，字体大小,头顶位置",
    "chatBubbleSetting": {
      "time": 10000,
      "size": 40,
      "font": "HT24",
      "offsetY": 0.5
    }
    "?isShowProfileBtn": "是否显示我的资料按钮",
    "isShowProfileBtn": true,
    "?isShowAddFriendBtn": "是否显示添加好友按钮",
    "isShowAddFriendBtn": true,
    "?chatTagSetting": "聊天好友标签相关配置",
    "chatTagSetting":
    {
      "?selectTagMax": "能选择的总标签数",
      "selectTagMax": 12,
      "1": {
        "tagTypeRes": "set:chat.json image:img_9_tag_blue",
        "tagTypeName": "ui.chat.profile.tagTypeName1",
        "tagTypeColor": "3295e0"
      },
      "2": {
        "tagTypeRes": "set:chat.json image:img_9_tag_green",
        "tagTypeName": "ui.chat.profile.tagTypeName2",
        "tagTypeColor": "359559"
      },
      "3": {
        "tagTypeRes": "set:chat.json image:img_9_tag_purple",
        "tagTypeName": "ui.chat.profile.tagTypeName3",
        "tagTypeColor": "d917c9"
      },
      "4": {
        "tagTypeRes": "set:chat.json image:img_9_tag_yellow",
        "tagTypeName": "ui.chat.profile.tagTypeName4",
        "tagTypeColor": "eea036"
      }
    },
      "?isShowMiniSizeBtn": "是否显示聊天小窗收缩按钮",
    "isShowMiniSizeBtn": true,
    "?isShowPlayerAddBtn": "是否好友名片添加好友按钮",
    "isShowPlayerAddBtn": true,
    "?isShowPlayerDelBtn": "是否好友名片删除好友按钮",
    "isShowPlayerDelBtn": true,
    "?isShowChatBtn": "是否显示小窗口旁的聊天按钮",
    "isShowChatBtn": true,
    "?isShowFriendBtn": "是否显示小窗口旁的好友按钮",
    "isShowFriendBtn": true
    "?isShowVoiceBtn": "是否显示小窗口旁的语音按钮",
    "isShowVoiceBtn": true
    "?isShowChannel": "聊天小窗是否显示前缀信息",
    "isShowChannel": true,
    "?onlineUpdateTime": "在线状态更新数据更新间隔单位秒",
    "onlineUpdateTime": 180
    "isShowAutoPlayVoice": false,
    "?isOpenTagFunction": "是否开放标签功能",
    "isOpenTagFunction": false
     "?isShowLanguage": "好友列表item是否显示语言",
    "isShowLanguage": false,
    "?miniChatNameMaxLen": "聊天小窗玩家名字显示的长度",
    "miniChatNameMaxLen":7,
     "?isShowTeamHallBtn": "是否显示组队大厅按钮",
    "isShowTeamHallBtn": true,
    }
  },
]]

World.cfg.chatSetting = World.cfg.chatSetting or {}

require "common.chat_define"
require "common.chat_event"
require "common.chat_entity"
require "common.config.voice_shop_config"
require "common.config.emoji_config"
require "common.config.short_config"
require "common.config.tags_config"
require "common.config.tags_auto_config"

require "player.player_chat"
require "player.player_chat_packet"
require "player.player_chat_friend"
require "player.player_chat_tags"

if World.isClient then
    require "entity.entity_chat"
    require "chat_manager"
    require "gm_chat"
    require "player_spinfo_manager"
    require "async_process_tags"
    require "async_process_friend"

    ---加载插件资源,兼容移动编辑器World.cfg.plugins没有聊天，但子游戏有聊天插件的资源加载
    for _, loc in pairs(FileResourceManager:Instance():GetGameCustomFileNameIndexFolderList()) do
        ResourceGroupManager:Instance():addResourceLocation(Root.Instance():getRootPath(), "Media/PluginRes/" .. "platform_chat" .. "/" .. loc, "FileSystem", "General")
    end

    Lib.subscribeEvent(Event.EVENT_PLAYER_STATUS, function(status, uId, uName)
        --Profiler:begin("checkIsOpenChatBar")
        if status == 0 and uId == Me.platformUserId then
            Me:initClientFriendInfo()
            Me:checkIsOpenChatBar()
        end
        -- Me.testCurTime = os.clock()
        --Profiler:finish("checkIsOpenChatBar")
    end)
else
    require "player_spinfo_manager"
    require "async_process.async_process_chat"
    require "async_process.async_process_friend"
    require "async_process.async_process_tags"
    require "gm_chat"
end

local handlers = {}

function handlers.defaultSetting()
    return {
        settingKey = "chatSetting",
        maxHistory = 10,
        infoButtons = {
            {
                name = "ui.chat.player_private",
                image= "set:chat.json image:btn_9_adddot",
                clickEvent= {
                    isClient = true,
                    name = "EVENT_OPEN_PRIVATE_CHAT"
                }
            },
            {
                name = "ui.chat.invite",
                image = "set:chat.json image:btn_9_adddot",
                clickEvent = {
                    isClient = true,
                    name = "EVENT_INVITE_GAME"
                }
            }
        },
        refreshFriendTime = 60,
        chatBar = true,
        chatBarPos = { 0, 0 },
        chatLevel = 50,
        chatTabList = {1,3,5,8},
        miniMsgShowList = {1,3,5,8},
        chatBarRedShow = { 6 },
        emojiTabList = {1},
        alignment = {
            horizontalAlignment = 1,
            verticalAlignment = 2,
            offset = { 0, 0, 0, -19 },
            miniSize = { 500, 90, 280 },
            barOffset = { 0, -400, 0, -24, -24}
        },
        chtBarHeight = 23,
        miniContentSpacing = -5,
        chatFont = "HT16",
        chatFontColor = "ffffff",
        miniFontColorUsePre = true,
        mainNickFontColor = "ffffff",
        mainSelfFontColor = "000000",
        chatHeadColor = {"FFA500", "00FFFF", "FFC0CB", "FF5ED5", "CD5C5C", "FFFF00"},
        chatMainSelfVoiceColor = "000000",
        chatMainOtherVoiceColor = "ffffff",
        chatMiniVoiceColor = "39f3ff",
        voicePlayNormalRes = "set:chat.json image:ipt_9_normal",
        voicePlayPushRes = "set:chat.json image:ipt_9_hover",
        chatTypeColor = { "ffffff", "00ff00", "d39655", "ffffff", "39F3FF", "6bb54b", "6bb54b", "6bb54b", "6bb54b"},
        tabIcon = {
            {
                tabName = "ui.chat.chatMsgType1",
                nameSColor = "17FFFF",
                nameNColor = "DFE6F3",
                normal = "",
                select = "set:chat.json image:chb_9_select",
                point = "set:chat.json image:img_9_reddot"
            },
            {
                tabName = "ui.chat.chatMsgType2",
                nameSColor = "17FFFF",
                nameNColor = "DFE6F3",
                normal = "",
                select = "set:chat.json image:chb_9_select",
                point = "set:chat.json image:img_9_reddot"
            },
            {
                tabName = "ui.chat.chatMsgType3",
                nameSColor = "17FFFF",
                nameNColor = "DFE6F3",
                normal = "",
                select = "set:chat.json image:chb_9_select",
                point = "set:chat.json image:img_9_reddot"
            },
            {
                tabName = "ui.chat.chatMsgType4",
                nameSColor = "17FFFF",
                nameNColor = "DFE6F3",
                normal = "",
                select = "set:chat.json image:chb_9_select",
                point = "set:chat.json image:img_9_reddot"
            },
            {
                tabName = "ui.chat.chatMsgType5",
                nameSColor = "17FFFF",
                nameNColor = "DFE6F3",
                normal = "",
                select = "set:chat.json image:chb_9_select",
                point = "set:chat.json image:img_9_reddot"
            },
            {
                tabName = "ui.chat.chatMsgType6",
                nameSColor = "17FFFF",
                nameNColor = "DFE6F3",
                normal = "",
                select = "set:chat.json image:chb_9_select",
                point = "set:chat.json image:img_9_reddot"
            },
            {
                tabName = "ui.chat.chatMsgType7",
                nameSColor = "17FFFF",
                nameNColor = "DFE6F3",
                normal = "",
                select = "set:chat.json image:chb_9_select",
                point = "set:chat.json image:img_9_reddot"
            },
            {
                tabName = "ui.chat.chatMsgType8",
                nameSColor = "17FFFF",
                nameNColor = "DFE6F3",
                normal = "",
                select = "set:chat.json image:chb_9_select",
                point = "set:chat.json image:img_9_reddot"
            },
            {
                tabName = "ui.chat.chatMsgType9",
                nameSColor = "17FFFF",
                nameNColor = "DFE6F3",
                normal = "",
                select = "set:chat.json image:chb_9_select",
                point = "set:chat.json image:img_9_reddot"
            }
        },
        maxChatsCnt = 200,
        hideWaitTime = 10,
        voiceMaxTime = 59,
        voiceLastTime = 10,
        maxMsgSize = 80,
        duration = 2.5,
        freeSoundPerDay = 15,
        infoSetting = {
            _lvKey = "playerLevel"
        },
        emojiSendLimit = {
            limitTime = 10,
            limitTimes = 3,
            cdTime = 30
        },
        chatBubbleSetting = {
            time = 10000,
            size = 40,
            font = "HT24",
            offsetY = 0.5
        },
        isShowProfileBtn = false,
        isShowAddFriendBtn = false,
        chatTagSetting =
        {
            selectTagMax= 12,
            ["1"]= {
                tagTypeRes= "set:chat.json image:img_9_tag_blue",
                tagTypeName= "ui.chat.profile.tagTypeName1",
                tagTypeColor= "3295e0"
            },
            ["2"]= {
                tagTypeRes= "set:chat.json image:img_9_tag_green",
                tagTypeName= "ui.chat.profile.tagTypeName2",
                tagTypeColor= "359559"
            },
            ["3"]= {
                tagTypeRes= "set:chat.json image:img_9_tag_purple",
                tagTypeName= "ui.chat.profile.tagTypeName3",
                tagTypeColor= "d917c9"
            },
            ["4"]= {
                tagTypeRes= "set:chat.json image:img_9_tag_yellow",
                tagTypeName= "ui.chat.profile.tagTypeName4",
                tagTypeColor= "eea036"
            }
        },
        isShowMiniSizeBtn = true,
        isShowPlayerAddBtn = true,
        isShowPlayerDelBtn = true,
        isShowChatBtn = false,
        isShowFriendBtn = false,
        isShowVoiceBtn = true,
        isShowChannel = false,
        onlineUpdateTime = 180,
        isShowAutoPlayVoice = false,
        isOpenTagFunction = false,
        isShowLanguage = true,
        miniChatNameMaxLen = 24,
        isOpenChatHeadColor = true,
        isShowTeamHallBtn = true,
    }
end

---@param player Player
function handlers.OnPlayerLogin(player)
    -- 服务端登陆
    player:loginRequestFriendInfo()
    player:requestWebThePlayGameTimes(player.platformUserId)
    player:updateFreeSoundFlag()
    player:loginUpdateNewConditionTags()
end

function handlers.onGameReady()
    CGame.instance:getShellInterface():onGetTalkList(0, World.cfg.chatSetting.maxHistory or 10)
    local UIChatManage = T(UIMgr, "UIChatManage")
    UIChatManage:init()
end

---@param player Player
function handlers.OnPlayerSaveDB(player)

    local PlayerSpInfoManager = T(Lib, "PlayerSpInfoManager")
    PlayerSpInfoManager:savePlayerSpInfoById(player.platformUserId)
end

---@param userId userId
function handlers.OnPlayerSaveDBByUserId(userId)

    local PlayerSpInfoManager = T(Lib, "PlayerSpInfoManager")
    PlayerSpInfoManager:savePlayerSpInfoById(userId)
end

--- 外部调用的打开聊天界面
function handlers.openChatWndByType(chatWinSizeType)
    --- @type UIChatManage
    local UIChatManage = T(UIMgr, "UIChatManage")
    UIChatManage:showChatViewByType(chatWinSizeType)
end

---发送系统消息
function handlers.sendOneSystemMsg(content, msgPack)
    if World.isClient then
        --- @type UIChatManage
        local UIChatManage = T(UIMgr, "UIChatManage")
        UIChatManage:sendChatSystemMsg(Define.Page.SYSTEM, content, msgPack)
    else
        local msg = {}
        if type(content) == "table" then
            for k, m in pairs(content) do
                msg[k] = World.CurWorld:filterWord(m)
                if not msg[k] or utf8.len(msg[k]) > 1000 then
                    return
                end
            end
        else
            local msg = World.CurWorld:filterWord(content)
            if not msg or utf8.len(msg) > 1000 then
                return
            end
        end

        local packet = {
            pid = "ChatSystemMessage",
            msg = msg,
            args = table.pack(nil, nil, Define.Page.SYSTEM),
            msgPack = msgPack
        }
        WorldServer.BroadcastPacket(packet)
    end
end

function handlers.systemMsgOne(player, msg, msgPack)
    local args = table.pack(nil, nil, Define.Page.SYSTEM)
    if World.isClient then
        if not player:isOpenedChatTabType(args[3]) then
            return
        end
        msg = Lang:toText(msg)
        Lib.emitEvent(Event.EVENT_CHAT_MESSAGE, msg, nil, nil, false, args, nil, msgPack)
    else
        local packet = {
            pid = "ChatSystemMessage",
            msg = msg,
            args = args,
            msgPack = msgPack
        }
        player:sendPacket(packet)
    end
end

---组队邀请喊话
function handlers.sendTeamChatInviteMsg(teamInviteData)
    --- @type UIChatManage
    local UIChatManage = T(UIMgr, "UIChatManage")
    UIChatManage:sendTeamChatInviteMsg(teamInviteData)
end

---发送邀请同玩消息
function handlers.sendInviteMsg(userId)
    --- @type UIChatManage
    local UIChatManage = T(UIMgr, "UIChatManage")
    UIChatManage:sendInviteMsg(userId)
end

---设置小聊天框布局
function handlers.setMiniChatAlignmentType(horizontalType, verticalType, offset, barOffset)
    Lib.emitEvent(Event.EVENT_SET_CHAT_ALIGNMENT, horizontalType, verticalType, offset, barOffset)
end

---收到平台的私聊消息
function handlers.receivePlatformPrivateMsg(sourceType, messageType, content)
    --- @type UIChatManage
    local UIChatManage = T(UIMgr, "UIChatManage")
    UIChatManage:receivePlatformPrivateMsg(sourceType, messageType, content)
end
--玩家登陆时拉取玩家好友私聊的历史消息记录表列表
function handlers.receiveHistoryTalkList(listInfo)
    --- @type UIChatManage
    local UIChatManage = T(UIMgr, "UIChatManage")
    UIChatManage:receiveHistoryTalkList(listInfo)
end
--返回玩家与目标好友的详细私聊记录
function handlers.receiveHistoryTalkDetail(targetId, detailContent)
    --- @type UIChatManage
    local UIChatManage = T(UIMgr, "UIChatManage")
    UIChatManage:receiveHistoryTalkDetail(targetId, detailContent)
end


--- 设置玩家特殊消息keyValue存储
---@param userId string
---@param key string
---@param userId any
function handlers.setPlayerSpKeyValueById(userId,key,val,cb)
    --- @type PlayerSpInfoManager
    local PlayerSpInfoManager = T(Lib, "PlayerSpInfoManager")
    PlayerSpInfoManager:setPlayerSpKeyValueById(userId,key,val,cb)
    --Plugins.CallTargetPluginFunc("platform_chat", "setPlayerSpKeyValueById", userID,key,val)
end
---獲取玩家特殊消息
---@param userId string
---@param cb function
function handlers.getPlayerSpDataById(userId,cb, useClientCache)
    --- @type PlayerSpInfoManager
    local PlayerSpInfoManager = T(Lib, "PlayerSpInfoManager")
    PlayerSpInfoManager:getPlayerSpDataById(userId,cb, useClientCache)
    --Plugins.CallTargetPluginFunc("platform_chat", "setPlayerSpKeyValueById", userID,key,val)
end

--- 服务端调用增加亲密度
------@param userId1 number
-----@param userId2 number
-----@param val number
function handlers.addSpDataIntimacyValById(userId1, userId2, val)
    --- @type PlayerSpInfoManager
    local PlayerSpInfoManager = T(Lib, "PlayerSpInfoManager")
    PlayerSpInfoManager:addSpDataIntimacyValById(userId1, userId2, val)
end

--- 服务端调用设置亲密度
------@param userId1 number
-----@param userId2 number
-----@param val number
function handlers.setSpDataIntimacyValById(userId1, userId2, val)
    --- @type PlayerSpInfoManager
    local PlayerSpInfoManager = T(Lib, "PlayerSpInfoManager")
    PlayerSpInfoManager:setSpDataIntimacyValById(userId1, userId2, val)
end

---客户端批量獲取玩家特殊消息
---@param userIds table
---@param cb function
function handlers.getPlayerSpDataListById(userIds,cb)
    --- @type PlayerSpInfoManager
    local PlayerSpInfoManager = T(Lib, "PlayerSpInfoManager")
    PlayerSpInfoManager:getPlayerSpDataListById(userIds,cb)
end

--- 增加玩家标签
--- @param tagsList table
function handlers.addPlayerTagsList(tagsList)
    Me:operateAddPlayerTags(tagsList)
end

--- 删除玩家标签
--- @param tagsList table
function handlers.deletePlayerTagsList(tagsList)
    Me:operateDeletePlayerTags(tagsList)
end

--- 增加条件标签次数
--- @param player table
--- @param condition number
--- @param counts number
function handlers.addConditionAutoCounts(player, condition, counts)
    player:addConditionAutoCounts(condition, counts)
end

--- 设置条件标签次数
--- @param player table
--- @param condition number
--- @param counts number
function handlers.updateConditionAutoCounts(player, condition, counts)
    player:updateConditionAutoCounts(condition, counts)
end

--- 获取推荐好友列表
------@param callFunc function
function handlers.getRecommendFriendList(player, callFunc)
    player:getRecommendFriendList(callFunc)
end

--- 标签推荐玩家，划掉某些用户
------@param index number
function handlers.operateDisLikeUser(player, index)
    player:operateDisLikeUser(index)
end

--- 搜索好友
---@param searchTxt string
---@param callFunc function
function handlers.operateSearchUser(player, searchTxt, callFunc)
    player:operateSearchUser(searchTxt, callFunc)
end

--- 请求同玩、非同玩好友列表
function handlers.operateRequestServerFriendInfo(friendType, pageNum)
    Me:doRequestServerFriendInfo(friendType, pageNum)
end
--- 提供外部调用接口，给某个玩家发送一条私聊信息，客户端调用
function handlers.doSendPrivateChatMsg(userId, msg, emoji)
    --- @type UIChatManage
    local UIChatManage = T(UIMgr, "UIChatManage")
    UIChatManage:requestAppSendOnePrivate(userId, msg, emoji)
end

-- 外部服务器调用的，给某个玩家发送一条私聊信息
function handlers.pushClientSendPrivateChatEmoji(player, userId)
    if not World.isClient then
        player:sendPacket({
            pid = "PushClientSendPrivateChatEmoji",
            senderId = userId,
        })
    end
end

--- 提供外部调用接口，给某个玩家发送一条私聊表情,客户端调用
function handlers.doSendPrivateChatEmoji(userId, emojiIcon)
    local emojiInfo = {type = Define.chatEmojiTab.FACE}
    if emojiIcon then
        emojiInfo = {
            type = Define.chatEmojiTab.FACE,
            emojiData = emojiIcon
        }
    else
        local EmojiConfig = T(Config, "EmojiConfig")
        local allEmojiCfg = EmojiConfig:getItems()
        local icon = allEmojiCfg[math.random(1, #allEmojiCfg)].icon

        emojiInfo = {
            type = Define.chatEmojiTab.FACE,
            emojiData = icon
        }
    end
    --- @type UIChatManage
    local UIChatManage = T(UIMgr, "UIChatManage")
    UIChatManage:requestAppSendOnePrivate(userId, "", emojiInfo)
end

--- 提供外部客户端调用接口，给某个玩家发送一条聊天信息，客户端调用
function handlers.doRequestServerSendChatMsg(curTab, msg, time, emoji)
    if World.isClient then
        --- @type UIChatManage
        local UIChatManage = T(UIMgr, "UIChatManage")
        UIChatManage:requestServerSendChatMsg(curTab, msg, time, emoji)
    end
end

--- 外部客户端调用的批量获取标签的接口
---@param userIds table
---@param callFunc function
function handlers.getPlayerListChatTagData(userIds, callFunc)
    AsyncProcess.GetPlayerListTagData(userIds,function(data)
        if callFunc then
            callFunc(data)
        end
    end)
end

--- 外部客户端调用的批量获取玩家在线状态的接口
---@param userIds table
---@param callFunc function
function handlers.getPlayerListOnlineState(userIds, callFunc)
    AsyncProcess.GetPlayerOnlineState(userIds, function(data)
        if callFunc then
            callFunc(data)
        end
    end)
end

--- 外部调用的获取玩家是否是我的好友的接口
---@param userId number
---@param callFunc function
function handlers.checkOnePlayerIsMyFriend(userId, callFunc, player)
    if World.isClient then
        if callFunc then
            callFunc(Me:checkPlayerIsMyFriend(userId))
        end
        --if Me:checkPlayerIsMyFriend(userId) then
        --    if callFunc then
        --        callFunc(Me:checkPlayerIsMyFriend(userId))
        --    end
        --else
        --    AsyncProcess.CheckClientPlayerIsMyFriend(userId, function(data)
        --        local isMyFriend = data.status ~= 0
        --        if isMyFriend then
        --            Me:addPlayerFriendFromExist(userId, data.status)
        --        else
        --            Me:removePlayerFriendFromExist(userId)
        --        end
        --        callFunc(data.status)
        --    end)
        --end
    else
        if callFunc then
            callFunc(player:checkPlayerIsMyFriend(userId))
        end
    end
end

--- 外部客户端调用的获取玩家是否是我的好友的接口,无回调直接返回true or false
---@param userId number
function handlers.checkPlayerIsMyChatFriend(userId, player)
    if World.isClient then
        local state = Me:checkPlayerIsMyFriend(userId)
        if (state == Define.friendStatus.gameFriend) or (state == Define.friendStatus.platformFriend) then
            return state
        end
    else
        local state = player:checkPlayerIsMyFriend(userId)
        if (state == Define.friendStatus.gameFriend) or (state == Define.friendStatus.platformFriend) then
            return state
        end
    end
    return false
end

--- 外部客户端调用的打开玩家详情界面
---@param userId number
function handlers.openPlayerDetailWnd(userId)
    if World.isClient then
        Lib.emitEvent(Event.EVENT_OPEN_PLAYER_INFORMATION, userId)
    end
end

--- 外部客户端调用的打开玩家名片界面，玩家互动界面
---@param userId number
function handlers.openChatPlayerInfoWnd(userId)
    if World.isClient then
        --- @type UIChatManage
        local UIChatManage = T(UIMgr, "UIChatManage")
        UIChatManage:openChatPlayerInfoWnd(userId)
    end
end

--- 外部客户端调用的打开玩家名片界面，玩家互动界面
---@param userIds number[]
function handlers.getPlayerSpDataByIdList(userIds, cb)
    --- @type PlayerSpInfoManager
    local PlayerSpInfoManager = T(Lib, "PlayerSpInfoManager")
    PlayerSpInfoManager:getPlayerSpDataByIdList(userIds, cb)
end

--- 外部调用获取当前好友总数（平台好友、同玩好友）
function handlers.getPlayerFriendsNum(player, friendType)
    if not World.isClient then
        return player:getPlayerFriendsNum(friendType)
    end
end

return function(name, ...)
    if type(handlers[name]) ~= "function" then
        return
    end
    return handlers[name](...)
end