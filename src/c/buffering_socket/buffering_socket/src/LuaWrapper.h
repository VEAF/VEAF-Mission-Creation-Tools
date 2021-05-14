#ifndef LUA_WRAPPER_H
#define LUA_WRAPPER_H

extern "C" {
	#include "lua.h"          
	#include "lualib.h"
	#include "lauxlib.h"
}

#include <string>
#include <iostream>
#include <fstream>
#include <chrono>
#include <queue>
#include "BufferingSocket.h"

#endif //LUA_WRAPPER_H