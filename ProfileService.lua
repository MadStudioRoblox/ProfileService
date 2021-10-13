-- local Madwork = _G.Madwork
--[[
{Madwork}

-[ProfileService]---------------------------------------
	(STANDALONE VERSION)
	DataStore profiles - universal session-locked savable table API
	
	Official documentation:
		https://madstudioroblox.github.io/ProfileService/

	DevForum discussion:
		https://devforum.roblox.com/t/ProfileService/667805
	
	WARNINGS FOR "Profile.Data" VALUES:
	 	! Do not create numeric tables with gaps - attempting to replicate such tables will result in an error;
		! Do not create mixed tables (some values indexed by number and others by string key), as only
		     the data indexed by number will be replicated.
		! Do not index tables by anything other than numbers and strings.
		! Do not reference Roblox Instances
		! Do not reference userdata (Vector3, Color3, CFrame...) - Serialize userdata before referencing
		! Do not reference functions
		
	WARNING: Calling ProfileStore:LoadProfileAsync() with a "profile_key" which wasn't released in the SAME SESSION will result
		in an error! If you want to "ProfileStore:LoadProfileAsync()" instead of using the already loaded profile, :Release()
		the old Profile object.
		
	Members:
	
		ProfileService.ServiceLocked         [bool]
		
		ProfileService.IssueSignal           [ScriptSignal] (error_message, profile_store_name, profile_key)
		ProfileService.CorruptionSignal      [ScriptSignal] (profile_store_name, profile_key)
		ProfileService.CriticalStateSignal   [ScriptSignal] (is_critical_state)
	
	Functions:
	
		ProfileService.GetProfileStore(profile_store_index, profile_template) --> [ProfileStore]
			profile_store_index   [string] -- DataStore name
			OR
			profile_store_index   [table]: -- Allows the developer to define more GlobalDataStore variables
				{
					Name = "StoreName", -- [string] -- DataStore name
					-- Optional arguments:
					Scope = "StoreScope", -- [string] -- DataStore scope
				}
			profile_template      [table] -- Profiles will default to given table (hard-copy) when no data was saved previously

		ProfileService.IsLive() --> [bool] -- (CAN YIELD!!!)
			-- Returns true if ProfileService is connected to live Roblox DataStores
				
	Members [ProfileStore]:
	
		ProfileStore.Mock   [ProfileStore] -- Reflection of ProfileStore methods, but the methods will use a mock DataStore
		
	Methods [ProfileStore]:
	
		ProfileStore:LoadProfileAsync(profile_key, not_released_handler) --> [Profile] or nil -- not_released_handler(place_id, game_job_id)
			profile_key            [string] -- DataStore key
			not_released_handler   nil or []: -- Defaults to "ForceLoad"
				[string] "ForceLoad" -- Force loads profile on first call
				OR
				[string] "Steal" -- Steals the profile ignoring it's session lock
				OR
				[function] (place_id, game_job_id) --> [string] "Repeat", "Cancel", "ForceLoad" or "Steal"
					place_id      [number] or nil
					game_job_id   [string] or nil

				-- not_released_handler [function] will be triggered in cases where the profile is not released by a session. This
				--	function may yield for as long as desirable and must return one of three string values:

						["Repeat"] - ProfileService will repeat the profile loading proccess and may trigger the release handler again
						["Cancel"] - ProfileStore:LoadProfileAsync() will immediately return nil
						["ForceLoad"] - ProfileService will repeat the profile loading call, but will return Profile object afterwards
							and release the profile for another session that has loaded the profile
						["Steal"] - The profile will usually be loaded immediately, ignoring an existing remote session lock and applying
							a session lock for this session.

		ProfileStore:GlobalUpdateProfileAsync(profile_key, update_handler) --> [GlobalUpdates] or nil
			-- Returns GlobalUpdates object if update was successful, otherwise returns nil
			profile_key      [string] -- DataStore key
			update_handler   [function] (global_updates [GlobalUpdates])
			
		ProfileStore:ViewProfileAsync(profile_key, version) --> [Profile] or nil
			-- Reads profile without requesting a session lock; Data will not be saved and profile doesn't need to be released
			profile_key   [string] -- DataStore key
			version       nil or [string] -- DataStore key version

		ProfileStore:ProfileVersionQuery(profile_key, sort_direction, min_date, max_date) --> [ProfileVersionQuery]
			profile_key      [string]
			sort_direction   nil or [Enum.SortDirection]
			min_date         nil or [DateTime]
			max_date         nil or [DateTime]
			
		ProfileStore:WipeProfileAsync(profile_key) --> is_wipe_successful [bool]
			-- Completely wipes out profile data from the DataStore / mock DataStore with no way to recover it.
						
		* Parameter description for "ProfileStore:GlobalUpdateProfileAsync()":
		
			profile_key      [string] -- DataStore key
			update_handler   [function] (GlobalUpdates) -- This function gains access to GlobalUpdates object methods
				(update_handler can't yield)

	Methods [ProfileVersionQuery]:

		ProfileVersionQuery:NextAsync() --> [Profile] or nil -- (Yields)
			-- Returned profile has the same rules as profile returned by :ViewProfileAsync()
		
	Members [Profile]:
	
		Profile.Data              [table] -- Writable table that gets saved automatically and once the profile is released
		Profile.MetaData          [table] (Read-only) -- Information about this profile
		
			Profile.MetaData.ProfileCreateTime   [number] (Read-only) -- os.time() timestamp of profile creation
			Profile.MetaData.SessionLoadCount    [number] (Read-only) -- Amount of times the profile was loaded
			Profile.MetaData.ActiveSession       [table] (Read-only) {place_id, game_job_id} / nil -- Set to a session link if a
				game session is currently having this profile loaded; nil if released
			Profile.MetaData.MetaTags            [table] {["tag_name"] = tag_value, ...} -- Saved and auto-saved just like Profile.Data
			Profile.MetaData.MetaTagsLatest      [table] (Read-only) -- Latest version of MetaData.MetaTags that was definetly saved to DataStore
				(You can use Profile.MetaData.MetaTagsLatest for product purchase save confirmation, but create a system to clear old tags after
				they pile up)

		Profile.MetaTagsUpdated   [ScriptSignal] (meta_tags_latest) -- Fires after every auto-save, after
			--	Profile.MetaData.MetaTagsLatest has been updated with the version that's guaranteed to be saved;
			--  .MetaTagsUpdated will fire regardless of whether .MetaTagsLatest changed after update;
			--	.MetaTagsUpdated may fire after the Profile is released - changes to Profile.Data are not saved
			--	after release.

		Profile.RobloxMetaData    [table] -- Writable table that gets saved automatically and once the profile is released
		Profile.UserIds           [table] -- (Read-only) -- {user_id [number], ...} -- User ids associated with this profile

		Profile.KeyInfo           [DataStoreKeyInfo]
		Profile.KeyInfoUpdated    [ScriptSignal] (key_info [DataStoreKeyInfo])
		
		Profile.GlobalUpdates     [GlobalUpdates]
		
	Methods [Profile]:
	
		-- SAFE METHODS - Will not error after profile expires:
		Profile:IsActive() --> [bool] -- Returns true while the profile is active and can be written to
			
		Profile:GetMetaTag(tag_name) --> value [any]
			tag_name   [string]
		
		Profile:Reconcile() -- Fills in missing (nil) [string_key] = [value] pairs to the Profile.Data structure
		
		Profile:ListenToRelease(listener) --> [ScriptConnection] (place_id / nil, game_job_id / nil)
			-- WARNING: Profiles can be released externally if another session force-loads
			--	this profile - use :ListenToRelease() to handle player leaving cleanup.
			
		Profile:Release() -- Call after the session has finished working with this profile
			e.g., after the player leaves (Profile object will become expired) (Does not yield)

		Profile:ListenToHopReady(listener) --> [ScriptConnection] () -- Passed listener will be executed after the releasing UpdateAsync call finishes;
			--	Wrap universe teleport requests with this method AFTER releasing the profile to improve session lock sharing between universe places;
			--  :ListenToHopReady() will usually call the listener in around a second, but may ocassionally take up to 7 seconds when a release happens
			--	next to an auto-update in regular usage scenarios.

		Profile:AddUserId(user_id) -- Associates user_id with profile (GDPR compliance)
			user_id   [number]

		Profile:RemoveUserId(user_id) -- Unassociates user_id with profile (safe function)
			user_id   [number]

		Profile:Identify() --> [string] -- Returns a string containing DataStore name, scope and key; Used for debug;
			-- Example return: "[Store:"GameData";Scope:"Live";Key:"Player_2312310"]"
		
		Profile:SetMetaTag(tag_name, value) -- Equivalent of Profile.MetaData.MetaTags[tag_name] = value
			tag_name   [string]
			value      [any]
		
		Profile:Save() -- Call to quickly progress global update state or to speed up save validation processes (Does not yield)

		-- VIEW-MODE ONLY:

		Profile:ClearGlobalUpdates() -- Clears all global updates data from a profile payload

		Profile:OverwriteAsync() -- (Yields) Saves the profile payload to the DataStore and removes the session lock
		
	Methods [GlobalUpdates]:
	
	-- ALWAYS PUBLIC:
		GlobalUpdates:GetActiveUpdates() --> [table] {{update_id, update_data [table]}, ...}
		GlobalUpdates:GetLockedUpdates() --> [table] {{update_id, update_data [table]}, ...}
		
	-- ONLY WHEN FROM "Profile.GlobalUpdates":
		GlobalUpdates:ListenToNewActiveUpdate(listener) --> [ScriptConnection] (update_id, update_data)
			update_data   [table]
		GlobalUpdates:ListenToNewLockedUpdate(listener) --> [ScriptConnection] (update_id, update_data)
			update_data   [table]
		GlobalUpdates:LockActiveUpdate(update_id)  -- WARNING: will error after profile expires
		GlobalUpdates:ClearLockedUpdate(update_id) -- WARNING: will error after profile expires
		
	-- EXPOSED TO "update_handler" DURING ProfileStore:GlobalUpdateProfileAsync() CALL
		GlobalUpdates:AddActiveUpdate(update_data)
			update_data   [table]
		GlobalUpdates:ChangeActiveUpdate(update_id, update_data)
			update_data   [table]
		GlobalUpdates:ClearActiveUpdate(update_id)
		
--]]

local SETTINGS = {

	AutoSaveProfiles = 30, -- Seconds (This value may vary - ProfileService will split the auto save load evenly in the given time)
	RobloxWriteCooldown = 7, -- Seconds between successive DataStore calls for the same key
	ForceLoadMaxSteps = 8, -- Steps taken before ForceLoad request steals the active session for a profile
	AssumeDeadSessionLock = 30 * 60, -- (seconds) If a profile hasn't been updated for 30 minutes, assume the session lock is dead
		-- As of writing, os.time() is not completely reliable, so we can only assume session locks are dead after a significant amount of time.
	
	IssueCountForCriticalState = 5, -- Issues to collect to announce critical state
	IssueLast = 120, -- Seconds
	CriticalStateLast = 120, -- Seconds
	
	MetaTagsUpdatedValues = { -- Technical stuff - do not alter
		ProfileCreateTime = true,
		SessionLoadCount = true,
		ActiveSession = true,
		ForceLoadSession = true,
		LastUpdate = true,
	},
	
}

local Madwork -- Standalone Madwork reference for portable version of ProfileService
do

	local MadworkScriptSignal = {}

	local FreeRunnerThread = nil
	
	local function AcquireRunnerThreadAndCallEventHandler(fn, ...)
		local acquired_runner_thread = FreeRunnerThread
		FreeRunnerThread = nil
		fn(...)
		FreeRunnerThread = acquired_runner_thread
	end
	
	local function RunEventHandlerInFreeThread(...)
		AcquireRunnerThreadAndCallEventHandler(...)
		while true do
			AcquireRunnerThreadAndCallEventHandler(coroutine.yield())
		end
	end
	
	-- ScriptConnection object:

	local ScriptConnection = {
		--[[
			_listener = listener,
			_script_signal = script_signal,
			_disconnect_listener = disconnect_listener,
			_disconnect_param = disconnect_param,
			
			_next = next_script_connection,
			_is_connected = is_connected,
		--]]
	}
	ScriptConnection.__index = ScriptConnection

	function ScriptConnection:Disconnect()

		if self._is_connected == false then
			return
		end

		self._is_connected = false
		self._script_signal._listener_count -= 1

		if self._script_signal._head == self then
			self._script_signal._head = self._next
		else
			local prev = self._script_signal._head
			while prev ~= nil and prev._next ~= self do
				prev = prev._next
			end
			if prev ~= nil then
				prev._next = self._next
			end
		end

		if self._disconnect_listener ~= nil then
			if not FreeRunnerThread then
				FreeRunnerThread = coroutine.create(RunEventHandlerInFreeThread)
			end
			task.spawn(FreeRunnerThread, self._disconnect_listener, self._disconnect_param)
			self._disconnect_listener = nil
		end

	end
	
	-- ScriptSignal object:

	local ScriptSignal = {
		--[[
			_head = nil,
			_listener_count = 0,
		--]]
	}
	ScriptSignal.__index = ScriptSignal

	function ScriptSignal:Connect(listener, disconnect_listener, disconnect_param) --> [ScriptConnection]

		local script_connection = {
			_listener = listener,
			_script_signal = self,
			_disconnect_listener = disconnect_listener,
			_disconnect_param = disconnect_param,

			_next = self._head,
			_is_connected = true,
		}
		setmetatable(script_connection, ScriptConnection)

		self._head = script_connection
		self._listener_count += 1

		return script_connection

	end

	function ScriptSignal:GetListenerCount() --> [number]
		return self._listener_count
	end

	function ScriptSignal:Fire(...)
		local item = self._head
		while item ~= nil do
			if item._is_connected == true then
				if not FreeRunnerThread then
					FreeRunnerThread = coroutine.create(RunEventHandlerInFreeThread)
				end
				task.spawn(FreeRunnerThread, item._listener, ...)
			end
			item = item._next
		end
	end

	function ScriptSignal:FireUntil(continue_callback, ...)
		local item = self._head
		while item ~= nil do
			if item._is_connected == true then
				item._listener(...)
				if continue_callback() ~= true then
					return
				end
			end
			item = item._next
		end
	end

	function MadworkScriptSignal.NewScriptSignal() --> [ScriptSignal]
		return {
			_head = nil,
			_listener_count = 0,
			Connect = ScriptSignal.Connect,
			GetListenerCount = ScriptSignal.GetListenerCount,
			Fire = ScriptSignal.Fire,
			FireUntil = ScriptSignal.FireUntil,
		}
	end

	-- Madwork framework namespace:
	
	Madwork = {
		NewScriptSignal = MadworkScriptSignal.NewScriptSignal,
		ConnectToOnClose = function(task, run_in_studio_mode)
			if game:GetService("RunService"):IsStudio() == false or run_in_studio_mode == true then
				game:BindToClose(task)
			end
		end,
	}

end

----- Service Table -----

local ProfileService = {

	ServiceLocked = false, -- Set to true once the server is shutting down

	IssueSignal = Madwork.NewScriptSignal(), -- (error_message, profile_store_name, profile_key) -- Fired when a DataStore API call throws an error
	CorruptionSignal = Madwork.NewScriptSignal(), -- (profile_store_name, profile_key) -- Fired when DataStore key returns a value that has
	-- all or some of it's profile components set to invalid data types. E.g., accidentally setting Profile.Data to a noon table value

	CriticalState = false, -- Set to true while DataStore service is throwing too many errors
	CriticalStateSignal = Madwork.NewScriptSignal(), -- (is_critical_state) -- Fired when CriticalState is set to true
	-- (You may alert players with this, or set up analytics)

	ServiceIssueCount = 0,

	_active_profile_stores = {}, -- {profile_store, ...}

	_auto_save_list = {}, -- {profile, ...} -- loaded profile table which will be circularly auto-saved

	_issue_queue = {}, -- [table] {issue_time, ...}
	_critical_state_start = 0, -- [number] 0 = no critical state / os.clock() = critical state start

	-- Debug:
	_mock_data_store = {},
	_user_mock_data_store = {},

	_use_mock_data_store = false,

}

--[[
	Saved profile structure:
	
	DataStoreProfile = {
		Data = {},
		MetaData = {
			ProfileCreateTime = 0,
			SessionLoadCount = 0,
			ActiveSession = {place_id, game_job_id} / nil,
			ForceLoadSession = {place_id, game_job_id} / nil,
			MetaTags = {},
			LastUpdate = 0, -- os.time()
		},
		RobloxMetaData = {},
		UserIds = {},
		GlobalUpdates = {
			update_index,
			{
				{update_id, version_id, update_locked, update_data},
				...
			}
		},
	}
	
	OR
	
	DataStoreProfile = {
		GlobalUpdates = {
			update_index,
			{
				{update_id, version_id, update_locked, update_data},
				...
			}
		},
	}
--]]

----- Private Variables -----

local ActiveProfileStores = ProfileService._active_profile_stores
local AutoSaveList = ProfileService._auto_save_list
local IssueQueue = ProfileService._issue_queue

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local PlaceId = game.PlaceId
local JobId = game.JobId

local AutoSaveIndex = 1 -- Next profile to auto save
local LastAutoSave = os.clock()

local LoadIndex = 0

local ActiveProfileLoadJobs = 0 -- Number of active threads that are loading in profiles
local ActiveProfileSaveJobs = 0 -- Number of active threads that are saving profiles

local CriticalStateStart = 0 -- os.clock()

local IsStudio = RunService:IsStudio()
local IsLiveCheckActive = false

local UseMockDataStore = false
local MockDataStore = ProfileService._mock_data_store -- Mock data store used when API access is disabled

local UserMockDataStore = ProfileService._user_mock_data_store -- Separate mock data store accessed via ProfileStore.Mock
local UseMockTag = {}

local CustomWriteQueue = {
	--[[
		[store] = {
			[key] = {
				LastWrite = os.clock(),
				Queue = {callback, ...},
				CleanupJob = nil,
			},
			...
		},
		...
	--]]
}

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

local function ReconcileTable(target, template)
	for k, v in pairs(template) do
		if type(k) == "string" then -- Only string keys will be reconciled
			if target[k] == nil then
				if type(v) == "table" then
					target[k] = DeepCopyTable(v)
				else
					target[k] = v
				end
			elseif type(target[k]) == "table" and type(v) == "table" then
				ReconcileTable(target[k], v)
			end
		end
	end
end

----- Private functions -----

local function IdentifyProfile(store_name, store_scope, key)
	return string.format(
		"[Store:\"%s\";%sKey:\"%s\"]",
		store_name,
		store_scope ~= nil and string.format("Scope:\"%s\";", store_scope) or "",
		key
	)
end

local function CustomWriteQueueCleanup(store, key)
	if CustomWriteQueue[store] ~= nil then
		CustomWriteQueue[store][key] = nil
		if next(CustomWriteQueue[store]) == nil then
			CustomWriteQueue[store] = nil
		end
	end
end

local function CustomWriteQueueMarkForCleanup(store, key)
	if CustomWriteQueue[store] ~= nil then
		if CustomWriteQueue[store][key] ~= nil then

			local queue_data = CustomWriteQueue[store][key]
			local queue = queue_data.Queue

			if queue_data.CleanupJob == nil then

				queue_data.CleanupJob = RunService.Heartbeat:Connect(function()
					if os.clock() - queue_data.LastWrite > SETTINGS.RobloxWriteCooldown and #queue == 0 then
						queue_data.CleanupJob:Disconnect()
						CustomWriteQueueCleanup(store, key)
					end
				end)

			end

		elseif next(CustomWriteQueue[store]) == nil then
			CustomWriteQueue[store] = nil
		end
	end
end

local function CustomWriteQueueAsync(callback, store, key) --> ... -- Passed return from callback

	if CustomWriteQueue[store] == nil then
		CustomWriteQueue[store] = {}
	end
	if CustomWriteQueue[store][key] == nil then
		CustomWriteQueue[store][key] = {LastWrite = 0, Queue = {}, CleanupJob = nil}
	end

	local queue_data = CustomWriteQueue[store][key]
	local queue = queue_data.Queue

	-- Cleanup job:

	if queue_data.CleanupJob ~= nil then
		queue_data.CleanupJob:Disconnect()
		queue_data.CleanupJob = nil
	end

	-- Queue logic:

	if os.clock() - queue_data.LastWrite > SETTINGS.RobloxWriteCooldown and #queue == 0 then
		queue_data.LastWrite = os.clock()
		return callback()
	else
		table.insert(queue, callback)
		while true do
			if os.clock() - queue_data.LastWrite > SETTINGS.RobloxWriteCooldown and queue[1] == callback then
				table.remove(queue, 1)
				queue_data.LastWrite = os.clock()
				return callback()
			end
			task.wait()
		end
	end

end

local function IsCustomWriteQueueEmptyFor(store, key) --> is_empty [bool]
	local lookup = CustomWriteQueue[store]
	if lookup ~= nil then
		lookup = lookup[key]
		return lookup == nil or #lookup.Queue == 0
	end
	return true
end

local function WaitForLiveAccessCheck() -- This function was created to prevent the ProfileService module yielding execution when required
	while IsLiveCheckActive == true do
		task.wait()
	end
end

local function WaitForPendingProfileStore(profile_store)
	while profile_store._is_pending == true do
		task.wait()
	end
end

local function RegisterIssue(error_message, store_name, store_scope, profile_key) -- Called when a DataStore API call errors
	warn("[ProfileService]: DataStore API error " .. IdentifyProfile(store_name, store_scope, profile_key) .. " - \"" .. tostring(error_message) .. "\"")
	table.insert(IssueQueue, os.clock()) -- Adding issue time to queue
	ProfileService.IssueSignal:Fire(tostring(error_message), store_name, profile_key)
end

local function RegisterCorruption(store_name, store_scope, profile_key) -- Called when a corrupted profile is loaded
	warn("[ProfileService]: Resolved profile corruption " .. IdentifyProfile(store_name, store_scope, profile_key))
	ProfileService.CorruptionSignal:Fire(store_name, profile_key)
end

local function NewMockDataStoreKeyInfo(params)

	local version_id_string = tostring(params.VersionId or 0)
	local meta_data = params.MetaData or {}
	local user_ids = params.UserIds or {}

	return {
		CreatedTime = params.CreatedTime,
		UpdatedTime = params.UpdatedTime,
		Version = string.rep("0", 16) .. "."
			.. string.rep("0", 10 - string.len(version_id_string)) .. version_id_string
			.. "." .. string.rep("0", 16) .. "." .. "01",

		GetMetadata = function()
			return DeepCopyTable(meta_data)
		end,

		GetUserIds = function()
			return DeepCopyTable(user_ids)
		end,
	}

end

local function MockUpdateAsync(mock_data_store, profile_store_name, key, transform_function, is_get_call) --> loaded_data, key_info

	local profile_store = mock_data_store[profile_store_name]

	if profile_store == nil then
		profile_store = {}
		mock_data_store[profile_store_name] = profile_store
	end

	local epoch_time = math.floor(os.time() * 1000)
	local mock_entry = profile_store[key]
	local mock_entry_was_nil = false

	if mock_entry == nil then
		mock_entry_was_nil = true
		if is_get_call ~= true then
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
	end

	local mock_key_info = mock_entry_was_nil == false and NewMockDataStoreKeyInfo(mock_entry) or nil

	local transform, user_ids, roblox_meta_data = transform_function(mock_entry and mock_entry.Data, mock_key_info)

	if transform == nil then
		return nil
	else
		if mock_entry ~= nil and is_get_call ~= true then
			mock_entry.Data = transform
			mock_entry.UserIds = DeepCopyTable(user_ids or {})
			mock_entry.MetaData = DeepCopyTable(roblox_meta_data or {})
			mock_entry.VersionId += 1
			mock_entry.UpdatedTime = epoch_time
		end

		return DeepCopyTable(transform), mock_entry ~= nil and NewMockDataStoreKeyInfo(mock_entry) or nil
	end

end

local function IsThisSession(session_tag)
	return session_tag[1] == PlaceId and session_tag[2] == JobId
end

--[[
update_settings = {
	ExistingProfileHandle = function(latest_data),
	MissingProfileHandle = function(latest_data),
	EditProfile = function(lastest_data),
}
--]]
local function StandardProfileUpdateAsyncDataStore(profile_store, profile_key, update_settings, is_user_mock, is_get_call, version) --> loaded_data, key_info
	local loaded_data, key_info
	local success, error_message = pcall(function()
		local transform_function = function(latest_data)

			local missing_profile = false
			local data_corrupted = false
			local global_updates_data = {0, {}}

			if latest_data == nil then
				missing_profile = true
			elseif type(latest_data) ~= "table" then
				missing_profile = true
				data_corrupted = true
			end

			if type(latest_data) == "table" then
				-- Case #1: Profile was loaded
				if type(latest_data.Data) == "table"
					and type(latest_data.MetaData) == "table"
					and type(latest_data.GlobalUpdates) == "table" then

					latest_data.WasCorrupted = false -- Must be set to false if set previously
					global_updates_data = latest_data.GlobalUpdates
					if update_settings.ExistingProfileHandle ~= nil then
						update_settings.ExistingProfileHandle(latest_data)
					end
					-- Case #2: Profile was not loaded but GlobalUpdate data exists
				elseif latest_data.Data == nil
					and latest_data.MetaData == nil
					and type(latest_data.GlobalUpdates) == "table" then

					latest_data.WasCorrupted = false -- Must be set to false if set previously
					global_updates_data = latest_data.GlobalUpdates or global_updates_data
					missing_profile = true
				else
					missing_profile = true
					data_corrupted = true
				end
			end

			-- Case #3: Profile was not created or corrupted and no GlobalUpdate data exists
			if missing_profile == true then
				latest_data = {
					-- Data = nil,
					-- MetaData = nil,
					GlobalUpdates = global_updates_data,
				}
				if update_settings.MissingProfileHandle ~= nil then
					update_settings.MissingProfileHandle(latest_data)
				end
			end

			-- Editing profile:
			if update_settings.EditProfile ~= nil then
				update_settings.EditProfile(latest_data)
			end

			-- Data corruption handling (Silently override with empty profile) (Also run Case #1)
			if data_corrupted == true then
				latest_data.WasCorrupted = true -- Temporary tag that will be removed on first save
			end

			return latest_data, latest_data.UserIds, latest_data.RobloxMetaData
		end
		if is_user_mock == true then -- Used when the profile is accessed through ProfileStore.Mock
			loaded_data, key_info = MockUpdateAsync(UserMockDataStore, profile_store._profile_store_lookup, profile_key, transform_function, is_get_call)
			task.wait() -- Simulate API call yield
		elseif UseMockDataStore == true then -- Used when API access is disabled
			loaded_data, key_info = MockUpdateAsync(MockDataStore, profile_store._profile_store_lookup, profile_key, transform_function, is_get_call)
			task.wait() -- Simulate API call yield
		else
			loaded_data, key_info = CustomWriteQueueAsync(
				function() -- Callback
					if is_get_call == true then
						local get_data, get_key_info
						if version ~= nil then
							local success, error_message = pcall(function()
								get_data, get_key_info = profile_store._global_data_store:GetVersionAsync(profile_key, version)
							end)
							if success == false and type(error_message) == "string" and string.find(error_message, "not valid") ~= nil then
								warn("[ProfileService]: Passed version argument is not valid; Traceback:\n" .. debug.traceback())
							end
						else
							get_data, get_key_info = profile_store._global_data_store:GetAsync(profile_key)
						end
						get_data = transform_function(get_data)
						return get_data, get_key_info
					else
						return profile_store._global_data_store:UpdateAsync(profile_key, transform_function)
					end
				end,
				profile_store._profile_store_lookup, -- Store
				profile_key -- Key
			)
		end
	end)
	if success == true and type(loaded_data) == "table" then
		-- Corruption handling:
		if loaded_data.WasCorrupted == true and is_get_call ~= true then
			RegisterCorruption(
				profile_store._profile_store_name,
				profile_store._profile_store_scope,
				profile_key
			)
		end
		-- Return loaded_data:
		return loaded_data, key_info
	else
		RegisterIssue(
			(error_message ~= nil) and error_message or "Undefined error",
			profile_store._profile_store_name,
			profile_store._profile_store_scope,
			profile_key
		)
		-- Return nothing:
		return nil
	end
end

local function RemoveProfileFromAutoSave(profile)
	local auto_save_index = table.find(AutoSaveList, profile)
	if auto_save_index ~= nil then
		table.remove(AutoSaveList, auto_save_index)
		if auto_save_index < AutoSaveIndex then
			AutoSaveIndex = AutoSaveIndex - 1 -- Table contents were moved left before AutoSaveIndex so move AutoSaveIndex left as well
		end
		if AutoSaveList[AutoSaveIndex] == nil then -- AutoSaveIndex was at the end of the AutoSaveList - reset to 1
			AutoSaveIndex = 1
		end
	end
end

local function AddProfileToAutoSave(profile) -- Notice: Makes sure this profile isn't auto-saved too soon
	-- Add at AutoSaveIndex and move AutoSaveIndex right:
	table.insert(AutoSaveList, AutoSaveIndex, profile)
	if #AutoSaveList > 1 then
		AutoSaveIndex = AutoSaveIndex + 1
	elseif #AutoSaveList == 1 then
		-- First profile created - make sure it doesn't get immediately auto saved:
		LastAutoSave = os.clock()
	end
end

local function ReleaseProfileInternally(profile)
	-- 1) Remove profile object from ProfileService references: --
	-- Clear reference in ProfileStore:
	local profile_store = profile._profile_store
	local loaded_profiles = profile._is_user_mock == true and profile_store._mock_loaded_profiles or profile_store._loaded_profiles
	loaded_profiles[profile._profile_key] = nil
	if next(profile_store._loaded_profiles) == nil and next(profile_store._mock_loaded_profiles) == nil then -- ProfileStore has turned inactive
		local index = table.find(ActiveProfileStores, profile_store)
		if index ~= nil then
			table.remove(ActiveProfileStores, index)
		end
	end
	-- Clear auto update reference:
	RemoveProfileFromAutoSave(profile)
	-- 2) Trigger release listeners: --
	local place_id
	local game_job_id
	local active_session = profile.MetaData.ActiveSession
	if active_session ~= nil then
		place_id = active_session[1]
		game_job_id = active_session[2]
	end
	profile._release_listeners:Fire(place_id, game_job_id)
