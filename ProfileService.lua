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
		More information on https://madstudioroblox.github.io/ProfileService/troubleshooting/
		! Do not store NaN values
	 	! Do not create array tables with non-sequential indexes - attempting to replicate such tables will result in an error;
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
		
		ProfileService.IssueSignal           [ScriptSignal](error_message)
		ProfileService.CorruptionSignal      [ScriptSignal](profile_store_name, profile_key)
		ProfileService.CriticalStateSignal   [ScriptSignal](is_critical_state)
	
	Functions:
	
		ProfileService.GetProfileStore(profile_store_name, profile_template) --> [ProfileStore]
		
		* Parameter description for "ProfileService.GetProfileStore()":
		
			profile_store_name   [string] -- DataStore name
			profile_template     []:
				{}                        [table] -- Profiles will default to given table (hard-copy) when no data was saved previously
				nil                       [nil] -- ProfileStore:LoadProfileAsync() method will be locked
				
	Members [ProfileStore]:
	
		ProfileStore.Mock   [ProfileStore] -- Reflection of ProfileStore methods, but the methods will use a mock DataStore
		
	Methods [ProfileStore]:
	
		ProfileStore:LoadProfileAsync(profile_key, not_released_handler) --> [Profile / nil] not_released_handler(place_id, game_job_id)
		ProfileStore:GlobalUpdateProfileAsync(profile_key, update_handler) --> [GlobalUpdates / nil] (update_handler(GlobalUpdates))
			-- Returns GlobalUpdates object if update was successful, otherwise returns nil
		
		ProfileStore:ViewProfileAsync(profile_key) --> [Profile / nil] -- Notice #1: Profile object methods will not be available;
			Notice #2: Profile object members will be nil (Profile.Data = nil, Profile.MetaData = nil) if the profile hasn't
			been created, with the exception of Profile.GlobalUpdates which could be empty or populated by
			ProfileStore:GlobalUpdateProfileAsync()
			
		ProfileStore:WipeProfileAsync(profile_key) --> is_wipe_successful [bool] -- Completely wipes out profile data from the
			DataStore / mock DataStore with no way to recover it.
		
		* Parameter description for "ProfileStore:LoadProfileAsync()":
		
			profile_key            [string] -- DataStore key
			not_released_handler = "ForceLoad" -- Force loads profile on first call
			OR
			not_released_handler = "Steal" -- Steals the profile ignoring it's session lock
			OR
			not_released_handler   [function] (place_id, game_job_id) --> [string] ("Repeat" / "Cancel" / "ForceLoad")
				-- "not_released_handler" will be triggered in cases where the profile is not released by a session. This
				function may yield for as long as desirable and must return one of three string values:
					["Repeat"] - ProfileService will repeat the profile loading proccess and may trigger the release handler again
					["Cancel"] - ProfileStore:LoadProfileAsync() will immediately return nil
					["ForceLoad"] - ProfileService will repeat the profile loading call, but will return Profile object afterwards
						and release the profile for another session that has loaded the profile
					["Steal"] - The profile will usually be loaded immediately, ignoring an existing remote session lock and applying
						a session lock for this session.
						
		* Parameter description for "ProfileStore:GlobalUpdateProfileAsync()":
		
			profile_key      [string] -- DataStore key
			update_handler   [function] (GlobalUpdates) -- This function gains access to GlobalUpdates object methods
				(update_handler can't yield)
		
	Members [Profile]:
	
		Profile.Data            [table] -- Writable table that gets saved automatically and once the profile is released
		Profile.MetaData        [table] (Read-only) -- Information about this profile
		
			Profile.MetaData.ProfileCreateTime   [number] (Read-only) -- os.time() timestamp of profile creation
			Profile.MetaData.SessionLoadCount    [number] (Read-only) -- Amount of times the profile was loaded
			Profile.MetaData.ActiveSession       [table] (Read-only) {place_id, game_job_id} / nil -- Set to a session link if a
				game session is currently having this profile loaded; nil if released
			Profile.MetaData.MetaTags            [table] {["tag_name"] = tag_value, ...} -- Saved and auto-saved just like Profile.Data
			Profile.MetaData.MetaTagsLatest      [table] (Read-only) -- Latest version of MetaData.MetaTags that was definetly saved to DataStore
				(You can use Profile.MetaData.MetaTagsLatest for product purchase save confirmation, but create a system to clear old tags after
				they pile up)
		
		Profile.GlobalUpdates   [GlobalUpdates]
		
	Methods [Profile]:
	
		-- SAFE METHODS - Will not error after profile expires:
		Profile:IsActive() --> [bool] -- Returns true while the profile is active and can be written to
			
		Profile:GetMetaTag(tag_name) --> value
		
		Profile:ListenToRelease(listener) --> [ScriptConnection] (place_id / nil, game_job_id / nil) -- WARNING: Profiles can be released externally if another session
			force-loads this profile - use :ListenToRelease() to handle player leaving cleanup.
			
		Profile:Release() -- Call after the session has finished working with this profile
			e.g., after the player leaves (Profile object will become expired) (Does not yield)
		
		-- DANGEROUS METHODS - Will error if the profile is expired:
		-- MetaTags - Save and read values stored in Profile.MetaData for storing info about the
			profile itself like "Profile:SetMetaTag("FirstTimeLoad", true)"
		Profile:SetMetaTag(tag_name, value)
		
		Profile:Save() -- Call to quickly progress global update state or to speed up save validation processes (Does not yield)

		
	Methods [GlobalUpdates]:
	
	-- ALWAYS AVAILABLE:
		GlobalUpdates:GetActiveUpdates() --> [table] {{update_id, update_data}, ...}
		GlobalUpdates:GetLockedUpdates() --> [table] {{update_id, update_data}, ...}
		
	-- ONLY ACCESSIBLE THROUGH "Profile.GlobalUpdates":
		GlobalUpdates:ListenToNewActiveUpdate(listener) --> [ScriptConnection] listener(update_id, update_data)
		GlobalUpdates:ListenToNewLockedUpdate(listener) --> [ScriptConnection] listener(update_id, update_data)
		-- WARNING: GlobalUpdates:LockUpdate() and GlobalUpdates:ClearLockedUpdate() will error after profile expires
		GlobalUpdates:LockActiveUpdate(update_id)
		GlobalUpdates:ClearLockedUpdate(update_id)
		
	-- AVAILABLE INSIDE "update_handler" DURING A ProfileStore:GlobalUpdateProfileAsync() CALL
		GlobalUpdates:AddActiveUpdate(update_data)
		GlobalUpdates:ChangeActiveUpdate(update_id, update_data)
		GlobalUpdates:ClearActiveUpdate(update_id)
		
--]]

