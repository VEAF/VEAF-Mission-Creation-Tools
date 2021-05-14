#include "LuaWrapper.h"

/**
 * This object is the LUA wrapper for the BufferingSocket object.
 * It exposes the BufferingSocket object methods to the LUA script calling it.
 */

static BufferingSocket tcpSocket;
static const char* VERSION = "1.0.0";

static int getVersion(lua_State* luaState) {
    lua_pushstring(luaState, VERSION); // return VERSION to the LUA caller
    return (1); // push one value to the LUA state
}

static int startSession(lua_State* luaState) {
    // Starting the session - prepare (nothing at the moment)

    // Create the sender thread and connect to the server
    auto *host = new std::string(lua_tolstring(luaState, 1, 0));
    const int *port = new int(lua_tointeger(luaState, 2));
    tcpSocket.createConnection(host, port);

    lua_pushinteger(luaState, 1); // return "1" to the LUA caller
    return (1); // push one value to the LUA state
}

static int endSession(lua_State* luaState) {

    // Close the socket and terminate the sender thread
    tcpSocket.stop();

    return (0); // no value to return to the LUA state
}

static int send(lua_State* luaState) {

    // Add data to the buffer
    tcpSocket.enqueueForSending(new std::string(lua_tolstring(luaState, 1, 0)));

    // return 2 values :
    lua_pushinteger(luaState, tcpSocket.getFlagConnected()); // is the socket connected ?
    lua_pushinteger(luaState, tcpSocket.getAndResetReconnected()); // was there a recent reconnection to the server ?

    return (2); // push 2 values to the LUA state
}

extern "C" int __declspec(dllexport) luaopen_BufferingSocket(lua_State * L) {
    
    static const luaL_Reg Map[] = {
            {"startSession", startSession}, // Called at the begining of the session; prepares the buffer and start the sender thread
            {"endSession", endSession },  // Called at the end of the session; flushes the buffer, closes the connection and terminates the sender thread
            {"send", send},              // Add data to the buffer to be sent from the sender thread
            {"getVersion", getVersion},              // Add data to the buffer to be sent from the sender thread
            { NULL, NULL }
    };

    // Register the list of functions for lua
    luaL_register(L, "BufferingSocket", Map);       

    return 1;
}