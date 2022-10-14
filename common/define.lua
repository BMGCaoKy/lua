Define = {}

Define.TRAY_CLASS_BAG	= "bag"
Define.TRAY_CLASS_EQUIP	= "equip"
Define.TRAY_CLASS_IMPRINT	= "imprint"

-- 容器类型(和配置对应)
Define.TRAY_TYPE = {
	BAG					= 0,
	EXTRA_BAG			= 1000,  --强制加item到背包时，背包不足临时存放的地方
	HAND_BAG			= 20,	--????????

	--扩充新的背包，用于特殊物品专属的背包存放位置
	EXTEND_BAG_1		= 21,
	EXTEND_BAG_2		= 22,
	EXTEND_BAG_3		= 23,
	EXTEND_BAG_4		= 24,
	EXTEND_BAG_5		= 25,
	EXTEND_BAG_6		= 26,


	EQUIP_1				= 1,
	EQUIP_2				= 2,
	EQUIP_3				= 3,
	EQUIP_4				= 4,
	EQUIP_5				= 5,
	EQUIP_6				= 6,
	EQUIP_7				= 7,
	EQUIP_8				= 8,
    EQUIP_9				= 9,

	EQUIP_10			= 10,
	EQUIP_11			= 11,
	EQUIP_12			= 12,

}

-- 容器逻辑 class
Define.TRAY_TYPE_CLASS = {
	[Define.TRAY_TYPE.BAG]	= Define.TRAY_CLASS_BAG,

	[Define.TRAY_TYPE.EQUIP_1]	= Define.TRAY_CLASS_EQUIP,
	[Define.TRAY_TYPE.EQUIP_2]	= Define.TRAY_CLASS_EQUIP,
	[Define.TRAY_TYPE.EQUIP_3]	= Define.TRAY_CLASS_EQUIP,
	[Define.TRAY_TYPE.EQUIP_4]	= Define.TRAY_CLASS_EQUIP,
	[Define.TRAY_TYPE.EQUIP_5]	= Define.TRAY_CLASS_EQUIP,
	[Define.TRAY_TYPE.EQUIP_6]	= Define.TRAY_CLASS_EQUIP,
	[Define.TRAY_TYPE.EQUIP_7]	= Define.TRAY_CLASS_EQUIP,
	[Define.TRAY_TYPE.EQUIP_8]	= Define.TRAY_CLASS_EQUIP,
    [Define.TRAY_TYPE.EQUIP_9]	= Define.TRAY_CLASS_EQUIP,

	[Define.TRAY_TYPE.EQUIP_10]	= Define.TRAY_CLASS_IMPRINT,
	[Define.TRAY_TYPE.EQUIP_11]	= Define.TRAY_CLASS_IMPRINT,
	[Define.TRAY_TYPE.EQUIP_12]	= Define.TRAY_CLASS_IMPRINT,

	[Define.TRAY_TYPE.HAND_BAG]	= Define.TRAY_CLASS_BAG,
	[Define.TRAY_TYPE.EXTRA_BAG] = Define.TRAY_CLASS_BAG,
	[Define.TRAY_TYPE.EXTEND_BAG_1] = Define.TRAY_CLASS_BAG,
	[Define.TRAY_TYPE.EXTEND_BAG_2] = Define.TRAY_CLASS_BAG,
	[Define.TRAY_TYPE.EXTEND_BAG_3] = Define.TRAY_CLASS_BAG,
	[Define.TRAY_TYPE.EXTEND_BAG_4] = Define.TRAY_CLASS_BAG,
	[Define.TRAY_TYPE.EXTEND_BAG_5] = Define.TRAY_CLASS_BAG,
	[Define.TRAY_TYPE.EXTEND_BAG_6] = Define.TRAY_CLASS_BAG,


}

Define.BLOCK_FACE = {
	["INVALID"] = 0,
	["UP"] = 1,
	["DOWN"] = 2,
	["LEFT"] = 3,
	["RIGHT"] = 4,
	["FRONT"] = 5,
	["BEHIND"] = 6,
}

Define.ITEM_OBJ_TYPE_SETTLED	= 1
Define.ITEM_OBJ_TYPE_ISOLATED	= 2

Define.ENTITY_INTO_TYPE_PLAYER = 1
Define.ENTITY_INTO_TYPE_PET_1 = 2

Define.BROADCAST_COMMON = 0
Define.BROADCAST_INVITE = 1
Define.BROADCAST_REMOVE = 2
Define.BROADCAST_SEND_MSG = 3
Define.BROADCAST_SEND_EMAIL = 4

Define.PARTY_ALMOST_OVER = 104801
Define.PARTY_OVER = 104802

Define.CAMP_PLAYER_DEF = 1

Define.RoomCommonMsgType = {

}

Define.DBSubKey = {
	PlayerData = 1,
	HomeData = 2
}

Define.EntityMoveStatus = {
	"EMPTY",
	"IDLE",
	"RUN",
	"WALK",
	"SPRINT",
	"SWIMMING",
	"SWIMMING_IDLE",
	"JUMP",
	"FALLING",
	"AERIAL",
	"CLIMB",
	"FLY",
	"FLY_IDLE",
}

Define.ExchangeItemsReason = {
	BuyShop = 1,
	BuyVoice = 2
}

Define.SkillRechargeType = 
{
	Immediate = 1, 
	All = 2
}

Define.SkillRechargeMethod = 
{
	Once = 1 , 
	All = 2
}

Define.SkillFloatType = 
{
	None = 0,
	Free = 1,
	Direction = 2,
	All = 3
}

Define.SkillStopMode = 
{
	ClickAgain = 1,
	ReleaseButton = 2
}