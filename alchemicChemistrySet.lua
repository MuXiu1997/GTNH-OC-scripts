-- Alchemic Chemistry Set Automation

local component = require('component')
local sides = require('sides')
local tu = require('transposerUtil')

--region SETUP
local SIDES = {
  INPUT       = sides.top,
  OUTPUT      = sides.top,
  PLACEHOLDER = sides.top,
  -- alchemic chemistry set
  ACS         = sides.top,
}
local ADDRESSES = {
  TRANSPOSER = ''
}
local PLACEHOLDER_LABEL = 'placeholder'
--endregion SETUP

local transposer = component.proxy(component.get(ADDRESSES.TRANSPOSER))

local function loop()
  if (tu.isEmpty(transposer, SIDES.INPUT)) then
    return
  end

  -- block me interface
  transposer.transferItem(SIDES.PLACEHOLDER, SIDES.INPUT)

  local acsSlot = 2
  for slot = 1, transposer.getInventorySize(SIDES.INPUT) do
    local stack = transposer.getStackInSlot(SIDES.INPUT, slot)
    if (stack ~= nil and stack.label ~= PLACEHOLDER_LABEL) then
      for _ = 1, stack.size do
        transposer.transferItem(SIDES.INPUT, SIDES.ACS, 1, slot, acsSlot)
        acsSlot = acsSlot + 1
      end
    end
  end

  -- waiting for completion
  while (transposer.getSlotStackSize(SIDES.ACS, 7) == 0) do
    os.sleep(0.1)
  end

  tu.transferSlotStack(SIDES.ACS, SIDES.OUTPUT, 7)
  -- there should only be one placeholder in the input
  transposer.transferItem(SIDES.INPUT, SIDES.PLACEHOLDER)
end

function start()
  while (true) do
    loop()
    os.sleep(0.5)
  end
end
