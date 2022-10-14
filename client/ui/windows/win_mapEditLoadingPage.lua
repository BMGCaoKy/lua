local enumShowType = {LOAD_MAP = 0,
                    DOWNLOAD_MAP = 1}




function M:init()
	assert(WinBase)
    WinBase.init(self, "loadingPage_edit.json")
    self:root():SetLevel(10)

    self.progressBar = self:child("LoadingPage-Progress")
    self.valueText = self:child("LoadingPage-Value")

    self:child("LoadingPage-Text"):SetText(Lang:toText("win.map.edit.loading.page.load.text"))

    self.m_showType = enumShowType.LOAD_MAP

	self.m_progress = 0.0
	self.m_pregressFileSize = 0.0
    self.isLoadShowProgress = true

    Lib.subscribeEvent(Event.EVENT_DOWNLOAD_TEMPLATE_PROGRESS, function(progress, fillSize)
        self.m_showType = enumShowType.DOWNLOAD_MAP
        self:showLoadingPage(self.m_showType, progress, fillSize)
    end)
end

function M:showLoadingPage(showType, progress, fileSize)
    if showType == enumShowType.DOWNLOAD_MAP then
        self:onDownloadMapProgress(progress,fileSize)
    end
end

function M:refreshUi()
    if self.m_showType == enumShowType.DOWNLOAD_MAP then
        self:refreshProgress(self.m_progress, self.m_pregressFileSize)
        local nowFileSize = self.m_pregressFileSize/1048576 * self.m_progress
        local text = string.format("%.2f%s%.2f%s", nowFileSize,"M/",self.m_pregressFileSize/1048576, "M")
        self.valueText:SetText(text)
        if self.m_progress == 1 then
            self:child("LoadingPage-Text"):SetText(Lang:toText("win.map.edit.loading.page.load"))
        end
    end

    self.progressBar:SetProgress(self.m_progress)
end

function M:onDownloadMapProgress(progess, fileSize)  --todo
	self.m_progress =progess
	self.m_pregressFileSize = fileSize
	self.m_showType = enumShowType.DOWNLOAD_MAP
    if self.isLoadShowProgress then
        self:child("LoadingPage-ProgressBG"):SetVisible(true)
        self.valueText:SetVisible(true)
        self:child("LoadingPage-TextBG"):SetVisible(true)
        self.isLoadShowProgress = false
    end
	self:refreshUi()
end

function M:refreshProgress(progress, pregressFileSize)
    
end

function M:showLoadingSuccess(msg)

end

function M:exitGame()
    CGame.instance:exitGame("offline")
end


function M:onClose()
end

function M:onReload(reloadArg)

end

return M