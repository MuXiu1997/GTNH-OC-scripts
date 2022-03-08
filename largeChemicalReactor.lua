-- Large Chemical Reactor Automation

local component = require('component')
local sides = require('sides')
local thread = require('thread')

--region SETUP
local SIDES = {
  INPUT      = sides.top,
  OUTPUT_I   = sides.top,
  OUTPUT_O   = sides.top,
  BUFFER_I   = sides.top,
  BUFFER_O   = sides.top,
  LCR_INPUT  = sides.top,
  LCR_OUTPUT = sides.top,
  TANK_I     = sides.top,
  TANK_O     = sides.top,
}
local ADDRESSES = {
  INPUT_TRANSPOSER  = '',
  OUTPUT_TRANSPOSER = '',
}
local PLACEHOLDER_PREFIX = 'LCR:'
--endregion SETUP

local inputTransposer = component.proxy(component.get(ADDRESSES.INPUT_TRANSPOSER))
local outputTransposer = component.proxy(component.get(ADDRESSES.OUTPUT_TRANSPOSER))

local placeholder = {
  prefix       = PLACEHOLDER_PREFIX,
  match        = function(self, str)
    return string.sub(str, 1, string.len(self.prefix)) == self.prefix
  end,
  removePrefix = function(self, str)
    return string.sub(str, string.len(self.prefix) + 1)
  end
}

local function isInputEmpty()
  return transposer.getSlotStackSize(SIDES.INPUT, 1) == 0
end

local function tableSize(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end

local function isEmptyVolumetricFlask(stack)
  return stack.name == 'gregtech:gt.Volumetric_Flask' and stack.amount == 0
end

local function isNonEmptyVolumetricFlask(stack)
  return stack.name == 'gregtech:gt.Volumetric_Flask' and stack.amount > 0
end

local function waitingForCompletion()
  while true do
    if outputTransposer.getTankLevel(SIDES.TANK_O, 1) > 0 or outputTransposer.getSlotStackSize(SIDES.LCR_OUTPUT, 1) > 0 then
      return
    end
  end
end

local function loop()
  if isInputEmpty() then
    return
  end

  local fluidOutputSolution = {}
  local inputSlot = 1
  for stack in transposer.getAllStack(SIDES.INPUT) do
    if isNonEmptyVolumetricFlask(stack) then
      while true do
        if inputTransposer.transferItem(SIDES.INPUT, SIDES.TANK_I, 64, inputSlot) == 0 then
          break
        end
      end
    elseif isEmptyVolumetricFlask(stack) then
      inputTransposer.transferItem(SIDES.INPUT, SIDES.BUFFER_I, 64, inputSlot)
    elseif stack.label and placeholder:match(stack.label) then
      local patternId = placeholder:removePrefix(stack.label)
      fluidOutputSolution = dofile(patternId)
    else
      inputTransposer.transferItem(SIDES.INPUT, SIDES.LCR_INPUT, 64, inputSlot)
    end
    inputSlot = inputSlot + 1
  end

  local volumetricFlaskMap = {}
  local bufferSlot = 1
  for stack in transposer.getAllStack(SIDES.BUFFER_I) do
    if stack.capacity then
      volumetricFlaskMap[stack.capacity] = slot
    end
    bufferSlot = bufferSlot + 1
  end

  waitingForCompletion()

  local emptyingTank = thread.create(function()
    while tableSize(fluidOutputSolution) > 0 do
      local fluidName = ''
      while true do
        local fluid = outputTransposer.getFluidInTank(SIDES.TANK_O, 1)
        if fluid.amount > 0 then
          fluidName = fluid.name
          break
        end
      end

      local solution = fluidOutputSolution[fluidName]

      local remainingAmount = 0
      for capacity, size in pairs(solution) do
        remainingAmount = remainingAmount + (capacity * size)
      end

      for capacity, size in pairs(solution) do
        for _ = 1, size do
          while true do
            if remainingAmount > capacity and outputTransposer.getTankLevel(SIDES.TANK_O, 1) > capacity then
              break
            end
            if remainingAmount == capacity and outputTransposer.getTankLevel(SIDES.TANK_O, 1) == capacity then
              break
            end
          end
          while true do
            if outputTransposer.transferItem(SIDES.BUFFER_O, SIDES.TANK_O, 1, volumetricFlaskMap[capacity]) == 1 then
              break
            end
          end
          remainingAmount = remainingAmount - capacity
        end
      end
      fluidOutputSolution[fluidName] = nil
    end
  end)

  local emptyingLcrOutput = thread.create(function()
    while true do
      if outputTransposer.transferItem(SIDES.LCR_OUTPUT, SIDES.OUTPUT_O) == 0 then
        return
      end
    end
  end)
  local emptyingLcrInput = thread.create(function()
    while true do
      if inputTransposer.transferItem(SIDES.LCR_INPUT, SIDES.OUTPUT_I) == 0 then
        return
      end
    end
  end)

  thread.waitForAll({ emptyingTank, emptyingLcrOutput, emptyingLcrInput })
  inputTransposer.transferItem(SIDES.INPUT, SIDES.OUTPUT_I)
end

function start()
  while (true) do
    loop()
    os.sleep(0.5)
  end
end
