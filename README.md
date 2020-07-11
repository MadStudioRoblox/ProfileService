# Madwork - ProfileService
ProfileService.lua is a stand-alone ModuleScript that handles the loading and saving of your game's DataStore profiles (reffered to as just "profiles" later on) along with additional power user features such as:

- **Profile session ownership handling** (A case when another Roblox server is still using the profile)
- **Global updates** (An easy way of setting up a gifts among players system)
- **"MetaTags"** (A handy organizational feature for storing information about the profile itself)

> **Disclaimer**: Although ProfileService has been thoroughly tested (Auto test source included), it has not been used within a large scale Roblox project yet. If you find any bugs please report an issue!

*ProfileService is part of the **Madwork** framework*
*Developed by [loleris](https://twitter.com/LM_loleris)*

## Why?

The most common issues Roblox developers run into when creating their own DataStore modules are:

 - Getting confused on how to handle DataStore errors
 - Having to rewrite their DataStore code for every new project
 - Experiencing player data loss

ProfileService is the perfect solution to the regular DataStore usage when data from the DataStore is loaded once and only auto-saved (and saved after finishing work) afterwards.

ProfileService **is an abstraction** of DataStore profiles, which means that it is not tied to the `Player` instance and can be easily used for various game features like **group owned houses** where house data could not be tied to a particular player profile and the group owned house would preferably only be loaded on a single Roblox server.

ProfileService allows you to easily maintain player profiles that remain loaded even after the player leaves which can be handy for certain competitive games like MMO's (A game where you would lose your items if you get killed in combat). If you're willing to go to such lengths, at least :P.

## Setting up

Roblox library: https://www.roblox.com/library/5331689994/ProfileService

ProfileService.lua is supposed to be a ModuleScript which you can place inside your Roblox place's ServerScriptService or wherever else you prefer. ProfileService can only be used server-side. Access the ProfileService functions through the declared variable within another Script or ModuleScript:
```lua
local ProfileService = require(game.ServerScriptService.ProfileService)
```
Before use, I advise getting familiar with the Roblox [DataStore documentation](https://developer.roblox.com/en-us/articles/Data-store)
## API
### ProfileService:
***Members:*** (variables)
```lua
ProfileService.IssueSignal   [ScriptSignal](error_message)
-- Analytics endpoint for DataStore error logging
-- Example:
ProfileService.IssueSignal:Connect(function(error_message)
  print("ProfileService experienced a DataStore error:", error_message)
end)
```
```lua
ProfileService.CorruptionSignal   [ScriptSignal](profile_store_name, profile_key)
-- Analytics endpoint for cases when a DataStore key returns
--   a value that has all or some of it's profile components
--   set to invalid data types. E.g., accidentally setting
--   Profile.Data to a non table value
```
```lua
ProfileService.CriticalStateSignal   [ScriptSignal] (is_critical_state)
-- Analytics endpoint for cases when DataStore is throwing
--   too many errors and it's most likely affecting your
--   game really really bad - this could be due to developer
--   errrors or due to Roblox server problems.
--   (You can use this to alert players... But it's not like
--   they will make use of it much:P)
```
***Functions:***
```lua
ProfileService.GetProfileStore(profile_store_name, profile_template) --> [ProfileStore]
-- profile_store_name   [string] -- DataStore name
-- profile_template     [table] -- Profile.Data will default to given table (deep-copy)
--    when no data was saved previously
```
---
### [ProfileStore]:
```lua
-- (This method will yield)
ProfileStore:LoadProfileAsync(profile_key, not_released_handler) --> [Profile] or nil
-- profile_key            [string] -- DataStore key
-- not_released_handler   "ForceLoad" or [function](place_id, game_job_id)
--
-- When not_released_handler is a function:
-- not_released_handler(place_id, game_job_id) will be called in
-- a case where the profile has not been released by another game server.
-- not_released_handler must return one of the following arguments:
return "Repeat" -- ProfileService will repeat the profile loading
--   proccess and may call the release handler again
return "Cancel" -- :LoadProfileAsync() will immediately return nil
return "ForceLoad" -- ProfileService will repeat the profile loading
--   call while trying to make the owner game server release the
--   profile. It will "steal" the profile ownership if the server
--   doesn't release the profile in time.
--
-- :LoadProfileAsync() will continue to load the profile indefinetly
--   until "Cancel" is passed or the server is shutting down,
--   regardless if DataStore is throwing errors.
```

```lua
-- (This method will yield)
ProfileStore:GlobalUpdateProfileAsync(profile_key, update_handler) --> [GlobalUpdates] or nil
-- profile_key      [string] -- DataStore key
-- update_handler   [function](global_updates) -- This function is
--   called with a GlobalUpdates object
-- Global updates will work for profiles that haven't been created
```

```lua
-- (This method will yield)
ProfileStore:ViewProfileAsync(profile_key) --> [Profile] or nil
-- profile_key      [string] -- DataStore key
-- Writing and saving is not possible for profiles in view mode.
-- Profile.Data and Profile.MetaData will be nil if the profile
-- hasn't been created before.
```
---
### [Profile]:

***Members:*** (variables)

```lua
Profile.Data [table] -- Writable table that gets saved periodically
--   and after the profile is released
```
```lua
Profile.MetaData [table] (Read-only) -- Data about the profile itself

Profile.MetaData.ProfileCreateTime [number] (Read-only)
-- os.time() timestamp of profile creation
Profile.MetaData.SessionLoadCount [number] (Read-only)
-- Amount of times the profile was loaded
Profile.MetaData.ActiveSession [table] (Read-only) -- {place_id, game_job_id} or nil
-- Set to a session link if a Roblox server is currently the
--   owner of this profile; nil if released
Profile.MetaData.MetaTags [table] -- {["tag_name"] = tag_value, ...}
-- Saved and auto-saved just like Profile.Data
Profile.MetaData.MetaTagsLatest [table] (Read-only)
-- the most recent version of MetaData.MetaTags which has
--   been saved to the DataStore during the last auto-save
--   or Profile:Save() call
```
```lua
Profile.GlobalUpdates [GlobalUpdates]
```
> Notice: You can use Profile.MetaData.MetaTagsLatest for product purchase confirmation (By storing `receiptInfo.PurchaseId` values inside `Profile.MetaData.MetaTags` and waiting for them in `Profile.MetaData.MetaTagsLatest`). Don't forget to clear really old `PurchaseId`'s to stay under DataStore limits.

***Methods:***
```lua
Profile:IsActive() --> [bool] -- Returns true while the profile is
--   active and can be written to
```
```lua
Profile:GetMetaTag(tag_name) --> value
-- tag_name   [string]
```
```lua
Profile:ListenToRelease(listener) --> [ScriptConnection] ()
-- listener   [function]()
-- Profiles can be both released inside the same server that
--   has this profile loaded, or by another Roblox server that
--   is trying to ForceLoad the profile. In general use, the
--   calling of this listener would be extremely rare and the
--   recommended behaviour is to :Kick() the Player within the
--   listener function
```
```lua
Profile:Release() -- Releases the ownership of this profile
--   for this Roblox server. Call this method after writing
--   and reading from the profile is no longer going to
--   happen. The profile will be saved for the last time.
--   (e.g., call after the player leaves) (Does not yield)
```
***"Dangerous" methods:*** (Will error after the profile is released)
```lua
Profile:SetMetaTag(tag_name, value)
-- tag_name   [string]
-- value      -- Any value supported by DataStore
-- You may also read / write directly inside
--   Profile.MetaData.MetaTags
--   (While the profile is active)
```
```lua
Profile:Save() -- Call to quickly progress GlobalUpdates
--   state or to speed up save validation processes
--   (Does not yield)
```
---
### [GlobalUpdates]:

Global updates are a powerful feature of ProfileService used for sending information to a desired player profile across servers, within the server or to a player profile that is not currently active in any Roblox server. The primary intended use of global updates is to support sending gifts among players, or giving items to players through a custom admin tool. The benefit of using global updates is it's API simplicity and the fact that global updates are pulled from the DataStore whenever the profile is auto-saved **at no additional expense of more DataStore calls!**

Global updates can be `Active`, `Locked` and `Cleared`:

 - Whenever a global update is created, it will be `Active` by default
 - `Active` updates can be **changed** or **cleared** within a `:GlobalUpdateProfileAsync()` call
 - Normally, when the profile is active on a Roblox server, you should always progress all `Active` updates to the `Locked` state
 - `Locked` updates can no longer be **changed** or **cleared** within a `:GlobalUpdateProfileAsync()` call
 - `Locked` updates are ready to be processed (e.g., add gift to player inventory) and imediately `Locked` by calling `:LockActiveUpdate(update_id)`
 - `Cleared` updates will immediately disappear from the profile forever
```

***Always available:***
```lua
GlobalUpdates:GetActiveUpdates() --> [table] {{update_id, update_data}, ...}
-- Should be used at startup to progress any pending
--   active updates to locked state
```
```lua
GlobalUpdates:GetLockedUpdates() --> [table] {{update_id, update_data}, ...}
-- Should be used at startup to progress any pending
--   locked updates to cleared state
```
***Only when accessed from `Profile.GlobalUpdates`:***
```lua
GlobalUpdates:ListenToNewActiveUpdate(listener) --> [ScriptConnection]
-- listener   [function](update_id, update_data)
-- WARNING: will error after profile expires
```
```lua
GlobalUpdates:ListenToNewLockedUpdate(listener) --> [ScriptConnection]
-- listener   [function](update_id, update_data)
-- Must always call GlobalUpdates:ClearLockedUpdate(update_id)
--   after processing the locked update.
-- WARNING: will error after profile expires
```
```lua
GlobalUpdates:LockActiveUpdate(update_id)
-- update_id   [number] -- Id of an existing global update
-- Turns an active update into a locked update.
--   Will invoke :ListenToNewLockedUpdate() after
--   an auto-save or Profile:Save()
```
```lua
GlobalUpdates:ClearLockedUpdate(update_id)
-- update_id   [number] -- Id of an existing global update
-- Clears a locked update completely from the profile
```

***Available inside `update_handler` during a `ProfileStore:GlobalUpdateProfileAsync()` call:***
```lua
GlobalUpdates:AddActiveUpdate(update_data)
-- update_data   [table] -- Your custom global update data
-- Used to send a new global update to the profile
```
```lua
GlobalUpdates:ChangeActiveUpdate(update_id, update_data)
-- update_id     [number] -- Id of an existing global update
-- update_data   [table] -- New data that replaces previously set update_data
-- Changing global updates can be used for stacking player
--   gifts, particularly when lots of players might send lots
--   of gifts to a Youtube celebrity so the profile would not
--   hit the DataStore data limit
```
```lua
GlobalUpdates:ClearActiveUpdate(update_id)
-- update_id   [number] -- Id of an existing global update
-- Removes the global data from the profile completely.
```
