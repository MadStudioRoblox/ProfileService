!!! warning
    Never yield (use `wait()` or asynchronous Roblox API calls) inside listener functions

!!! notice
    Methods with `Async` in their name are methods that will yield - just like `wait()`

## ProfileService
### ProfileService.ServiceLocked
```lua
ProfileService.ServiceLocked   [bool]
```
Set to false when the Roblox server is shutting down.
`ProfileStore` methods should not be called after this value is set to `false`
### ProfileService.IssueSignal
```lua
ProfileService.IssueSignal   [ScriptSignal](error_message [string])
```
Analytics endpoint for DataStore error logging. Example usage:
```lua
ProfileService.IssueSignal:Connect(function(error_message)
  pcall(function()
    AnalyticsService:FireEvent("ProfileServiceIssue", error_message)
  end)
end)
```
### ProfileService.CorruptionSignal
```lua
ProfileService.CorruptionSignal   [ScriptSignal](profile_store_name [string], profile_key [string])
```
Analytics endpoint for cases when a DataStore key returns a value that has all or some
of it's profile components set to invalid data types. E.g., accidentally setting
Profile.Data to a non table value
### ProfileService.CriticalStateSignal
```lua
ProfileService.CriticalStateSignal   [ScriptSignal] (is_critical_state [bool])
```
Analytics endpoint for cases when DataStore is throwing too many errors and it's most
likely affecting your game really really bad - this could be due to developer errrors
or due to Roblox server problems. Could be used to alert players about data store outages.

