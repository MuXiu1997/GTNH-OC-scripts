-- Alchemic Chemistry Set Automation

local component = require('component')
local sides = require('sides')

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

--- @return boolean
local function isInputEmpty()
  return transposer.getSlotStackSize(SIDES.INPUT, 1) == 0
end

local function transferToACS()
  local stacksIterator = transposer.getAllStack(SIDES.INPUT)
  local inputSlot = 1
  local acsSlot = 2
  while true do
    local stack = stacksIterator()
    if (stack.label == PLACEHOLDER_LABEL) then
      return
    end
    for _ = 1, stack.size do
      transposer.transferItem(SIDES.INPUT, SIDES.ACS, 1, inputSlot, acsSlot)
      acsSlot = acsSlot + 1
    end
    inputSlot = inputSlot + 1
  end
end

local function waitingForCompletion()
  while true do
    if 0 < transposer.getSlotStackSize(SIDES.ACS, 7) then
      return
    end
  end
end

local function loop()
  if (isInputEmpty()) then
    return
  end

  -- block me interface
  transposer.transferItem(SIDES.PLACEHOLDER, SIDES.INPUT)

  transferToACS()

  waitingForCompletion()

  transposer.transferItem(SIDES.ACS, SIDES.OUTPUT, 64, 7)
  -- there should only be one placeholder in the input
  -- unblock me interface
  transposer.transferItem(SIDES.INPUT, SIDES.PLACEHOLDER)
end

function start()
  while (true) do
    loop()
    os.sleep(0.5)
  end
end
