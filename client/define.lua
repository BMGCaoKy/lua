---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by wangpq.
--- DateTime: 2020/6/30 20:27
---
-- app invoke game interface action type
Define.GameActionType =
{
    GAME_ACTION_REFRESH_DRESS = 1,  -- refresh dress
    GAME_ACTION_ENABLE_INDIE = 2, -- enable indie
    GAME_ACTION_DISABLE_RECHARGE = 3, --disable recharge
    GAME_ACTION_SHOW_VIDEO_AD = 4, -- show video ad
    GAME_ACTION_HIDE_VIDEO_AD = 5, -- hide video ad
    GAME_ACTION_SHOW_EMAIL_RED = 6, -- show email red point
    GAME_ACTION_HIDE_EMAIL_RED = 7, -- hide email red point
    GAME_ACTION_SHOW_FRIEND_RED = 8, -- show friend red point
    GAME_ACTION_HIDE_FRIEND_RED = 9, -- hide friend red point
    GAME_ACTION_NOT_REMIND_FALSE = 10, --get NotShowDiamondBlueLackTips false
    GAME_ACTION_NOT_REMIND_TRUE = 11, --get NotShowDiamondBlueLackTips true
    GAME_ACTION_REFRESH_PROPS = 12, -- refresh props
    GAME_ACTION_EXTRA_PARAMS = 13, -- extra params
    GAME_ACTION_DATA_FUNCTION = 10000, -- call data func
    GAME_ACTION_JSON_FUNCTION = 10001, -- call json func
};