local SETTINGS = {

	AutoSaveProfiles = 30, -- Seconds (This value may vary - ProfileService will split the auto save load evenly in the given time)
	LoadProfileRepeatDelay = 15, -- Seconds between successive DataStore calls for the same key
	ForceLoadMaxSteps = 4, -- Steps taken before ForceLoad request steals the active session for a profile
	AssumeDeadSessionLock = 30 * 60, -- (seconds) If a profile hasn't been updated for 30 minutes, assume the session lock is dead
		-- As of writing, os.time() is not completely reliable, so we can only assume session locks are dead after a significant amount of time.
	
	IssueCountForCriticalState = 5, -- Issues to collect to announce critical state
	IssueLast = 120, -- Seconds
	CriticalStateLast = 120, -- Seconds
	
}

local Madwork -- Standalone Madwork reference for portable version of ProfileService
do
	-- ScriptConnection object:
	local ScriptConnection = {
		-- _listener = function -- [function]
		-- _listener_table = {} -- [table] -- Table from which the function entry will be removed
	}
	
	function ScriptConnection:Disconnect()
		local listener = self._listener
		if listener ~= nil then
			local listener_table = self._listener_table
			for i = 1, #listener_table do
				if listener == listener_table[i] then
					table.remove(listener_table, i)
					break
				end
			end
			self._listener = nil
		end
	end
	
	function ScriptConnection.NewScriptConnection(listener_table, listener) --> [ScriptConnection]
		return {
			_listener = listener,
			_listener_table = listener_table,
			Disconnect = ScriptConnection.Disconnect
		}
	end
	
	-- ScriptSignal object:
	local ScriptSignal = {
		-- _listeners = {}
	}
	
	function ScriptSignal:Connect(listener) --> [ScriptConnection]
		if type(listener) ~= "function" then
			error("[ScriptSignal]: Only functions can be passed to ScriptSignal:Connect()")
		end
		table.insert(self._listeners, listener)
		return {
			_listener = listener,
			_listener_table = self._listeners,
			Disconnect = ScriptConnection.Disconnect
		}
	end
	
	function ScriptSignal:Fire(...)
		for _, listener in ipairs(self._listeners) do
			listener(...)
		end
	end
	
	function ScriptSignal.NewScriptSignal() --> [ScriptSignal]
		return {
			_listeners = {},
			Connect = ScriptSignal.Connect,
			Fire = ScriptSignal.Fire
		}
	end
	
	local RunService = game:GetService("RunService")
	local Heartbeat = RunService.Heartbeat
	
	Madwork = {
		NewScriptSignal = ScriptSignal.NewScriptSignal,
		NewScriptConnection = ScriptConnection.NewScriptConnection,
		HeartbeatWait = function(wait_time) --> time_elapsed
			if wait_time == nil or wait_time == 0 then
				return Heartbeat:Wait()
			else
				local time_elapsed = 0
				while time_elapsed <= wait_time do
					local time_waited = Heartbeat:Wait()
					time_elapsed = time_elapsed + time_waited
				end
				return time_elapsed
			end
		end,
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
	
	IssueSignal = Madwork.NewScriptSignal(), -- (error_message) -- Fired when a DataStore API call throws an error
	CorruptionSignal = Madwork.NewScriptSignal(), -- (profile_store_name, profile_key) -- Fired when DataStore key returns a value that has
		-- all or some of it's profile components set to invalid data types. E.g., accidentally setting Profile.Data to a noon table value
	
	CriticalState = false, -- Set to true while DataStore service is throwing too many errors
	CriticalStateSignal = Madwork.NewScriptSignal(), -- (is_critical_state) -- Fired when CriticalState is set to true
		-- (You may alert players with this, or set up analytics)
	
	ServiceIssueCount = 0,

	_active_profile_stores = {
		--[[
			{
				_profile_store_name = "", -- [string] -- DataStore name
				_profile_template = {} / nil, -- [table / nil]
				_global_data_store = global_data_store, -- [GlobalDataStore] -- Object returned by DataStoreService:GetDataStore(_profile_store_name)
				
				_loaded_profiles = {
					[profile_key] = {
						Data = {}, -- [table] -- Loaded once after ProfileStore:LoadProfileAsync() finishes
						MetaData = {}, -- [table] -- Updated with every auto-save
						GlobalUpdates = {, -- [GlobalUpdates]
							_updates_latest = {}, -- [table] {update_index, {{update_id, version_id, update_locked, update_data}, ...}}
							_pending_update_lock = {update_id, ...} / nil, -- [table / nil]
							_pending_update_clear = {update_id, ...} / nil, -- [table / nil]
							
							_new_active_update_listeners = {listener, ...} / nil, -- [table / nil]
							_new_locked_update_listeners = {listener, ...} / nil, -- [table / nil]
							
							_profile = Profile / nil, -- [Profile / nil]
							
							_update_handler_mode = true / nil, -- [bool / nil]
						}
						
						_profile_store = ProfileStore, -- [ProfileStore]
						_profile_key = "", -- [string]
						
						_release_listeners = {listener, ...} / nil, -- [table / nil]
						
						_view_mode = true / nil, -- [bool / nil]
						
						_load_timestamp = tick(),
						
						_is_user_mock = false, -- ProfileStore.Mock
					},
					...
				},
				_profile_load_jobs = {[profile_key] = {load_id, loaded_data}, ...},
				
				_mock_loaded_profiles = {[profile_key] = Profile, ...},
				_mock_profile_load_jobs = {[profile_key] = {load_id, loaded_data}, ...},
			},
			...
		--]]
	},
	
	_auto_save_list = { -- loaded profile table which will be circularly auto-saved
		--[[
			Profile,
			...
		--]]
	},
	
	_issue_queue = {}, -- [table] {issue_tick, ...}
	_critical_state_start = 0, -- [number] 0 = no critical state / tick() = critical state start
	
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
local LastAutoSave = tick()

local LoadIndex = 0

local ActiveProfileLoadJobs = 0 -- Number of active threads that are loading in profiles
local ActiveProfileSaveJobs = 0 -- Number of active threads that are saving profiles

local CriticalStateStart = 0 -- tick()

local IsStudio = RunService:IsStudio()
local UseMockDataStore = false
local MockDataStore = ProfileService._mock_data_store -- Mock data store used when API access is disabled

local UserMockDataStore = ProfileService._user_mock_data_store -- Separate mock data store accessed via ProfileStore.Mock
local UseMockTag = {}

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

----- Private functions -----

local function RegisterIssue(error_message) -- Called when a DataStore API call errors
	warn("[ProfileService]: DataStore API error - \"" .. tostring(error_message) .. "\"")
	table.insert(IssueQueue, tick()) -- Adding issue time to queue
	ProfileService.IssueSignal:Fire(tostring(error_message))
end

local function RegisterCorruption(profile_store_name, profile_key) -- Called when a corrupted profile is loaded
	warn("[ProfileService]: Profile corruption - ProfileStore = \"" .. profile_store_name .. "\", Key = \"" .. profile_key .. "\"")
	ProfileService.CorruptionSignal:Fire(profile_store_name, profile_key)
end

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

local function IsThisSession(session_tag)
	return session_tag[1] == PlaceId and session_tag[2] == JobId
end

--[[
update_settings = {
	ExistingProfileHandle = function(latest_data),
	MissingProfileHandle = function(latest_data),
	EditProfile = function(lastest_data),
	
	WipeProfile = nil / true,
}
--]]
local function StandardProfileUpdateAsyncDataStore(profile_store, profile_key, update_settings, is_user_mock)
	local loaded_data
	local wipe_status = false
	local success, error_message = pcall(function()
		if update_settings.WipeProfile ~= true then
			local transform_function = function(latest_data)
				if latest_data == "PROFILE_WIPED" then
					latest_data = nil -- Profile was previously wiped - ProfileService will act like it was empty
				end
				
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
					if type(latest_data.Data) == "table" and
						type(latest_data.MetaData) == "table" and
						type(latest_data.GlobalUpdates) == "table" then
						
						latest_data.WasCorrupted = false -- Must be set to false if set previously
						global_updates_data = latest_data.GlobalUpdates
						if update_settings.ExistingProfileHandle ~= nil then
							update_settings.ExistingProfileHandle(latest_data)
						end
					-- Case #2: Profile was not loaded but GlobalUpdate data exists
					elseif latest_data.Data == nil and
						latest_data.MetaData == nil and
						type(latest_data.GlobalUpdates) == "table" then
						
						latest_data.WasCorrupted = false -- Must be set to false if set previously
						global_updates_data = latest_data.GlobalUpdates
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
				
				return latest_data
			end
			if is_user_mock == true then -- Used when the profile is accessed through ProfileStore.Mock
				loaded_data = MockUpdateAsync(UserMockDataStore, profile_store._profile_store_name, profile_key, transform_function)
				Madwork.HeartbeatWait() -- Simulate API call yield
			elseif UseMockDataStore == true then -- Used when API access is disabled
				loaded_data = MockUpdateAsync(MockDataStore, profile_store._profile_store_name, profile_key, transform_function)
				Madwork.HeartbeatWait() -- Simulate API call yield
			else
				loaded_data = profile_store._global_data_store:UpdateAsync(profile_key, transform_function)
			end
		else
			if is_user_mock == true then -- Used when the profile is accessed through ProfileStore.Mock
				local profile_store = UserMockDataStore[profile_store._profile_store_name]
				if profile_store ~= nil then
					profile_store[profile_key] = nil
				end
				wipe_status = true
				Madwork.HeartbeatWait() -- Simulate API call yield
			elseif UseMockDataStore == true then -- Used when API access is disabled
				local profile_store = MockDataStore[profile_store._profile_store_name]
				if profile_store ~= nil then
					profile_store[profile_key] = nil
				end
				wipe_status = true
				Madwork.HeartbeatWait() -- Simulate API call yield
			else
				loaded_data = profile_store._global_data_store:UpdateAsync(profile_key, function()
					return "PROFILE_WIPED" -- It's impossible to set DataStore keys to nil after they have been set
				end)
				if loaded_data == "PROFILE_WIPED" then
					wipe_status = true
				end
			end
		end
	end)
	if update_settings.WipeProfile == true then
		return wipe_status
	elseif success == true and type(loaded_data) == "table" then
		-- Corruption handling:
		if loaded_data.WasCorrupted == true then
			RegisterCorruption(profile_store._profile_store_name, profile_key)
		end
		-- Return loaded_data:
		return loaded_data
	else
		RegisterIssue((error_message ~= nil) and error_message or "Undefined error")
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
		LastAutoSave = tick()
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
	for _, listener in ipairs(profile._release_listeners) do
		listener(place_id, game_job_id)
	end
	profile._release_listeners = {}
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
		if old_global_update == nil then
			is_new = true
		elseif new_global_update[2] > old_global_update[2] or new_global_update[3] ~= old_global_update[3] then
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
					for _, listener in ipairs(global_updates_object._new_active_update_listeners) do
						listener(new_global_update[1], new_global_update[4])
					end
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
					for _, listener in ipairs(global_updates_object._new_locked_update_listeners) do
						listener(new_global_update[1], new_global_update[4])
						-- Check if listener marked the update to be cleared:
						-- Normally there should be only one listener per profile for new locked global updates, but
						-- in case several listeners are connected we will not trigger more listeners after one listener
						-- marks the locked global update to be cleared.
						for _, update_id in ipairs(pending_update_clear) do
							if new_global_update[1] == update_id then
								is_pending_clear = true
								break
							end
						end
						if is_pending_clear == true then
							break
						end
					end
				end
			end
		end
	end
end

local function SaveProfileAsync(profile, release_from_session)
	if type(profile.Data) ~= "table" then
		RegisterCorruption(profile._profile_store._profile_store_name, profile._profile_key)
		error("[ProfileService]: PROFILE DATA CORRUPTED DURING RUNTIME! ProfileStore = \"" .. profile._profile_store._profile_store_name .. "\", Key = \"" .. profile._profile_key .. "\"")
	end
	if release_from_session == true then
		ReleaseProfileInternally(profile)
	end
	ActiveProfileSaveJobs = ActiveProfileSaveJobs + 1
	local loaded_data = StandardProfileUpdateAsyncDataStore(
		profile._profile_store,
		profile._profile_key,
		{
			ExistingProfileHandle = nil,
			MissingProfileHandle = nil,
			EditProfile = function(latest_data)
				-- 1) Check if this session still owns the profile: --
				local active_session = latest_data.MetaData.ActiveSession
				local force_load_session = latest_data.MetaData.ForceLoadSession
				local session_owns_profile = false
				local force_load_pending = false
				if type(active_session) == "table" then
					session_owns_profile = IsThisSession(active_session)
				end
				if type(force_load_session) == "table" then
					force_load_pending = not IsThisSession(force_load_session)
				end
				
				if session_owns_profile == true then -- We may only edit the profile if this session has ownership of the profile
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
					-- 3) Save profile data: --
					latest_data.Data = profile.Data
					latest_data.MetaData.MetaTags = profile.MetaData.MetaTags -- MetaData.MetaTags is the only actively savable component of MetaData
					latest_data.MetaData.LastUpdate = os.time()
					if release_from_session == true or force_load_pending == true then
						latest_data.MetaData.ActiveSession = nil
					end
				end
			end,
		},
		profile._is_user_mock
	)
	if loaded_data ~= nil then
		-- 4) Set latest data in profile: --
		-- Setting global updates:
		local global_updates_object = profile.GlobalUpdates -- [GlobalUpdates]
		local old_global_updates_data = global_updates_object._updates_latest
		local new_global_updates_data = loaded_data.GlobalUpdates
		global_updates_object._updates_latest = new_global_updates_data
		-- Setting MetaData:
		local keep_session_meta_tag_reference = profile.MetaData.MetaTags
		profile.MetaData = loaded_data.MetaData
		profile.MetaData.MetaTagsLatest = profile.MetaData.MetaTags
		profile.MetaData.MetaTags = keep_session_meta_tag_reference
		-- 5) Check if session still owns the profile: --
		local active_session = loaded_data.MetaData.ActiveSession
		local force_load_session = loaded_data.MetaData.ForceLoadSession
		local session_owns_profile = false
		if type(active_session) == "table" then
			session_owns_profile = IsThisSession(active_session)
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
		
		_new_active_update_listeners = {listener, ...} / nil, -- [table / nil]
		_new_locked_update_listeners = {listener, ...} / nil, -- [table / nil]
		
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
	table.insert(self._new_active_update_listeners, listener)
	return Madwork.NewScriptConnection(self._new_active_update_listeners, listener)
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
	table.insert(self._new_locked_update_listeners, listener)
	return Madwork.NewScriptConnection(self._new_locked_update_listeners, listener)
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
		
		_release_listeners = {listener, ...} / nil, -- [table / nil]
		
		_view_mode = true / nil, -- [bool / nil]
		
		_load_timestamp = tick(),
		
		_is_user_mock = false, -- ProfileStore.Mock
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
	if self._view_mode == true then
		error("[ProfileService]: Can't set meta tag in view mode")
	end
	if self:IsActive() == false then
		error("[ProfileService]: PROFILE EXPIRED - Meta tags can't be set")
	end
	self.MetaData.MetaTags[tag_name] = value