### ProfileService.GetProfileStore()
```lua
ProfileService.GetProfileStore(
    profile_store_name,
    profile_template
) --> [ProfileStore]
-- profile_store_name   [string] -- DataStore name
-- profile_template     [table] -- Profile.Data will default to
--   given table (deep-copy) when no data was saved previously
```
`ProfileStore` objects expose methods for loading / viewing profiles and sending global updates. Equivalent of [:GetDataStore()](https://developer.roblox.com/en-us/api-reference/function/DataStoreService/GetDataStore) in Roblox [DataStoreService](https://developer.roblox.com/en-us/api-reference/class/DataStoreService) API.

!!! notice
    `profile_template` is only copied for `Profile.Data` for new profiles. Changes made to `profile_template` will
    not fill in missing components in profiles that have been saved before changing `profile_template`.
    You may create your own function to fill in the missing components in `Profile.Data` as soon as it is
    loaded or have `nil` exceptions in your personal `:Get()` and `:Set()` method libraries.

## ProfileStore
### ProfileStore:LoadProfileAsync()

```lua
ProfileStore:LoadProfileAsync(
  profile_key,
  not_released_handler
) --> [Profile] or nil
-- profile_key            [string] -- DataStore key
-- not_released_handler   "ForceLoad" or [function](place_id, game_job_id)
```
For basic usage, pass `"ForceLoad"` for the `not_released_handler` argument.

`not_released_handler` as a `function` argument is called when the profile is
session-locked by a remote Roblox server:
```lua
local profile = ProfileStore:LoadProfileAsync(
  "Player_2312310",
  function(place_id, game_job_id)
    -- place_id and game_job_id identify the Roblox server that has
    --   this profile currently locked. In rare cases, if the server
    --   crashes, the profile will stay locked until ForceLoaded by
    --   a new session.
    return "Repeat" or "Cancel" or "ForceLoad"
  end
)
```
`not_released_handler` must return one of the three values:

- `return "Repeat"` - ProfileService will repeat the profile loading proccess and
may call the release handler again
- `return "Cancel"` - `:LoadProfileAsync()` will immediately return nil
- `return "ForceLoad"` - ProfileService will indefinetly attempt to load the profile.
If the profile is session-locked by a remote Roblox server, it will either be released
for that remote server or "stolen" (Stealing is nescessary for remote servers that are not
responding in time and for handling crashed server session-locks).

!!! warning
    `:LoadProfileAsync()` can return `nil` when another remote Roblox server attempts to load the profile at the same time.
    This case should be extremely rare and it would be recommended to [:Kick()](https://developer.roblox.com/en-us/api-reference/function/Player/Kick) the player if `:LoadProfileAsync()` does
    not return a `Profile` object.

!!! failure "Do not load a profile of the same key again before it is released"
    Trying to load a profile that has already been session-locked on the same server will result in an error. You may, however, instantly load the profile again after releasing it with `Profile:Release()`.

### ProfileStore:GlobalUpdateProfileAsync()
```lua
ProfileStore:GlobalUpdateProfileAsync(
  profile_key,
  update_handler
) --> [GlobalUpdates] or nil
-- profile_key      [string] -- DataStore key
-- update_handler   [function](global_updates) -- This function is
--   called with a GlobalUpdates object
```
Example usage of `:GlobalUpdateProfileAsync()`:
```lua
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

### ProfileStore:ViewProfileAsync()
```lua
ProfileStore:ViewProfileAsync(profile_key) --> [Profile] or nil
-- profile_key   [string] -- DataStore key
```
Writing and saving is not possible for profiles in view mode. `Profile.Data` and `Profile.MetaData` will be `nil`
if the profile hasn't been created.

## Profile

### Profile.Data
```lua
Profile.Data   [table]
```
`Profile.Data` is the primary variable of a Profile object. The developer is free to read and write from
the table while it is automatically saved to the [DataStore](https://developer.roblox.com/en-us/api-reference/class/DataStoreService).
`Profile.Data` will no longer be saved after being released remotely or locally via `Profile:Release()`.

### Profile.MetaData
```lua
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

!!! notice
    You can use `Profile.MetaData.MetaTagsLatest` for product purchase confirmation (By storing `receiptInfo.PurchaseId` values inside `Profile.MetaData.MetaTags` and waiting for them to appear in `Profile.MetaData.MetaTagsLatest`). Don't forget to clear really old `PurchaseId`'s to stay under DataStore limits.

### Profile.GlobalUpdates
```lua
Profile.GlobalUpdates [GlobalUpdates]
```

This is the `GlobalUpdates` object tied to this specific `Profile`. It exposes `GlobalUpdates` methods for update processing.

### Profile:IsActive()
```lua
Profile:IsActive() --> [bool]
```
Returns `true` while the profile is session-locked and saving of changes to `Profile.Data` is guaranteed.
### Profile:GetMetaTag()
```lua
Profile:GetMetaTag(tag_name) --> value
-- tag_name   [string]
```
### Profile:ListenToRelease()
```lua
Profile:ListenToRelease(listener) --> [ScriptConnection] ()
-- listener   [function]()
```
Listener functions subscribed to `Profile:ListenToRelease()` will be called when
the profile is released remotely (Being `"ForceLoad"`'ed on a remote server) or
locally (`Profile:Release()`). In common practice, the profile will rarely be released before
the player leaves the game so it's recommended to simply [:Kick()](https://developer.roblox.com/en-us/api-reference/function/Player/Kick) the Player when this happens.
### Profile:Release()
```lua
Profile:Release()
```
Removes the session lock for this profile for this Roblox server. Call this method after you're
done working with the `Profile` object. Profile data will be immediately saved for the last time.
### Profile:SetMetaTag()
```lua
Profile:SetMetaTag(tag_name, value)
-- tag_name   [string]
-- value      -- Any value supported by DataStore
```

!!! warning
    Calling `Profile:SetMetaTag()` when the `Profile` is released will throw an error.
    You can check `Profile:IsActive()` before using this method.

!!! notice
    You may also read / write directly inside `Profile.MetaData.MetaTags`

### Profile:Save()
```lua
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

## GlobalUpdates

Global updates is a powerful feature of ProfileService, used for sending information to a desired player profile across servers, within the server or to a player profile that is not currently active in any Roblox server. The primary intended use of global updates is to support sending gifts among players, or giving items to players through a custom admin tool. The benefit of using global updates is it's API simplicity (This is as simple as it gets, sorry 😂) and the fact that global updates are pulled from the DataStore whenever the profile is auto-saved **at no additional expense of more DataStore calls!**

Global updates can be `Active`, `Locked` and `Cleared`:

 - Whenever a global update is created, it will be `Active` by default
 - `Active` updates can be **changed** or **cleared** within a `:GlobalUpdateProfileAsync()` call
 - Normally, when the profile is active on a Roblox server, you should always progress all `Active` updates to the `Locked` state
 - `Locked` updates can no longer be **changed** or **cleared** within a `:GlobalUpdateProfileAsync()` call
 - `Locked` updates are ready to be processed (e.g., add gift to player inventory) and imediately `Locked` by calling `:LockActiveUpdate(update_id)`
 - `Cleared` updates will immediately disappear from the profile forever

### ***Always available***

#### GlobalUpdates:GetActiveUpdates()
```lua
GlobalUpdates:GetActiveUpdates() --> [table] { {update_id, update_data}, ...}
```
Should be used at startup to scan and progress any pending `Active` updates to `Locked` state.
#### GlobalUpdates:GetLockedUpdates()
```lua
GlobalUpdates:GetLockedUpdates() --> [table] { {update_id, update_data}, ...}
```
Should be used at startup to scan and progress any pending `Locked` updates to `Cleared` state.
### ***Only when accessed from `Profile.GlobalUpdates`***
#### GlobalUpdates:ListenToNewActiveUpdate()
```lua
GlobalUpdates:ListenToNewActiveUpdate(listener) --> [ScriptConnection]
-- listener   [function](update_id, update_data)
```
In most games, you should progress all `Active` updates to `Locked` state:
```lua
profile.GlobalUpdates:ListenToNewActiveUpdate(function(update_id, update_data)
  profile.GlobalUpdates:LockActiveUpdate(update_id)
end)
```
#### GlobalUpdates:ListenToNewLockedUpdate()
```lua
GlobalUpdates:ListenToNewLockedUpdate(listener) --> [ScriptConnection]
-- listener   [function](update_id, update_data)
-- Must always call GlobalUpdates:ClearLockedUpdate(update_id)
--   after processing the locked update.
```
When you get a `Locked` update via `GlobalUpdates:ListenToNewLockedUpdate()`, the update is
ready to be proccessed and immediately locked:
```lua
profile.GlobalUpdates:ListenToNewLockedUpdate(function(update_id, update_data)
  if update_data.Type == "AdminGift" and update_data.Item == "Coins" then
    profile.Data.Coins = profile.Data.Coins + update_data.Amount
  end
  profile.GlobalUpdates:ClearLockedUpdate(update_id)
end)
```
#### GlobalUpdates:LockActiveUpdate()
```lua
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
```lua
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
```lua
GlobalUpdates:AddActiveUpdate(update_data)
-- update_data   [table] -- Your custom global update data
```
Used to send a new `Active` update to the profile.
#### GlobalUpdates:ChangeActiveUpdate()
```lua
GlobalUpdates:ChangeActiveUpdate(update_id, update_data)
-- update_id     [number] -- Id of an existing global update
-- update_data   [table] -- New data that replaces previously set update_data
```
Changing `Active` updates can be used for stacking player gifts, particularly when
lots of players can be sending lots of gifts to a Youtube celebrity so the `Profile` would not
exceed the [DataStore data limit](https://developer.roblox.com/en-us/articles/Datastore-Errors#data-limits).
#### GlobalUpdates:ClearActiveUpdate()
```lua
GlobalUpdates:ClearActiveUpdate(update_id)
-- update_id   [number] -- Id of an existing global update
```
Removes an `Active` update from the profile completely.