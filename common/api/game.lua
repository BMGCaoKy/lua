local GameStaticTb = {
    Time = { get = function()
        return World.Now()
    end },
}

APIProxy.OverrideAPI(Game, nil, GameStaticTb)