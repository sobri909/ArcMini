# Arc Mini

1. `pod install`
2. Open the Xcode workspace -> the `Pods` project -> the `Upsurge` target, `Build Settings`, change the `Swift Language Version` to 4.2.
3. Add a new plist to the project, named `Config.plist`.
4. Add these string properties to the plist, using the corresponding values from your Foursquare/Last.fm developer accounts: 
    - `FoursquareClientId`
    - `FoursquareClientSecret`
    - `LastFmAPIKey` (not used yet)

Note that the app will work without the Foursquare and Last.fm config vars, but Foursquare place lookups will fail, so you will be unable to assign Foursquare venues to visits. 
