local ui_property = {}

ui_property.WINDOW_BASE_PROPERTY = {
--	导出到xml的name        xml的类型/编辑器类型
	HorizontalAlignment = "string/Anchor",
	VerticalAlignment = "string/Anchor",
	Alpha = "string/number",
	Visible = "string/boolean",
	ClippedByParent = "string/boolean",
	Disabled = "string/boolean",
	WindowTouchThroughMode = "string/string",
	WindowTouchThroughAlpha = "string/number",
	Rotation = "Rotation/Vector3i",
	PivotX = "Percentage/Percentage",
	PivotY = "Percentage/Percentage",
	SoundTriggerRange = "string/string",
	Volume = "string/number",
	SoundFile = "sound/sound",
	MousePassThroughEnabled = "MousePassThrough/MousePassThrough",
	level = "string/number",
	SizeConstraint = "string/string"
}

ui_property.STATICTEXT_PROPERTY = {
	Font = "string/Font",
	Font_size = "string/number",
	Text = "string/string",
	text_key = "key/key",
	AutoTextScale = "string/boolean",
	TextWordBreak = "string/boolean",
	BackgroundEnabled = "string/boolean",
	FrameEnabled = "string/boolean",
	HorzFormatting = "string/HorzFormatting",
	VertFormatting = "string/string",
	TextColours = "colours/colours",
	BackgroundColours = "colours/colours",
	FrameColours = "colours/colours",
	word_warpped = "string/boolean",--TODO 编辑器拆分出来的数据
	BorderEnable = "string/boolean",
	BorderColor = "colours/colours",
	BorderWidth = "string/number",
	TextBoldWeight = "string/string",
	MinAutoTextScale = "string/number",
	AutoScale = "string/string",
	TextWordBreak = "string/boolean"
}

ui_property.STATICIMAGE_PROPERTY = {
	BackgroundEnabled = "string/boolean",
	FrameEnabled = "string/boolean",
	Image = "image/image",
	StaticImageStretch = "stretch/stretch",
	ImageColours = "colours/colours",
	BackgroundColours = "colours/colours",
	FrameColours = "colours/colours",
	horzFormatting = "string/string",
	vertFormatting = "string/string",
	StaticImageCutStretch = "stretch/stretch",
	ImageBlendMode = "string/string",
	ImageSrcBlend = "string/string",
	ImageDstBlend = "string/string",
	ImageBlendOperation = "string/string",
	FillType = "string/string",
	FillPosition = "string/string",
	FillArea = "string/number",
	AntiClockwise = "string/boolean",
	IsUIMask = "string/boolean",
	IsDisplayUIMask = "string/boolean"
}

ui_property.BUTTON_PROPERTY = {
	Font = "string/Font",
	Font_size = "string/number",
	Text = "string/string",
	text_key = "key/key",
	AutoTextScale = "string/boolean",
	NormalTextColour = "colours/colours",
	HoverTextColour = "colours/colours",
	DisabledTextColour = "colours/colours",
	PushedTextColour = "colours/colours",
	BorderEnable = "string/boolean",
	BorderColor = "colours/colours",
	BorderWidth = "string/number",
	NormalImage = "image/image",
	HoverImage = "image/image",
	DisabledImage = "image/image",
	PushedImage = "image/image",
	NormalStretch = "stretch/stretch",
	HoverStretch = "stretch/stretch",
	DisabledStretch = "stretch/stretch",
	PushedStretch = "stretch/stretch",
	HorzImageFormatting = "string/string",
	VertImageFormatting = "string/string",
	TextBoldWeight = "string/string",
	btn_word_warpped = "string/boolean",
	enable_text_offset = "string/boolean",
	TextXOffset = "string/TextOffset",
	TextYOffset = "string/TextOffset",
	TextWordBreak = "string/boolean",
	TextOffset = "Vector2/Vector2"
}

ui_property.PROGRESSBAR_PROPERTY = {
	VerticalProgress = "string/boolean",
	ReversedProgress = "string/boolean",
	CurrentProgress = "Percentage/Percentage",
	progress_lights_image = "image/image",
	progress_background_image = "image/image",
	ProgressLightsStretch = "stretch/stretch",
	ProgressBgStretch = "stretch/stretch",
	ClipProgress = "string/boolean"
}

ui_property.EDITBOX_PROPERTY = {
	Text = "string/string",
	text_key = "key/key",
	Font = "string/Font",
	Font_size = "string/number",
	MaskText = "string/boolean",
	MaxTextLength = "string/number",
	ReadOnly = "string/boolean",
	BackGroundImage = "image/image",
	NormalTextColour = "colours/colours",
	SelectedTextColour = "colours/colours",
	ReadOnlyBGColour = "colours/colours",
	ActiveSelectionColour = "colours/colours",
	BackGroundStretch = "stretch/stretch",
	TextBoldWeight = "string/string"
}