end

function Profile:ListenToRelease(listener) --> [ScriptConnection] (place_id / nil, game_job_id / nil)
	if type(listener) ~= "function" then
		error("[ProfileService]: Only a function can be set as listener in Profile:ListenToRelease()")
	end
	if self._view_mode == true then
		error("[ProfileService]: Can't listen to Profile release in view mode")
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
		return {
			Disconnect = function() end,
		}
	else
		table.insert(self._release_listeners, listener)
		return Madwork.NewScriptConnection(self._release_listeners, listener)
	end
end

function Profile:Save()
	if self._view_mode == true then
		error("[ProfileService]: Can't save Profile in view mode")
	end
	if self:IsActive() == false then
		error("[ProfileService]: PROFILE EXPIRED - Can't save Profile")
	end
	-- We don't want auto save to trigger too soon after manual saving - this will reset the auto save timer:
	RemoveProfileFromAutoSave(self)
	AddProfileToAutoSave(self)
	-- Call save function in a new thread:
	coroutine.wrap(SaveProfileAsync)(self)
end

function Profile:Release()
	if self._view_mode == true then
		error("[ProfileService]: Can't release Profile in view mode")
	end
	if self:IsActive() == true then
		coroutine.wrap(SaveProfileAsync)(self, true) -- Call save function in a new thread with release_from_session = true
	end
