# nrfDFU
OSX command line application for performing an nRF51 device firmware update

This is a simple command line program I wrote based on Nordic's documentation and their 
RF Toolbox https://github.com/NordicSemiconductor/IOS-nRF-Toolbox sample app.

My goal was to better understand the nRF51 DFU process and to have a simple command 
line program I could use from build scripts to update projects of mine during development and testing.

For anyone interested in using this as a starting point for their own learning, main.c and NDDFUSampleController 
are what you would replace with your own OSX or iOS application. Those files are mostly concerned with
parsing command line arguments, selecting the BLE device to update and printing status.

The interesting code from a DFU perspective (and the code intended to be reused) is pretty much all in
NDDFUDevice and NDDFUFirmware. 

The code doesn't support SoftDevice or Bootloader updates yet, and things like app version, device ID and version
and the required SoftDevice ID are currently hardcoded.

My plan is to further clean up the code, which I expect will be mostly driven by my plan to include it in
an iOS app that I've written that talks to an nRF51 based board of mine.

Issues and especially pull requests welcome!

