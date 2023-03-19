-- This file is an example of OOP in LUABaseObject
-- Doing OOP in LUA is not easy, and there are a lot of different techniques.
-- We've tried some of them as years passed, and ended up using the following method.
-- CAVEAT: in our code, you'll find many different techniques that have all some problems; this one is only the latest we decided to use.

---The base class that will be the basis of our objects hierarchy
BaseObject = {}
---This init method is used to fill an object table; it can be a new instance of this class, or of a derived class; it's useful to set this in a method, so it can be used by all the constructors (incl. the derived ones)
---@param object any an instance to initialize
function BaseObject.init(object)
  object.mamberNumeric = 0
  object.memberString = nil
  object.memberTable = {}
end

---The constructor of the BaseObject class
---@param objectToCopy? any an object to copy (optional, will be set to an empty table)
---@return self any an instance of the BaseObject class 
function BaseObject:new(objectToCopy)
    veaf.loggers.get(veaf.Id):debug("BaseObject:new()")
    local objectToCreate = objectToCopy or {} -- create object if user does not provide one
    setmetatable(objectToCreate, self) -- set the metatable to the BaseObject table; it'll contain the "__index" metamethod (next line)
    self.__index = self -- set the __index metamethod in the metatable; that way, any call to a missing member in the instance table will be redirected to the BaseObject table
    -- NOTA: we could have done "BaseObject.__index = BaseObject", it's the same. That way, it's easier to copy/paste to another object!

    -- init the new object by calling the init method
    BaseObject.init(objectToCreate)

    -- return the initialized instance table
    return objectToCreate
end

---Set a string into memberString
---@param value string a string
---@return self table the instance, to allow for chain calling
function BaseObject:setName(value)
    veaf.loggers.get(veaf.Id):trace(string.format("BaseObject[]:setName(%s)", veaf.p(value)))
    self.memberString = value
    return self
end

---Adds an item to memberTable
---@param value any will be added to the table
---@return self table the instance, to allow for chain calling
function BaseObject:addToTable(value)
    veaf.loggers.get(veaf.Id):trace(string.format("BaseObject[]:addToTable(%s)", veaf.p(value)))
    table.insert(self.memberTable, value)
    return self
end

function BaseObject:getName()
    return self.memberString
end

---This derived class inherits from BaseObject
DerivedObject = BaseObject:new()
---This init method is used to fill an object table; it can be a new instance of this class, or of a derived class; it's useful to set this in a method, so it can be used by all the constructors (incl. the derived ones)
---@param object any an instance to initialize
---@diagnostic disable-next-line: duplicate-set-field -- this is an overloaded method
function DerivedObject.init(object)
  -- first, call the inherited init method!
  BaseObject.init(object)
  object.value = 0
end

---@diagnostic disable-next-line: duplicate-set-field -- this is an overloaded method
function DerivedObject:new(objectToCopy)
    veaf.loggers.get(veaf.Id):debug("DerivedObject:new()")
    local objectToCreate = objectToCopy or {} -- create object if user does not provide one
    setmetatable(objectToCreate, self)
    self.__index = self

    -- init the new object
    DerivedObject.init(objectToCreate)

    return objectToCreate
end

function DerivedObject:setValue(value)
    veaf.loggers.get(veaf.Id):trace(string.format("DerivedObject[]:setValue(%s)", veaf.p(value)))
    self.value = value
    return self
end

local base_1 = BaseObject:new()
base_1:setName("base_1")
base_1:addToTable("base_1_item")
print(veaf.p(base_1:getName()))
print(veaf.p(base_1.memberTable))

local base_2 = BaseObject:new()
base_2:setName("base_2")
base_2:addToTable("base_2_item")
print(veaf.p(base_2:getName()))
print(veaf.p(base_2.memberTable))

local derived_1 = DerivedObject:new()
derived_1:setName("derived_1")
derived_1:addToTable("derived_1_item")
derived_1:setValue("derived_1_value")
print(veaf.p(derived_1:getName()))
print(veaf.p(derived_1.value))
print(veaf.p(derived_1.memberTable))

