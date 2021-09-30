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

local ProfileService
do
	local did_yield = true
	task.spawn(function()
		ProfileService = require(ServerScriptService.ProfileService)
		did_yield = false
	end)
	if did_yield == true then
		error("[ProfileTest]: ProfileService ModuleScript should not yield when required!")
	end
end

local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")

----- Private Variables -----

local RandomProfileStoreKey1 = "Test_" .. tostring(HttpService:GenerateGUID())
local RandomProfileStoreScope1 = "Scope_" .. tostring(HttpService:GenerateGUID())

local RandomProfileStoreKey2 = "Test_" .. tostring(HttpService:GenerateGUID())
local RandomProfileStoreScope2 = "Scope_" .. tostring(HttpService:GenerateGUID())

local GameProfileStore1 = ProfileService.GetProfileStore(
	{
		Name = RandomProfileStoreKey1,
		Scope = RandomProfileStoreScope1,
	},
	SETTINGS.ProfileTemplate1
)

local GameProfileStore2 = ProfileService.GetProfileStore(
	{
		Name = RandomProfileStoreKey2,
		Scope = RandomProfileStoreScope2,
	},
	SETTINGS.ProfileTemplate2
)

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

local function MockUpdateAsync(mock_data_store, store_lookup, key, transform_function)
	local profile_store = mock_data_store[store_lookup]
	if profile_store == nil then
		profile_store = {}
		mock_data_store[store_lookup] = profile_store
	end
	local transform = transform_function(profile_store[key])
	if transform == nil then
		return nil
	else
		local epoch_time = math.floor(os.time() * 1000)
		local mock_entry = profile_store[key]
		if mock_entry == nil then
			mock_entry = {
				Data = nil,
				CreatedTime = epoch_time,
				UpdatedTime = epoch_time,
				VersionId = 0,
				UserIds = {},
				MetaData = {},
			}
			profile_store[key] = mock_entry
		end
		mock_entry.UpdatedTime = epoch_time
		mock_entry.VersionId += 1
		mock_entry.Data = DeepCopyTable(transform)
		return DeepCopyTable(mock_entry.Data)
	end
end

local function TestUpdateAsync(store_name, store_scope, key, transform_function)
	if ProfileService._use_mock_data_store == true or ProfileTest.TEST_MOCK == true then
		MockUpdateAsync(
			MockDataStore,
			store_name .. "\0" .. (store_scope or ""),
			key,
			transform_function
		)
	else
		local data_store = DataStoreService:GetDataStore(store_name, store_scope)
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

