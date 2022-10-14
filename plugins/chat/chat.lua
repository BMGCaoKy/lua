
--[[
     "chatSetting": {
        "infoButtons":[

        ],
        "?chatLevel": "聊天界面层级，默��8，入口以��1，喇叭商店以��2",
        "chatLevel": 48,
        "?chatBar": "独立聊天入口，默认关��,
        "chatBar": false,
        "?chatBarPos":"聊天入口位置，左上对齐，绝对坐标[x, y]",
        "chatBarPos":[355, 647],
        "?alignment": "布局方式：目前支持LT左上对齐，CB居中向下对齐,默认CB(只显示消息的小窗),miniSize[�� 小版的高, 大版的高]",
        "alignment": {
            "type":"CB",
            "offset":[
                0,0,0,-20
            ],
            "miniSize":[449, 203, 336]
        },
        "?chtBarHeight": "单行聊天高度，不填默��8",
        "chtBarHeight": 35,
        "?chatFont": "聊天字体，默认HT16",
        "chatFont": "PKM16",
        "?chatFontColor": "聊天文字颜色（不填则为黑色）",
        "chatFontColor": "000000",
        "?chatNiceNameColor": "聊天普通人名文字颜色（不填则为红色��,
        "chatNiceNameColor": "ff0000",
        "?chatSystemColor": "聊天系统颜色",
        "chatSystemColor": "000000",
        "?chatVoiceColor": "聊天语音小天线颜色、语音时长颜色",
        "chatVoiceColor": "8e4e16",
        "?familyVal": "家族面板读取的valueDef键名，如不填则不会出现家族分��,
        "familyVal": "curManorType",
        "?privateChannel":"私聊分页，默认false",
        "privateChannel":false,
        "?familyIcon": "使用valueDef同步回调时机修改，如业务重写请自行派发Lib.emitEvent(Event.EVENT_FAMILY_ICON_CHANGE, value)",
        "familyIcon": {
            "1": {
                "normal": "set:chat_main.json image:icon_history_n",
                "select": "set:chat_main.json image:icon_history_s"
            },
            "2": {
                "normal": "set:chat_main.json image:icon_common_chat_n",
                "select": "set:chat_main.json image:icon_common_chat_s"
            }
        },
        "tabBgImg": {
            "normal": "set:chat_main.json image:bg_page_normal_s",
            "select": "set:chat_main.json image:bg_page_n"
        },
        "?tabIcon":"顺序为公屏，阵营，历史，私聊",
        "tabIcon": [
            {
                "normal": "set:chat_main.json image:icon_common_chat_n",
                "select": "set:chat_main.json image:icon_common_chat_s",
                "point": "set:chat_main.json image:icon_chat_point"
            },
            {
                "normal": "set:chat_main.json image:icon_common_chat_n",
                "select": "set:chat_main.json image:icon_common_chat_s",
                "point": "set:chat_main.json image:icon_family_point"
            },
            {
                "normal": "set:chat_main.json image:icon_history_n",
                "select": "set:chat_main.json image:icon_history_s",
                "point": "set:chat_main.json image:icon_private_point"
            },
            {
                "normal": "set:chat_main.json image:icon_private_chat_n",
                "select": "set:chat_main.json image:icon_private_chat_s",
                "point": "set:chat_main.json image:icon_private_point"
            }
        ],
        "?maxChatsCnt": "单位：条，聊天队列最大数",
        "maxChatsCnt": 200,
        "?hideWaitTime": "单位：s，丢失焦点后的隐藏时��,
        "hideWaitTime": 10,
        "?voiceMaxTime": "单位：s，最长语音时间，默认59s",
        "voiceMaxTime": 59,
        "?voiceLastTime": "单位：s，语音倒计时开始时间，默认10s",
        "voiceLastTime": 10,
        "?maxMsgSize": "单位：条，文字聊天最大长度，中文��，不填默��50��,
        "maxMsgSize": 150,
        "?duration": "发送语音间隔事��,
        "duration": 3,
        "?freeSoundPerDay": "每日免费语音次数",
        "freeSoundPerDay": 5
        "?emojiSendLimit": "表情发送限制,例:15秒内发3次表情后，进入30秒cd",
        "emojiSendLimit":{
            limitTime = 15,
            limitTimes = 3,
            cdTime = 30
        },
        "?chatHeadColor": "玩家在此房间第一次发言时，玩家名字颜色，此后该玩家在本房间发言，其名字颜色均为该颜色（包括括号与冒号，[名字]:）",
        "chatHeadColor": ["FFA500", "0000FF", "FFC0CB", "800080", "FF0000", "008000"],
        "?chatBubbleSetting": "聊天头顶气泡配置:停留时间（毫秒），每行字数，字体大小",
        "chatBubbleSetting": {
            "time": 10000,
            "size": 40,
            "font": "HT24",
        },
        "?chatSelfNameColor": "自己名字颜色",
        "chatSelfNameColor": "33BD41"
    },
]]
require "common.chat_define"
require "common.chat_event"
require "common.chat_entity"
require "common.config.voice_shop_config"
require "common.config.emoji_config"
require "common.config.short_config"

require "player.player_chat"
require "player.player_chat_packet"



if World.isClient then
    require "entity.entity_chat"
    require "gm_chat"
    Lib.subscribeEvent(Event.EVENT_PLAYER_STATUS, function(status, uId, uName)
        if status == 0 and uId == Me.platformUserId then
            if World.cfg.chatSetting and World.cfg.chatSetting.chatBar then
                UIMgr:registerOpenWindow("chatBar", function()
                    UIMgr:registerOpenWindow("chatMain", function()
                        UI:getWnd("chatMain"):setShowMode(false)
                    end)
                end)
            else
                UIMgr:registerWindow("chatMain")
                --UI:getWnd()
            end
        end
    end)
else
    require "async_process.async_process_chat"
end

local handlers = {}

function handlers.onPlayerReady(player)
    Lib.logDebug("chat onPlayerReady")
    --World.Timer(20,function()
    --    if player.platformUserId then
    --        AsyncProcess.GetVoiceInfo(player.platformUserId)
    --    end
    --end)
end

function handlers.onPlayerLogout(player)
    --if player.platformUserId then
    --    AsyncProcess.SetVoiceInfo(player)
    --end
end

return function(name, ...)
    if type(handlers[name]) ~= "function" then
        return
    end
    handlers[name](...)
end