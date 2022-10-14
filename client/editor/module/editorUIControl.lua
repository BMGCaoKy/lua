local editorUIControl = L("editorUIControl", Lib.derive(EditorModule.baseDerive))

function editorUIControl:closeMainUI()
    UI:closeWnd("mapEditToolbar")
    UI:closeWnd("mapEditShortcut")
end

function editorUIControl:openMainUI()
    Lib.emitEvent(Event.EVENT_OPEN_EDIT_MAIN)
end

RETURN(editorUIControl)
