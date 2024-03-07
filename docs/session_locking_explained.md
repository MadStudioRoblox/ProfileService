# ProfileService's Session Locking Overview

If you're wondering how ProfileService implements their Session-Locking, then this is the right place to learn more about it.

There are several of locks and methods ProfileService has, each will be explained separately. All these explained session checks, are combined together within the ProfileService Module.

<br>

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

<br>

### Releasing
When ``:Release`` is used, it calls a local function named ``SaveProfileAsync``, which calls ``ReleaseProfileInternally`` if ``release_from_session`` is set to ``true``.
It will remove the loaded Profile table from ``ActiveProfileStores`` as well as from ProfileService's internal ``loaded_profiles``.

If ``:LoadProfileAsync`` would be used again, the table address will be new and different.


<br>
<br>

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
  };

  LastUpdate = <A value from os.time()>
}
```

If a Profile is not loaded in another game instance, ``loaded_data.MetaData.ActiveSession`` won't be present.

If it is loaded in a game, then ``MetaData.ActiveSession`` will be present, holding the **PlaceId** and the **JobId** of where it is loaded from.

If a Profile gets loaded, it will set ``MetaData.ActiveSession``.

### IsThisSession
This is a local function which checks whether ``ActiveSession`` has the same PlaceId and JobId.

<br>

### Releasing
When ``:Release`` is used without any errors _(remember it calls ``SaveProfileAsync`` which does the rest of the handling)_, ``ActiveSession`` will be set to ``nil`` and will so be completly removed.


### Saving
When the local function ``SaveProfileAsync`` is called, aslong it is _not forced to overwrite something_, it will check whether ``MetaData.ActiveSession`` is still owned by the same session.

e.g. whether the ``ActiveSession`` has the same ``{PlaceId, JobId}`` as from where it is being ran from.

<br>
<br>

## Case: Profile is taken by another session
If an ``ActiveSession`` mismatches the current one, it means that it's taken by another session. ProfileService, will either abort loading or yield until the session becomes free.

By default ``:LoadProfileAsync`` will attempt to _ForceLoad_, after a while it will steal the session.

ProfileService makes a few exceptions for ``ActiveSession``. As example, if a different session is checking whether the ProfileStore is session-locked, it will check the time it was last updated by checking ``MetaData.LastUpdate``. If it has been _dead_ for too long ``os.time() - last_update > SETTINGS.AssumeDeadSessionLock``. It will steal the session.

```lua
AssumeDeadSessionLock = 30 * 60, -- (seconds) If a profile hasn't been updated for 30 minutes, assume the session lock is dead
```

<br>

### Loading System
ProfileService queues load requests. If ``:LoadProfileAsync`` is used on the same key, it will try to return the last "load job" to ``nil``, and let the other one take over it.

If it's not loading a key already, it will add the current load job into ``profile_load_jobs``. If it already is in ``profile_load_jobs`` then it will wait.

If a function calls ``:LoadProfileAsync`` on the same key, while it's already loading it. Since it's in a separate thread, it will trigger the ``:LoadProfileAsync`` function making it check the ``profile_load_jobs`` table again.

If it finds the same key for the loading job, it waits for ``profile_load_job[2]`` to be set, from the initial loading thread that called ``StandardProfileUpdateAsyncDataStore`` with the key.

It will try to _yoink_ the load job based on ``profile_load_job ~= nil``.

<br>
Otherwise, it will process all entries inside of ``profile_load_jobs``

Loading System aborts if ``ProfileService.ServiceLocked`` gets set to ``true``, which happens on a game shutdown. The ``while loop`` will run all left tasks however, since ``break`` doesn't get invoked, but the ``while loop`` won't repeat anymore.

<br>
<br>


### ForceLoad
The default loading strategy of ProfileService.

ForceLoad is similar to ``Repeat``, except that after a certain amount of attempts defined by ``SETTINGS.ForceLoadMaxSteps``. If not interrupted, it will steal the session.

#### How it works
If ``:LoadProfileAsync`` gets called without a _not_released_handler_ argument, it will set it to ``ForceLoad``.

Then internally it sets ``request_force_load`` to ``true``.

If that's set to true, similar to ``ActiveSession``, it will create ``MetaData.ForceLoadSession`` with its own PlaceId and JobId, through ``StandardProfileUpdateAsyncDataStore``.

And that will save through the internal ``:UpdateAsync`` function, without modifying anything else.

Once it has set ``ForceLoadSession``, the next time it will try to re-check the ProfileStore. It will check whether ``ForceLoadSession`` is still the same or not. E.g. if another session is trying to force load, it would have to go through the same process, which would mean that ``ForceLoadSession`` would be different.

This would mean that the current force load is being interrupted.

If the ``ForceLoadSession`` mismatches, the current local loading task will be aborted, which likely make ``:LoadProfileAsync`` return ``nil.

In the case where it remains uninterrupted in the ``MetaData``. Once ``ForceLoad`` has reached the maximum retries defined by ``SETTINGS.ForceLoadMaxSteps``, it will steal the session, through ``steal_session``.


### Repeat
If it's set to ``Repeat``, it will actively re-retrieve the DataStore again and wait until ActiveSession was set free.

!!! notice **Note:** may or may not be recommended, as ``Repeat`` causes ``:UpdateAsync()`` to be called.


### Steal
If it's set to ``Steal``, ``aggressive_steal`` will be set to ``true``.

Steal will overwrite ``MetaData.ActiveSession = {PlaceId, JobId}`` and set ``MetaData.ForceLoadSession`` to ``nil``.


<br>
<br>

## Case: Editing Profile
If the actual Profile Data gets updated, ``MetaData.LastUpdate`` gets updated as well to current ``os.time()``. ``MetaData.SessionLoadCount`` may change as well.

If there's no Profile Data available, it will _deepcopy`` the template, and return that to ``:UpdateAsync()``.


<br>
<br>
<br>


## Conclusion
This was an overview over ProfileService's session-locking system. It should give an insight and understanding on how it works, for anyone that is looking to create their own sort of system.

In theory, you could enhance with ``MemoryStoreQueue`` or ``MessagingService`` to aid Roblox DataStores.

But putting the session-lock information directly in the table of the DataStore, is clever and easy.
