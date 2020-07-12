# Home

ProfileService is a stand-alone ModuleScript that particularly specialises in loading and auto-saving
DataStore profiles as well as providing easy tools for managing session-locking of those profiles.

Essentially, I'm providing you a ModuleScript that loads up a regular Lua table you can write to directly.
It handles auto-saving, multiple server session-locking collisions, server shutdowns and crashes for you.

If anything is missing or broken, [file an issue on GitHub](https://github.com/MadStudioRoblox/ProfileService/issues).

If you need help integrating ProfileService into your project, [join the discussion](https://devforum.roblox.com/t/profileservice-a-datastore-module/667805).

> **Disclaimer**: Although ProfileService has been thoroughly tested (Auto testing source included - [ProfileTest.lua](https://github.com/MadStudioRoblox/ProfileService/blob/master/ProfileTest.lua)), it has not been used within a large scale Roblox project yet. ProfileService is the successor to an earlier DataStore implementation used in [The Mad Murderer 2](https://www.roblox.com/games/1026891626/The-Mad-Murderer-2)

# Why not DataStore2?

The ideology of [DataStore2](https://devforum.roblox.com/t/how-to-use-datastore2-data-store-caching-and-data-loss-prevention/136317) (Berezaa method) is to _"Make your game playable no matter what, no matter the cost"_.
If you're familiar with what you're doing, then it _might_ be a viable solution. However, it might not be productive to glorify
a module for it's reliability when there have been no other open source solutions for preventing data loss and item duplication problems.

ProfileService is striving to be a DataStore solution that is the most accurate implementation of data storage following the
development guidelines and practices provided in the [official Roblox API](https://developer.roblox.com/en-us/articles/Data-store).
It's also lightweight, featuring only the most essential functionalities for your personal implementation and guiding you away from
flawed practices.

Lets not forget that a fair slice of data protection responsibility falls on the shoulders of the developer as well - data loss is possible
no matter the module you choose to use. Test your systems!