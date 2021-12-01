# FreedomTx Lua Dashboard (for TBS Crossfire)

a simple Dashboard i made for my own use for the TBS Mambo Radio
(also works on other OpenTX / Edge TX Radios from other manufacturers)

let me know if you want me to add somethings

Credit: Recycled some code from Andrew Farley

ToDo:
- use global values (not re-fetching values)
- better number format
- get rid of multiple default definitions
- not show anything if values are zero
- auto center Flight mode (FM)
- hide all GPS information if no GPS connected
- mini battery and Battery Icon Broken

Changelog:
- auto reset key values with new battery [checkForNewBattery()]
- showtopspeed
- show power usage
- add GPS data (altitude, sat count, speed)
- add mAh used (current Draw as small number)
- use LQ instead of RSSI
- auto align lables (like Volts and amps)
- Removed the Quad animation (just a waste of space)
