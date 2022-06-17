Most of the work with ProfileService is setting up your data loading code. Afterwards, data is read and written directly to the `Profile.Data` table without the necessity to use any ProfileService method calls - you set up your own read / write functions, wrappers, classes with profiles as components, etc!

The code below is a basic profile loader implementation for ProfileService:

!!! note
	Unlike most custom DataStore modules where you would listen for `Players.PlayerRemoving` to clean up,
	ProfileService may release (destroy) the profile before the player leaves the server - this has to be
	handled by using `Profile:ListenToRelease(listener_function)` - any amount of functions can be added!

``` lua
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local ProfileService = require(ServerScriptService.ProfileService)

-- Use the profile service to create the profile store. The second argument is the template.
-- The template table is what empty profiles will default to. Since loadProfile reconciles the profile,
-- missing values will be filled in from the template in existing profiles.
local profileStore = ProfileService.GetProfileStore("PlayerData", {
	Cash = 0,
	Items = {},
	LogInTimes = 0,
})

-- The profiles table relates active players to their profiles.
local profiles = {}

local function onProfileLoaded(player, profile)
	profile.Data.LogInTimes = profile.Data.LogInTimes + 1
	print(string.format("%s has logged in %i times.", player.Name, profile.Data.LogInTimes))
	
	profile.Data.Cash = profile.Data.Cash + 100
	print(player.Name .. " owns " .. tostring(profile.Data.Cash) .. " now!")
end

local function loadProfile(player)
	local profile = profileStore:LoadProfileAsync("Player_" .. player.UserId)
	if not profile then
		-- The profile couldn't be loaded possibly due to other
		-- Roblox servers trying to load this profile at the same time:
		player:Kick() 
		return
	end
	
	-- GDPR compliance
	profile:AddUserId(player.UserId) 
	
	-- Fill in missing variables from ProfileTemplate
	profile:Reconcile()
	
	-- If the player is still around even after their profile has been released,
	-- then we should kick them. The profile could've been loaded on another Roblox server.
	profile:ListenToRelease(function()
		player:Kick()
	end)
	
	if player:IsDescendantOf(Players) == true then
		-- A profile has been successfully loaded:
		return profile
	else
		-- Player left before the profile loaded:
		profile:Release()
	end
end

-- Adds a profile to the profiles table.
local function addProfile(player)
	-- Load the profile
	local profile = loadProfile(player)
	-- Save it into the profiles table
	profiles[player] = profile
	-- Give the player their cash and increment their log in times
	onProfileLoaded(player, profile)
end

-- Add the profiles of the players who have already joined the server
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(addProfile, player) -- Loading a profile is async
end

-- Add the profiles of new players
Players.PlayerAdded:Connect(addProfile)

-- When a player leaves the game, release the profile and remove it from the profiles table
Players.PlayerRemoving:Connect(function(player)
	local profile = profiles[player]
	if profile then
		profile:Release()
		profile[player] = nil
	end
end)
```
