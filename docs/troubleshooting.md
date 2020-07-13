## Problems in Roblox studio testing

ProfileService data saves will not persist between your Roblox studio testing sessions. In testing mode ProfileService will store and load all your profiles to and from a mock-up "DataStore" table which will disappear after you finish your testing session. The only way to know if your data saving works is through playing your game online on the Roblox servers.

## Saving data which Roblox cannot serialize

I've made the decision to opt-out `Profile.Data` and `Profile.MetaData.MetaTags` automatic checking
for unserializable data types for efficiency reasons. Consequently, you must be aware of what you
**MUST AVOID** writing inside `Profile.Data` or `Profile.MetaData.MetaTags`, directly and inside any nested tables:

- `NaN` values - you can check if a number is `NaN` by comparing it with itself - `print(NaN == NaN) --> false` (e.g., `Profile.Data = {Experience = 0/0}`). `NaN` values are a result of division by zero and edge cases of some math operations (`math.acos(2)` is `-NaN`).
- Table keys that are neither strings nor numbers (e.g., `Profile.Data[game.Workspace] = true`).
- Mixing string keys with number keys within the same table (e.g., `Profile.Data = {Coins = 100, [5] = "yes"}`).
- Storing tables with non-sequential indexes (e.g., `Profile.Data = {[1] = "Apple", [2] = "Banana", [3546] = "Peanut"}`). If you really have to store non-sequential numbers as indexes, you will have to turn those numbers into `string` indexes: `Profile.Data.Friends[tostring(user_id)] = {GoodFriend = true}`.
- Storing cyclic tables (e.g., `Profile.Data = {Self = Profile.Data}`).
- Storing any `userdata` including `Instance`, `Vector3`, `CFrame`, `Udim2`, etc. Check whether your value is a `userdata` by running `print(type(value) == "userdata")` (e.g., `Profile.Data = {LastPosition = Vector3.new(0, 0, 0)}`) - For storage, you will have to manually convert your `userdata` to tables, numbers and strings for storage (e.g., `Profile.Data = {LastPosition = {position.X, position.Y, position.Z} }`).

This is a limitation of the [DataStore API](https://developer.roblox.com/en-us/articles/Datastore-Errors) which ProfileService is based on.

!!! warning
    Failure to prevent these data types may result in silent data loss, silent errors, lots of fatal errors and general failure to save data.