end

local function CheckForNewGlobalUpdates(profile, old_global_updates_data, new_global_updates_data)
	local global_updates_object = profile.GlobalUpdates -- [GlobalUpdates]
	local pending_update_lock = global_updates_object._pending_update_lock -- {update_id, ...}
	local pending_update_clear = global_updates_object._pending_update_clear -- {update_id, ...}
	-- "old_" or "new_" global_updates_data = {update_index, {{update_id, version_id, update_locked, update_data}, ...}}
	for _, new_global_update in ipairs(new_global_updates_data[2]) do
		-- Find old global update with the same update_id:
		local old_global_update
		for _, global_update in ipairs(old_global_updates_data[2]) do
			if global_update[1] == new_global_update[1] then
				old_global_update = global_update
				break
			end
		end
		-- A global update is new when it didn't exist before or its version_id or update_locked state changed:
		local is_new = false
		if old_global_update == nil or new_global_update[2] > old_global_update[2] or new_global_update[3] ~= old_global_update[3] then
			is_new = true
		end
		if is_new == true then
			-- Active global updates:
			if new_global_update[3] == false then
				-- Check if update is not pending to be locked: (Preventing firing new active update listeners more than necessary)
				local is_pending_lock = false
				for _, update_id in ipairs(pending_update_lock) do
					if new_global_update[1] == update_id then
						is_pending_lock = true
						break
					end
				end
				if is_pending_lock == false then
					-- Trigger new active update listeners:
					global_updates_object._new_active_update_listeners:Fire(new_global_update[1], new_global_update[4])
				end
			end
			-- Locked global updates:
			if new_global_update[3] == true then
				-- Check if update is not pending to be cleared: (Preventing firing new locked update listeners after marking a locked update for clearing)
				local is_pending_clear = false
				for _, update_id in ipairs(pending_update_clear) do
					if new_global_update[1] == update_id then
						is_pending_clear = true
						break
					end
				end
				if is_pending_clear == false then
					-- Trigger new locked update listeners:

					global_updates_object._new_locked_update_listeners:FireUntil(
						function()
							-- Check if listener marked the update to be cleared:
							-- Normally there should be only one listener per profile for new locked global updates, but
							-- in case several listeners are connected we will not trigger more listeners after one listener
							-- marks the locked global update to be cleared.
							return table.find(pending_update_clear, new_global_update[1]) == nil
						end,
						new_global_update[1], new_global_update[4]
					)

				end
			end
		end
	end
