local logger = {}
local lastWindow
local windowInfo = {}

logger.enabled = false

function logger:handleInput(input)
    if not self.enabled then
        return false
    end
    if input.type ~= InputType.Mouse or input.subtype ~= MouseInputSubType.MouseMove then
        return false
    end
    local outPosition = GUISystem.instance:AdaptPosition(input.position)
    local window = GUISystem.instance:GetTargetGUIWindow(outPosition)
    if not World.CurWorld or not window or lastWindow == window then
        return false
    end

    lastWindow = window
	print("================ hover UI ================")
	local desktop = GUISystem.instance:GetRootWindow()
	while true 
	do
		windowInfo.name = window:GetName()
		windowInfo.uiType = window
		windowInfo.img = window:GetImageName()
		if string.len(windowInfo.img) == 0 then 
			windowInfo.img = nil
		end

		local jsonPath = window:data("jsonPath")
		if jsonPath then
			windowInfo.json = jsonPath
			print(Lib.v2s(windowInfo))
			break
		else
			windowInfo.json = nil
			window = window:GetParent()
			print(Lib.v2s(windowInfo))
			if window:getId() == desktop:getId() then
				print("error: not the json")
				break
			end
		end
    end
    
    return false
end

return logger