ui_property.CHECKBOX_PROPERTY = {
	Text = "string/string",
	text_key = "key/key",
	unselectableImage = "image/image",
	selectableImage = "image/image",
	Font = "string/Font",
	Font_size = "string/number",
	Selected = "string/boolean",
	NormalTextColour = "colours/colours",
	DisabledTextColour = "colours/colours",
	PushedTextColour = "colours/colours",
	BorderEnable = "string/boolean",
	BorderColor = "colours/colours",
	BorderWidth = "string/number",
	UnselectableStretch = "stretch/stretch",
	SelectableStretch = "stretch/stretch",
	TextBoldWeight = "string/string"
}

ui_property.RADIOBUTTON_PROPERTY = {
	GroupID = "string/number",
	Selected = "string/boolean",
	unselectableImage = "image/image",
	selectableImage = "image/image",
	Text = "string/string",
	text_key = "key/key",
	Font = "string/Font",
	Font_size = "string/number",
	NormalTextColour = "colours/colours",
	DisabledTextColour = "colours/colours",
	PushedTextColour = "colours/colours",
	BorderEnable = "string/boolean",
	BorderColor = "colours/colours",
	BorderWidth = "string/number",
	UnselectableStretch = "stretch/stretch",
	SelectableStretch = "stretch/stretch",
	TextBoldWeight = "string/string",
	TextXPos = "string/string",
	HorzLabelFormatting = "string/string",
	ImageXSizeImcress = "string/string"
}

ui_property.HORIZONTALSLIDER_PROPERTY = {
	ReversedDirection = "string/boolean",
	MaximumValue = "string/number",
	CurrentValue = "string/number",
	slider_top = "image/image",
	slider_bg = "image/image",
	TopImageStretch = "stretch/stretch",
	BgImageStretch = "stretch/stretch",
	thumb = "thumb/thumb",
	MinValue = "string/number",
	ClickStep = "string/number",
	WholeNumbers = "string/boolean",
	MoveByStep = "string/boolean"
}

ui_property.VERTICALSLIDER_PROPERTY = {
	ReversedDirection = "string/boolean",
	MaximumValue = "string/number",
	CurrentValue = "string/number",
	thumb_image = "image/image",
	slider_top = "image/image",
	slider_bg = "image/image",
	TopImageStretch = "stretch/stretch",
	BgImageStretch = "stretch/stretch",
	MinValue = "string/number",
	ClickStep = "string/number",
	WholeNumbers = "string/boolean",
	MoveByStep = "string/boolean"
}

ui_property.SCROLLABLEVIEW_PROPERTY = {
	BackGroundImage = "image/image",
	ForceHorzScrollbar = "string/boolean",
	ForceVertScrollbar = "string/boolean",
	moveAble = "string/boolean",
	BgImageStretch = "stretch/stretch",
	HorzScrollPosition = "string/number",
	VertScrollPosition = "string/number",
	Resistance = "string/number",
	ScrollRestrictType = "string/string",
	HorizontalMovable = "string/boolean",
	VerticalMovable = "string/boolean",
	ReboundTime = "string/number"
}

ui_property.ACTORWINDOW_PROPERTY = {
	ActorName = "ActorName/ActorName",
	SkillName = "string/string",
	RotateX = "string/number",
	RotateY = "string/number",
	RotateZ = "string/number",	
	ActorScale = "string/number",
	PositionX = "string/number",
	PositionY = "string/number"
}

ui_property.EFFECTWINDOW_PROPERTY = {
	effectName = "EffectName/EffectName",
	effectXRotate = "string/number",
	effectYRotate = "string/number",
	effectZRotate = "string/number",	
	effectScale = "string/number",
	effectXPosition = "string/number",
	effectYPosition = "string/number",
	effectPlayMode = "string/string",
	--EffectPosition = "Vector2/Vector2",
	--EffectRotation = "Rotation/Vector3i"
}

ui_property.HORIZONTALLAYOUTCONTAINER_PROPERTY = {
	space = "string/number",
	dir = "string/string",
	ControlChildrenSize = "string/boolean",
	ChildrenSize = "Vector2/Vector2"
}

ui_property.VERTICALLAYOUTCONTAINER_PROPERTY = {
	space = "string/number",
	dir = "string/string",
	ControlChildrenSize = "string/boolean",
	ChildrenSize = "Vector2/Vector2"
}