end

local function SaveProfileAsync(profile, release_from_session, is_overwriting)
	if type(profile.Data) ~= "table" then
		RegisterCorruption(
			profile._profile_store._profile_store_name,
			profile._profile_store._profile_store_scope,
			profile._profile_key
		)
		error("[ProfileService]: PROFILE DATA CORRUPTED DURING RUNTIME! Profile: " .. profile:Identify())
	end
	if release_from_session == true and is_overwriting ~= true then
		ReleaseProfileInternally(profile)
	end
	ActiveProfileSaveJobs = ActiveProfileSaveJobs + 1
	local last_session_load_count = profile.MetaData.SessionLoadCount
	-- Compare "SessionLoadCount" when writing to profile to prevent a rare case of repeat last save when the profile is loaded on the same server again
	local repeat_save_flag = true -- Released Profile save calls have to repeat until they succeed
	while repeat_save_flag == true do
		if release_from_session ~= true then
			repeat_save_flag = false
		end
		local loaded_data, key_info = StandardProfileUpdateAsyncDataStore(
			profile._profile_store,
			profile._profile_key,
			{
				ExistingProfileHandle = nil,
				MissingProfileHandle = nil,
				EditProfile = function(latest_data)

					local session_owns_profile = false
					local force_load_pending = false

					if is_overwriting ~= true then
						-- 1) Check if this session still owns the profile: --
						local active_session = latest_data.MetaData.ActiveSession
						local force_load_session = latest_data.MetaData.ForceLoadSession
						local session_load_count = latest_data.MetaData.SessionLoadCount

						if type(active_session) == "table" then
							session_owns_profile = IsThisSession(active_session) and session_load_count == last_session_load_count
						end
						if type(force_load_session) == "table" then
							force_load_pending = not IsThisSession(force_load_session)
						end
					else
						session_owns_profile = true
					end

					if session_owns_profile == true then -- We may only edit the profile if this session has ownership of the profile

						if is_overwriting ~= true then
							-- 2) Manage global updates: --
							local latest_global_updates_data = latest_data.GlobalUpdates -- {update_index, {{update_id, version_id, update_locked, update_data}, ...}}
							local latest_global_updates_list = latest_global_updates_data[2]

							local global_updates_object = profile.GlobalUpdates -- [GlobalUpdates]
							local pending_update_lock = global_updates_object._pending_update_lock -- {update_id, ...}
							local pending_update_clear = global_updates_object._pending_update_clear -- {update_id, ...}
							-- Active update locking:
							for i = 1, #latest_global_updates_list do
								for _, lock_id in ipairs(pending_update_lock) do
									if latest_global_updates_list[i][1] == lock_id then
										latest_global_updates_list[i][3] = true
										break
									end
								end
							end
							-- Locked update clearing:
							for _, clear_id in ipairs(pending_update_clear) do
								for i = 1, #latest_global_updates_list do
									if latest_global_updates_list[i][1] == clear_id and latest_global_updates_list[i][3] == true then
										table.remove(latest_global_updates_list, i)
										break
									end
								end
							end
						end

						-- 3) Save profile data: --
						latest_data.Data = profile.Data
						latest_data.RobloxMetaData = profile.RobloxMetaData
						latest_data.UserIds = profile.UserIds

						if is_overwriting ~= true then
							latest_data.MetaData.MetaTags = profile.MetaData.MetaTags -- MetaData.MetaTags is the only actively savable component of MetaData
							latest_data.MetaData.LastUpdate = os.time()
							if release_from_session == true or force_load_pending == true then
								latest_data.MetaData.ActiveSession = nil
							end
						else
							latest_data.MetaData = profile.MetaData
							latest_data.MetaData.ActiveSession = nil
							latest_data.MetaData.ForceLoadSession = nil
							latest_data.GlobalUpdates = profile.GlobalUpdates._updates_latest
						end

					end
				end,
			},
			profile._is_user_mock
		)
		if loaded_data ~= nil and key_info ~= nil then
			if is_overwriting == true then
				break
			end
			repeat_save_flag = false
			-- 4) Set latest data in profile: --
			-- Updating DataStoreKeyInfo:
			profile.KeyInfo = key_info
			-- Setting global updates:
			local global_updates_object = profile.GlobalUpdates -- [GlobalUpdates]
			local old_global_updates_data = global_updates_object._updates_latest
			local new_global_updates_data = loaded_data.GlobalUpdates
			global_updates_object._updates_latest = new_global_updates_data
			-- Setting MetaData:
			local session_meta_data = profile.MetaData
			local latest_meta_data = loaded_data.MetaData
			for key in pairs(SETTINGS.MetaTagsUpdatedValues) do
				session_meta_data[key] = latest_meta_data[key]
			end
			session_meta_data.MetaTagsLatest = latest_meta_data.MetaTags
			-- 5) Check if session still owns the profile: --
			local active_session = loaded_data.MetaData.ActiveSession
			local session_load_count = loaded_data.MetaData.SessionLoadCount
			local session_owns_profile = false
			if type(active_session) == "table" then
				session_owns_profile = IsThisSession(active_session) and session_load_count == last_session_load_count
			end
			local is_active = profile:IsActive()
			if session_owns_profile == true then
				-- 6) Check for new global updates: --
				if is_active == true then -- Profile could've been released before the saving thread finished
					CheckForNewGlobalUpdates(profile, old_global_updates_data, new_global_updates_data)
				end
			else
				-- Session no longer owns the profile:
				-- 7) Release profile if it hasn't been released yet: --
				if is_active == true then
					ReleaseProfileInternally(profile)
				end
				-- Cleanup reference in custom write queue:
				CustomWriteQueueMarkForCleanup(profile._profile_store._profile_store_lookup, profile._profile_key)
				-- Hop ready listeners:
				if profile._hop_ready == false then
					profile._hop_ready = true
					profile._hop_ready_listeners:Fire()
				end
			end
			-- Signaling MetaTagsUpdated listeners after a possible external profile release was handled:
			profile.MetaTagsUpdated:Fire(profile.MetaData.MetaTagsLatest)
			-- Signaling KeyInfoUpdated listeners:
			profile.KeyInfoUpdated:Fire(key_info)
		elseif repeat_save_flag == true then
			task.wait() -- Prevent infinite loop in case DataStore API does not yield
		end
	end
	ActiveProfileSaveJobs = ActiveProfileSaveJobs - 1
