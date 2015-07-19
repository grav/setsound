# setsound
Set sound device in Ableton Live programmatically

I got tired of selecting input and output device in Ableton Live prefs, whenever I connected my external audio device to my computer, so I hacked this Mac app together.

setsound detects when Live is running and the audio device is connected and asks you if it should select the device in the preferences.

Since there's no API for selecting the audio device in Live, it's hacked together using AppleScript for moving the mouse and doing funky keystrokes, so it's quite brittle. But it does save me from some repetitive mouse and keyboard action :-)

