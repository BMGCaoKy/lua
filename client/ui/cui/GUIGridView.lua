---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by 10184.
--- DateTime: 2021/5/17 10:58
---
---@class GUIGridView : GUIWindow
---@field AddItem fun(self : GUIGridView, item : GUIWindow) : void
---@field AddItemByIndex fun(self : GUIGridView, item : GUIWindow, index : number) : void
---@field GetItem fun(self : GUIGridView, index : number) : GUIWindow
---@field GetItemCount fun(self : GUIGridView) : number
---@field InitConfig fun(self : GUIGridView, hInterval : number, vInterval : number, rowSize : number) : void
---@field RemoveAllItems fun(self : GUIGridView) : void
---@field RemoveItem fun(self : GUIGridView, item : GUIWindow, needDestroy : boolean) : void
---@field SetMoveAble fun(self : GUIGridView, moveAble : boolean) : void
---@field SetScrollOffset fun(self : GUIGridView, offset : number) : void
---@field GetScrollOffset fun(self : GUIGridView) : number
---@field GetHorizontalInterval fun(self : GUIGridView) : number
---@field GetVerticalInterval fun(self : GUIGridView) : number
---@field GetRowSize fun(self : GUIGridView) : number
---@field SetVirtualListOffset fun(self : GUIGridView, offset : number) : void
---@field GetVirtualListOffset fun(self : GUIGridView) : number
---@field EnableVirtualList fun(self : GUIGridView) : void
---@field GoLastScroll fun(self : GUIGridView) : void
---@field GetMinScrollOffset fun(self : GUIGridView) : number
