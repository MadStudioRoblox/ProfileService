-- local Madwork = _G.Madwork
--[[
{Madwork}

-[ProfileTest]---------------------------------------
	(STANDALONE VERSION)
	A brief testing of ProfileService
	
	NOTICE: Assumes that "ProfileService" ModuleScript is inside ServerScriptService
--]]

local SETTINGS = {
	
	ProfileTemplate1 = {
		Counter = 0,
		Array = {},
		Dictionary = {},
	},
	
	ProfileTemplate2 = {
		Value = 0,
	}
	
}

----- Service Table -----

local ProfileTest = {
	TEST_MOCK = false, -- When set to true, tests ProfileStore.Mock functionality
}

----- Loaded Services & Modules -----

local ServerScriptService = game:GetService("ServerScriptService")

local ProfileService = require(ServerScriptService.ProfileService)
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")

----- Private Variables -----

local RandomProfileStoreKey1 = "Test_" .. tostring(HttpService:GenerateGUID())
local RandomProfileStoreKey2 = "Test_" .. tostring(HttpService:GenerateGUID())

local GameProfileStore1 = ProfileService.GetProfileStore(RandomProfileStoreKey1, SETTINGS.ProfileTemplate1)
local GameProfileStore2 = ProfileService.GetProfileStore(RandomProfileStoreKey2, SETTINGS.ProfileTemplate2)

local MockDataStore = ProfileService._mock_data_store -- For studio testing

----- Utils -----

local function DeepCopyTable(t)
	local copy = {}
	for key, value in pairs(t) do
		if type(value) == "table" then
			copy[key] = DeepCopyTable(value)
		else
			copy[key] = value
		end
	end
	return copy
end

local function KeyToString(key)
	if type(key) == "string" then
		return "\"" .. key .. "\""
	else
		return tostring(key)
	end
end

local function TableToString(t)
	local output = "{"
	local entries = 0
	for key, value in pairs(t) do
		entries = entries + 1
		if type(value) == "string" then
			output = output .. (entries > 1 and ", " or "") .. "[" .. KeyToString(key) .. "] = \"" .. value .. "\""
		elseif type(value) == "number" then
			output = output .. (entries > 1 and ", " or "") .. "[" .. KeyToString(key) .. "] = " .. value
		elseif type(value) == "table" then
			output = output .. (entries > 1 and ", " or "") .. "[" .. KeyToString(key) .. "] = " .. TableToString(value)
		elseif type(value) == "userdata" then
			if typeof(value) == "Instance" then
				output = output .. (entries > 1 and ", " or "") .. "[" .. KeyToString(key) .. "] = Instance:" .. tostring(value)
			else
				output = output .. (entries > 1 and ", " or "") .. "[" .. KeyToString(key) .. "] = userdata:" .. typeof(value)
			end
		else
			output = output .. (entries > 1 and ", " or "") .. "[" .. KeyToString(key) .. "] = " .. tostring(value)
		end
	end
	output = output .. "}"
	return output
end

local function TestPass(test_txt, mode)
	print(test_txt .. ": " .. ((mode == true) and "PASS" or "FAILED"))
end

----- Private functions -----

local function MockUpdateAsync(mock_data_store, profile_store_name, key, transform_function)
	local profile_store = mock_data_store[profile_store_name]
	if profile_store == nil then
		profile_store = {}
		mock_data_store[profile_store_name] = profile_store
	end
	local transform = transform_function(profile_store[key])
	if transform == nil then
		return nil
	else
		profile_store[key] = DeepCopyTable(transform)
		return DeepCopyTable(profile_store[key])
	end
end

local function TestUpdateAsync(profile_store_name, key, transform_function)
	if ProfileService._use_mock_data_store == true or ProfileTest.TEST_MOCK == true then
		MockUpdateAsync(MockDataStore, profile_store_name, key, transform_function)
	else
		local data_store = DataStoreService:GetDataStore(profile_store_name)
		data_store:UpdateAsync(key, transform_function)
	end
end

----- Initialize -----

