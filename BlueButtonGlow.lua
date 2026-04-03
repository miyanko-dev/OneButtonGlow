local glowFrames = {}
local glowSources = {}

-- Build a highlight overlay, via AssistedCombatHighlight template, to replace native button glows

local function buildGlowFrame(button)
    local glow = CreateFrame("Frame", nil, button, "ActionBarButtonAssistedCombatHighlightTemplate")
    glow:SetPoint("CENTER")
    glow:Hide()

    local btnW, btnH = button:GetSize()
    if btnW > 0 and btnH > 0 then
        glow:SetSize(btnW, btnH)
        if glow.Flipbook then
            glow.Flipbook:SetSize(btnW * 1.5, btnH * 1.5)
        end
        glow._prevW, glow._prevH = btnW, btnH
    end

    glowFrames[button] = glow
    return glow
end

-- Sync glow dimensions, via cached size comparison, to match dynamic button resizing

local function syncGlowSize(button, glow)
    local btnW, btnH = button:GetSize()
    if btnW <= 0 or btnH <= 0 then return end
    if glow._prevW == btnW and glow._prevH == btnH then return end

    glow:SetSize(btnW, btnH)
    if glow.Flipbook then
        glow.Flipbook:SetSize(btnW * 1.5, btnH * 1.5)
    end
    glow._prevW, glow._prevH = btnW, btnH
end

-- Activate custom glow, via size sync and flipbook play, to indicate button highlight

local function activateGlow(button)
    local glow = glowFrames[button] or buildGlowFrame(button)
    syncGlowSize(button, glow)

    if not glow:IsShown() then
        glow:Show()
    end

    local flipbook = glow.Flipbook
    if flipbook and flipbook.Anim and not flipbook.Anim:IsPlaying() then
        flipbook.Anim:Play()
    end
end

-- Deactivate custom glow, via animation stop and hide, to clear button highlight

local function deactivateGlow(button)
    local glow = glowFrames[button]
    if not glow then return end

    local flipbook = glow.Flipbook
    if flipbook and flipbook.Anim then
        flipbook.Anim:Stop()
    end
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

-- Suppress native spell alert frame, via alpha override, to prevent duplicate highlights

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

-- Register spell alert source, via flag set and native suppression, to activate custom glow

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

-- Sync assisted highlight source, via flag toggle and native suppression, to update custom glow

local function onAssistedChanged(_, btn, shown)
    if not btn then return end
    suppressAssistedGlow(btn)

    local src = glowSources[btn] or {}
    src.assist = shown or nil
    glowSources[btn] = src

    refreshGlow(btn)
end

-- Hook button glow managers at login, via hooksecurefunc, to intercept native highlight triggers

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
