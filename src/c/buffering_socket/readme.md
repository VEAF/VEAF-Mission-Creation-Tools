# Buffering socket

## What is it ?

This object is a buffered socket.
It will accept data, store it in a queue, and send it to a server via a tcp socket, from a separate thread, when able.
We call it from a DCS hook, using a lua wrapper (LuaWrapper) to avoid blocking the main game thread.
This code comes from [Perun](https://github.com/szporwolik/perun) with some modifications.

## How to build it ?

Use CMake (and optionaly Visual Studio Code).

Here's a tutorial explaining how to set everything up (taken from [here](https://computingonplains.wordpress.com/building-c-applications-with-cmake-and-visual-studio-code/)) :

- install Visual Studio Code from [here](https://code.visualstudio.com)
- install the Visual Studio Build Tools from [here](https://visualstudio.microsoft.com/downloads/) ; go to the "All Downloads" section, get "Tools for Visual Studio 2019" and install them (do not install Visual Studio, we already got Code)
- run Visual Studio Code, and open this folder ; follow the prompts and select the "Tools for Visual Studio 2019" kit

## How do I use it ?

Put the `buffering_socket.dll` file in the LUA path.
If needed, modify the package path from the script, to point to the library :

```lua
package.cpath = package.cpath..';'.. lfs.writedir()..'/Mods/services/buffering_socket/bin/' ..'?.dll;'
```

From a LUA script, require the library :

```lua
BufferingSocket.DLL = require('buffering_socket') 
```

Then call the exposed methods :

- `StartSession`
- `EndSession`
- `Send`
- `Connect`

See an example in our server hook [here](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/master/src/scripts/Hooks/VEAF-Server-hook.lua)