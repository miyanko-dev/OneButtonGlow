local glowFrames = {}
local glowSources = {}

-- Build a proc glow overlay, via SpellAlert template, to replace native button glows

local function buildGlowFrame(button)
    local btnW, btnH = button:GetSize()
    if btnW <= 0 or btnH <= 0 then return nil end

    local glow = CreateFrame("Frame", nil, button, "ActionButtonSpellAlertTemplate")
    glow:SetPoint("CENTER")
    glow:SetSize(btnW * 1.4, btnH * 1.4)
    glow.ProcStartFlipbook:Hide()
    glow:Hide()

    glow._prevW, glow._prevH = btnW, btnH
    glowFrames[button] = glow
    return glow
end

-- Sync glow dimensions, via cached size check, to match dynamic button resizing

local function syncGlowSize(button, glow)
    local btnW, btnH = button:GetSize()
    if btnW <= 0 or btnH <= 0 then return end
    if glow._prevW == btnW and glow._prevH == btnH then return end

    glow:SetSize(btnW * 1.4, btnH * 1.4)
    glow._prevW, glow._prevH = btnW, btnH
end

-- Activate proc glow, via direct loop play, to indicate button highlight

local function activateGlow(button)
    local glow = glowFrames[button] or buildGlowFrame(button)
    if not glow then return end
    syncGlowSize(button, glow)

    if not glow:IsShown() then
        glow:Show()
        glow.ProcLoop:Play()
    end
end

-- Deactivate proc glow, via hide, to clear button highlight

local function deactivateGlow(button)
    local glow = glowFrames[button]
    if not glow then return end
    glow:Hide()
end

-- Evaluate active glow sources, via flag check, to toggle visibility

local function refreshGlow(button)
    local src = glowSources[button]

    if src and (src.spell or src.assist) then
        activateGlow(button)
    else
        deactivateGlow(button)
        glowSources[button] = nil
    end
end

-- Suppress native spell alert, via alpha override, to prevent duplicate highlights

local function suppressSpellAlert(button)
    if button.SpellActivationAlert then
        button.SpellActivationAlert:SetAlpha(0)
    end

    local rotFrame = button.AssistedCombatRotationFrame
    if rotFrame and rotFrame.SpellActivationAlert then
        rotFrame.SpellActivationAlert:SetAlpha(0)
    end
end

-- Suppress native assisted highlight, via alpha override, to prevent duplicate highlights

local function suppressAssistedGlow(button)
    if button.AssistedCombatHighlightFrame then
        button.AssistedCombatHighlightFrame:SetAlpha(0)
    end
end

-- Register spell alert source, via native suppression and flag set, to activate custom glow

local function onAlertShown(_, btn)
    if not btn then return end
    suppressSpellAlert(btn)

    local src = glowSources[btn] or {}
    src.spell = true
    glowSources[btn] = src

    refreshGlow(btn)
end

-- Clear spell alert source, via flag reset, to deactivate custom glow

local function onAlertHidden(_, btn)
    if not btn then return end

    local src = glowSources[btn]
    if src then src.spell = nil end

    refreshGlow(btn)
end

-- Sync assisted highlight source, via native suppression and flag toggle, to update custom glow

local function onAssistedChanged(_, btn, shown)
    if not btn then return end
    suppressAssistedGlow(btn)

    local src = glowSources[btn] or {}
    src.assist = shown or nil
    glowSources[btn] = src

    refreshGlow(btn)
end

-- Hook glow managers at login, via hooksecurefunc, to intercept native highlight triggers

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self)
    if ActionButtonSpellAlertManager then
        hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", onAlertShown)
        hooksecurefunc(ActionButtonSpellAlertManager, "HideAlert", onAlertHidden)
    end

    if AssistedCombatManager then
        hooksecurefunc(AssistedCombatManager, "SetAssistedHighlightFrameShown", onAssistedChanged)
    end

    self:UnregisterEvent("PLAYER_LOGIN")
    self:SetScript("OnEvent", nil)
end)
