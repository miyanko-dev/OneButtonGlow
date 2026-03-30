local ADDON_NAME = ...

local buttonGlowFrames = {}
local buttonGlowSources = {} -- [button] = { spellAlert, assistedHighlight }
local managersHooked = false


local function GetOrCreateButtonGlow(button)
    if buttonGlowFrames[button] then return buttonGlowFrames[button] end

    local glow = CreateFrame("Frame", nil, button, "ActionBarButtonAssistedCombatHighlightTemplate")
    glow:SetPoint("CENTER", button, "CENTER", 0, 0)

    local buttonWidth, buttonHeight = button:GetSize()
    if buttonWidth > 0 and buttonHeight > 0 then
        glow:SetSize(buttonWidth, buttonHeight)
        if glow.Flipbook then glow.Flipbook:SetSize(buttonWidth * 1.47, buttonHeight * 1.47) end
    end

    glow:Hide()
    buttonGlowFrames[button] = glow
    return glow
end


local function SyncButtonGlowSize(button, glow)
    local buttonWidth, buttonHeight = button:GetSize()
    local sizeChanged = glow._cachedWidth ~= buttonWidth or glow._cachedHeight ~= buttonHeight

    if buttonWidth > 0 and buttonHeight > 0 and sizeChanged then
        glow:SetSize(buttonWidth, buttonHeight)
        if glow.Flipbook then glow.Flipbook:SetSize(buttonWidth * 1.47, buttonHeight * 1.47) end
        glow._cachedWidth, glow._cachedHeight = buttonWidth, buttonHeight
    end
end


local function EnsureGlowFlipbookPlaying(glow)
    if not (glow.Flipbook and glow.Flipbook.Anim) then return end
    if not glow.Flipbook.Anim:IsPlaying() then glow.Flipbook.Anim:Play() end
end


local function ShowButtonGlow(button)
    local glow = GetOrCreateButtonGlow(button)
    SyncButtonGlowSize(button, glow)
    glow:Show()
    EnsureGlowFlipbookPlaying(glow)
end


local function HideButtonGlow(button)
    local glow = buttonGlowFrames[button]
    if not glow then return end
    if glow.Flipbook and glow.Flipbook.Anim then glow.Flipbook.Anim:Stop() end
    glow:Hide()
end


local function RefreshButtonGlowVisibility(button)
    local sources = buttonGlowSources[button]

    if sources and (sources.spellAlert or sources.assistedHighlight) then
        ShowButtonGlow(button)
    else
        HideButtonGlow(button)
        buttonGlowSources[button] = nil
    end
end


-- Suppress native visuals so the custom glow is the sole indicator
local function SuppressNativeSpellAlert(button)
    if button.SpellActivationAlert then
        button.SpellActivationAlert:SetAlpha(0)
    end

    if button.AssistedCombatRotationFrame and button.AssistedCombatRotationFrame.SpellActivationAlert then
        button.AssistedCombatRotationFrame.SpellActivationAlert:SetAlpha(0)
    end
end


local function SuppressNativeAssistedHighlight(button)
    if button.AssistedCombatHighlightFrame then
        button.AssistedCombatHighlightFrame:SetAlpha(0)
    end
end


-- Register spellAlert source and suppress native alert frame
local function OnSpellAlertShown(_, actionButton)
    if not actionButton then return end

    SuppressNativeSpellAlert(actionButton)

    if not buttonGlowSources[actionButton] then buttonGlowSources[actionButton] = {} end
    buttonGlowSources[actionButton].spellAlert = true

    RefreshButtonGlowVisibility(actionButton)
end


-- Clear spellAlert source
local function OnSpellAlertHidden(_, actionButton)
    if not actionButton then return end

    local sources = buttonGlowSources[actionButton]
    if sources then sources.spellAlert = false end

    RefreshButtonGlowVisibility(actionButton)
end


-- Sync assistedHighlight source and suppress native highlight frame
local function OnAssistedHighlightChanged(_, actionButton, isShown)
    if not actionButton then return end

    SuppressNativeAssistedHighlight(actionButton)

    if not buttonGlowSources[actionButton] then buttonGlowSources[actionButton] = {} end
    buttonGlowSources[actionButton].assistedHighlight = isShown or false

    RefreshButtonGlowVisibility(actionButton)
end


local addonEventFrame = CreateFrame("Frame")
addonEventFrame:RegisterEvent("PLAYER_LOGIN")
addonEventFrame:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_LOGIN" or managersHooked then return end

    if ActionButtonSpellAlertManager then
        hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", OnSpellAlertShown)
        hooksecurefunc(ActionButtonSpellAlertManager, "HideAlert", OnSpellAlertHidden)
    end

    if AssistedCombatManager then
        hooksecurefunc(AssistedCombatManager, "SetAssistedHighlightFrameShown", OnAssistedHighlightChanged)
    end

    managersHooked = true
    self:UnregisterEvent("PLAYER_LOGIN")
end)