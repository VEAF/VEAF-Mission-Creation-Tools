MyClass = {}

function MyClass:new (objectToCopy)
  local objectToCreate = objectToCopy or {} -- create object if user does not provide one
  setmetatable(objectToCreate, self)
  self.__index = self
  
    -- init tables (no need to init simple values)
  objectToCreate.name = nil
  objectToCreate.content = {}

  return objectToCreate
end

function MyClass:setName(value)
  print(string.format("MyClass[]:setName([%s])", value or ""))
  self.name = value
  return self
end

function MyClass:getName()
  return self.name
end

function MyClass:addContent(value)
  print(string.format("MyClass[%s]:addContent([%s])", self.name or "", value or ""))
  table.insert(self.content, value)
  return self
end

function MyClass:getContent()
    return self.content
end

function MyClass:print()
  print(string.format("MyClass[%s]:print()", self.name or ""))
  for _, content in pairs(self:getContent()) do
    print(content)
  end
  return self
end

local myInstance1 = MyClass:new()
myInstance1:setName("instance1")
myInstance1:addContent("content1")
myInstance1:addContent("content2")

local myInstance2 = MyClass:new()
myInstance2:setName("instance2")
myInstance1:addContent("content3")

print(string.format("myInstance1:getName() = [%s]", myInstance1:getName()))
print(string.format("myInstance2:getName() = [%s]", myInstance2:getName()))

myInstance1:print()
myInstance2:print()


--[[
 Account = {
   balance = 0,
   name = nil,
   content = {}
}
    
function Account:new (objectToCopy)
  local objectToCreate = objectToCopy or {}   -- create object if user does not provide one
  setmetatable(objectToCreate, self)
  self.__index = self
  objectToCreate.content = {}
  return objectToCreate
end

function Account:withdraw (v)
  self.balance = self.balance - v
  print("["..self.name.."]-"..v.."->"..self.balance)
end

function Account:deposit (v)
  self.balance = self.balance + v
  print("["..self.name.."]+"..v.."->"..self.balance)
end

function Account:setName (v)
  self.name = v
  print("name="..self.name)
  return self
end

function Account:addContent(value)
  print(string.format("Account[%s]:addContent([%s])", self.name or "", value or ""))
  table.insert(self.content, value)
  return self
end

function Account:getContent()
    return self.content
end

function Account:print()
  print(string.format("Account[%s]:print()", self.name or ""))
  for _, content in pairs(self:getContent()) do
    print(content)
  end
  return self
end

CheckingAccount = Account:new{
  checkbookNumber = nil
}

function CheckingAccount:new (objectToCopy)
  local objectToCreate = objectToCopy or {}   -- create object if user does not provide one
  setmetatable(objectToCreate, self)
  self.__index = self
  --objectToCreate.content = {}
  return objectToCreate
end

function CheckingAccount:setCheckbookNumber (v)
  self.checkbookNumber = v
  print("checkbookNumber="..self.checkbookNumber)
  return self
end

function CheckingAccount:print()
  print(string.format("CheckingAccount[%s]:print()", self.name or ""))
  for _, content in pairs(self:getContent()) do
    print(content)
  end
  print(string.format("CheckingAccount[%s]:checkbookNumber=%s", self.name or "", self.checkbookNumber or ""))
  return self
end

a = Account:new():setName("a")
a:deposit(100.00)
a:addContent("a-content1")
a:addContent("a-content2")
a:print()

b = Account:new():setName("b")
b:print()
b:deposit(100.00)
b:withdraw(100.00)
b:addContent("b-content3")
b:print()

a:withdraw(100.00)

c = CheckingAccount:new():setName("c"):setCheckbookNumber("12345")
c:print()
c:deposit(200.00)
c:addContent("c-content4")

a:print()
b:print()
c:print()
]]