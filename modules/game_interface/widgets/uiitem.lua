function UIItem:onDragEnter(mousePos)
    if self:isVirtual() then
        return false
    end

    local item = self:getItem()
    if not item then
        return false
    end

    self:setBorderWidth(1)
    self.currentDragThing = item
    g_mouse.pushCursor('target')
    return true
end

function UIItem:onDragLeave(droppedWidget, mousePos)
    if self:isVirtual() then
        return false
    end
    self.currentDragThing = nil
    g_mouse.popCursor('target')
    self:setBorderWidth(0)
    self.hoveredWho = nil
    return true
end

function UIItem:onDrop(widget, mousePos)
    self:setBorderWidth(0)

    if not self:canAcceptDrop(widget, mousePos) then
        return false
    end

    local item = widget.currentDragThing
    if not item:isItem() then
        return false
    end

    local itemPos = item:getPosition()
    local itemTile = item:getTile()
    local toPos = self.position
    if not (toPos) and self:getParent() and self:getParent().slotPosition then
        toPos = self:getParent().slotPosition
    end

    if self.selectable then
        if item:isPickupable() then
            self:setItem(Item.create(item:getId(), item:getCountOrSubType()))
            return true
        end
        return false
    end

    if not itemPos or not toPos then
        local pressedWidget = g_ui.getPressedWidget()
        local rootWidget = g_ui.getRootWidget()
        if pressedWidget and rootWidget then
            local parentWidget = pressedWidget:getParent()
            local mousePosWidget = g_ui.getRootWidget():recursiveGetChildByPos(mousePos, false)
            if parentWidget and mousePosWidget then
                local mousePosWidgetParent = mousePosWidget:getParent()
                if mousePosWidgetParent and mousePosWidgetParent:getId() == 'actionBarPanel' then
                    if not itemPos and parentWidget:getId() == 'actionBarPanel' then
                        modules.game_actionbar.onDragReassign(widget, item)
                    elseif not toPos and parentWidget:getId() == 'contentsPanel' then
                        modules.game_actionbar.onChooseItemByDrag(self, mousePos, item)
                    end
                end
            end
        end
        return false
    end
    if itemPos.x ~= 65535 and not itemTile then
        return false
    end

    if itemPos.x == toPos.x and itemPos.y == toPos.y and itemPos.z == toPos.z then
        return false
    end

    if item:getCount() > 1 then
        modules.game_interface.moveStackableItem(item, toPos)
    else
        g_game.move(item, toPos, 1)
    end

    return true
end

function UIItem:onDestroy()
    if self == g_ui.getDraggingWidget() and self.hoveredWho then
        self.hoveredWho:setBorderWidth(0)
    end

    if self.hoveredWho then
        self.hoveredWho = nil
    end
end

function UIItem:onHoverChange(hovered)
    UIWidget.onHoverChange(self, hovered)

    if self:isVirtual() or not self:isDraggable() then
        return
    end

    local draggingWidget = g_ui.getDraggingWidget()
    if draggingWidget and self ~= draggingWidget then
        local gotMap = draggingWidget:getClassName() == 'UIGameMap'
        local gotItem = draggingWidget:getClassName() == 'UIItem' and not draggingWidget:isVirtual()
        if hovered and (gotItem or gotMap) then
            self:setBorderWidth(1)
            draggingWidget.hoveredWho = self
        else
            self:setBorderWidth(0)
            draggingWidget.hoveredWho = nil
        end
    end

    if g_game.getFeature(GameItemTooltipV8) then
        local tooltip = ""
        local function splitTextIntoLines(text, maxLineLength)
            local words = {}
            for word in text:gmatch("%S+") do
                table.insert(words, word)
            end

            local lines = {}
            local currentLine = words[1]
            for i = 2, #words do
                if currentLine:len() + 1 + words[i]:len() > maxLineLength then
                    table.insert(lines, currentLine)
                    currentLine = words[i]
                else
                    currentLine = currentLine .. " " .. words[i]
                end
            end
            table.insert(lines, currentLine)

            return table.concat(lines, "\n")
        end

        if self:getItem() and self:getItem():getTooltip():len() > 0 then
            tooltip = splitTextIntoLines(self:getItem():getTooltip(), 80)
            if tooltip then
                self:setTooltip(tooltip)
            end
        end
    end
end

function UIItem:onMouseRelease(mousePosition, mouseButton)
    if self.cancelNextRelease then
        self.cancelNextRelease = false
        return true
    end

    if self:isVirtual() then
        return false
    end

    local item = self:getItem()
    if not item or not self:containsPoint(mousePosition) then
        return false
    end

    if modules.client_options.getOption('classicControl') and
        ((g_mouse.isPressed(MouseLeftButton) and mouseButton == MouseRightButton) or
            (g_mouse.isPressed(MouseRightButton) and mouseButton == MouseLeftButton)) then
        g_game.look(item)
        self.cancelNextRelease = true
        return true
    elseif modules.game_interface.processMouseAction(mousePosition, mouseButton, nil, item, item, nil, nil) then
        return true
    end
    return false
end

function UIItem:canAcceptDrop(widget, mousePos)
    if not self.selectable and (self:isVirtual() or not self:isDraggable()) then
        return false
    end

    if not widget or not widget.currentDragThing then
        return false
    end

    local children = rootWidget:recursiveGetChildrenByPos(mousePos)
    for i = 1, #children do
        local child = children[i]
        if child == self then
            return true
        elseif not child:isPhantom() then
            return false
        end
    end

    error('Widget ' .. self:getId() .. ' not in drop list.')
    return false
end