end

----- Public functions -----

-- GlobalUpdates object:

local GlobalUpdates = {
	--[[
		_updates_latest = {}, -- [table] {update_index, {{update_id, version_id, update_locked, update_data}, ...}}
		_pending_update_lock = {update_id, ...} / nil, -- [table / nil]
		_pending_update_clear = {update_id, ...} / nil, -- [table / nil]
		
		_new_active_update_listeners = [ScriptSignal] / nil, -- [table / nil]
		_new_locked_update_listeners = [ScriptSignal] / nil, -- [table / nil]
		
		_profile = Profile / nil, -- [Profile / nil]
		
		_update_handler_mode = true / nil, -- [bool / nil]
	--]]
}
GlobalUpdates.__index = GlobalUpdates

-- ALWAYS PUBLIC:
function GlobalUpdates:GetActiveUpdates() --> [table] {{update_id, update_data}, ...}
	local query_list = {}
	for _, global_update in ipairs(self._updates_latest[2]) do
		if global_update[3] == false then
			local is_pending_lock = false
			if self._pending_update_lock ~= nil then
				for _, update_id in ipairs(self._pending_update_lock) do
					if global_update[1] == update_id then
						is_pending_lock = true -- Exclude global updates pending to be locked
						break
					end
				end
			end
			if is_pending_lock == false then
				table.insert(query_list, {global_update[1], global_update[4]})
			end
		end
	end
	return query_list
end

function GlobalUpdates:GetLockedUpdates() --> [table] {{update_id, update_data}, ...}
	local query_list = {}
	for _, global_update in ipairs(self._updates_latest[2]) do
		if global_update[3] == true then
			local is_pending_clear = false
			if self._pending_update_clear ~= nil then
				for _, update_id in ipairs(self._pending_update_clear) do
					if global_update[1] == update_id then
						is_pending_clear = true -- Exclude global updates pending to be cleared
						break
					end
				end
			end
			if is_pending_clear == false then
				table.insert(query_list, {global_update[1], global_update[4]})
			end
		end
	end
	return query_list
end

-- ONLY WHEN FROM "Profile.GlobalUpdates":
function GlobalUpdates:ListenToNewActiveUpdate(listener) --> [ScriptConnection] listener(update_id, update_data)
	if type(listener) ~= "function" then
		error("[ProfileService]: Only a function can be set as listener in GlobalUpdates:ListenToNewActiveUpdate()")
	end
	local profile = self._profile
	if self._update_handler_mode == true then
		error("[ProfileService]: Can't listen to new global updates in ProfileStore:GlobalUpdateProfileAsync()")
	elseif self._new_active_update_listeners == nil then
		error("[ProfileService]: Can't listen to new global updates in view mode")
	elseif profile:IsActive() == false then -- Check if profile is expired
		return { -- Do not connect listener if the profile is expired
			Disconnect = function() end,
		}
	end
	-- Connect listener:
	return self._new_active_update_listeners:Connect(listener)
