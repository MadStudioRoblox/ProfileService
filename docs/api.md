!!! warning
    Never yield (use `wait()` or asynchronous Roblox API calls) inside listener functions

!!! notice
    Methods with `Async` in their name are methods that will yield - just like `wait()`

## ProfileService
### ProfileService.ServiceLocked
``` lua
ProfileService.ServiceLocked   [bool]
```
Set to false when the Roblox server is shutting down.
`ProfileStore` methods should not be called after this value is set to `false`
### ProfileService.IssueSignal
``` lua
ProfileService.IssueSignal   [ScriptSignal](error_message [string], profile_store_name [string], profile_key [string])
```
Analytics endpoint for DataStore error logging. Example usage:
``` lua
ProfileService.IssueSignal:Connect(function(error_message, profile_store_name, profile_key)
  pcall(function()
    AnalyticsService:FireEvent(
      "ProfileServiceIssue",
      error_message,
      profile_store_name,
      profile_key
    )
  end)
end)
```
### ProfileService.CorruptionSignal
``` lua
ProfileService.CorruptionSignal   [ScriptSignal](profile_store_name [string], profile_key [string])
```
Analytics endpoint for cases when a DataStore key returns a value that has all or some
of it's profile components set to invalid data types. E.g., accidentally setting
Profile.Data to a non table value
### ProfileService.CriticalStateSignal
``` lua
ProfileService.CriticalStateSignal   [ScriptSignal] (is_critical_state [bool])
```
Analytics endpoint for cases when DataStore is throwing too many errors and it's most
likely affecting your game really really bad - this could be due to developer errors
or due to Roblox server problems. Could be used to alert players about data store outages.

