-- Blood Alter Automation

--[[
AE Pattern Example:

| <Blank Slate> * 1 |    | <Reinforced Slate> * 1 |
|                   | -> |                        |
| <BA_LP:4000>  * 1 |    | <BA_LP:4000>       * 1 |

]]

local component = require('component')
local newPlaceholder = require('placeholder')
local sides = require('sides')
local tu = require('transposerUtil')

--region SETUP
local SIDES = {
  INPUT       = sides.east,
  OUTPUT      = sides.bottom,
  BLOOD_ALTER = sides.south,
}
local ADDRESSES = {
  TRANSPOSER  = '6258',
  BLOOD_ALTER = 'a60c'
}
local PLACEHOLDER_PREFIX = 'BA_LP:'
--endregion SETUP

local transposer = component.proxy(component.get(ADDRESSES.TRANSPOSER))
local bloodAlter = component.proxy(component.get(ADDRESSES.BLOOD_ALTER))

local placeholder = newPlaceholder(PLACEHOLDER_PREFIX)

local function loop()
  if (tu.isEmpty(transposer, SIDES.INPUT)) then
    return
  end

  local bloodRequired = 0
  local inputSlot = 0
  local inputName = ''

  for slot = 1, transposer.getInventorySize(SIDES.INPUT) do
    if 0 < bloodRequired and 0 < inputSlot then
      break
    end
    local stack = transposer.getStackInSlot(SIDES.INPUT, slot)
    if (stack ~= nil) then
      if (stack.label and placeholder:match(stack.label)) then
        bloodRequired = tonumber(placeholder.removePrefix(stack.label))
      else
        inputSlot = slot
        inputName = stack.name
      end
    end
  end

  while (bloodAlter.getCurrentBlood() < bloodRequired) do
    os.sleep(1)
  end

  transposer.transferItem(SIDES.INPUT, SIDES.BLOOD_ALTER, 1, inputSlot)

  while (transposer.getStackInSlot(SIDES.BLOOD_ALTER, 1).name == inputName) do
    os.sleep(0.1)
  end

  transposer.transferItem(SIDES.BLOOD_ALTER, SIDES.OUTPUT)
  -- there should only be one placeholder in the input
  transposer.transferItem(SIDES.INPUT, SIDES.OUTPUT)
end

function start()
  while (true) do
    loop()
    os.sleep(0.5)
  end
end