end

-- ProfileStore object:

local ProfileStore = {
	--[[
		Mock = {},
	
		_profile_store_name = "", -- [string] -- DataStore name
		_profile_template = {} / nil, -- [table / nil]
		_global_data_store = global_data_store, -- [GlobalDataStore] -- Object returned by DataStoreService:GetDataStore(_profile_store_name)
		
		_loaded_profiles = {[profile_key] = Profile, ...},
		_profile_load_jobs = {[profile_key] = {load_id, loaded_data}, ...},
		
		_mock_loaded_profiles = {[profile_key] = Profile, ...},
		_mock_profile_load_jobs = {[profile_key] = {load_id, loaded_data}, ...},
	--]]
}
ProfileStore.__index = ProfileStore

function ProfileStore:LoadProfileAsync(profile_key, not_released_handler, _use_mock) --> [Profile / nil] not_released_handler(place_id, game_job_id)
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
	
	local is_user_mock = _use_mock == UseMockTag
	
	-- Check if profile with profile_key isn't already loaded in this session:
	for _, profile_store in ipairs(ActiveProfileStores) do
		if profile_store._profile_store_name == self._profile_store_name then
			local loaded_profiles = is_user_mock == true and profile_store._mock_loaded_profiles or profile_store._loaded_profiles
			if loaded_profiles[profile_key] ~= nil then
				error("[ProfileService]: Profile of ProfileStore \"" .. self._profile_store_name .. "\" with key \"" .. profile_key .. "\" is already loaded in this session")
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
		local loaded_data
		local load_id = LoadIndex + 1
		LoadIndex = load_id
		local profile_load_job = profile_load_jobs[profile_key] -- {load_id, loaded_data}
		if profile_load_job ~= nil then
			profile_load_job[1] = load_id -- Yoink load job
			while profile_load_job[2] == nil do -- Wait for job to finish
				Madwork.HeartbeatWait()
			end
			if profile_load_job[1] == load_id then -- Load job hasn't been double-yoinked
				loaded_data = profile_load_job[2]
				profile_load_jobs[profile_key] = nil
			else
				return nil
			end
		else
			profile_load_job = {load_id, nil}
			profile_load_jobs[profile_key] = profile_load_job
			profile_load_job[2] = StandardProfileUpdateAsyncDataStore(
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
			)
			if profile_load_job[1] == load_id then -- Load job hasn't been yoinked
				loaded_data = profile_load_job[2]
				profile_load_jobs[profile_key] = nil
			else
				return nil -- Load job yoinked
			end
		end
		-- Handle load_data:
		if loaded_data ~= nil then
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
						
						_new_active_update_listeners = {},
						_new_locked_update_listeners = {},
						
						_profile = nil,
					}
					setmetatable(global_updates_object, GlobalUpdates)
					local profile = {
						Data = loaded_data.Data,
						MetaData = loaded_data.MetaData,
						GlobalUpdates = global_updates_object,
						
						_profile_store = self,
						_profile_key = profile_key,
						
						_release_listeners = {},
						
						_load_timestamp = tick(),
						
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
							Madwork.HeartbeatWait(SETTINGS.LoadProfileRepeatDelay) -- Let the cycle repeat again after a delay
						else
							-- Another session tried to force load this profile:
							ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
							return nil
						end
						request_force_load = false -- Only request a force load once
					elseif aggressive_steal == true then
						Madwork.HeartbeatWait(SETTINGS.LoadProfileRepeatDelay) -- Let the cycle repeat again after a delay
					else
						local handler_result = not_released_handler(active_session[1], active_session[2])
						if handler_result == "Repeat" then
							Madwork.HeartbeatWait(SETTINGS.LoadProfileRepeatDelay) -- Let the cycle repeat again after a delay
						elseif handler_result == "Cancel" then
							ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
							return nil
						elseif handler_result == "ForceLoad" then
							force_load = true
							request_force_load = true
							Madwork.HeartbeatWait(SETTINGS.LoadProfileRepeatDelay) -- Let the cycle repeat again after a delay
						elseif handler_result == "Steal" then
							aggressive_steal = true
							Madwork.HeartbeatWait(SETTINGS.LoadProfileRepeatDelay) -- Let the cycle repeat again after a delay
						else
							error("[ProfileService]: Invalid return from not_released_handler")
						end
					end
				end
			else
				ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
				error("[ProfileService]: Invalid ActiveSession value in Profile.MetaData - Fatal corruption") -- It's unlikely this will ever fire
			end
		else
			Madwork.HeartbeatWait(SETTINGS.LoadProfileRepeatDelay) -- Let the cycle repeat again after a delay
		end
	end
	ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
	return nil -- If loop breaks return nothing
end

function ProfileStore:GlobalUpdateProfileAsync(profile_key, update_handler, _use_mock) --> [GlobalUpdates / nil] (update_handler(GlobalUpdates))
	if type(profile_key) ~= "string" then
		error("[ProfileService]: Invalid profile_key")
	elseif string.len(profile_key) == 0 then
		error("[ProfileService]: Invalid profile_key")
	end
	if type(update_handler) ~= "function" then
		error("[ProfileService]: Invalid update_handler")
	end
	
	if ProfileService.ServiceLocked == true then
		return nil
	end
	
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
		-- Handling loaded_data:
		if loaded_data ~= nil then
			-- Return GlobalUpdates object (Update successful):
			local global_updates_object = {
				_updates_latest = loaded_data.GlobalUpdates,
			}
			setmetatable(global_updates_object, GlobalUpdates)
			return global_updates_object
		else
			Madwork.HeartbeatWait(SETTINGS.LoadProfileRepeatDelay) -- Let the cycle repeat again
		end
	end
	return nil -- Return nothing (Update unsuccessful)
end
		
function ProfileStore:ViewProfileAsync(profile_key, _use_mock) --> [Profile / nil]
	if type(profile_key) ~= "string" then
		error("[ProfileService]: Invalid profile_key")
	elseif string.len(profile_key) == 0 then
		error("[ProfileService]: Invalid profile_key")
	end
	
	if ProfileService.ServiceLocked == true then
		return nil
	end
	
	while ProfileService.ServiceLocked == false do
		-- Load profile:
		local loaded_data = StandardProfileUpdateAsyncDataStore(
			self,
			profile_key,
			{
				ExistingProfileHandle = nil,
				MissingProfileHandle = nil,
				EditProfile = nil,
			},
			_use_mock == UseMockTag
		)
		-- Handle load_data:
		if loaded_data ~= nil then
			-- Create Profile object:
			local global_updates_object = {
				_updates_latest = loaded_data.GlobalUpdates,
				_profile = nil,
			}
			setmetatable(global_updates_object, GlobalUpdates)
			local profile = {
				Data = loaded_data.Data,
				MetaData = loaded_data.MetaData,
				GlobalUpdates = global_updates_object,
				
				_profile_store = self,
				_profile_key = profile_key,
				
				_view_mode = true,
				
				_load_timestamp = tick(),
			}
			setmetatable(profile, Profile)
			global_updates_object._profile = profile
			-- Returning Profile object:
			return profile
		else
			Madwork.HeartbeatWait(SETTINGS.LoadProfileRepeatDelay) -- Let the cycle repeat again after a delay
		end
	end
	return nil -- If loop breaks return nothing
end

function ProfileStore:WipeProfileAsync(profile_key, _use_mock) --> is_wipe_successful [bool]
	if type(profile_key) ~= "string" then
		error("[ProfileService]: Invalid profile_key")
	elseif string.len(profile_key) == 0 then
		error("[ProfileService]: Invalid profile_key")
	end
	
	if ProfileService.ServiceLocked == true then
		return false
	end
	
	return StandardProfileUpdateAsyncDataStore(
		self,
		profile_key,
		{
			WipeProfile = true
		},
		_use_mock == UseMockTag
	)
end

-- New ProfileStore:

function ProfileService.GetProfileStore(profile_store_name, profile_template) --> [ProfileStore]
	if type(profile_store_name) ~= "string" then
		error("[ProfileService]: profile_store_name must be a string")
	elseif string.len(profile_store_name) == 0 then
		error("[ProfileService]: Invalid profile_store_name")
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
			ViewProfileAsync = function(_, profile_key)
				return profile_store:ViewProfileAsync(profile_key, UseMockTag)
			end,
			WipeProfileAsync = function(_, profile_key)
				return profile_store:WipeProfileAsync(profile_key, UseMockTag)
			end
		},
		
		_profile_store_name = profile_store_name,
		_profile_template = profile_template,
		_global_data_store = nil,
		_loaded_profiles = {},
		_profile_load_jobs = {},
		_mock_loaded_profiles = {},
		_mock_profile_load_jobs = {},
	}
	if UseMockDataStore == false then
		profile_store._global_data_store = DataStoreService:GetDataStore(profile_store_name)
	end
	setmetatable(profile_store, ProfileStore)
	return profile_store
