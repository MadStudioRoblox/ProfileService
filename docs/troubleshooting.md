## Problems in Roblox studio testing

ProfileService data saves will not persist between your Roblox studio testing sessions. In testing mode ProfileService will store and load all your profiles to and from a mock-up "DataStore" table which will disappear after you finish your testing session. The only way to know if your data saving works is through playing your game online on the Roblox servers.

## Saving data which Roblox cannot serialize

I've made the decision to opt-out `Profile.Data` and `Profile.MetaData.MetaTags` automatic checking
for unserializable data types for efficiency reasons. Consequently, you must be aware of what you
**MUST AVOID** writing inside `Profile.Data` or `Profile.MetaData.MetaTags`, directly and inside any nested tables:

- `NaN` values - you can check if a number is `NaN` by comparing it with itself - `print(NaN == NaN) --> false` (Not a number; Result of division by zero and other edge cases of math libraries).
- Table keys that are neither strings nor numbers (e.g., `Profile.Data[game.Workspace] = true`).
- Mixing string keys with number keys within the same table (e.g., `Profile.Data = {Coins = 100, [5] = "yes"}`).
- Storing tables with non-sequential indexes (e.g., `Profile.Data = {[1] = "Apple", [2] = "Banana", [3546] = "Peanut"}`).
- Storing cyclic tables (e.g., `Profile.Data = {Self = Profile.Data}`).
- Storing any `userdata` including `Instance`, `Vector3`, `CFrame`, `Udim2`, etc. Check whether your value is a `userdata` by running `print(type(value) == "userdata")` (e.g., `Profile.Data = {LastPosition = Vector3.new(0, 0, 0)}`) - You will have to manually convert your `userdata` to tables, numbers and strings for storage (e.g., `Profile.Data = {LastPosition = {0, 0, 0} }`).

This a limitation of the [DataStore API](https://developer.roblox.com/en-us/articles/Datastore-Errors), not ProfileService.