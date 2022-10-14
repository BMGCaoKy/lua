InputSystem.instance = InputSystem:Instance()

rawset(_G, 'InputType', {
    Invalid = 0,
    Mouse = 1,
    Keyboard = 2,
    TouchScreen = 3
})

rawset(_G, 'MouseInputSubType', {
    Invalid = 0, 
    LeftDown = 1,
    LeftUp = 2,
    RightDown = 3,
    RightUp = 4,
    MiddleDown = 5,
    MiddleUp = 6,
    MouseMove = 7,
    MouseLeave = 8,
    MouseWheel = 9,
})

rawset(_G, 'KeyboardInputSubType', {
    Invalid = 0,
    KeyDown = 1,
    KeyUp = 2
})

rawset(_G, 'TouchScreenInputSubType', {
    Invalid = 0,
    TouchDown = 1,
    TouchUp = 2,
    TouchMove = 3,
    TouchCancel = 4
})

InputSystem.instance:addHandler(require 'ui.ui_hover_logger', 350)