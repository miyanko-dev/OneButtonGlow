local ADDON_NAME = ...

local blueGlows = {}
local glowSources = {} -- [button] = { spellAlert, assistedHighlight }
local hooked = false

local function GetBlueGlow(button)
    if blueGlows[button] then return blueGlows[button] end
    local glow = CreateFrame("Frame", nil, button, "ActionBarButtonAssistedCombatHighlightTemplate")
    glow:SetPoint("CENTER", button, "CENTER", 0, 0)
    local bw, bh = button:GetSize()
    if bw > 0 and bh > 0 then
        glow:SetSize(bw, bh)
        if glow.Flipbook then glow.Flipbook:SetSize(bw * 1.47, bh * 1.47) end
    end
    glow:Hide()
    blueGlows[button] = glow
    return glow
end

local function SyncGlowSize(button, glow)
    local bw, bh = button:GetSize()
    if bw > 0 and bh > 0 and (glow._cachedW ~= bw or glow._cachedH ~= bh) then
        glow:SetSize(bw, bh)
        if glow.Flipbook then glow.Flipbook:SetSize(bw * 1.47, bh * 1.47) end
        glow._cachedW, glow._cachedH = bw, bh
    end
end

local function EnsureGlowAnimating(glow)
    if not (glow.Flipbook and glow.Flipbook.Anim) then return end
    if not glow.Flipbook.Anim:IsPlaying() then glow.Flipbook.Anim:Play() end
end

local function ShowBlueGlow(button)
    local glow = GetBlueGlow(button)
    SyncGlowSize(button, glow)
    glow:Show()
    EnsureGlowAnimating(glow)
end

local function HideBlueGlow(button)
    local glow = blueGlows[button]
    if not glow then return end
    if glow.Flipbook and glow.Flipbook.Anim then glow.Flipbook.Anim:Stop() end
    glow:Hide()
end

local function UpdateGlowState(button)
    local src = glowSources[button]
    if src and (src.spellAlert or src.assistedHighlight) then
        ShowBlueGlow(button)
    else
        HideBlueGlow(button)
        glowSources[button] = nil
    end
end

-- Suppress native alert and glow visuals
local function SuppressBlizzardAlert(button)
    if button.SpellActivationAlert then button.SpellActivationAlert:SetAlpha(0) end
    if button.AssistedCombatRotationFrame and button.AssistedCombatRotationFrame.SpellActivationAlert then
        button.AssistedCombatRotationFrame.SpellActivationAlert:SetAlpha(0)
    end
end

local function SuppressBlizzardAssistedHighlight(button)
    if button.AssistedCombatHighlightFrame then button.AssistedCombatHighlightFrame:SetAlpha(0) end
end

-- Hook: ActionButtonSpellAlertManager
local function OnSpellAlertShow(_, actionButton)
    if not actionButton then return end
    SuppressBlizzardAlert(actionButton)
    if not glowSources[actionButton] then glowSources[actionButton] = {} end
    glowSources[actionButton].spellAlert = true
    UpdateGlowState(actionButton)
end

local function OnSpellAlertHide(_, actionButton)
    if not actionButton then return end
    local src = glowSources[actionButton]
    if src then src.spellAlert = false end
    UpdateGlowState(actionButton)
end

-- Hook: AssistedCombatManager
local function OnAssistedHighlightChanged(_, actionButton, shown)
    if not actionButton then return end
    SuppressBlizzardAssistedHighlight(actionButton)
    if not glowSources[actionButton] then glowSources[actionButton] = {} end
    glowSources[actionButton].assistedHighlight = shown or false
    UpdateGlowState(actionButton)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" and not hooked then
        if ActionButtonSpellAlertManager then
            hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", OnSpellAlertShow)
            hooksecurefunc(ActionButtonSpellAlertManager, "HideAlert", OnSpellAlertHide)
        end
        if AssistedCombatManager then
            hooksecurefunc(AssistedCombatManager, "SetAssistedHighlightFrameShown", OnAssistedHighlightChanged)
        end
        hooked = true
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
