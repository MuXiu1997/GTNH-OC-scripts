-- Blood Alter Automation

--[[
AE Pattern Example:

| <Blank Slate> * 1 |    | <Reinforced Slate> * 1 |
|                   | -> |                        |
| <BA_LP:4000>  * 1 |    | <BA_LP:4000>       * 1 |

]]

local component = require('component')
local sides = require('sides')

--region SETUP
local SIDES = {
  INPUT       = sides.top,
  OUTPUT      = sides.top,
  BLOOD_ALTER = sides.top,
}
local ADDRESSES = {
  TRANSPOSER  = '',
  BLOOD_ALTER = ''
}
local PLACEHOLDER_PREFIX = 'BA_LP:'
--endregion SETUP

local transposer = component.proxy(component.get(ADDRESSES.TRANSPOSER))
local bloodAlter = component.proxy(component.get(ADDRESSES.BLOOD_ALTER))

local placeholder = {
  prefix       = PLACEHOLDER_PREFIX,
  match        = function(self, str)
    return string.sub(str, 1, string.len(self.prefix)) == self.prefix
  end,
  removePrefix = function(self, str)
    return string.sub(str, string.len(self.prefix) + 1)
  end
}

--- @return boolean
local function isInputEmpty()
  return transposer.getSlotStackSize(SIDES.INPUT, 1) == 0
end

local function waitingForEnoughBlood(bloodRequired)
  while true do
    if bloodRequired <= bloodAlter.getCurrentBlood() then
      return
    end
  end
end

local function waitingForCompletion(toBeProcessedName)
  while true do
    if transposer.getStackInSlot(SIDES.BLOOD_ALTER, 1).name ~= toBeProcessedName then
      return
    end
  end
end

local function loop()
  if isInputEmpty() then
    return
  end

  local bloodRequired = 0
  local toBeProcessedSlot = 0
  local toBeProcessedName = ''

  local stacksIterator = transposer.getAllStack(SIDES.INPUT)
  local inputSlot = 1
  while bloodRequired == 0 or toBeProcessedSlot == 0 do
    local stack = stacksIterator()
    if (stack.label and placeholder:match(stack.label)) then
      bloodRequired = tonumber(placeholder:removePrefix(stack.label))
    else
      toBeProcessedSlot = inputSlot
      toBeProcessedName = stack.name
    end
    inputSlot = inputSlot + 1
  end

  waitingForEnoughBlood(bloodRequired)

  -- transfer to blood alter
  -- a placeholder is left to block me interface
  transposer.transferItem(SIDES.INPUT, SIDES.BLOOD_ALTER, 1, toBeProcessedSlot)

  waitingForCompletion(toBeProcessedName)

  transposer.transferItem(SIDES.BLOOD_ALTER, SIDES.OUTPUT)

  -- there should only be one placeholder in the input
  -- unblock me interface
  transposer.transferItem(SIDES.INPUT, SIDES.OUTPUT)
end

function start()
  while (true) do
    loop()
    os.sleep(0.5)
  end
end
