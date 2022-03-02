-- Alchemic Chemistry Set Automation

local sides = require('sides')
local component = require('component')

--region SETUP
local SIDES = {
  INPUT       = sides.east,
  OUTPUT      = sides.bottom,
  PLACEHOLDER = sides.top,
  -- alchemic chemistry set
  ACS         = sides.south,
}
local ADDRESSES = {
  TRANSPOSER = 'ea52'
}
local PLACEHOLDER_LABEL = 'placeholder'
--endregion SETUP

local transposer = component.proxy(component.get(ADDRESSES.TRANSPOSER))

local function is_input_empty()
  for slot = 1, transposer.getInventorySize(SIDES.INPUT) do
    if transposer.getSlotStackSize(SIDES.INPUT, slot) > 0 then
      return false
    end
  end
  return true
end

local function loop()
  if (is_input_empty()) then
    return
  end

  -- block me interface
  transposer.transferItem(SIDES.PLACEHOLDER, SIDES.INPUT)

  local ACS_slot = 2
  for slot = 1, transposer.getInventorySize(SIDES.INPUT) do
    local stack = transposer.getStackInSlot(SIDES.INPUT, slot)
    if (stack ~= nil and stack.label ~= PLACEHOLDER_LABEL) then
      for _ = 1, stack.size do
        transposer.transferItem(SIDES.INPUT, SIDES.ACS, 1, slot, ACS_slot)
        ACS_slot = ACS_slot + 1
      end
    end
  end

  while (transposer.getStackInSlot(SIDES.ACS, 7) == nil) do
    os.sleep(0.1)
  end

  transposer.transferItem(SIDES.ACS, SIDES.OUTPUT, transposer.getSlotStackSize(SIDES.ACS, 7), 7)
  -- there should only be one placeholder in the input
  transposer.transferItem(SIDES.INPUT, SIDES.PLACEHOLDER)
end

local function main()
  while (true) do
    loop()
    os.sleep(0.5)
  end
end

main()