end

function GlobalUpdates:ListenToNewLockedUpdate(listener) --> [ScriptConnection] listener(update_id, update_data)
	if type(listener) ~= "function" then
		error("[ProfileService]: Only a function can be set as listener in GlobalUpdates:ListenToNewLockedUpdate()")
	end
	local profile = self._profile
	if self._update_handler_mode == true then
		error("[ProfileService]: Can't listen to new global updates in ProfileStore:GlobalUpdateProfileAsync()")
	elseif self._new_locked_update_listeners == nil then
		error("[ProfileService]: Can't listen to new global updates in view mode")
	elseif profile:IsActive() == false then -- Check if profile is expired
		return { -- Do not connect listener if the profile is expired
			Disconnect = function() end,
		}
	end
	-- Connect listener:
	return self._new_locked_update_listeners:Connect(listener)
end

function GlobalUpdates:LockActiveUpdate(update_id)
	if type(update_id) ~= "number" then
		error("[ProfileService]: Invalid update_id")
	end
	local profile = self._profile
	if self._update_handler_mode == true then
		error("[ProfileService]: Can't lock active global updates in ProfileStore:GlobalUpdateProfileAsync()")
	elseif self._pending_update_lock == nil then
		error("[ProfileService]: Can't lock active global updates in view mode")
	elseif profile:IsActive() == false then -- Check if profile is expired
		error("[ProfileService]: PROFILE EXPIRED - Can't lock active global updates")
	end
	-- Check if global update exists with given update_id
	local global_update_exists = nil
	for _, global_update in ipairs(self._updates_latest[2]) do
		if global_update[1] == update_id then
			global_update_exists = global_update
			break
		end
	end
	if global_update_exists ~= nil then
		local is_pending_lock = false
		for _, lock_update_id in ipairs(self._pending_update_lock) do
			if update_id == lock_update_id then
				is_pending_lock = true -- Exclude global updates pending to be locked
				break
			end
		end
		if is_pending_lock == false and global_update_exists[3] == false then -- Avoid id duplicates in _pending_update_lock
			table.insert(self._pending_update_lock, update_id)
		end
	else
		error("[ProfileService]: Passed non-existant update_id")
	end
end

function GlobalUpdates:ClearLockedUpdate(update_id)
	if type(update_id) ~= "number" then
		error("[ProfileService]: Invalid update_id")
	end
	local profile = self._profile
	if self._update_handler_mode == true then
		error("[ProfileService]: Can't clear locked global updates in ProfileStore:GlobalUpdateProfileAsync()")
	elseif self._pending_update_clear == nil then
		error("[ProfileService]: Can't clear locked global updates in view mode")
	elseif profile:IsActive() == false then -- Check if profile is expired
		error("[ProfileService]: PROFILE EXPIRED - Can't clear locked global updates")
	end
	-- Check if global update exists with given update_id
	local global_update_exists = nil
	for _, global_update in ipairs(self._updates_latest[2]) do
		if global_update[1] == update_id then
			global_update_exists = global_update
			break
		end
	end
	if global_update_exists ~= nil then
		local is_pending_clear = false
		for _, clear_update_id in ipairs(self._pending_update_clear) do
			if update_id == clear_update_id then
				is_pending_clear = true -- Exclude global updates pending to be cleared
				break
			end
		end
		if is_pending_clear == false and global_update_exists[3] == true then -- Avoid id duplicates in _pending_update_clear
			table.insert(self._pending_update_clear, update_id)
		end
	else
		error("[ProfileService]: Passed non-existant update_id")
	end
end

-- EXPOSED TO "update_handler" DURING ProfileStore:GlobalUpdateProfileAsync() CALL
function GlobalUpdates:AddActiveUpdate(update_data)
	if type(update_data) ~= "table" then
		error("[ProfileService]: Invalid update_data")
	end
	if self._new_active_update_listeners ~= nil then
		error("[ProfileService]: Can't add active global updates in loaded Profile; Use ProfileStore:GlobalUpdateProfileAsync()")
	elseif self._update_handler_mode ~= true then
		error("[ProfileService]: Can't add active global updates in view mode; Use ProfileStore:GlobalUpdateProfileAsync()")
	end
	-- self._updates_latest = {}, -- [table] {update_index, {{update_id, version_id, update_locked, update_data}, ...}}
	local updates_latest = self._updates_latest
	local update_index = updates_latest[1] + 1 -- Incrementing global update index
	updates_latest[1] = update_index
	-- Add new active global update:
	table.insert(updates_latest[2], {update_index, 1, false, update_data})
end

function GlobalUpdates:ChangeActiveUpdate(update_id, update_data)
	if type(update_id) ~= "number" then
		error("[ProfileService]: Invalid update_id")
	end
	if type(update_data) ~= "table" then
		error("[ProfileService]: Invalid update_data")
	end
	if self._new_active_update_listeners ~= nil then
		error("[ProfileService]: Can't change active global updates in loaded Profile; Use ProfileStore:GlobalUpdateProfileAsync()")
	elseif self._update_handler_mode ~= true then
		error("[ProfileService]: Can't change active global updates in view mode; Use ProfileStore:GlobalUpdateProfileAsync()")
	end
	-- self._updates_latest = {}, -- [table] {update_index, {{update_id, version_id, update_locked, update_data}, ...}}
	local updates_latest = self._updates_latest
	local get_global_update = nil
	for _, global_update in ipairs(updates_latest[2]) do
		if update_id == global_update[1] then
			get_global_update = global_update
			break
		end
	end
	if get_global_update ~= nil then
		if get_global_update[3] == true then
			error("[ProfileService]: Can't change locked global update")
		end
		get_global_update[2] = get_global_update[2] + 1 -- Increment version id
		get_global_update[4] = update_data -- Set new global update data
	else
		error("[ProfileService]: Passed non-existant update_id")
	end
end

function GlobalUpdates:ClearActiveUpdate(update_id)
	if type(update_id) ~= "number" then
		error("[ProfileService]: Invalid update_id argument")
	end
	if self._new_active_update_listeners ~= nil then
		error("[ProfileService]: Can't clear active global updates in loaded Profile; Use ProfileStore:GlobalUpdateProfileAsync()")
	elseif self._update_handler_mode ~= true then
		error("[ProfileService]: Can't clear active global updates in view mode; Use ProfileStore:GlobalUpdateProfileAsync()")
	end
	-- self._updates_latest = {}, -- [table] {update_index, {{update_id, version_id, update_locked, update_data}, ...}}
	local updates_latest = self._updates_latest
	local get_global_update_index = nil
	local get_global_update = nil
	for index, global_update in ipairs(updates_latest[2]) do
		if update_id == global_update[1] then
			get_global_update_index = index
			get_global_update = global_update
			break
		end
	end
	if get_global_update ~= nil then
		if get_global_update[3] == true then
			error("[ProfileService]: Can't clear locked global update")
		end
		table.remove(updates_latest[2], get_global_update_index) -- Remove active global update
	else
		error("[ProfileService]: Passed non-existant update_id")
	end
end

-- Profile object:

local Profile = {
	--[[
		Data = {}, -- [table] -- Loaded once after ProfileStore:LoadProfileAsync() finishes
		MetaData = {}, -- [table] -- Updated with every auto-save
		GlobalUpdates = GlobalUpdates, -- [GlobalUpdates]
		
		_profile_store = ProfileStore, -- [ProfileStore]
		_profile_key = "", -- [string]
		
		_release_listeners = [ScriptSignal] / nil, -- [table / nil]
		_hop_ready_listeners = [ScriptSignal] / nil, -- [table / nil]
		_hop_ready = false,
		
		_view_mode = true / nil, -- [bool] or nil
		
		_load_timestamp = os.clock(),
		
		_is_user_mock = false, -- ProfileStore.Mock
		_mock_key_info = {},
	--]]
}
Profile.__index = Profile

function Profile:IsActive() --> [bool]
	local loaded_profiles = self._is_user_mock == true and self._profile_store._mock_loaded_profiles or self._profile_store._loaded_profiles
	return loaded_profiles[self._profile_key] == self
end

function Profile:GetMetaTag(tag_name) --> value
	local meta_data = self.MetaData
	if meta_data == nil then
		return nil
		-- error("[ProfileService]: This Profile hasn't been loaded before - MetaData not available")
	end
	return self.MetaData.MetaTags[tag_name]
end

function Profile:SetMetaTag(tag_name, value)
	if type(tag_name) ~= "string" then
		error("[ProfileService]: tag_name must be a string")
	elseif string.len(tag_name) == 0 then
		error("[ProfileService]: Invalid tag_name")
	end
	self.MetaData.MetaTags[tag_name] = value
end

function Profile:Reconcile()
	ReconcileTable(self.Data, self._profile_store._profile_template)
end

function Profile:ListenToRelease(listener) --> [ScriptConnection] (place_id / nil, game_job_id / nil)
	if type(listener) ~= "function" then
		error("[ProfileService]: Only a function can be set as listener in Profile:ListenToRelease()")
	end
	if self._view_mode == true then
		return {Disconnect = function() end}
	end
	if self:IsActive() == false then
		-- Call release listener immediately if profile is expired
		local place_id
		local game_job_id
		local active_session = self.MetaData.ActiveSession
		if active_session ~= nil then
			place_id = active_session[1]
			game_job_id = active_session[2]
		end
		listener(place_id, game_job_id)
		return {Disconnect = function() end}
	else
		return self._release_listeners:Connect(listener)
	end
end

function Profile:Save()
	if self._view_mode == true then
		error("[ProfileService]: Can't save Profile in view mode - Should you be calling :OverwriteAsync() instead?")
	end
	if self:IsActive() == false then
		warn("[ProfileService]: Attempted saving an inactive profile "
			.. self:Identify() .. "; Traceback:\n" .. debug.traceback())
		return
	end
	-- Reject save request if a save is already pending in the queue - this will prevent the user from
	--	unecessary API request spam which we could not meaningfully execute anyways!
	if IsCustomWriteQueueEmptyFor(self._profile_store._profile_store_lookup, self._profile_key) == true then
		-- We don't want auto save to trigger too soon after manual saving - this will reset the auto save timer:
		RemoveProfileFromAutoSave(self)
		AddProfileToAutoSave(self)
		-- Call save function in a new thread:
		task.spawn(SaveProfileAsync, self)
	end
