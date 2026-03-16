-- StrongCombatAssist: replace all action button highlight visuals with the blue animated highlight

local blueGlowCache = {}
local activeCount = {}
local hookedButtons = {}
local noop = function() end

local ALERT_CHILDREN = { "ProcStartFlipbook", "ProcLoopFlipbook", "ProcAltGlow", "ProcLoop", "ProcStartAnim" }

local function getOrCreateBlueGlow(button)
    if blueGlowCache[button] then return blueGlowCache[button] end
    local gf = CreateFrame("Frame", nil, button, "ActionBarButtonAssistedCombatHighlightTemplate")
    gf:SetPoint("CENTER", button, "CENTER")
    gf:Hide()
    blueGlowCache[button] = gf
    return gf
end

local function showBlueGlow(button)
    activeCount[button] = (activeCount[button] or 0) + 1
    local gf = getOrCreateBlueGlow(button)
    local w, h = button:GetWidth(), button:GetHeight()
    if w > 0 and h > 0 then
        local gw, gh = w * 1.4, h * 1.4
        gf:SetSize(gw, gh)
        if gf.Flipbook then gf.Flipbook:SetSize(gw, gh) end
    end
    gf:Show()
    if not gf.Flipbook.Anim:IsPlaying() then gf.Flipbook.Anim:Play() end
end

local function hideBlueGlow(button)
    activeCount[button] = math.max(0, (activeCount[button] or 0) - 1)
    if (activeCount[button] or 0) > 0 then return end
    local gf = blueGlowCache[button]
    if not gf then return end
    gf.Flipbook.Anim:Stop()
    gf:Hide()
end

-- Force AssistedCombatHighlightFrame animation to always play, even out of combat
local function onAssistedHighlightChanged(self, actionButton, shown)
    if not actionButton then return end
    local frame = actionButton.AssistedCombatHighlightFrame
    if frame and frame.Flipbook and shown and not frame.Flipbook.Anim:IsPlaying() then
        frame.Flipbook.Anim:Play()
    end
end

-- Suppress a single alert child based on its actual object type:
-- AnimationGroups get stopped and their Play shadowed; Textures get hidden and their Show shadowed
local function suppressAlertChild(child)
    if not child then return end
    if child:GetObjectType() == "AnimationGroup" then
        child:Stop()
        child.Play = noop
    else
        child:Hide()
        child.Show = noop
    end
end

local function trySetupAlertHooks(button)
    if hookedButtons[button] or not button.SpellActivationAlert then return end
    hookedButtons[button] = true

    local alert = button.SpellActivationAlert

    -- Parent alert frame is a real Frame, so HookScript works here
    alert:HookScript("OnShow", function() showBlueGlow(button) end)
    alert:HookScript("OnHide", function() hideBlueGlow(button) end)

    for _, childName in ipairs(ALERT_CHILDREN) do
        suppressAlertChild(alert[childName])
    end

    if button.ShowOverlayGlow then
        hooksecurefunc(button, "ShowOverlayGlow", function(self)
            if self.overlay then self.overlay:SetAlpha(0) end
            showBlueGlow(self)
        end)
    end
    if button.HideOverlayGlow then
        hooksecurefunc(button, "HideOverlayGlow", function(self)
            if self.overlay then self.overlay:SetAlpha(1) end
            hideBlueGlow(self)
        end)
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_SHOW")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if AssistedCombatManager then
            hooksecurefunc(AssistedCombatManager, "SetAssistedHighlightFrameShown", onAssistedHighlightChanged)
        end
        ActionBarButtonEventsFrame:ForEachFrame(trySetupAlertHooks)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")

    elseif event == "SPELL_ACTIVATION_OVERLAY_SHOW" then
        C_Timer.After(0, function()
            ActionBarButtonEventsFrame:ForEachFrame(function(button)
                local wasAlreadyHooked = hookedButtons[button]
                trySetupAlertHooks(button)

                if button.SpellActivationAlert and button.SpellActivationAlert:IsShown() then
                    -- Suppress children that may have been shown before hooks were set up
                    for _, childName in ipairs(ALERT_CHILDREN) do
                        suppressAlertChild(button.SpellActivationAlert[childName])
                    end
                    -- OnShow hook was not set up yet for this button's first proc, trigger manually
                    if not wasAlreadyHooked then
                        showBlueGlow(button)
                    end
                end
            end)
        end)
    end
end)