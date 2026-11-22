local BSR = ...

Hook.Patch(
    "Barotrauma.CrewManager",
    "RemoveCharacterInfo",
    function(instance, ptable)
        local targetInfo = ptable["characterInfo"]
        local infoName = targetInfo and targetInfo.Name or "Unknown"

        if not BSR.allowFireCharacter then
            ptable.PreventExecution = true
            print("[BotShuttleRespawn] Prevented deletion of CharacterInfo for: " .. tostring(infoName))
        else
            print("[BotShuttleRespawn] Allowed deletion (fired) of CharacterInfo for: " .. tostring(infoName))
        end
        BSR.allowFireCharacter = false
        return nil
    end,
    Hook.HookMethodType.Before
)

Hook.Patch(
    "Barotrauma.CrewManager",
    "FireCharacter",
    function(instance, ptable)
        BSR.allowFireCharacter = true
        print("[BotShuttleRespawn] FireCharacter triggered!")
    end,
    Hook.HookMethodType.Before
)