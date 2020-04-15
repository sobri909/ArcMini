# Arc Mini

1. Comment/uncomment the appropriate lines in the `Podfile` to point to public LocoKit releases instead of local.
2. Add a new plist to the project, named `Config.plist`.
3. Add these string properties to the plist, using the corresponding values from your Foursquare/Last.fm developer accounts: 
    - `FoursquareClientId`
    - `FoursquareClientSecret`
    - `LastFmAPIKey` (not used yet)

Note that the app will work without these config vars, but Foursquare place lookups will fail, so you will be unable to assign Foursquare venues to visits. 
