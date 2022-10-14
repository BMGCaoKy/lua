Define.ChatMsgType = {
    common         = 1,
    family         = 2,
    private        = 3
}
Define.ChatPlayerType = {
    vip               = 1,
    svip              = 2,
    server            = 3
}
Define.Page = {
    COMMON = 1,     -- 世界
    FAMILY = 2,     -- 家族
    PRIVATE = 3,    -- 私聊
    MAP_CHAT = 4,   -- 当前
    SYSTEM = 5,     -- 系统
    TEAM = 6,       -- 组队
    CAREER = 7,        -- 职业
    FRIEND = 8,        -- 好友
    NEAR = 9,        -- 附近的人
}

-- 当前聊天窗口类型
Define.chatWinSizeType = {
    noChatWnd = 0,        --关闭状态
    mainChat = 1,      --聊天主界面
    bigMiniChat = 2,      --聊天大mini界面
    smallMiniChat = 3       --聊天小mini界面
}

Define.ChatViewStatus = {
    Hide = 1,
    Main = 2,
    Mini = 3
}

-- 好友list类型，获取好友列表的时候用
Define.chatFriendType = {
    platform = 0,      --平台好友,非同玩好友
    game = 1,      --同玩好友
    apply = 2,        -- 好友申请
}
-- 从平台一次拉取的好友数量
Define.friendOnceRequestNum = 10

-- 好友类型,判断是不是好友的时候用
Define.friendStatus = {
    notFriend = 0,      -- 非好友
    platformFriend = 1,      -- 平台好友
    gameFriend = 2,        -- 同玩好友
}

-- 表情tab类型
Define.chatEmojiTab = {
    FACE = 1,     -- 表情
    GOODS = 2,    --物品
    PET = 3,      --宠物
    SHORT = 4,      -- 快捷短语
}

-- 聊天主界面信息Item类型
Define.chatMainContentType = {
    normalEx = 1,     -- 普通信息
    goodEx = 2,    -- 物品链接
    petEx = 3,      --宠物链接
    teamEx = 4,      --组队邀请
    systemEx = 5,      --系统消息
}

-- 私聊消息类型
Define.privateMessageType = {
    txtMsg = 0,        -- 文本消息
    imageMsg = 1,      -- 图片消息
    voiceMsg = 2,      --语音消息
    videoMsg = 3,      --视频消息
    emojiMsg = 4,      --游戏表情消息
    inviteMsg = 5,      --邀请进入游戏消息
}

-- 私聊消息来源
Define.privateMessageSource = {
    gameMsg = "source_game",        -- 游戏消息
    platformMsg = "",      -- 平台消息
}

Define.MainChatMaxCnt = 50       --主聊天界面显示的最大消息数
Define.miniChatMaxCnt = 200          --聊天小窗显示的最大消息数


--=====================================================================
--标签相关
--=====================================================================

-- 标签大类型
Define.tagKindType = {
    rabbit = 1,        -- 游戏
    hobby = 2,      -- 爱好
    personality = 3,      -- 个性
    feature = 4,      -- 特征
}

Define.tagConditionType = {
    talk = 1,               -- 1：在所有频道发言总数
    friend = 2,             -- 2：拥有好友数量
    pvp = 3,                -- 3：参与pvp次数
    fight = 4,              -- 	4：参与战斗次数
    money = 5,              -- 5：消费金魔方数量
}