end

function Profile:Release()
	if self._view_mode == true then
		return
	end
	if self:IsActive() == true then
		task.spawn(SaveProfileAsync, self, true) -- Call save function in a new thread with release_from_session = true
	end
end

function Profile:ListenToHopReady(listener) --> [ScriptConnection] ()
	if type(listener) ~= "function" then
		error("[ProfileService]: Only a function can be set as listener in Profile:ListenToHopReady()")
	end
	if self._view_mode == true then
		return {Disconnect = function() end}
	end
	if self._hop_ready == true then
		task.spawn(listener)
		return {Disconnect = function() end}
	else
		return self._hop_ready_listeners:Connect(listener)
	end
end

function Profile:AddUserId(user_id) -- Associates user_id with profile (GDPR compliance)

	if type(user_id) ~= "number" or user_id % 1 ~= 0 then
		warn("[ProfileService]: Invalid UserId argument for :AddUserId() ("
			.. tostring(user_id) .. "); Traceback:\n" .. debug.traceback())
		return
	end

	if user_id < 0 and self._is_user_mock ~= true and UseMockDataStore ~= true then
		return -- Avoid giving real Roblox APIs negative UserId's
	end

	if table.find(self.UserIds, user_id) == nil then
		table.insert(self.UserIds, user_id)
	end
	
end

function Profile:RemoveUserId(user_id) -- Unassociates user_id with profile (safe function)

	if type(user_id) ~= "number" or user_id % 1 ~= 0 then
		warn("[ProfileService]: Invalid UserId argument for :RemoveUserId() ("
			.. tostring(user_id) .. "); Traceback:\n" .. debug.traceback())
		return
	end
	
	local index = table.find(self.UserIds, user_id)

	if index ~= nil then
		table.remove(self.UserIds, index)
	end

end

function Profile:Identify() --> [string]
	return IdentifyProfile(
		self._profile_store._profile_store_name,
		self._profile_store._profile_store_scope,
		self._profile_key
	)
end

function Profile:ClearGlobalUpdates() -- Clears all global updates data from a profile payload

	if self._view_mode ~= true then
		error("[ProfileService]: :ClearGlobalUpdates() can only be used in view mode")
	end

	local global_updates_object = {
		_updates_latest = {0, {}},
		_profile = self,
	}
	setmetatable(global_updates_object, GlobalUpdates)

	self.GlobalUpdates = global_updates_object

end

function Profile:OverwriteAsync() -- Saves the profile to the DataStore and removes the session lock

	if self._view_mode ~= true then
		error("[ProfileService]: :OverwriteAsync() can only be used in view mode")
	end

	SaveProfileAsync(self, nil, true)

end

-- ProfileVersionQuery object:

local ProfileVersionQuery = {
	--[[
		_profile_store = profile_store,
		_profile_key = profile_key,
		_sort_direction = sort_direction,
		_min_date = min_date,
		_max_date = max_date,

		_query_pages = pages, -- [DataStoreVersionPages]
		_query_index = index, -- [number]
		_query_failure = false,

		_is_query_yielded = false,
		_query_queue = {},
	--]]
}
ProfileVersionQuery.__index = ProfileVersionQuery

function ProfileVersionQuery:_MoveQueue()
	while #self._query_queue > 0 do
		local queue_entry = table.remove(self._query_queue, 1)
		task.spawn(queue_entry)
		if self._is_query_yielded == true then
			break
		end
	end
end

function ProfileVersionQuery:NextAsync(_is_stacking) --> [Profile] or nil

	if self._profile_store == nil then
		return nil
	end

	local profile
	local is_finished = false

	local function query_job()

		if self._query_failure == true then
			is_finished = true
			return
		end

		-- First "next" call loads version pages:

		if self._query_pages == nil then

			self._is_query_yielded = true
			task.spawn(function()
				profile = self:NextAsync(true)
				is_finished = true
			end)
			
			local list_success, error_message = pcall(function()
				self._query_pages = self._profile_store._global_data_store:ListVersionsAsync(
					self._profile_key,
					self._sort_direction,
					self._min_date,
					self._max_date
				)
				self._query_index = 0
			end)

			if list_success == false or self._query_pages == nil then
				warn("[ProfileService]: Version query fail - " .. tostring(error_message))
				self._query_failure = true
			end

			self._is_query_yielded = false
			self:_MoveQueue()

			return

		end

		local current_page = self._query_pages:GetCurrentPage()
		local next_item = current_page[self._query_index + 1]

		-- No more entries:
		
		if self._query_pages.IsFinished == true and next_item == nil then
			is_finished = true
			return
		end

		-- Load next page when this page is over:

		if next_item == nil then

			self._is_query_yielded = true
			task.spawn(function()
				profile = self:NextAsync(true)
				is_finished = true
			end)

			local success = pcall(function()
				self._query_pages:AdvanceToNextPageAsync()
				self._query_index = 0
			end)

			if success == false or #self._query_pages:GetCurrentPage() == 0 then
				self._query_failure = true
			end

			self._is_query_yielded = false
			self:_MoveQueue()

			return

		end

		-- Next page item:

		self._query_index += 1
		profile = self._profile_store:ViewProfileAsync(self._profile_key, next_item.Version)
		is_finished = true

	end

	if self._is_query_yielded == false then
		query_job()
	else
		if _is_stacking == true then
			table.insert(self._query_queue, 1, query_job)
		else
			table.insert(self._query_queue, query_job)
		end
	end

	while is_finished == false do
		task.wait()
	end

	return profile

end

-- ProfileStore object:

local ProfileStore = {
	--[[
		Mock = {},
	
		_profile_store_name = "", -- [string] -- DataStore name
		_profile_store_scope = nil, -- [string] or [nil] -- DataStore scope
		_profile_store_lookup = "", -- [string] -- _profile_store_name .. "\0" .. (_profile_store_scope or "")
		
		_profile_template = {}, -- [table]
		_global_data_store = global_data_store, -- [GlobalDataStore] -- Object returned by DataStoreService:GetDataStore(_profile_store_name)
		
		_loaded_profiles = {[profile_key] = Profile, ...},
		_profile_load_jobs = {[profile_key] = {load_id, loaded_data}, ...},
		
		_mock_loaded_profiles = {[profile_key] = Profile, ...},
		_mock_profile_load_jobs = {[profile_key] = {load_id, loaded_data}, ...},
	--]]
}
ProfileStore.__index = ProfileStore

