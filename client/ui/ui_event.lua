---@class UIEvent
UIEvent = {
	EventWindowTouchDown = "WindowTouchDown",
	EventWindowTouchMove = "WindowTouchMove",
	EventWindowTouchNullprt = "WindowTouchNullprt",
	EventMotionRelease = "MotionRelease",
	EventWindowTouchUp = "WindowTouchUp",
	EventWindowLongTouchStart = "WindowLongTouchStart",
	EventWindowLongTouchEnd = "WindowLongTouchEnd",
	EventWindowTextChanged = "WindowTextChanged",
	EventWindowClick = "WindowClick",
	EventWindowDoubleClick = "WindowDoubleClick",

	EventWindowScrollMove = "WindowScrollMove",
	-- drag
	EventWindowDragStart = "WindowDragStart",
	EventWindowDragging = "WindowDragging",
	EventWindowDragEnd = "WindowDragEnd",

	EventWindowActionEnd = "UIActionEnd",

	-- button
	EventButtonClick = "ButtonClick",
	-- check
	EventCheckStateChanged = "CheckStateChanged",
	--radio change
	EventRadioStateChanged = "RadioStateChanged",

	-- GUIScrollCard
	EventScrollCardClick = "ScrollCardClick",

	-- all scroll view
	EventScrollMoveChange = "ScrollMoveChange",

	-- edit 接受输入
	EventEditTextInput = "EditTextInput",	

	-- size
	EventSizeChanged = "SizeChanged",

	-- wnd destroy 
	EventWindowDestroy = "WindowDestroy",

	-- reload layout
	EventReloadLayout = "ReloadLayout",
}