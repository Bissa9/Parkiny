# Parkiny
<img width="439" height="956" alt="Screenshot 2026-11-18 at 5 38 34 AM" src="https://github.com/user-attachments/assets/46f2a07c-7851-4eb1-9141-35e4a2f6aa42" />
<img width="439" height="956" alt="Screenshot 2026-11-18 at 5 38 47 AM" src="https://github.com/user-attachments/assets/bba3d8e8-5aaa-40b5-8a3a-b635b0881fa0" />


Objective-C iOS app that remembers where you parked. It follows your location, names the city, saves the spot, and draws a driving route back to the car.

## What you can do

- Save that spot. It is still there after the app closes
- Read the distance and compass direction back to the car
- Draw a driving route, then tap **Back** to follow yourself again
- Tap the location button at the top right to center the map on you

## What it uses

- MapKit for the map, the parked-car pin, and the route
- Core Location for the current position and the city name
- UserDefaults so the parked spot survives a relaunch

Location permission text is in `Parkiny/Info.plist` (`NSLocationWhenInUseUsageDescription`). The project has no API keys and no user data.

## Run it

1. Open `Parkiny.xcodeproj` in Xcode 16 or newer.
2. Select the shared **Parkiny** scheme and run on a device or simulator.
3. Allow location access. The dock should show a city and coordinates before you tap **Save Spot**.

The bundle id is `com.ebtisamkhalid.parkiny`. Signing is automatic. Pick your team in the Signing & Capabilities tab the first time you run it.

## Where the map is

On an iPhone, the blue dot is the phone's location. Apple Maps covers Egypt, so a real fix there shows a city such as Cairo and coordinates near `30, 31`.

The iOS Simulator uses a location you choose. It does not use the Mac's location. While the app is running, open **Features → Location → Custom Location…** and enter the place you want. Cairo is latitude `30.0444`, longitude `31.2357`. Xcode can set the same point from **Debug → Simulate Location → Custom Location…**.

If the dock says **Location is off**, open Settings → Privacy & Security → Location Services → Parkiny and choose While Using the App.
