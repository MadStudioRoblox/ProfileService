-- ProfileTemplate table is what empty profiles will default to.
-- Updating the template will not include missing template values
--   in existing player profiles!
local ProfileTemplate = {
	Cash = 0,
	Items = {},
	LogInTimes = 0,
}

----- Loaded Modules -----

local ProfileService = require(game.ServerScriptService.ProfileService)

----- Private Variables -----

local Players = game:GetService("Players")

local GameProfileStore = ProfileService.GetProfileStore(
	"PlayerData",
	ProfileTemplate
)

local Profiles = {} -- [player] = profile

----- Private Functions -----

local function GiveCash(profile, amount)
	-- If "Cash" was not defined in the ProfileTemplate at game launch,
	--   you will have to perform the following:
	if profile.Data.Cash == nil then
		profile.Data.Cash = 0
	end
	-- Increment the "Cash" value:
	profile.Data.Cash = profile.Data.Cash + amount
end

local function DoSomethingWithALoadedProfile(player, profile)
	profile.Data.LogInTimes = profile.Data.LogInTimes + 1
	print(player.Name .. " has logged in " .. tostring(profile.Data.LogInTimes)
		.. " time" .. ((profile.Data.LogInTimes > 1) and "s" or ""))
	GiveCash(profile, 100)
	print(player.Name .. " owns " .. tostring(profile.Data.Cash) .. " now!")
end

local function PlayerAdded(player)
	local profile = GameProfileStore:LoadProfileAsync("Player_" .. player.UserId)
	if profile ~= nil then
		profile:AddUserId(player.UserId) -- GDPR compliance
		profile:Reconcile() -- Fill in missing variables from ProfileTemplate (optional)
		profile:ListenToRelease(function()
			Profiles[player] = nil
			-- The profile could've been loaded on another Roblox server:
			player:Kick()
		end)
		if player:IsDescendantOf(Players) == true then
			Profiles[player] = profile
			-- A profile has been successfully loaded:
			DoSomethingWithALoadedProfile(player, profile)
		else
			-- Player left before the profile loaded:
			profile:Release()
		end
	else
		-- The profile couldn't be loaded possibly due to other
		--   Roblox servers trying to load this profile at the same time:
		player:Kick()
	end
end

----- Initialize -----

-- In case Players have joined the server earlier than this script ran:
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(PlayerAdded, player)
end

----- Connections -----

Players.PlayerAdded:Connect(PlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	local profile = Profiles[player]
	if profile ~= nil then
		profile:Release()
	end
end)
