## Problems in Roblox studio testing

ProfileService data saves will not persist between your Roblox studio testing sessions. In testing mode ProfileService will store and load all your profiles to and from a mock-up "DataStore" table which will disappear after you finish your testing session. The only way to know if your data saving works is through playing your game online on the Roblox servers.