local GameProfileStore1_live
if ProfileTest.TEST_MOCK == true then
	MockDataStore = ProfileService._user_mock_data_store
	GameProfileStore1_live = GameProfileStore1
	GameProfileStore1 = GameProfileStore1.Mock
	GameProfileStore2 = GameProfileStore2.Mock
	print("[MOCK]")
end

coroutine.wrap(function()
	
	print("RUNNING PROFILE TEST")
	
	-- NOTICE: Will finish much faster in studio than in Roblox servers - DataStore limits the frequency
	-- of UpdateAsync calls and will throw nasty warnings, but it should all work the same... Just much
	-- slower.
	
	--[[
	What to test:
		1) (Load - Release)(x5) - view
		2) Load - Global Update - Listen to new active update - lock - save - clear - release - load - release
		3) Global update (add, add, clear) on empty - view - load - release
		4) Load - set meta tag - wait for auto-save - check meta tag latest - release
		5) Test errors
		6) Test load yoinks
	--]]
	
	-- Test MOCK: --
	if ProfileTest.TEST_MOCK == true then
		local success_mock = pcall(function()
			local profile_live = GameProfileStore1:LoadProfileAsync("ProfileMock", "ForceLoad")
			wait(2)
			local profile_mock = GameProfileStore1_live:LoadProfileAsync("ProfileMock", "ForceLoad")
		end)
		TestPass("ProfileService mock test", success_mock == true)
	end
	
	-- Test #1: --
	for i = 1, 2 do
		local profile1 = GameProfileStore1:LoadProfileAsync("Profile1", "ForceLoad")
		profile1.Data.Counter = profile1.Data.Counter + 1
		profile1:Release()
	end
	local profile1 = GameProfileStore1:ViewProfileAsync("Profile1")
	TestPass("ProfileService test #1 - part1", profile1.Data.Counter == 2)
	GameProfileStore1:WipeProfileAsync("Profile1")
	profile1 = GameProfileStore1:ViewProfileAsync("Profile1")
	TestPass("ProfileService test #1 - part2", profile1.Data == nil)
	
	-- Test #2: --
	local profile2 = GameProfileStore1:LoadProfileAsync("Profile2", "ForceLoad")
	
	profile2.GlobalUpdates:ListenToNewActiveUpdate(function(update_id, update_data)
		if update_data.UpdateTag == "Hello!" then
			TestPass("ProfileService test #2 - part 1", #(profile2.GlobalUpdates:GetActiveUpdates()) == 1)
			profile2.GlobalUpdates:LockActiveUpdate(update_id)
			TestPass("ProfileService test #2 - part 2", #(profile2.GlobalUpdates:GetActiveUpdates()) == 0)
			profile2:Save()
		end
	end)
	
	local test2_checkpoint2 = false
	
	profile2.GlobalUpdates:ListenToNewLockedUpdate(function(update_id, update_data)
		if update_data.UpdateTag == "Hello!" then
			TestPass("ProfileService test #2 - part 3", #(profile2.GlobalUpdates:GetActiveUpdates()) == 0)
			TestPass("ProfileService test #2 - part 4", #(profile2.GlobalUpdates:GetLockedUpdates()) == 1)
			test2_checkpoint2 = true
			profile2.GlobalUpdates:ClearLockedUpdate(update_id)
			TestPass("ProfileService test #2 - part 5", #(profile2.GlobalUpdates:GetLockedUpdates()) == 0)
			profile2:Save()
		end
	end)
	
	GameProfileStore1:GlobalUpdateProfileAsync("Profile2", function(global_updates)
		global_updates:AddActiveUpdate({UpdateTag = "Hello!"})
	end)
	profile2:Save() -- Fetch global update
	
	--[[
	while true do
		print(TableToString(profile2.GlobalUpdates._updates_latest))
		wait(1)
	end
	--]]
	
	while test2_checkpoint2 == false do wait() end
	while #profile2.GlobalUpdates._updates_latest[2] ~= 0 do wait() end
	TestPass("ProfileService test #2 - part 6", true)
	
	-- Test #3: --
	GameProfileStore1:GlobalUpdateProfileAsync("Profile3", function(global_updates)
		global_updates:AddActiveUpdate({UpdateTag = "Test1"})
	end)
	GameProfileStore1:GlobalUpdateProfileAsync("Profile3", function(global_updates)
		global_updates:AddActiveUpdate({UpdateTag = "Test2"})
		global_updates:AddActiveUpdate({UpdateTag = "Test3"})
		global_updates:AddActiveUpdate({UpdateTag = "Test4"})
		for _, update_data in pairs(global_updates:GetActiveUpdates()) do
			if update_data[2].UpdateTag == "Test1" then
				global_updates:ClearActiveUpdate(update_data[1])
			elseif update_data[2].UpdateTag == "Test4" then
				global_updates:ChangeActiveUpdate(update_data[1], {UpdateTag = "Test1000000"})
			end
		end
	end)
	local profile3 = GameProfileStore1:ViewProfileAsync("Profile3")
	local profile_3_updates = profile3.GlobalUpdates:GetActiveUpdates()
	
	local updates_good = false
	pcall(function()
		updates_good = (profile_3_updates[1][2].UpdateTag == "Test2") and
			(profile_3_updates[2][2].UpdateTag == "Test3") and
			(profile_3_updates[3][2].UpdateTag == "Test1000000")
	end)
	TestPass("ProfileService test #3 - part 1", updates_good)
	
	profile3 = GameProfileStore1:LoadProfileAsync("Profile3", "ForceLoad")
	profile_3_updates = profile3.GlobalUpdates:GetActiveUpdates()
	
	updates_good = false
	pcall(function()
		updates_good = (profile_3_updates[1][2].UpdateTag == "Test2") and
			(profile_3_updates[2][2].UpdateTag == "Test3") and
			(profile_3_updates[3][2].UpdateTag == "Test1000000")
	end)
	TestPass("ProfileService test #3 - part 2", updates_good)
	
	-- Test #4: --
	local profile4 = GameProfileStore1:LoadProfileAsync("Profile4", "ForceLoad")
	profile4:SetMetaTag("LoadedFirstTime", true)
	profile4.MetaData.MetaTags["PurchaseIds"] = {}
	table.insert(profile4.MetaData.MetaTags["PurchaseIds"], "a")
	
	TestPass("ProfileService test #4 - part 1", profile4.MetaData.MetaTags.LoadedFirstTime == true)
	profile4:Save()
	
	while profile4.MetaData.MetaTagsLatest.LoadedFirstTime == nil do wait() end
	updates_good = false
	pcall(function()
		updates_good = profile4.MetaData.MetaTagsLatest.PurchaseIds[1] == "a"
	end)
	TestPass("ProfileService test #4 - part 2", profile4.MetaData.MetaTagsLatest.LoadedFirstTime == true and updates_good)
	profile4:SetMetaTag("LoadedFirstTime", false)
	TestPass("ProfileService test #4 - part 3", profile4.MetaData.MetaTagsLatest.LoadedFirstTime == true and profile4.MetaData.MetaTags.LoadedFirstTime == false)
	
	-- Test #5: --
	local load1 = nil
	local load2 = nil
	
	local success5_1 = pcall(function()
		load1 = GameProfileStore1:LoadProfileAsync("Profile5", "ForceLoad")
		wait(2)
		load2 = GameProfileStore1:LoadProfileAsync("Profile5", "ForceLoad")
	end)
	TestPass("ProfileService test #5 - part 1", success5_1 == false)
	
	if load1 ~= nil then load1:Release() end if load2 ~= nil then load2:Release() end
	load1 = nil
	load2 = nil
	local success5_2 = pcall(function()
		load1 = GameProfileStore1:LoadProfileAsync("Profile5", "ForceLoad")
		load1:Release()
		load2 = GameProfileStore1:LoadProfileAsync("Profile5", "ForceLoad")
	end)
	TestPass("ProfileService test #5 - part 2", success5_2 == true)
	
	-- Test #6: --
	local profile6_1
	local profile6_2
	local profile6_3
	
	coroutine.resume(coroutine.create(function()
		profile6_1 = GameProfileStore1:LoadProfileAsync("Profile6", "ForceLoad")
		if profile6_1 == nil then
			profile6_1 = 0
		end
	end))
	coroutine.resume(coroutine.create(function()
		profile6_2 = GameProfileStore1:LoadProfileAsync("Profile6", "ForceLoad")
		if profile6_2 == nil then
			profile6_2 = 0
		end
	end))
	coroutine.resume(coroutine.create(function()
		profile6_3 = GameProfileStore1:LoadProfileAsync("Profile6", "ForceLoad")
		if profile6_3 == nil then
			profile6_3 = 0
		end
	end))
	
	while profile6_1 == nil or profile6_2 == nil or profile6_3 == nil do
		wait()
	end
	
	TestPass("ProfileService test #6", profile6_1 == 0 and profile6_2 == 0 and type(profile6_3) == "table")
	
	-- Test #7: --
	print("Test #7 begin... (This can take a bit)")
	local corruption_signal_received = false
	ProfileService.CorruptionSignal:Connect(function(profile_store_name, profile_key)
		if profile_store_name == RandomProfileStoreKey1 and profile_key == "Profile7" then
			corruption_signal_received = true
		end
	end)
	TestUpdateAsync(RandomProfileStoreKey1, "Profile7", function() -- Injecting a faulty profile table
		return {"ThisAintRight"}
	end)
	local profile7 = GameProfileStore1:LoadProfileAsync("Profile7", "ForceLoad")
	TestPass("ProfileService test #7", corruption_signal_received)
	
	-- Test #8: --
	print("Test #8 begin... (ASYNC - HAS TO PASS IN AROUND A MINUTE)")
	local profile8 = GameProfileStore1:LoadProfileAsync("Profile8", "ForceLoad")
	profile8:ListenToRelease(function()
		TestPass("ProfileService test #8", true)
	end)
	TestUpdateAsync(RandomProfileStoreKey1, "Profile8", function() -- Injecting profile table of an unreleased session
		return {
			Data = {},
			MetaData = {
				ProfileCreateTime = 0,
				SessionLoadCount = 0,
				ActiveSession = {123, 123},
				ForceLoadSession = nil,
				MetaTags = {},
			},
			GlobalUpdates = {0, {}},
		}
	end)
	
	-- Test #9: --
	print("Test #9 begin... (ASYNC - HAS TO PASS IN AROUND A MINUTE)")
	local profile9 = GameProfileStore1:LoadProfileAsync("Profile9", "ForceLoad")
	profile9:ListenToRelease(function()
		TestPass("ProfileService test #9", true)
	end)
	TestUpdateAsync(RandomProfileStoreKey1, "Profile9", function() -- Injecting profile table with force load request
		return {
			Data = {},
			MetaData = {
				ProfileCreateTime = 0,
				SessionLoadCount = 0,
				ActiveSession = profile9.MetaData.ActiveSession,
				ForceLoadSession = {123, 123},
				MetaTags = {},
			},
			GlobalUpdates = {0, {}},
		}
	end)
	
	-- Test #10: --
	print("Test #10 begin... (This will take over a minute)")
	local not_released_handler_test = false
	TestUpdateAsync(RandomProfileStoreKey1, "Profile10", function() -- Injecting profile table of an unreleased session
		return {
			Data = {},
			MetaData = {
				ProfileCreateTime = 0,
				SessionLoadCount = 0,
				ActiveSession = {123, 123},
				ForceLoadSession = nil,
				MetaTags = {},
			},
			GlobalUpdates = {0, {}},
		}
	end)
	local profile10 = GameProfileStore1:LoadProfileAsync("Profile10", function(place_id, game_job_id)
		if place_id == 123 and game_job_id == 123 then
			not_released_handler_test = true
			return "ForceLoad"
		else
			return "Cancel"
		end
	end)
	TestPass("ProfileService test #10", profile10 ~= nil and not_released_handler_test == true)
	
	-- Test #11: --
	local profile11 = GameProfileStore1:LoadProfileAsync("Profile11", "ForceLoad")
	profile11.Data = {Array = false}
	profile11:Reconcile()
	TestPass("ProfileService test #11", profile11.Data.Counter == 0 and profile11.Data.Array == false and type(profile11.Data.Dictionary) == "table")
	
end)()

return ProfileTest