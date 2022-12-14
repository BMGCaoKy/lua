---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by 10184.
--- DateTime: 2021/5/17 10:31
---
---@class GUIWindow
---@field getId fun(self : GUIWindow) : number
---@field child fun(self : GUIWindow, name : string) : GUIWindow
---@field GetParent fun(self : GUIWindow) : GUIWindow
---@field SetVisible fun(self : GUIWindow, value : boolean) : void
---@field IsVisible fun(self : GUIWindow) : boolean
---@field setEnabled fun(self : GUIWindow, value : boolean) : void
---@field IsEnabled fun(self : GUIWindow) : boolean
---@field setEnableLongTouch fun(self : GUIWindow, value : boolean) : void
---@field GetChildByIndex fun(self : GUIWindow, index : number) : GUIWindow
---@field GetChildCount fun(self : GUIWindow) : number
---@field AddChildWindow fun(self : GUIWindow, child : GUIWindow) : void
---@field SetWidth fun(self : GUIWindow, width : number[]) : void
---@field GetWidth fun(self : GUIWindow) : number[]
---@field SetHeight fun(self : GUIWindow, height : number[]) : void
---@field GetHeight fun(self : GUIWindow) : number[]
---@field RemoveChildWindow1 fun(self : GUIWindow, child : GUIWindow) : void
---@field SetText fun(self : GUIWindow, text : string) : void
---@field GetText fun(self : GUIWindow) : string
---@field SetArea fun(self : GUIWindow, area : table) : void
---@field Clone fun(self : GUIWindow, nameSuffix : string, target : GUIWindow) : void
---@field GetType fun(self : GUIWindow) : string
---@field GetName fun(self : GUIWindow) : string
---@field GetTypeString fun(self : GUIWindow) : string
---@field SetXPosition fun(self : GUIWindow, x : number[]) : void
---@field GetXPosition fun(self : GUIWindow) : number[]
---@field SetYPosition fun(self : GUIWindow, y : number[]) : void
---@field GetYPosition fun(self : GUIWindow) : number[]
---@field GetFont fun(self : GUIWindow) : GUIFont
---@field GetPixelSize fun(self : GUIWindow) : Vector2
---@field GetUnclippedOuterRect fun(self : GUIWindow) : number[]
---@field GetRenderArea fun(self : GUIWindow) : number[]
---@field SetHorizontalAlignment fun(self : GUIWindow, horizontal : number) : void
---@field SetVerticalAlignment fun(self : GUIWindow, vertical : number) : void
---@field SetTextHorzAlign fun(self : GUIWindow, horizontal : number) : void
---@field SetTextVertAlign fun(self : GUIWindow, vertical : number) : void
---@field SetProperty fun(self : GUIWindow, property : string, value : string) : void
---@field GetPropertyString fun(self : GUIWindow, property : string, value : string) : string
---@field SetTouchable fun(self : GUIWindow, touchable : boolean) : void
---@field IsTouchable fun(self : GUIWindow) : boolean
---@field SetDrawColor fun(self : GUIWindow, color : table) : boolean
---@field CleanupChildren fun(self : GUIWindow) : void