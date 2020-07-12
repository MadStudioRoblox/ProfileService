
# Madwork - ProfileService
ProfileService.lua is a stand-alone ModuleScript that handles the loading and saving of your game's DataStore profiles (reffered to as just "profiles" later on) along with additional power user features such as:

- **Profile session ownership handling** (A case when another Roblox server is still using the profile)
- **Global updates** (An easy way of setting up a gifts among players system)
- **"MetaTags"** (A handy organizational feature for storing information about the profile itself)

*ProfileService is part of the **Madwork** framework*
*Developed by [loleris](https://twitter.com/LM_loleris)*

## API:
[ProfileService documentation](https://madstudioroblox.github.io/ProfileService/)

## Why?

The most common issues Roblox developers run into when creating their own DataStore modules are:

 - Getting confused on how to handle DataStore errors
 - Having to rewrite their DataStore code for every new project
 - Experiencing player data loss

ProfileService is the perfect solution to the regular DataStore usage when data from the DataStore is loaded once and only auto-saved (and saved after finishing work) afterwards.

ProfileService **is an abstraction** of DataStore profiles, which means that it is not tied to the `Player` instance and can be easily used for various game features like **group owned houses** where house data could not be tied to a particular player profile and the group owned house would preferably only be loaded on a single Roblox server.

ProfileService allows you to easily maintain player profiles that remain loaded even after the player leaves which can be handy for certain competitive games like MMO's (A game where you would lose your items if you get killed in combat). If you're willing to go to such lengths, at least 😛.
