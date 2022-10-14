function M:init()
    WinBase.init(self, "myPageView.json")
	local panel = self:child("myPageView-testpane")
	panel:InitializeContainer()

	for i = 1, 30 do
		local image = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", string.format("WIN_MAIN_GRID_VIEW_SLOTxxx_%d", i))
        image:SetProperty("StretchType", "NineGrid")
        image:SetProperty("StretchOffset", "8 11 8 13")
        image:SetImage("set:new_gui_material.json image:wupinkuang")
        image:SetArea({ 0, 0 }, { 0, i * 64 }, { 0, 64 }, { 0, 64 })	
		panel:AddItem(image)
	end

	panel:SetHoriScrollEnable(false)
end

return M