task.spawn(function()
	
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

	local live_mode = ProfileService.IsLive()

	-- Versioning test:

	if live_mode == true then

		print("Running versioning test... (Can take a few minutes)")

		-- Creating several versions for the same key:

		local profile = GameProfileStore1:LoadProfileAsync("VersioningTest")
		profile.Data.Gold = 10
		profile:Release()

		local payload = GameProfileStore1:ViewProfileAsync("VersioningTest")
		for i = 1, 3 do
			payload.Data.Gold += 10
			payload:OverwriteAsync()
		end

		-- There should be 5 versions for this key in total:

		local query = GameProfileStore1:ProfileVersionQuery(
			"VersioningTest",
			Enum.SortDirection.Descending,
			nil,
			DateTime.fromUnixTimestamp(os.time() + 10000) -- Future time
		  )
		local query_results = {}
		local pending_tasks = 0

		for i = 1, 6 do
			pending_tasks += 1
			task.spawn(function()
			  local result = query:NextAsync()
			  if result ~= nil then
				if i == 6 then
					error("6 entries found when there should be only 5 (might be an order of query returns problem)")
				end
				table.insert(query_results, result)
			  end
			  pending_tasks -= 1
			end)
		end

		while pending_tasks > 0 do
			task.wait()
		end

		local expecting_values = {0, 10, 20, 30, 40}

		for _, entry in ipairs(query_results) do
			local index = table.find(expecting_values, entry.Data.Gold or 0)
			if index ~= nil then
				table.remove(expecting_values, index)
			end
		end

		for i = 1, 10 do
			task.wait() -- Wait a few frames for the query queue to resolve
		end

		if #query._query_queue > 0 then
			error("Version query queue leak detected")
		end

		TestPass("ProfileService versioning test", #expecting_values == 0)

	else
		print("Versioning test not supported in mock mode")
	end

	-- Test profile payloads:

	do

		print("Running payload test... (Can take a few minutes)")

		-- Create profile with some data and an active global update:
		
		local profile = GameProfileStore1:LoadProfileAsync("PayloadTest")
		profile.Data = {
			Coins = 68,
		}
		profile:AddUserId(2312310)
		profile:SetMetaTag("Version", 1)
		profile.RobloxMetaData = {Playtime = 123456}
		
		GameProfileStore1:GlobalUpdateProfileAsync("PayloadTest",
			function(global_updates)
				global_updates:AddActiveUpdate({GiftType = "SpecialGift"})
			end
		)

		-- We need the profile to be active, and ensure all above data is saved in the DataStore:

		local wait_for_profile = true
		profile.KeyInfoUpdated:Connect(function()
			wait_for_profile = false
		end)
		while wait_for_profile == true do wait() end

		if #profile.GlobalUpdates:GetActiveUpdates() == 0 then
			error("Global update was not received")
		end

		-- Create a profile payload:

		profile.Coins = 1000000 -- The player JUST received tons of cash!!! Payloads can lose up to
			-- several minutes of in-game progress when overwriting. You should use :LoadProfileAsync()
			-- If you want to protect in-game progress.

		local payload = GameProfileStore1:ViewProfileAsync("PayloadTest")
		payload.Data.Coins += 1
		payload:AddUserId(50)

		local active_update_check = payload.GlobalUpdates:GetActiveUpdates()[1]
		active_update_check = active_update_check and active_update_check[2]
		active_update_check = active_update_check and active_update_check.GiftType

		if active_update_check ~= "SpecialGift" then
			error("Global update was not received in the viewed profile")
		end

		payload:ClearGlobalUpdates()

		if #payload.GlobalUpdates:GetActiveUpdates() ~= 0 then
			error("Global updates could not be cleared")
		end

		payload:OverwriteAsync()

		-- The profile should lose its session lock:

		local start_time = os.clock()
		wait_for_profile = true
		profile:ListenToHopReady(function()
			wait_for_profile = false
		end)
		while wait_for_profile == true do
			if os.clock() - start_time > 240 then
				error("Session steal by payload timeout")
			end
			wait()
		end

		if profile:IsActive() == true then
			error("Faulty :IsActive()")
		end

		-- Load and check new data:

		profile = GameProfileStore1:LoadProfileAsync("PayloadTest")

		local key_info = profile.KeyInfo
		local metadata = key_info:GetMetadata()
		local user_ids = key_info:GetUserIds()

		local is_passed = profile.Data.Coins == 69
			and metadata.Playtime == 123456 and table.find(user_ids, 2312310) ~= nil
			and table.find(user_ids, 50) ~= nil and #profile.GlobalUpdates:GetActiveUpdates() == 0

		TestPass("ProfileService payload test", is_passed)

		profile:Release()

	end

	-- Test KeyInfo:

	do

		local profile = GameProfileStore1:LoadProfileAsync("ProfileKeyInfo")
		profile.RobloxMetaData = {Color = {0.955, 0, 0}, Dedication = "Veteran"}
		profile:AddUserId(2312310)
		profile:AddUserId(50)
		profile:AddUserId(420)
		profile:RemoveUserId(50)

		profile:Release()

		local wait_for_profile = true
		profile:ListenToHopReady(function()
			wait_for_profile = false
		end)

		while wait_for_profile == true do wait() end

		local key_info = profile.KeyInfo
		local metadata = key_info:GetMetadata()
		local user_ids = key_info:GetUserIds()
		
		local is_color_good = type(metadata.Color) == "table"
			and metadata.Color[1] == 0.955
			and metadata.Color[2] == 0
			and metadata.Color[3] == 0

		local is_passed = is_color_good == true
			and metadata.Dedication == "Veteran" and table.find(user_ids, 2312310) ~= nil
			and table.find(user_ids, 420) ~= nil and table.find(user_ids, 50) == nil

		if live_mode == true and profile._is_user_mock ~= true and type(key_info) == "table" then
			error("MOCK KEY INFO LEAK")
		end

		TestPass("ProfileService key info (Roblox Metadata) test", is_passed)

	end
	
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
	TestPass("ProfileService test #1 - part2", profile1 == nil)
	
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
	TestUpdateAsync(RandomProfileStoreKey1, RandomProfileStoreScope1, "Profile7", function() -- Injecting a faulty profile table
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
	TestUpdateAsync(RandomProfileStoreKey1, RandomProfileStoreScope1, "Profile8", function() -- Injecting profile table of an unreleased session
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
	TestUpdateAsync(RandomProfileStoreKey1, RandomProfileStoreScope1, "Profile9", function() -- Injecting profile table with force load request
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
	TestUpdateAsync(RandomProfileStoreKey1, RandomProfileStoreScope1, "Profile10", function() -- Injecting profile table of an unreleased session
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
	
end)
