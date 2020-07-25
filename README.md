# Madwork - ProfileService

ProfileService is a stand-alone ModuleScript that specialises in loading and auto-saving
DataStore profiles.

A DataStore `Profile` (Later referred to as just `Profile`) is a set of data which is meant to be loaded up
**only once** inside a Roblox server and then written to and read from locally on that server
(With no delays associated with talking with the DataStore every time data changes) whilst being
periodically auto-saved and saved immediately once after the server finishes working with the `Profile`.

The benefits of using ProfileService for your game's profiles are:

- **Easy to learn, and eventually forget** - ProfileService does not give you any data getter or setter functions. It gives you the freedom to write your own data interface.

- **Built for massive scalability** - low resource footprint, no excessive type checking. Great for 100+ player servers. ProfileService automatically spreads the DataStore API calls evenly within the auto-save loop timeframe.

- **Already does the things you wouldn't dare script yourself (but should)** - session-locking is essential to keeping your data protected from multiple server editing - this is a potential cause of item loss or item duplication loopholes. ProfileService offers a very comprehensive and short API for handling session-locking yourself or just letting ProfileService do it automatically for you.

- **Future-proof** - with features like `MetaTags` and `GlobalUpdates`, you will always be able to add new functionality to your profiles without headaches.

- **Made for ambitious projects** - ProfileService is a **profile object abstraction** detached from the `Player` instance - this allows the developer to create profiles for entities other than players, such as: group-owned houses, savable multiplayer game instances, etc.

---
*ProfileService is part of the **Madwork** framework*
*Developed by [loleris](https://twitter.com/LM_loleris)*

***It's documented:***
**[ProfileService wiki](https://madstudioroblox.github.io/ProfileService/)**

***It's open source:***
[Roblox library](https://www.roblox.com/library/5331689994/ProfileService)

**Watch while you eat pizza on the couch - YouTube tutorials:**  
**[ProfileService tutorial playlist](https://www.youtube.com/playlist?list=PLUUm0OvGDjJ8_e8co48ngMJC4XwCaUIIH)** by @okeanskiy  
**[Session-locking explained and savable leaderstats](https://youtu.be/P5NuM0gPmew)** by @EncodedLua  
(Will add new tutorials as they come)