function ProfileStore:LoadProfileAsync(profile_key, not_released_handler, _use_mock) --> [Profile / nil] not_released_handler(place_id, game_job_id)

	not_released_handler = not_released_handler or "ForceLoad"

	if self._profile_template == nil then
		error("[ProfileService]: Profile template not set - ProfileStore:LoadProfileAsync() locked for this ProfileStore")
	end
	if type(profile_key) ~= "string" then
		error("[ProfileService]: profile_key must be a string")
	elseif string.len(profile_key) == 0 then
		error("[ProfileService]: Invalid profile_key")
	end
	if type(not_released_handler) ~= "function" and not_released_handler ~= "ForceLoad" and not_released_handler ~= "Steal" then
		error("[ProfileService]: Invalid not_released_handler")
	end

	if ProfileService.ServiceLocked == true then
		return nil
	end

	WaitForPendingProfileStore(self)

	local is_user_mock = _use_mock == UseMockTag

	-- Check if profile with profile_key isn't already loaded in this session:
	for _, profile_store in ipairs(ActiveProfileStores) do
		if profile_store._profile_store_lookup == self._profile_store_lookup then
			local loaded_profiles = is_user_mock == true and profile_store._mock_loaded_profiles or profile_store._loaded_profiles
			if loaded_profiles[profile_key] ~= nil then
				error("[ProfileService]: Profile " .. IdentifyProfile(self._profile_store_name, self._profile_store_scope, profile_key) .. " is already loaded in this session")
				-- Are you using Profile:Release() properly?
			end
		end
	end

	ActiveProfileLoadJobs = ActiveProfileLoadJobs + 1
	local force_load = not_released_handler == "ForceLoad"
	local force_load_steps = 0
	local request_force_load = force_load -- First step of ForceLoad
	local steal_session = false -- Second step of ForceLoad
	local aggressive_steal = not_released_handler == "Steal" -- Developer invoked steal
	while ProfileService.ServiceLocked == false do
		-- Load profile:
		-- SPECIAL CASE - If LoadProfileAsync is called for the same key before another LoadProfileAsync finishes,
		-- yoink the DataStore return for the new call. The older call will return nil. This would prevent very rare
		-- game breaking errors where a player rejoins the server super fast.
		local profile_load_jobs = is_user_mock == true and self._mock_profile_load_jobs or self._profile_load_jobs
		local loaded_data, key_info
		local load_id = LoadIndex + 1
		LoadIndex = load_id
		local profile_load_job = profile_load_jobs[profile_key] -- {load_id, {loaded_data, key_info} or nil}
		if profile_load_job ~= nil then
			profile_load_job[1] = load_id -- Yoink load job
			while profile_load_job[2] == nil do -- Wait for job to finish
				task.wait()
			end
			if profile_load_job[1] == load_id then -- Load job hasn't been double-yoinked
				loaded_data, key_info = table.unpack(profile_load_job[2])
				profile_load_jobs[profile_key] = nil
			else
				ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
				return nil
			end
		else
			profile_load_job = {load_id, nil}
			profile_load_jobs[profile_key] = profile_load_job
			profile_load_job[2] = table.pack(StandardProfileUpdateAsyncDataStore(
				self,
				profile_key,
				{
					ExistingProfileHandle = function(latest_data)
						if ProfileService.ServiceLocked == false then
							local active_session = latest_data.MetaData.ActiveSession
							local force_load_session = latest_data.MetaData.ForceLoadSession
							-- IsThisSession(active_session)
							if active_session == nil then
								latest_data.MetaData.ActiveSession = {PlaceId, JobId}
								latest_data.MetaData.ForceLoadSession = nil
							elseif type(active_session) == "table" then
								if IsThisSession(active_session) == false then
									local last_update = latest_data.MetaData.LastUpdate
									if last_update ~= nil then
										if os.time() - last_update > SETTINGS.AssumeDeadSessionLock then
											latest_data.MetaData.ActiveSession = {PlaceId, JobId}
											latest_data.MetaData.ForceLoadSession = nil
											return
										end
									end
									if steal_session == true or aggressive_steal == true then
										local force_load_uninterrupted = false
										if force_load_session ~= nil then
											force_load_uninterrupted = IsThisSession(force_load_session)
										end
										if force_load_uninterrupted == true or aggressive_steal == true then
											latest_data.MetaData.ActiveSession = {PlaceId, JobId}
											latest_data.MetaData.ForceLoadSession = nil
										end
									elseif request_force_load == true then
										latest_data.MetaData.ForceLoadSession = {PlaceId, JobId}
									end
								else
									latest_data.MetaData.ForceLoadSession = nil
								end
							end
						end
					end,
					MissingProfileHandle = function(latest_data)
						latest_data.Data = DeepCopyTable(self._profile_template)
						latest_data.MetaData = {
							ProfileCreateTime = os.time(),
							SessionLoadCount = 0,
							ActiveSession = {PlaceId, JobId},
							ForceLoadSession = nil,
							MetaTags = {},
						}
					end,
					EditProfile = function(latest_data)
						if ProfileService.ServiceLocked == false then
							local active_session = latest_data.MetaData.ActiveSession
							if active_session ~= nil and IsThisSession(active_session) == true then
								latest_data.MetaData.SessionLoadCount = latest_data.MetaData.SessionLoadCount + 1
								latest_data.MetaData.LastUpdate = os.time()
							end
						end
					end,
				},
				is_user_mock
			))
			if profile_load_job[1] == load_id then -- Load job hasn't been yoinked
				loaded_data, key_info = table.unpack(profile_load_job[2])
				profile_load_jobs[profile_key] = nil
			else
				ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
				return nil -- Load job yoinked
			end
		end
		-- Handle load_data:
		if loaded_data ~= nil and key_info ~= nil then
			local active_session = loaded_data.MetaData.ActiveSession
			if type(active_session) == "table" then
				if IsThisSession(active_session) == true then
					-- Special component in MetaTags:
					loaded_data.MetaData.MetaTagsLatest = DeepCopyTable(loaded_data.MetaData.MetaTags)
					-- Case #1: Profile is now taken by this session:
					-- Create Profile object:
					local global_updates_object = {
						_updates_latest = loaded_data.GlobalUpdates,
						_pending_update_lock = {},
						_pending_update_clear = {},

						_new_active_update_listeners = Madwork.NewScriptSignal(),
						_new_locked_update_listeners = Madwork.NewScriptSignal(),

						_profile = nil,
					}
					setmetatable(global_updates_object, GlobalUpdates)
					local profile = {
						Data = loaded_data.Data,
						MetaData = loaded_data.MetaData,
						MetaTagsUpdated = Madwork.NewScriptSignal(),

						RobloxMetaData = loaded_data.RobloxMetaData or {},
						UserIds = loaded_data.UserIds or {},
						KeyInfo = key_info,
						KeyInfoUpdated = Madwork.NewScriptSignal(),

						GlobalUpdates = global_updates_object,

						_profile_store = self,
						_profile_key = profile_key,

						_release_listeners = Madwork.NewScriptSignal(),
						_hop_ready_listeners = Madwork.NewScriptSignal(),
						_hop_ready = false,

						_load_timestamp = os.clock(),

						_is_user_mock = is_user_mock,
					}
					setmetatable(profile, Profile)
					global_updates_object._profile = profile
					-- Referencing Profile object in ProfileStore:
					if next(self._loaded_profiles) == nil and next(self._mock_loaded_profiles) == nil then -- ProfileStore object was inactive
						table.insert(ActiveProfileStores, self)
					end
					if is_user_mock == true then
						self._mock_loaded_profiles[profile_key] = profile
					else
						self._loaded_profiles[profile_key] = profile
					end
					-- Adding profile to AutoSaveList;
					AddProfileToAutoSave(profile)
					-- Special case - finished loading profile, but session is shutting down:
					if ProfileService.ServiceLocked == true then
						SaveProfileAsync(profile, true) -- Release profile and yield until the DataStore call is finished
						profile = nil -- nil will be returned by this call
					end
					-- Return Profile object:
					ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
					return profile
				else
					-- Case #2: Profile is taken by some other session:
					if force_load == true then
						local force_load_session = loaded_data.MetaData.ForceLoadSession
						local force_load_uninterrupted = false
						if force_load_session ~= nil then
							force_load_uninterrupted = IsThisSession(force_load_session)
						end
						if force_load_uninterrupted == true then
							if request_force_load == false then
								force_load_steps = force_load_steps + 1
								if force_load_steps == SETTINGS.ForceLoadMaxSteps then
									steal_session = true
								end
							end
							task.wait() -- Overload prevention
						else
							-- Another session tried to force load this profile:
							ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
							return nil
						end
						request_force_load = false -- Only request a force load once
					elseif aggressive_steal == true then
						task.wait() -- Overload prevention
					else
						local handler_result = not_released_handler(active_session[1], active_session[2])
						if handler_result == "Repeat" then
							task.wait() -- Overload prevention
						elseif handler_result == "Cancel" then
							ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
							return nil
						elseif handler_result == "ForceLoad" then
							force_load = true
							request_force_load = true
							task.wait() -- Overload prevention
						elseif handler_result == "Steal" then
							aggressive_steal = true
							task.wait() -- Overload prevention
						else
							error(
								"[ProfileService]: Invalid return from not_released_handler (\"" .. tostring(handler_result) .. "\")(" .. type(handler_result) .. ");" ..
									"\n" .. IdentifyProfile(self._profile_store_name, self._profile_store_scope, profile_key) ..
									" Traceback:\n" .. debug.traceback()
							)
						end
					end
				end
			else
				ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
				return nil -- In this scenario it is likely the ProfileService.ServiceLocked flag was raised
			end
		else
			task.wait() -- Overload prevention
		end
	end
	ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
	return nil -- If loop breaks return nothing
end

function ProfileStore:GlobalUpdateProfileAsync(profile_key, update_handler, _use_mock) --> [GlobalUpdates / nil] (update_handler(GlobalUpdates))
	if type(profile_key) ~= "string" or string.len(profile_key) == 0 then
		error("[ProfileService]: Invalid profile_key")
	end
	if type(update_handler) ~= "function" then
		error("[ProfileService]: Invalid update_handler")
	end

	if ProfileService.ServiceLocked == true then
		return nil
	end

	WaitForPendingProfileStore(self)

	while ProfileService.ServiceLocked == false do
		-- Updating profile:
		local loaded_data = StandardProfileUpdateAsyncDataStore(
			self,
			profile_key,
			{
				ExistingProfileHandle = nil,
				MissingProfileHandle = nil,
				EditProfile = function(latest_data)
					-- Running update_handler:
					local global_updates_object = {
						_updates_latest = latest_data.GlobalUpdates,
						_update_handler_mode = true,
					}
					setmetatable(global_updates_object, GlobalUpdates)
					update_handler(global_updates_object)
				end,
			},
			_use_mock == UseMockTag
		)
		CustomWriteQueueMarkForCleanup(self._profile_store_lookup, profile_key)
		-- Handling loaded_data:
		if loaded_data ~= nil then
			-- Return GlobalUpdates object (Update successful):
			local global_updates_object = {
				_updates_latest = loaded_data.GlobalUpdates,
			}
			setmetatable(global_updates_object, GlobalUpdates)
			return global_updates_object
		else
			task.wait() -- Overload prevention
		end
	end
	return nil -- Return nothing (Update unsuccessful)
end

function ProfileStore:ViewProfileAsync(profile_key, version, _use_mock) --> [Profile / nil]
	if type(profile_key) ~= "string" or string.len(profile_key) == 0 then
		error("[ProfileService]: Invalid profile_key")
	end

	if ProfileService.ServiceLocked == true then
		return nil
	end

	WaitForPendingProfileStore(self)

	if version ~= nil and (_use_mock == UseMockTag or UseMockDataStore == true) then
		return nil -- No version support in mock mode
	end

	while ProfileService.ServiceLocked == false do
		-- Load profile:
		local loaded_data, key_info = StandardProfileUpdateAsyncDataStore(
			self,
			profile_key,
			{
				ExistingProfileHandle = nil,
				MissingProfileHandle = function(latest_data)
					latest_data.Data = DeepCopyTable(self._profile_template)
					latest_data.MetaData = {
						ProfileCreateTime = os.time(),
						SessionLoadCount = 0,
						ActiveSession = nil,
						ForceLoadSession = nil,
						MetaTags = {},
					}
				end,
				EditProfile = nil,
			},
			_use_mock == UseMockTag,
			true, -- Use :GetAsync()
			version -- DataStore key version
		)
		CustomWriteQueueMarkForCleanup(self._profile_store_lookup, profile_key)
		-- Handle load_data:
		if loaded_data ~= nil then
			if key_info == nil then
				return nil -- Load was successful, but the key was empty - return no profile object
			end
			-- Create Profile object:
			local global_updates_object = {
				_updates_latest = loaded_data.GlobalUpdates, -- {0, {}}
				_profile = nil,
			}
			setmetatable(global_updates_object, GlobalUpdates)
			local profile = {
				Data = loaded_data.Data,
				MetaData = loaded_data.MetaData,
				MetaTagsUpdated = Madwork.NewScriptSignal(),

				RobloxMetaData = loaded_data.RobloxMetaData or {},
				UserIds = loaded_data.UserIds or {},
				KeyInfo = key_info,
				KeyInfoUpdated = Madwork.NewScriptSignal(),

				GlobalUpdates = global_updates_object,

				_profile_store = self,
				_profile_key = profile_key,

				_view_mode = true,

				_load_timestamp = os.clock(),
			}
			setmetatable(profile, Profile)
			global_updates_object._profile = profile
			-- Returning Profile object:
			return profile
		else
			task.wait() -- Overload prevention
		end
	end
	return nil -- If loop breaks return nothing
end

