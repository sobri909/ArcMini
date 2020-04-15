# Arc Mini

1. Add a new plist to the project, named `Config.plist`.
2. Add these string properties to the plist, using the corresponding values from your Foursquare/Last.fm developer accounts: 
    - `FoursquareClientId`
    - `FoursquareClientSecret`
    - `LastFmAPIKey` (not used yet)

Note that the app will work without these config vars, but Foursquare place lookups will fail, so you will be unable to assign Foursquare venues to visits. 
