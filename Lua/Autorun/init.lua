if CLIENT and not SERVER then return end

local modPath = ...
local BSR = {}

loadfile(modPath .. "/Lua/BotShuttleRespawn/state.lua")(BSR)
loadfile(modPath .. "/Lua/BotShuttleRespawn/utils.lua")(BSR)
loadfile(modPath .. "/Lua/BotShuttleRespawn/crew_hooks.lua")(BSR)
loadfile(modPath .. "/Lua/BotShuttleRespawn/respawn_hooks.lua")(BSR)
loadfile(modPath .. "/Lua/BotShuttleRespawn/commands.lua")(BSR)

print("[BotShuttleRespawn] Mod loaded successfully (Debug Mode ON)!")