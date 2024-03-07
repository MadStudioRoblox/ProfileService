# ProfileService's Session Locking Overview

If you're wondering how ProfileService implements their Session-Locking, then this is the right place to learn more about it.

There are several of locks and methods ProfileService has, each will be explained separately. All these explained session checks, are combined together within the ProfileService Module.

## Only Load once per Server
When ``ProfileService:LoadProfileAsync`` is called, it looks up its own Private Variable for Active Stores, which is defined in the code like so:
```lua
local ActiveProfileStores = ProfileService._active_profile_stores
```

It checks whether the Profile _was already loaded_ in the same server or not, through ``loaded_profiles[profile_key]``. The ``profile_key`` is the actual ``key``, same as for regular Roblox DataStores.

If the Profile is already loaded, it will throw an Error:
> _is already loaded in this session_

If it **isn't loaded**, it will store it inside ``ProfileService._active_profile_stores``.

``ActiveProfileStores``, stores the same table address that gets returned by ``ProfileService:LoadProfileAsync``, so it's automatically in sync, and that's how ``ProfileService`` processes the data later.
This allows anyone to have freedom for creating their own Data Infrastructure.

### Releasing
When ``:Release`` is used, it calls a local function named ``SaveProfileAsync``, which calls ``ReleaseProfileInternally`` if ``release_from_session`` is set to ``true``.
It will remove the loaded Profile table from ``ActiveProfileStores`` as well as from ProfileService's internal ``loaded_profiles``.

If ``:LoadProfileAsync`` would be used again, the table address will be new and different.


## Session-Locking
When ``ProfileService:LoadProfileAsync`` is called, when loading, it will call ``StandardProfileUpdateAsyncDataStore``, which will create a DataStore as well.

Your regular Profile Data is stored inside a table named ``Data``. But there's also Metadata that is used by ProfileService stored inside of ``MetaData``.

Which looks like so: 
_(Note that there's more than just that)_
```
MetaData = {
  ActiveSession = {
    [1] = <PlaceId>;
    [2] = <JobId>;
  }
}
```

If a Profile is not loaded in another game instance, ``loaded_data.MetaData.ActiveSession`` won't be present.

If it is loaded in a game, then ``MetaData.ActiveSession`` will be present, holding the **PlaceId** and the **JobId** of where it is loaded from.

If a Profile gets loaded, it will set ``MetaData.ActiveSession``.

### IsThisSession
This is a local function which checks whether ``ActiveSession`` has the same PlaceId and JobId.

### Releasing
When ``:Release`` is used without any errors _(remember it calls ``SaveProfileAsync`` which does the rest of the handling)_, ``ActiveSession`` will be set to ``nil`` and will so be completly removed.

### Saving
When the local function ``SaveProfileAsync`` is called, aslong it is _not forced to overwrite something_, it will check whether ``MetaData.ActiveSession`` is still owned by the same session.

e.g. whether the ``ActiveSession`` has the same ``{PlaceId, JobId}`` as from where it is being ran from.


## Case, Profile is taken by another session
If an ``ActiveSession`` mismatches the current one, it means that it's taken by another session.

By default ``:LoadProfileAsync`` will attempt to _ForceLoad_.

### Loading System
ProfileService queues load requests.


### ForceLoad


### Repeat
If it's set to Repeat, it will actively re-retrieve the DataStore again and wait until ActiveSession was set free.

**Note:** may or may not be recommended, as ``Repeat`` causes ``:UpdateAsync()`` to be called.
