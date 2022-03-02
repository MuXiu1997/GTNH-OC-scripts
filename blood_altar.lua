-- Blood Alter Automation

--[[
AE Pattern Example:

| <Blank Slate> * 1 |    | <Reinforced Slate> * 1 |
|                   | -> |                        |
| <BA_LP:4000>  * 1 |    | <BA_LP:4000>       * 1 |

]]

local sides = require('sides')
local component = require('component')

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
local blood_alter = component.proxy(component.get(ADDRESSES.BLOOD_ALTER))

local function is_input_empty()
  for slot = 1, transposer.getInventorySize(SIDES.INPUT) do
    if transposer.getSlotStackSize(SIDES.INPUT, slot) > 0 then
      return false
    end
  end
  return true
end

local function start_with(str, prefix)
  return string.sub(str, 1, string.len(prefix)) == prefix
end

local function remove_prefix(str, prefix)
  return string.sub(str, string.len(prefix) + 1)
end

local function loop()
  if (is_input_empty()) then
    return
  end

  local blood_required = 0
  local input_slot = 0
  local input_name = ''

  for slot = 1, transposer.getInventorySize(SIDES.INPUT) do
    local stack = transposer.getStackInSlot(SIDES.INPUT, slot)
    if (stack ~= nil) then
      if (stack.label and start_with(stack.label, PLACEHOLDER_PREFIX)) then
        blood_required = tonumber(remove_prefix(stack.label, PLACEHOLDER_PREFIX))
      else
        input_slot = slot
        input_name = stack.name
      end
    end
  end

  while (blood_alter.getCurrentBlood() < blood_required) do
    os.sleep(1)
  end

  transposer.transferItem(SIDES.INPUT, SIDES.BLOOD_ALTER, 1, input_slot)

  while (transposer.getStackInSlot(SIDES.BLOOD_ALTER, 1).name == input_name) do
    os.sleep(0.1)
  end

  transposer.transferItem(SIDES.BLOOD_ALTER, SIDES.OUTPUT)
  transposer.transferItem(SIDES.INPUT, SIDES.OUTPUT)
end

local function main()
  while (true) do
    loop()
    os.sleep(0.5)
  end
end

main()
