local handles = {}

function interaction_event(name, ...)
    local func = handles[name]
    if not func then
        return
    end
    func(Me, ...)
end

function handles:ButtonSetClickAction(objID, context)
    local btnCfg, callbacks = context.btnCfg, context.innerCallbacks
    local nextCfgOnClick = btnCfg.nextCfgOnClick
    local hideOnClick = btnCfg.hideOnClick

    if nextCfgOnClick then
        callbacks[#callbacks + 1] = function ()
            Me:updateObjectInteractionUI({
                objID = objID,
                show = true,
                cfgKey = nextCfgOnClick,
            })
        end
    else
        if hideOnClick then
            callbacks[#callbacks + 1] = function ()
                Me:updateObjectInteractionUI({
                    objID = objID,
                    show = false
                })
            end
        end
    end

end