function ProfileStore:ProfileVersionQuery(profile_key, sort_direction, min_date, max_date, _use_mock) --> [ProfileVersionQuery]
	if type(profile_key) ~= "string" or string.len(profile_key) == 0 then
		error("[ProfileService]: Invalid profile_key")
	end

	if ProfileService.ServiceLocked == true then
		return setmetatable({}, ProfileVersionQuery) -- Silently fail :Next() requests
	end

	WaitForPendingProfileStore(self)

	if _use_mock == UseMockTag or UseMockDataStore == true then
		error("[ProfileService]: :ProfileVersionQuery() is not supported in mock mode")
	end

	-- Type check:
	if sort_direction ~= nil and (typeof(sort_direction) ~= "EnumItem"
		or sort_direction.EnumType ~= Enum.SortDirection) then
		error("[ProfileService]: Invalid sort_direction (" .. tostring(sort_direction) .. ")")
	end

	if min_date ~= nil and typeof(min_date) ~= "DateTime" and typeof(min_date) ~= "number" then
		error("[ProfileService]: Invalid min_date (" .. tostring(min_date) .. ")")
	end

	if max_date ~= nil and typeof(max_date) ~= "DateTime" and typeof(max_date) ~= "number" then
		error("[ProfileService]: Invalid max_date (" .. tostring(max_date) .. ")")
	end

	min_date = typeof(min_date) == "DateTime" and min_date.UnixTimestampMillis or min_date
	max_date = typeof(max_date) == "DateTime" and max_date.UnixTimestampMillis or max_date

	local profile_version_query = {
		_profile_store = self,
		_profile_key = profile_key,
		_sort_direction = sort_direction,
		_min_date = min_date,
		_max_date = max_date,

		_query_pages = nil,
		_query_index = 0,
		_query_failure = false,

		_is_query_yielded = false,
		_query_queue = {},
	}
	setmetatable(profile_version_query, ProfileVersionQuery)

	return profile_version_query

end

function ProfileStore:WipeProfileAsync(profile_key, _use_mock) --> is_wipe_successful [bool]
	if type(profile_key) ~= "string" or string.len(profile_key) == 0 then
		error("[ProfileService]: Invalid profile_key")
	end

	if ProfileService.ServiceLocked == true then
		return false
	end

	WaitForPendingProfileStore(self)

	local wipe_status = false

	if _use_mock == UseMockTag then -- Used when the profile is accessed through ProfileStore.Mock
		local mock_data_store = UserMockDataStore[self._profile_store_lookup]
		if mock_data_store ~= nil then
			mock_data_store[profile_key] = nil
		end
		wipe_status = true
		task.wait() -- Simulate API call yield
	elseif UseMockDataStore == true then -- Used when API access is disabled
		local mock_data_store = MockDataStore[self._profile_store_lookup]
		if mock_data_store ~= nil then
			mock_data_store[profile_key] = nil
		end
		wipe_status = true
		task.wait() -- Simulate API call yield
	else
		wipe_status = pcall(function()
			self._global_data_store:RemoveAsync(profile_key)
		end)
	end

	CustomWriteQueueMarkForCleanup(self._profile_store_lookup, profile_key)

	return wipe_status
end

-- New ProfileStore:

function ProfileService.GetProfileStore(profile_store_index, profile_template) --> [ProfileStore]

	local profile_store_name
	local profile_store_scope = nil

	-- Parsing profile_store_index:
	if type(profile_store_index) == "string" then
		-- profile_store_index as string:
		profile_store_name = profile_store_index
	elseif type(profile_store_index) == "table" then
		-- profile_store_index as table:
		profile_store_name = profile_store_index.Name
		profile_store_scope = profile_store_index.Scope
	else
		error("[ProfileService]: Invalid or missing profile_store_index")
	end

	-- Type checking:
	if profile_store_name == nil or type(profile_store_name) ~= "string" then
		error("[ProfileService]: Missing or invalid \"Name\" parameter")
	elseif string.len(profile_store_name) == 0 then
		error("[ProfileService]: ProfileStore name cannot be an empty string")
	end

	if profile_store_scope ~= nil and (type(profile_store_scope) ~= "string" or string.len(profile_store_scope) == 0) then
		error("[ProfileService]: Invalid \"Scope\" parameter")
	end

	if type(profile_template) ~= "table" then
		error("[ProfileService]: Invalid profile_template")
	end

	local profile_store
	profile_store = {
		Mock = {
			LoadProfileAsync = function(_, profile_key, not_released_handler)
				return profile_store:LoadProfileAsync(profile_key, not_released_handler, UseMockTag)
			end,
			GlobalUpdateProfileAsync = function(_, profile_key, update_handler)
				return profile_store:GlobalUpdateProfileAsync(profile_key, update_handler, UseMockTag)
			end,
			ViewProfileAsync = function(_, profile_key, version)
				return profile_store:ViewProfileAsync(profile_key, version, UseMockTag)
			end,
			FindProfileVersionAsync = function(_, profile_key, sort_direction, min_date, max_date)
				return profile_store:FindProfileVersionAsync(profile_key, sort_direction, min_date, max_date, UseMockTag)
			end,
			WipeProfileAsync = function(_, profile_key)
				return profile_store:WipeProfileAsync(profile_key, UseMockTag)
			end
		},

		_profile_store_name = profile_store_name,
		_profile_store_scope = profile_store_scope,
		_profile_store_lookup = profile_store_name .. "\0" .. (profile_store_scope or ""),

		_profile_template = profile_template,
		_global_data_store = nil,
		_loaded_profiles = {},
		_profile_load_jobs = {},
		_mock_loaded_profiles = {},
		_mock_profile_load_jobs = {},
		_is_pending = false,
	}
	setmetatable(profile_store, ProfileStore)

	if IsLiveCheckActive == true then
		profile_store._is_pending = true
		task.spawn(function()
			WaitForLiveAccessCheck()
			if UseMockDataStore == false then
				profile_store._global_data_store = DataStoreService:GetDataStore(profile_store_name, profile_store_scope)
			end
			profile_store._is_pending = false
		end)
	else
		if UseMockDataStore == false then
			profile_store._global_data_store = DataStoreService:GetDataStore(profile_store_name, profile_store_scope)
		end
	end

	return profile_store
end

function ProfileService.IsLive() --> [bool] -- (CAN YIELD!!!)

	WaitForLiveAccessCheck()

	return UseMockDataStore == false

end

----- Initialize -----

if IsStudio == true then
	IsLiveCheckActive = true
	task.spawn(function()
		local status, message = pcall(function()
			-- This will error if current instance has no Studio API access:
			DataStoreService:GetDataStore("____PS"):SetAsync("____PS", os.time())
		end)
		local no_internet_access = status == false and string.find(message, "ConnectFail", 1, true) ~= nil
		if no_internet_access == true then
			warn("[ProfileService]: No internet access - check your network connection")
		end
		if status == false and
			(string.find(message, "403", 1, true) ~= nil or -- Cannot write to DataStore from studio if API access is not enabled
				string.find(message, "must publish", 1, true) ~= nil or -- Game must be published to access live keys
				no_internet_access == true) then -- No internet access

			UseMockDataStore = true
			ProfileService._use_mock_data_store = true
			print("[ProfileService]: Roblox API services unavailable - data will not be saved")
		else
			print("[ProfileService]: Roblox API services available - data will be saved")
		end
		IsLiveCheckActive = false
	end)
end

----- Connections -----

-- Auto saving and issue queue managing:
RunService.Heartbeat:Connect(function()
	-- 1) Auto saving: --
	local auto_save_list_length = #AutoSaveList
	if auto_save_list_length > 0 then
		local auto_save_index_speed = SETTINGS.AutoSaveProfiles / auto_save_list_length
		local os_clock = os.clock()
		while os_clock - LastAutoSave > auto_save_index_speed do
			LastAutoSave = LastAutoSave + auto_save_index_speed
			local profile = AutoSaveList[AutoSaveIndex]
			if os_clock - profile._load_timestamp < SETTINGS.AutoSaveProfiles then
				-- This profile is freshly loaded - auto-saving immediately after loading will cause a warning in the log:
				profile = nil
				for _ = 1, auto_save_list_length - 1 do
					-- Move auto save index to the right:
					AutoSaveIndex = AutoSaveIndex + 1
					if AutoSaveIndex > auto_save_list_length then
						AutoSaveIndex = 1
					end
					profile = AutoSaveList[AutoSaveIndex]
					if os_clock - profile._load_timestamp >= SETTINGS.AutoSaveProfiles then
						break
					else
						profile = nil
					end
				end
			end
			-- Move auto save index to the right:
			AutoSaveIndex = AutoSaveIndex + 1
			if AutoSaveIndex > auto_save_list_length then
				AutoSaveIndex = 1
			end
			-- Perform save call:
			if profile ~= nil then
				task.spawn(SaveProfileAsync, profile) -- Auto save profile in new thread
			end
		end
	end
	-- 2) Issue queue: --
	-- Critical state handling:
	if ProfileService.CriticalState == false then
		if #IssueQueue >= SETTINGS.IssueCountForCriticalState then
			ProfileService.CriticalState = true
			ProfileService.CriticalStateSignal:Fire(true)
			CriticalStateStart = os.clock()
			warn("[ProfileService]: Entered critical state")
		end
	else
		if #IssueQueue >= SETTINGS.IssueCountForCriticalState then
			CriticalStateStart = os.clock()
		elseif os.clock() - CriticalStateStart > SETTINGS.CriticalStateLast then
			ProfileService.CriticalState = false
			ProfileService.CriticalStateSignal:Fire(false)
			warn("[ProfileService]: Critical state ended")
		end
	end
	-- Issue queue:
	while true do
		local issue_time = IssueQueue[1]
		if issue_time == nil then
			break
		elseif os.clock() - issue_time > SETTINGS.IssueLast then
			table.remove(IssueQueue, 1)
		else
			break
		end
	end
end)

-- Release all loaded profiles when the server is shutting down:
task.spawn(function()
	WaitForLiveAccessCheck()
	Madwork.ConnectToOnClose(
		function()
			ProfileService.ServiceLocked = true
			-- 1) Release all active profiles: --
			-- Clone AutoSaveList to a new table because AutoSaveList changes when profiles are released:
			local on_close_save_job_count = 0
			local active_profiles = {}
			for index, profile in ipairs(AutoSaveList) do
				active_profiles[index] = profile
			end
			-- Release the profiles; Releasing profiles can trigger listeners that release other profiles, so check active state:
			for _, profile in ipairs(active_profiles) do
				if profile:IsActive() == true then
					on_close_save_job_count = on_close_save_job_count + 1
					task.spawn(function() -- Save profile on new thread
						SaveProfileAsync(profile, true)
						on_close_save_job_count = on_close_save_job_count - 1
					end)
				end
			end
			-- 2) Yield until all active profile jobs are finished: --
			while on_close_save_job_count > 0 or ActiveProfileLoadJobs > 0 or ActiveProfileSaveJobs > 0 do
				task.wait()
			end
			return -- We're done!
		end,
		UseMockDataStore == false -- Always run this OnClose task if using Roblox API services
	)
end)

return ProfileService