ui_property.GRIDVIEW_PROPERTY = {
	hInterval = "string/Space",
	vInterval = "string/Space",
	rowSize = "string/number",
	dir = "string/string",
	ControlChildrenSize = "string/boolean",
	ChildrenSize = "Vector2/Vector2",
	Space = "Vector2/Vector2"
}

ui_property.CUSTOMHORIZONTALSLIDER_PROPERTY = {
	MaximumValue = "string/number",
	CurrentValue = "string/number",
	MinValue = "string/number",
	ClickStep = "string/number",
	WholeNumbers = "string/boolean",
	MoveByStep = "string/boolean"
}

ui_property.CUSTOMVERTICALSLIDER_PROPERTY = {
	MaximumValue = "string/number",
	CurrentValue = "string/number",
	MinValue = "string/number",
	ClickStep = "string/number",
	WholeNumbers = "string/boolean",
	MoveByStep = "string/boolean"
}

ui_property.SLIDERTHUMB_PROPERTY = {
	thumb_image = "image/image",
	thumb_stretch = "stretch/stretch",
}

ui_property.VSLIDERTHUMB_PROPERTY = {
	thumb_image = "image/image",
	thumb_stretch = "stretch/stretch",
}

ui_property.MASKWINDOW_PROPERTY = {
	Reverse = "string/boolean",
	MaskType = "string/string",
	MaskImage = "image/image",
	SideNum = "string/number"
}

ui_property.UI_WINDOW = {
	ui_property.WINDOW_BASE_PROPERTY,
	ui_property.STATICTEXT_PROPERTY,
	ui_property.STATICIMAGE_PROPERTY,
	ui_property.BUTTON_PROPERTY,
	ui_property.PROGRESSBAR_PROPERTY,
	ui_property.EDITBOX_PROPERTY,
	ui_property.CHECKBOX_PROPERTY,
	ui_property.RADIOBUTTON_PROPERTY,
	ui_property.HORIZONTALSLIDER_PROPERTY,
	ui_property.VERTICALSLIDER_PROPERTY,
	ui_property.HORIZONTALLAYOUTCONTAINER_PROPERTY,
	ui_property.VERTICALLAYOUTCONTAINER_PROPERTY,
	ui_property.SCROLLABLEVIEW_PROPERTY,
	ui_property.GRIDVIEW_PROPERTY,
	ui_property.ACTORWINDOW_PROPERTY,
	ui_property.EFFECTWINDOW_PROPERTY,
	ui_property.CUSTOMHORIZONTALSLIDER_PROPERTY,
	ui_property.CUSTOMVERTICALSLIDER_PROPERTY,
	ui_property.SLIDERTHUMB_PROPERTY,
	ui_property.VSLIDERTHUMB_PROPERTY,
	ui_property.MASKWINDOW_PROPERTY
}

ui_property.AttributeSheetMapping = {
	DefaultWindow = ui_property.WINDOW_BASE_PROPERTY,
	StaticText = ui_property.STATICTEXT_PROPERTY,
	StaticImage = ui_property.STATICIMAGE_PROPERTY,
	Button = ui_property.BUTTON_PROPERTY,
	ProgressBar = ui_property.PROGRESSBAR_PROPERTY,
	Editbox = ui_property.EDITBOX_PROPERTY,
	Checkbox = ui_property.CHECKBOX_PROPERTY,
	RadioButton = ui_property.RADIOBUTTON_PROPERTY,
	HorizontalSlider = ui_property.HORIZONTALSLIDER_PROPERTY,
	VerticalSlider = ui_property.VERTICALSLIDER_PROPERTY,
	ScrollableView = ui_property.SCROLLABLEVIEW_PROPERTY,
	ActorWindow = ui_property.ACTORWINDOW_PROPERTY,
	EffectWindow = ui_property.EFFECTWINDOW_PROPERTY,
	HorizontalLayoutContainer = ui_property.HORIZONTALLAYOUTCONTAINER_PROPERTY,
	VerticalLayoutContainer = ui_property.VERTICALLAYOUTCONTAINER_PROPERTY,
	GridView = ui_property.GRIDVIEW_PROPERTY,
	CustomHorizontalSlider = ui_property.CUSTOMHORIZONTALSLIDER_PROPERTY,
	CustomVerticalSlider = ui_property.CUSTOMVERTICALSLIDER_PROPERTY,
	SliderThumb = ui_property.SLIDERTHUMB_PROPERTY,
	VSliderThumb = ui_property.VSLIDERTHUMB_PROPERTY,
	MaskWindow = ui_property.MASKWINDOW_PROPERTY
}

return ui_property