local ProfileTemplate = {
	Cash = 0,
	Items = {},
	LogInTimes = 0,
}

----- Loaded Services & Modules -----

local ProfileService = require(game.ServerScriptService.ProfileService)

----- Private Variables -----

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local GameProfileStore = ProfileService.GetProfileStore("PlayerData", ProfileTemplate)

local Profiles = {} -- [player] = profile

----- Private Functions -----

local function DoSomethingWithALoadedProfile(player, profile)
	profile.Data.LogInTimes = profile.Data.LogInTimes + 1
	print(player.Name .. " has logged in " .. tostring(profile.Data.LogInTimes) .. " time" .. ((profile.Data.LogInTimes > 1) and "s" or ""))
end

local function PlayerAdded(player)
	local profile = GameProfileStore:LoadProfileAsync("Player_" .. player.UserId, "ForceLoad")
	if profile ~= nil then
		profile:ListenToRelease(function()
			Profiles[player] = nil
			player:Kick() -- The profile could've been loaded on another Roblox server
		end)
		if player:IsDescendantOf(Players) == true then
			Profiles[player] = profile
			-- A profile has been successfully loaded!
			DoSomethingWithALoadedProfile(player, profile)
		else
			profile:Release() -- Player left before the profile loaded
		end
	else
		player:Kick() -- The profile couldn't be loaded possibly due to other
		--   Roblox servers trying to load this profile at the same time
	end
end

----- Initialize -----

for _, player in ipairs(Players:GetPlayers()) do
	coroutine.wrap(PlayerAdded)(player)
end

----- Connections -----

Players.PlayerAdded:Connect(PlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	local profile = Profiles[player]
	if profile ~= nil then
		profile:Release()
	end
end)
