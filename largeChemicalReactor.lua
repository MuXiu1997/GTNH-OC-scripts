-- Large Chemical Reactor Automation

local component = require('component')
local newPlaceholder = require('placeholder')
local sides = require('sides')
local tu = require('transposerUtil')
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

local placeholder = newPlaceholder(PLACEHOLDER_PREFIX)

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

local function loop()
  if (tu.isEmpty(inputTransposer, SIDES.INPUT)) then
    return
  end

  local fluidOutputSolution = {}
  for slot = 1, inputTransposer.getInventorySize(SIDES.INPUT) do
    local stack = inputTransposer.getStackInSlot(SIDES.INPUT, slot)
    if stack == nil then
      break
    end
    if isNonEmptyVolumetricFlask(stack) then
      thread.create(tu.waitTransferSlotStack, inputTransposer, SIDES.INPUT, SIDES.TANK_I, slot)
    elseif isEmptyVolumetricFlask(stack) then
      tu.transferSlotStack(inputTransposer, SIDES.INPUT, SIDES.BUFFER_I, slot)
    elseif stack.label ~= nil and placeholder:match(stack.label) then
      local patternId = placeholder:removePrefix(stack.label)
      fluidOutputSolution = dofile(patternId)
    else
      tu.transferSlotStack(inputTransposer, SIDES.INPUT, SIDES.LCR_INPUT, slot)
    end
  end

  local volumetricFlaskMap = {}
  for slot = 1, outputTransposer.getInventorySize(SIDES.BUFFER_O) do
    local stack = outputTransposer.getStackInSlot(SIDES.BUFFER_O, slot)
    if stack == nil then
      break
    end
    volumetricFlaskMap[stack.capacity] = slot
  end

  while true do
    if outputTransposer.getTankLevel(SIDES.TANK_O, 1) > 0 or outputTransposer.getSlotStackSize(SIDES.LCR_OUTPUT, 1) > 0 then
      break
    end
  end

  local emptyingTank = thread.create(
    function()
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
              if outputTransposer.transferItem(SIDES.BUFFER_O, SIDES.TANK_O, 1, volumetricFlaskMap[capacity]) == 1 then break end
            end
            remainingAmount = remainingAmount - capacity
          end
        end
        fluidOutputSolution[fluidName] = nil
      end
    end
  )
  local emptyingLcrOutput = thread.create(tu.transferAllSlotStacks, outputTransposer, SIDES.LCR_OUTPUT, SIDES.OUTPUT_O)
  local emptyingLcrInput = thread.create(tu.transferAllSlotStacks, inputTransposer, SIDES.LCR_INPUT, SIDES.OUTPUT_I)

  thread.waitForAll({ emptyingTank, emptyingLcrOutput, emptyingLcrInput })
  inputTransposer.transferItem(SIDES.INPUT, SIDES.OUTPUT_I)
end

function start()
  while (true) do
    loop()
    os.sleep(0.5)
  end
end