### ProfileService.GetProfileStore()
``` lua
ProfileService.GetProfileStore(
    profile_store_index,
    profile_template
) --> [ProfileStore]
-- profile_store_index   [string] -- DataStore name
-- OR
-- profile_store_index   [table]: -- Allows the developer to define more GlobalDataStore variables
--  {
--    Name = "StoreName", -- [string] -- DataStore name
--    -- Optional arguments:
--    Scope = "StoreScope", -- [string] -- DataStore scope
--  }
-- profile_template     [table] -- Profile.Data will default to
--   given table (deep-copy) when no data was saved previously
```
`ProfileStore` objects expose methods for loading / viewing profiles and sending global updates. Equivalent of [:GetDataStore()](https://developer.roblox.com/en-us/api-reference/function/DataStoreService/GetDataStore) in Roblox [DataStoreService](https://developer.roblox.com/en-us/api-reference/class/DataStoreService) API.

!!! notice
    By default, `profile_template` is only copied for `Profile.Data` for new profiles. Changes made to `profile_template` can be applied to `Profile.Data` of previously saved profiles by calling [Profile:Reconcile()](#profilereconcile). You can also create your own function to fill in the missing components in `Profile.Data` as soon as it is loaded or have `nil` exceptions in your personal `:Get()` and `:Set()` method libraries.

## ProfileStore
### ProfileStore:LoadProfileAsync()

``` lua
ProfileStore:LoadProfileAsync(
  profile_key,
  not_released_handler
) --> [Profile] or nil
-- profile_key            [string] -- DataStore key
-- not_released_handler   nil or []: -- Defaults to "ForceLoad"
--   	[string] "ForceLoad" -- Force loads profile on first call
-- 		OR
-- 		[string] "Steal" -- Steals the profile ignoring it's session lock
-- 		OR
-- 		[function] (place_id, game_job_id) --> [string] "Repeat", "Cancel", "ForceLoad" or "Steal"
-- 		  	place_id      [number] or nil
-- 		  	game_job_id   [string] or nil
```
For basic usage, pass `nil` for the `not_released_handler` argument.

`not_released_handler` as a `function` argument is called when the profile is
session-locked by a remote Roblox server:
``` lua
local profile = ProfileStore:LoadProfileAsync(
  "Player_2312310",
  function(place_id, game_job_id)
    -- place_id and game_job_id identify the Roblox server that has
    --   this profile currently locked. In rare cases, if the server
    --   crashes, the profile will stay locked until ForceLoaded by
    --   a new session.
    return "Repeat" or "Cancel" or "ForceLoad" or "Steal"
  end
)
```
`not_released_handler` must return one of the following values:

- `return "Repeat"` - ProfileService will repeat the profile loading proccess and
may call the release handler again
- `return "Cancel"` - `:LoadProfileAsync()` will immediately return nil
- `return "ForceLoad"` - ProfileService will indefinitely attempt to load the profile.
If the profile is session-locked by a remote Roblox server, it will either be released
for that remote server or "stolen" (Stealing is necessary for remote servers that are not
responding in time and for handling crashed server session-locks).
- `return "Steal"` - The profile will usually be loaded immediately, ignoring an existing remote session lock and applying a session lock for this session. `"Steal"` can be used to clear dead session locks faster than `"ForceLoad"` assuming your code knows that the session lock is dead.

!!! notice
    ProfileService saves profiles to live DataStore keys in Roblox Studio when [Roblox API services are enabled](https://developer.roblox.com/en-us/articles/Data-store#using-data-stores-in-studio). See [ProfileStore.Mock](#profilestoremock) if saving to live keys during testing is not desired.

!!! warning
    `:LoadProfileAsync()` can return `nil` when another remote Roblox server attempts to load the profile at the same time.
    This case should be extremely rare and it would be recommended to [:Kick()](https://developer.roblox.com/en-us/api-reference/function/Player/Kick) the player if `:LoadProfileAsync()` does
    not return a `Profile` object.

!!! failure "Do not load a profile of the same key again before it is released"
    Trying to load a profile that has already been session-locked on the same server will result in an error. You may, however, instantly load the profile again after releasing it with `Profile:Release()`.

### ProfileStore:GlobalUpdateProfileAsync()
``` lua
ProfileStore:GlobalUpdateProfileAsync(
  profile_key,
  update_handler
) --> [GlobalUpdates] or nil
-- profile_key      [string] -- DataStore key
-- update_handler   [function](global_updates) -- This function is
--   called with a GlobalUpdates object
```

Used to create and manage `Active` global updates for a specified `Profile`. Can be called on any Roblox server of your game.
Updates should reach the recipient in less than 30 seconds, regardless of whether it was called on the same server the `Profile` is session-locked to. See [Global Updates](#global-updates) for more information.

Example usage of `:GlobalUpdateProfileAsync()`:
``` lua
ProfileStore:GlobalUpdateProfileAsync(
  "Player_2312310",
  function(global_updates)
    global_updates:AddActiveUpdate({
      Type = "AdminGift",
      Item = "Coins",
      Amount = 1000,
    })
  end
)
```

!!! notice
    `:GlobalUpdateProfileAsync()` will work for profiles that haven't been created (profiles are created when they're
    loaded using `:LoadProfileAsync()` for the first time)

!!! failure "Yielding inside the `update_handler` function will throw an error"

!!! failure "Avoid rapid use of ProfileStore:GlobalUpdateProfileAsync()"
    Excessive use of [ProfileStore:GlobalUpdateProfileAsync()](#profilestoreglobalupdateprofileasync) can lead to dead session locks and event lost
    `Profile.Data` (latter is mostly possible only if the `Profile` is loaded in the same session as `:GlobalUpdateProfileAsync()` is called). This is due to a queue
    system that executes every write request for the `Profile` every 7 seconds - if this queue grows larger than the [BindToClose timeout](https://developer.roblox.com/en-us/api-reference/function/DataModel/BindToClose) (approx. 30 seconds), some requests in the queue can be lost after the game shuts down.

### ProfileStore:ViewProfileAsync()
``` lua
ProfileStore:ViewProfileAsync(profile_key, version) --> [Profile] or nil
-- profile_key   [string] -- DataStore key
-- version       nil or [string] -- DataStore key version
```
!!! notice "Passing `version` argument in mock mode (Or offline mode) will throw an error - Mock versioning is not supported"
Attempts to load the latest profile version (or a specified version via the `version` argument) from the DataStore without claiming a session lock.
Returns `nil` if such version does not exist. Returned `Profile` will not auto-save and releasing won't do anything.
Data in the returned `Profile` can be changed to create a payload which can be saved via [Profile:OverwriteAsync()](#profileoverwriteasync).

`:ViewProfileAsync()` is the the prefered way of viewing player data without editing it.

### ProfileStore:ProfileVersionQuery()
```lua
ProfileStore:ProfileVersionQuery(profile_key, sort_direction, min_date, max_date) --> [ProfileVersionQuery]
-- profile_key      [string]
-- sort_direction   nil or [Enum.SortDirection] -- Defaults to "Ascending"
-- min_date         nil or [DateTime] or [number] (epoch time millis)
-- max_date         nil or [DateTime] or [number] (epoch time millis)
```
Creates a profile version query using [DataStore:ListVersionsAsync() (Official documentation)](https://developer.roblox.com/en-us/api-reference/function/DataStore/ListVersionsAsync). Results are retrieved through `ProfileVersionQuery:Next()`. For additional help, check the [versioning example in official Roblox documentation](https://developer.roblox.com/en-us/articles/Data-store#versioning-1). Date definitions are easier with the [DateTime (Official documentation)](https://developer.roblox.com/en-us/api-reference/datatype/DateTime) library. User defined day and time will have to be converted to [Unix time (Wikipedia)](https://en.wikipedia.org/wiki/Unix_time) while taking their timezone into account to expect the most precise results, though you can be rough and just set the date and time in the UTC timezone and expect a maximum margin of error of 24 hours for your query results.

**Examples of query arguments:**

   - Pass `nil` for `sort_direction`, `min_date` and `max_date` to find the oldest available version
   - Pass `Enum.SortDirection.Descending` for `sort_direction`, `nil` for `min_date` and `max_date` to find the most recent version.
   - Pass `Enum.SortDirection.Descending` for `sort_direction`, `nil` for `min_date` and `DateTime` **defining a time before an event**
    (e.g. two days earlier before your game unrightfully stole 1,000,000 rubies from a player) for `max_date` to find the most recent
    version of a `Profile` that existed before said event.

**Case example: "I lost all of my rubies on August 14th!"**

```lua
-- Get a ProfileStore object with the same arguments you passed to the
--  ProfileStore that loads player Profiles. It can also just be
--  the very same ProfileStore object:

local ProfileStore = ProfileService.GetProfileStore(store_name, template)

-- If you can't figure out the exact time and timezone the player lost rubies
--  in on the day of August 14th, then your best bet is to try querying
--  UTC August 13th. If the first entry still doesn't have the rubies - 
--  try a new query of UTC August 12th and etc.

local max_date = DateTime.fromUniversalTime(2021, 08, 13) -- UTC August 13th, 2021

local query = ProfileStore:ProfileVersionQuery(
  "Player_2312310", -- The same profile key that gets passed to :LoadProfileAsync()
  Enum.SortDirection.Descending,
  nil,
  max_date
)

-- Get the first result in the query:
local profile = query:NextAsync()

if profile ~= nil then

  profile:ClearGlobalUpdates()

  profile:OverwriteAsync() -- This method does the actual rolling back;
    -- Don't call this method until you're sure about setting the latest
    -- version to a copy of the previous one

  print("Rollback success!")

  print(profile.Data) -- You'll be able to surf table contents if
    -- you're runing this code in studio with access to API services
    -- enabled and have expressive output enabled; If the printed
    -- data doesn't have the rubies, you'll want to change your
    -- query parameters.

else
  print("No version to rollback to")
end
```

**Case example: Studying data mutation over time**

```lua
-- You have ProfileService working in your game. You join
--  the game with your own account and go to https://www.unixtimestamp.com
--  and save the current UNIX timestamp resembling present time.
--  You can then make the game alter your data by giving you
--  currency, items, experience, etc.

local ProfileStore = ProfileService.GetProfileStore(store_name, template)

-- UNIX timestamp you saved:
local min_date = DateTime.fromUnixTimestamp(1628952101)
local print_minutes = 5 -- Print the next 5 minutes of history

local query = ProfileStore:ProfileVersionQuery(
  "Player_2312310",
  Enum.SortDirection.Ascending,
  min_date
)

-- You can now attempt to print out every snapshot of your data saved
--  at an average periodic interval of 30 seconds (ProfileService auto-save)
--  starting from the time you took the UNIX timestamp!

local finish_update_time = min_date.UnixTimestampMillis + (print_minutes * 60000)

print("Fetching ", print_minutes, "minutes of saves:")

local entry_count = 0

while true do

  entry_count +=1
  local profile = query:NextAsync()

  if profile ~= nil then

    if profile.KeyInfo.UpdatedTime > finish_update_time then
      if entry_count == 1 then
        print("No entries found in set time period. (Start timestamp too early)")
      else
        print("Time period finished.")
      end
      break
    end

    print(
      "Entry", entry_count, "-",
      DateTime.fromUnixTimestampMillis(profile.KeyInfo.UpdatedTime):ToIsoDate()
    )

    print(profile.Data) -- Printing table for studio expressive output

  else
    if entry_count == 1 then
      print("No entries found in set time period. (Start timestamp too late)")
    else
      print("No more entries in query.")
    end
    break
  end

end

```

### ProfileStore:WipeProfileAsync()
``` lua
ProfileStore:WipeProfileAsync(profile_key) --> is_wipe_successful [bool]
-- profile_key   [string] -- DataStore key
```
Use `:WipeProfileAsync()` to erase user data when complying with right of erasure requests. In live Roblox servers `:WipeProfileAsync()` must be used on profiles created through `ProfileStore.Mock` after `Profile:Release()` and it's known that the `Profile` will no longer be loaded again.

### ProfileStore.Mock
``` lua
local ProfileTemplate = {}
local GameProfileStore = ProfileService.GetProfileStore(
  "PlayerData",
  ProfileTemplate
)

local LiveProfile = GameProfileStore:LoadProfileAsync(
  "profile_key",
  "ForceLoad"
)
local MockProfile = GameProfileStore.Mock:LoadProfileAsync(
  "profile_key",
  "ForceLoad"
)
print(LiveProfile ~= MockProfile) --> true

-- When done using mock profile on live servers: (Prevent memory leak)
MockProfile:Release()
GameProfileStore.Mock:WipeProfileAsync("profile_key")
-- You don't really have to wipe mock profiles in studio testing
```

`ProfileStore.Mock` is a reflection of methods available in the `ProfileStore` object with the exception of profile operations
being performed
on profiles stored on a separate, detached "fake" DataStore that will be forgotten when the game session ends. You may load profiles
of the same key from `ProfileStore` and `ProfileStore.Mock` in parallel - these will be two different profiles because the regular and mock versions of the same `ProfileStore` are completely isolated from each other.

`ProfileStore.Mock` is useful for customizing your testing environment in cases when you want to [enable Roblox API services](https://developer.roblox.com/en-us/articles/Data-store#using-data-stores-in-studio) in studio, but don't want ProfileService to save to live keys:
``` lua
local RunService = game:GetService("RunService")
local GameProfileStore = ProfileService.GetProfileStore("PlayerData", ProfileTemplate)
if RunService:IsStudio() == true then
  GameProfileStore = GameProfileStore.Mock
end
```
A few more things:

-  Even when Roblox API services are disabled, `ProfileStore` and `ProfileStore.Mock` will store profiles in separate stores.
-  It's better to think of `ProfileStore` and `ProfileStore.Mock` as two different `ProfileStore` objects unrelated to each
other in any way.
-  It's possible to create a project that utilizes both live and mock profiles on live servers!

## Profile

### Profile.Data
``` lua
Profile.Data   [table]
-- Non-strict reference - developer can set this value to a new table reference
```
`Profile.Data` is the primary variable of a Profile object. The developer is free to read and write from
the table while it is automatically saved to the [DataStore](https://developer.roblox.com/en-us/api-reference/class/DataStoreService).
`Profile.Data` will no longer be saved after being released remotely or locally via `Profile:Release()`.

### Profile.MetaData
``` lua
Profile.MetaData [table] (Read-only) -- Data about the profile itself

Profile.MetaData.ProfileCreateTime [number] (Read-only)
-- os.time() timestamp of profile creation

Profile.MetaData.SessionLoadCount [number] (Read-only)
-- Amount of times the profile was loaded

Profile.MetaData.ActiveSession [table] or nil (Read-only)
-- {place_id, game_job_id} or nil
-- Set to a session link if a Roblox server is currently the
--   owner of this profile; nil if released

Profile.MetaData.MetaTags [table] (Writable)
-- {["tag_name"] = tag_value, ...}
-- Saved and auto-saved just like Profile.Data

Profile.MetaData.MetaTagsLatest [table] (Read-only)
-- the most recent version of MetaData.MetaTags which has
--   been saved to the DataStore during the last auto-save
--   or Profile:Save() call
```

`Profile.MetaData` is a table containing data about the profile itself. `Profile.MetaData.MetaTags` is saved
on the same DataStore key together with `Profile.Data`.

### Profile.MetaTagsUpdated
```lua
Profile.MetaTagsUpdated [ScriptSignal] (meta_tags_latest)
```

This signal fires after every auto-save, after `Profile.MetaData.MetaTagsLatest` has been updated with the version that's guaranteed to be saved. `MetaTagsUpdated` will fire regardless of whether `MetaTagsLatest` changed after update.

**`MetaTagsUpdated` will also fire after the Profile is saved for the last time and released**. Remember that changes to `Profile.Data` will not be saved after release - `Profile:IsActive()` will return `false` if the profile is released.

`MetaTagsUpdated` example use can be found in the [Developer Products example code](/ProfileService/tutorial/developer_products/).

### Profile.RobloxMetaData
```lua
Profile.RobloxMetaData [table]
-- Non-strict reference - developer can set this value to a new table reference
```
!!! failure "Be cautious of very harsh limits for maximum Roblox Metadata size - As of writing this, total table content size cannot exceed 300 characters."

Table that gets saved as [Metadata (Official documentation)](https://developer.roblox.com/en-us/articles/Data-store#metadata-1) of a DataStore key belonging to the profile.
The way this table is saved is equivalent to using `DataStoreSetOptions:SetMetaData(Profile.RobloxMetaData)` and passing the `DataStoreSetOptions` object to a `:SetAsync()` call,
except changes will truly get saved on the next auto-update cycle or when the profile is released.
The periodic saving and saving upon releasing behaviour is identical to that of `Profile.Data` - After the profile is released further changes to this value will not be saved.

**Example:**

```lua
local profile -- A profile object you loaded

-- Mimicking the Roblox hub example:
profile.RobloxMetaData = {["ExperienceElement"] = "Fire"}

-- You can read from it and write to it at will:
print(profile.RobloxMetaData.ExperienceElement)
profile.RobloxMetaData.ExperienceElement = nil
profile.RobloxMetaData.UserCategory = "Casual"

-- I think setting it to a whole table at profile load would
--   be more safe considering the size limit for meta data
--   is pretty tight:
profile.RobloxMetaData = {
  UserCategory = "Casual",
  FavoriteColor = {1, 0, 0},
}
```

### Profile.UserIds
```lua
Profile.UserIds [table] -- (READ-ONLY) -- {user_id [number], ...}
```
User ids associated with this profile. Entries must be added with [Profile:AddUserId()](#profileadduserid) and removed with [Profile:RemoveUserId()](#profileremoveuserid).

### Profile.KeyInfo
```lua
Profile.KeyInfo [DataStoreKeyInfo]
```
The [DataStoreKeyInfo (Official documentation)](https://developer.roblox.com/en-us/api-reference/class/DataStoreKeyInfo)
instance related to this profile

### Profile.KeyInfoUpdated
```lua
Profile.KeyInfoUpdated [ScriptSignal] (key_info [DataStoreKeyInfo])
```
A signal that gets triggered every time `Profile.KeyInfo` is updated with a new [DataStoreKeyInfo](https://developer.roblox.com/en-us/api-reference/class/DataStoreKeyInfo)
instance reference after every auto-save or profile release.

### Profile.GlobalUpdates
``` lua
Profile.GlobalUpdates [GlobalUpdates]
```

This is the `GlobalUpdates` object tied to this specific `Profile`. It exposes `GlobalUpdates` methods for update processing. (See [Global Updates](#global-updates) for more info)

### Profile:IsActive()
``` lua
Profile:IsActive() --> [bool]
```
Returns `true` while the profile is session-locked and saving of changes to `Profile.Data` is guaranteed.
### Profile:GetMetaTag()
``` lua
Profile:GetMetaTag(tag_name) --> value
-- tag_name   [string]
```
Equivalent of `Profile.MetaData.MetaTags[tag_name]`. See [Profile:SetMetaTag()](#profilesetmetatag) for more info.
### Profile:Reconcile()
``` lua
Profile:Reconcile() --> nil
```
Fills in missing variables inside `Profile.Data` from `profile_template` table that was provided when calling `ProfileService.GetProfileStore()`. It's often necessary to use `:Reconcile()` if you're applying changes to your
`profile_template` over the course of your game's development after release.

The right time to call this method can be seen in the [basic usage example](/ProfileService/tutorial/basic_usage/).

The following function is used in the reconciliation process:
``` lua
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
```
### Profile:ListenToRelease()
``` lua
Profile:ListenToRelease(listener) --> [ScriptConnection] (place_id / nil, game_job_id / nil)
-- listener   [function] (place_id / nil, game_job_id / nil)
```
Listener functions subscribed to `Profile:ListenToRelease()` will be called when
the profile is released remotely (Being `"ForceLoad"`'ed on a remote server) or
locally (`Profile:Release()`). In common practice, the profile will rarely be released before
the player leaves the game so it's recommended to simply [:Kick()](https://developer.roblox.com/en-us/api-reference/function/Player/Kick) the Player when this happens.

!!! warning
    After `Profile:ListenToRelease()` is triggered, it is too late to change `Profile.Data` for the final time.
    As long as the profile is active (`Profile:IsActive()` == `true`), you should store all profile related data
    immediately after it becomes available. An item trading operation between two profiles must happen without
    any yielding after it is confirmed that both profiles are active.

### Profile:Release()
``` lua
Profile:Release()
```
Removes the session lock for this profile for this Roblox server. Call this method after you're
done working with the `Profile` object. Profile data will be immediately saved for the last time.
### Profile:ListenToHopReady()
``` lua
Profile:ListenToHopReady(listener) --> [ScriptConnection] ()
-- listener   [function] ()
```
In many cases ProfileService will be fast enough when loading and releasing profiles as the player teleports between
places belonging to the same universe / game. However, if you're experiencing noticable delays when loading profiles
after a universe teleport, you should try implementing `:ListenToHopReady()`.

A listener passed to `:ListenToHopReady()` will be executed after the releasing UpdateAsync call finishes.
`:ListenToHopReady()` will usually call the listener in around a second, but may ocassionally take up to 7
seconds when a profile is released next to an auto-update interval (regular usage scenario - rapid
loading / releasing of the same profile key may yield different results).

**Example use:**
``` lua
local TeleportService = game:GetService("TeleportService")
local profile, player, place_id

profile:Release()
profile:ListenToHopReady(function()
  TeleportService:TeleportAsync(place_id, {player})
end)
```

In short, `Profile:ListenToRelease()` and `Profile:ListenToHopReady()` will both execute the listener function after release, but `Profile:ListenToHopReady()` will
additionally wait until the session lock is removed from the `Profile`.

### Profile:AddUserId()
```lua
Profile:AddUserId(user_id)
-- user_id   [number]
```
Associates a `UserId` with the profile. Multiple users can be associated with a single profile by calling this method for each individual `UserId`.
The primary use of this method is to comply with GDPR (The right to erasure). More information in [official documentation](https://developer.roblox.com/en-us/articles/Data-store#metadata-1).

The right time to call this method can be seen in the [basic usage example](/ProfileService/tutorial/basic_usage/).

### Profile:RemoveUserId()
```lua
Profile:RemoveUserId(user_id)
-- user_id   [number]
```
Unassociates `UserId` with the profile if it was initially associated.

### Profile:Identify()
```lua
Profile:Identify() --> [string]
-- Example return: "[Store:"GameData";Scope:"Live";Key:"Player_2312310"]"
```

Returns a string containing DataStore name, scope and key; Used for debugging;

### Profile:SetMetaTag()
``` lua
Profile:SetMetaTag(tag_name, value)
-- tag_name   [string]
-- value      -- Any value supported by DataStore
```
Equivalent of `Profile.MetaData.MetaTags[tag_name] = value`. Use for tagging your profile
with information about itself such as:

- `profile:SetMetaTag("DataVersion", 1)` to let your game code know whether `Profile.Data` needs to be converted
after massive changes to the game.
- Anything set through `profile:SetMetaTag(tag_name, value)` will be available through `Profile.MetaData.MetaTagsLatest[tag_name]` after an auto-save or a `:Save()` call - `Profile.MetaData.MetaTagsLatest` is a version
of `Profile.MetaData.MetaTags` that has been successfully saved to the DataStore.

!!! notice
    You can use `Profile.MetaData.MetaTagsLatest` for product purchase confirmation (By storing `receiptInfo.PurchaseId` values inside `Profile.MetaData.MetaTags` and waiting for them to appear in `Profile.MetaData.MetaTagsLatest`). Don't forget to clear really old `PurchaseId`'s to stay under DataStore limits.

### Profile:Save()
``` lua
Profile:Save() -- Call to quickly progress GlobalUpdates
--   state or to speed up save validation processes
--   (Does not yield)
```
Call `Profile:Save()` to quickly progress `GlobalUpdates` state or to speed up the propagation of
`Profile.MetaData.MetaTags` changes to `Profile.MetaData.MetaTagsLatest`.

`Profile:Save()` **should not be called for saving** `Profile.Data` or `Profile.MetaData.MetaTags` -
this is already done for you automatically.

!!! warning
    Calling `Profile:Save()` when the `Profile` is released will throw an error.
    You can check `Profile:IsActive()` before using this method.

### Profile:ClearGlobalUpdates()
```lua
Profile:ClearGlobalUpdates()
```
!!! failure "Only works for profiles loaded through [:ViewProfileAsync()](#profilestoreviewprofileasync) or [:ProfileVersionQuery()](#profilestoreprofileversionquery)"
Clears all global update data (active or locked) for a profile payload. It may be desirable to clear potential "residue" global updates (e.g. pending gifts) which were existing in a snapshot which is being used to recover
player data through [:ProfileVersionQuery()](#profilestoreprofileversionquery).

### Profile:OverwriteAsync()
```lua
Profile:OverwriteAsync()
```
!!! failure "Only works for profiles loaded through [:ViewProfileAsync()](#profilestoreviewprofileasync) or [:ProfileVersionQuery()](#profilestoreprofileversionquery)"

!!! failure "Only use for rollback payloads (Setting latest version to a copy of a previous version)!"
    **Using this method for editing latest player data when the player is in-game can lead to several minutes of lost progress - it should be replaced by [:LoadProfileAsync()](#profilestoreloadprofileasync) which will wait for the next live profile auto-save if the player is in-game, allowing the remote server to release the profile and save latest data.**

Pushes the `Profile` payload to the DataStore (saves the profile) and releases the session lock for the profile.

## Global Updates

Global updates is a powerful feature of ProfileService, used for sending information to a desired player profile across servers, within the server or to a player profile that is not currently active in any Roblox server (Kind of like [MessagingService](https://developer.roblox.com/en-us/api-reference/class/MessagingService), but slower and doesn't require the recipient to be active). The primary intended use of global updates is to support sending gifts among players, or giving items to players through a custom admin tool. The benefit of using global updates is it's API simplicity (This is as simple as it gets, sorry 😂) and the fact that global updates are pulled from the DataStore whenever the profile is auto-saved **at no additional expense of more DataStore calls!**

Global updates can be `Active`, `Locked` and `Cleared`:

 - Whenever a global update is created, it will be `Active` by default
 - `Active` updates can be **changed** or **cleared** within a `:GlobalUpdateProfileAsync()` call
 - Normally, when the profile is active on a Roblox server, you should always progress all `Active` updates to the `Locked` state
 - `Locked` updates can no longer be **changed** or **cleared** within a `:GlobalUpdateProfileAsync()` call
 - `Locked` updates are ready to be processed (e.g., add gift to player inventory) and imediately `Locked` by calling `:LockActiveUpdate(update_id)`
 - `Cleared` updates will immediately disappear from the profile forever

### ***Always available***

#### GlobalUpdates:GetActiveUpdates()
``` lua
GlobalUpdates:GetActiveUpdates() --> [table] { {update_id, update_data}, ...}
```
Should be used immediately after a `Profile` is loaded to scan and progress any pending `Active` updates to `Locked` state:
``` lua
for _, update in ipairs(profile.GlobalUpdates:GetActiveUpdates()) do
  profile.GlobalUpdates:LockActiveUpdate(update[1])
end
```
#### GlobalUpdates:GetLockedUpdates()
``` lua
GlobalUpdates:GetLockedUpdates() --> [table] { {update_id, update_data}, ...}
```
Should be used immediately after a `Profile` is loaded to scan and progress any pending `Locked` updates to `Cleared` state:
``` lua
for _, update in ipairs(profile.GlobalUpdates:GetLockedUpdates()) do
  local update_id = update[1]
  local update_data = update[2]
  if update_data.Type == "AdminGift" and update_data.Item == "Coins" then
    profile.Data.Coins = profile.Data.Coins + update_data.Amount
  end
  profile.GlobalUpdates:ClearLockedUpdate(update_id)
end
```
### ***Only when accessed from `Profile.GlobalUpdates`***
#### GlobalUpdates:ListenToNewActiveUpdate()
``` lua
GlobalUpdates:ListenToNewActiveUpdate(listener) --> [ScriptConnection]
-- listener   [function](update_id, update_data)
```
In most games, you should progress all `Active` updates to `Locked` state:
``` lua
profile.GlobalUpdates:ListenToNewActiveUpdate(function(update_id, update_data)
  profile.GlobalUpdates:LockActiveUpdate(update_id)
end)
```
#### GlobalUpdates:ListenToNewLockedUpdate()
``` lua
GlobalUpdates:ListenToNewLockedUpdate(listener) --> [ScriptConnection]
-- listener   [function](update_id, update_data)
-- Must always call GlobalUpdates:ClearLockedUpdate(update_id)
--   after processing the locked update.
```
When you get a `Locked` update via `GlobalUpdates:ListenToNewLockedUpdate()`, the update is
ready to be proccessed and immediately locked:
``` lua
profile.GlobalUpdates:ListenToNewLockedUpdate(function(update_id, update_data)
  if update_data.Type == "AdminGift" and update_data.Item == "Coins" then
    profile.Data.Coins = profile.Data.Coins + update_data.Amount
  end
  profile.GlobalUpdates:ClearLockedUpdate(update_id)
end)
```
#### GlobalUpdates:LockActiveUpdate()
``` lua
GlobalUpdates:LockActiveUpdate(update_id)
-- update_id   [number] -- Id of an existing global update
```
Turns an `Active` update into a `Locked` update. Will invoke `GlobalUpdates:ListenToNewLockedUpdate()` after
an auto-save (less than 30 seconds) or `Profile:Save()`.

!!! warning
    Calling `GlobalUpdates:LockActiveUpdate()` when the `Profile` is released will throw an error.
    You can check `Profile:IsActive()` before using this method. ProfileService guarantees that the
    `Profile` will be active when `GlobalUpdates:ListenToNewActiveUpdate()` listeners are triggered.
  
#### GlobalUpdates:ClearLockedUpdate()
``` lua
GlobalUpdates:ClearLockedUpdate(update_id)
-- update_id   [number] -- Id of an existing global update
```
Clears a `Locked` update completely from the profile.

!!! warning
    Calling `GlobalUpdates:ClearLockedUpdate()` when the `Profile` is released will throw an error.
    You can check `Profile:IsActive()` before using this method. ProfileService guarantees that the
    `Profile` will be active when `GlobalUpdates:ListenToNewLockedUpdate()` listeners are triggered.

### ***Available inside `update_handler` during a `ProfileStore:GlobalUpdateProfileAsync()` call***
#### GlobalUpdates:AddActiveUpdate()
``` lua
GlobalUpdates:AddActiveUpdate(update_data)
-- update_data   [table] -- Your custom global update data
```
Used to send a new `Active` update to the profile.
#### GlobalUpdates:ChangeActiveUpdate()
``` lua
GlobalUpdates:ChangeActiveUpdate(update_id, update_data)
-- update_id     [number] -- Id of an existing global update
-- update_data   [table] -- New data that replaces previously set update_data
```
Changing `Active` updates can be used for stacking player gifts, particularly when
lots of players can be sending lots of gifts to a Youtube celebrity so the `Profile` would not
exceed the [DataStore data limit](https://developer.roblox.com/en-us/articles/Datastore-Errors#data-limits).
#### GlobalUpdates:ClearActiveUpdate()
``` lua
GlobalUpdates:ClearActiveUpdate(update_id)
-- update_id   [number] -- Id of an existing global update
```
Removes an `Active` update from the profile completely.