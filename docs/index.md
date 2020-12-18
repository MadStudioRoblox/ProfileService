# Home

ProfileService is a stand-alone ModuleScript that specialises in loading and auto-saving
DataStore profiles.

A DataStore `Profile` (Later referred to as just `Profile`) is a set of data which is meant to be loaded up
**only once** inside a Roblox server and then written to and read from locally on that server
(With no delays associated with talking with the DataStore every time data changes) whilst being
periodically auto-saved and saved immediately once after the server finishes working with the `Profile`.

The benefits of using ProfileService for your game's profiles are:

- **Easy to learn, and eventually forget** - ProfileService does not give you any data getter or setter functions. It gives you the freedom to write your own data interface.
- **Built for massive scalability** - low resource footprint, no excessive type checking. Great for 100+ player
servers. ProfileService automatically spreads the DataStore API calls evenly within the auto-save loop timeframe.
- **Already does the things you wouldn't dare script yourself (but should)** - session-locking is essential to keeping your data
protected from multiple server editing - this is a potential cause of item loss or item duplication loopholes. ProfileService
offers a very comprehensive and short API for handling session-locking yourself or just letting ProfileService do it automatically for you.
- **Future-proof** - with features like `MetaTags` and `GlobalUpdates`, you will always be able to add new functionality to your profiles without headaches.
- **Made for ambitious projects** - ProfileService is a **profile object abstraction** detached from the `Player` instance - this allows the developer to create profiles for entities other than players, such as: group-owned houses, savable multiplayer game instances, etc.

If anything is missing or broken, [file an issue on GitHub](https://github.com/MadStudioRoblox/ProfileService/issues).

If you need help integrating ProfileService into your project, [join the discussion](https://devforum.roblox.com/t/profileservice-a-datastore-module/667805).

> **Disclaimer**: Although ProfileService has been thoroughly tested (Auto testing source included - [ProfileTest.lua](https://github.com/MadStudioRoblox/ProfileService/blob/master/ProfileTest.server.lua)), it has not been used within a large scale Roblox project yet. ProfileService is the successor to an earlier DataStore implementation used in [The Mad Murderer 2](https://www.roblox.com/games/1026891626/The-Mad-Murderer-2)

# Why not DataStore2?

[DataStore2](https://devforum.roblox.com/t/how-to-use-datastore2-data-store-caching-and-data-loss-prevention/136317) is mostly a Roblox DataStore wrapper module which automatically saves duplicates of your data. [ProfileService](https://devforum.roblox.com/t/profileservice-a-datastore-module/667805) is an extension module which gives you powerful tools to manage profile session-locking, cross server gifting and profile data organizing.

ProfileService protects your data only from the relevant Roblox server problems. **It's completely stacked** when it comes to protecting your game data from [item duplication exploits](https://www.youtube.com/watch?v=Bz5Rje4HnM4).

ProfileService is striving to be a DataStore solution that is the most accurate implementation of data storage following the
development guidelines and practices provided in the [official Roblox API](https://developer.roblox.com/en-us/articles/Data-store).