end

----- Initialize -----

if IsStudio == true then
	local status, message = pcall(function()
		-- This will error if current instance has no Studio API access:
		DataStoreService:GetDataStore("____PS"):SetAsync("____PS", os.time())
	end)
	if status == false and (string.find(message, "403", 1, true) ~= nil or string.find(message, "must publish", 1, true) ~= nil) then
		UseMockDataStore = true
		ProfileService._use_mock_data_store = true
		print("[ProfileService]: Roblox API services unavailable - data will not be saved")
	else
		print("[ProfileService]: Roblox API services available - data will be saved")
	end
end

----- Connections -----

-- Auto saving and issue queue managing:
RunService.Heartbeat:Connect(function()
	-- 1) Auto saving: --
	local auto_save_list_length = #AutoSaveList
	if auto_save_list_length > 0 then
		local auto_save_index_speed = SETTINGS.AutoSaveProfiles / auto_save_list_length
		local current_tick = tick()
		while current_tick - LastAutoSave > auto_save_index_speed do
			LastAutoSave = LastAutoSave + auto_save_index_speed
			local profile = AutoSaveList[AutoSaveIndex]
			if current_tick - profile._load_timestamp < SETTINGS.AutoSaveProfiles then
				-- This profile is freshly loaded - auto-saving immediately after loading will cause a warning in the log:
				profile = nil
				for i = 1, auto_save_list_length - 1 do
					-- Move auto save index to the right:
					AutoSaveIndex = AutoSaveIndex + 1
					if AutoSaveIndex > auto_save_list_length then
						AutoSaveIndex = 1
					end
					profile = AutoSaveList[AutoSaveIndex]
					if current_tick - profile._load_timestamp >= SETTINGS.AutoSaveProfiles then
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
			-- print("[ProfileService]: Auto updating profile - profile_store_name = \"" .. profile._profile_store._profile_store_name .. "\"; profile_key = \"" .. profile._profile_key .. "\"")
			if profile ~= nil then
				coroutine.wrap(SaveProfileAsync)(profile) -- Auto save profile in new thread
			end
		end
	end
	-- 2) Issue queue: --
	-- Critical state handling:
	if ProfileService.CriticalState == false then
		if #IssueQueue >= SETTINGS.IssueCountForCriticalState then
			ProfileService.CriticalState = true
			ProfileService.CriticalStateSignal:Fire(true)
			CriticalStateStart = tick()
			warn("[ProfileService]: Entered critical state")
		end
	else
		if #IssueQueue >= SETTINGS.IssueCountForCriticalState then
			CriticalStateStart = tick()
		elseif tick() - CriticalStateStart > SETTINGS.CriticalStateLast then
			ProfileService.CriticalState = false
			ProfileService.CriticalStateSignal:Fire(false)
			warn("[ProfileService]: Critical state ended")
		end
	end
	-- Issue queue:
	while true do
		local issue_tick = IssueQueue[1]
		if issue_tick == nil then
			break
		elseif tick() - issue_tick > SETTINGS.IssueLast then
			table.remove(IssueQueue, 1)
		else
			break
		end
	end
end)

-- Release all loaded profiles when the server is shutting down:
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
				coroutine.wrap(function() -- Save profile on new thread
					SaveProfileAsync(profile, true)
					on_close_save_job_count = on_close_save_job_count - 1
				end)()
			end
		end
		-- 2) Yield until all active profile jobs are finished: --
		while on_close_save_job_count > 0 or ActiveProfileLoadJobs > 0 or ActiveProfileSaveJobs > 0 do
			Madwork.HeartbeatWait()
		end
		return -- We're done!
	end,
	UseMockDataStore == false -- Always run this OnClose task if using Roblox API services
)

return ProfileService