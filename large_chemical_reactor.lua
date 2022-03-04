-- Large Chemical Reactor Automation

local component = require('component')
local sides = require('sides')

--region SETUP
local SIDES = {
  INPUT      = sides.top,
  OUTPUT_I   = sides.bottom,
  OUTPUT_O   = sides.bottom,
  BUFFER_I   = sides.east,
  BUFFER_O   = sides.west,
  LCR_INPUT  = sides.north,
  LCR_OUTPUT = sides.north,
  TANK_I     = sides.south,
  TANK_O     = sides.south,
}
local ADDRESSES = {
  INPUT_TRANSPOSER  = '6258',
  OUTPUT_TRANSPOSER = '6259',
}
local PLACEHOLDER_PREFIX = 'LCR:'
--endregion SETUP

local input_transposer = component.proxy(component.get(ADDRESSES.INPUT_TRANSPOSER))
local output_transposer = component.proxy(component.get(ADDRESSES.OUTPUT_TRANSPOSER))

local function is_input_empty()
  for slot = 1, input_transposer.getInventorySize(SIDES.INPUT) do
    if input_transposer.getSlotStackSize(SIDES.INPUT, slot) > 0 then
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

local function table_size(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end

local function loop()
  if (is_input_empty()) then
    return
  end

  local fluid_output_solution = {}
  for slot = 1, input_transposer.getInventorySize(SIDES.INPUT) do
    local stack = input_transposer.getStackInSlot(SIDES.INPUT, slot)
    if stack ~= nil then
      if stack.name == 'gregtech:gt.Volumetric_Flask' and stack.amount > 0 then
        while input_transposer.getSlotStackSize(SIDES.INPUT, slot) > 0 do
          input_transposer.transferItem(SIDES.INPUT, SIDES.TANK_I, input_transposer.getSlotStackSize(SIDES.INPUT, slot), slot)
        end
      elseif stack.name == 'gregtech:gt.Volumetric_Flask' and stack.amount == 0 then
        input_transposer.transferItem(SIDES.INPUT, SIDES.BUFFER_I, input_transposer.getSlotStackSize(SIDES.INPUT, slot), slot)
      elseif start_with(stack.label, PLACEHOLDER_PREFIX) then
        local pattern_number = remove_prefix(stack.label, PLACEHOLDER_PREFIX)
        fluid_output_solution = require(pattern_number)()
      else
        input_transposer.transferItem(SIDES.INPUT, SIDES.LCR_INPUT, input_transposer.getSlotStackSize(SIDES.INPUT, slot), slot)
      end
    end
  end

  while true do
    if output_transposer.getTankLevel(SIDES.TANK_O, 1) > 0 or output_transposer.getSlotStackSize(SIDES.LCR_OUTPUT, 1) > 0 then
      break
    end
  end

  for slot = 1, output_transposer.getInventorySize(SIDES.LCR_OUTPUT) do
    if output_transposer.getSlotStackSize(SIDES.LCR_OUTPUT, slot) > 0 then
      output_transposer.transferItem(SIDES.LCR_OUTPUT, SIDES.OUTPUT_O, output_transposer.getSlotStackSize(SIDES.LCR_OUTPUT, slot), slot)
    end
  end

  for slot = 1, output_transposer.getInventorySize(SIDES.LCR_INPUT) do
    if output_transposer.getSlotStackSize(SIDES.LCR_INPUT, slot) > 0 then
      output_transposer.transferItem(SIDES.LCR_INPUT, SIDES.OUTPUT_O, output_transposer.getSlotStackSize(SIDES.LCR_INPUT, slot), slot)
    end
  end

  while table_size(fluid_output_solution) > 0 do
    local fluid_name = ''
    while true do
      local fluid = output_transposer.getFluidInTank(SIDES.TANK_O, 1)
      if fluid.amount > 0 then
        fluid_name = fluid.name
        break
      end
    end

    local solution = fluid_output_solution[fluid_name]

    local remaining_amount = 0
    for capacity, size in pairs(solution) do
      remaining_amount = remaining_amount + (capacity * size)
    end

    for capacity, size in pairs(solution) do
      for _ = 1, size do
        while true do
          if remaining_amount > capacity and output_transposer.getTankLevel(SIDES.TANK_O, 1) > capacity then
            break
          end
          if remaining_amount == capacity and output_transposer.getTankLevel(SIDES.TANK_O, 1) == capacity then
            break
          end
        end
        for slot = 1, output_transposer.getInventorySize(SIDES.BUFFER_O) do
          local stack = output_transposer.getStackInSlot(SIDES.BUFFER_O, slot)
          if stack ~= nil and stack.capacity == capacity then
            while true do
              if output_transposer.transferItem(SIDES.BUFFER_O, SIDES.TANK_O, slot, 1) == 1 then break end
            end
            while true do
              if output_transposer.transferItem(SIDES.TANK_O, SIDES.OUTPUT_I) == 1 then break end
            end
            remaining_amount = remaining_amount - capacity
            break
          end
        end
      end
    end
    fluid_output_solution[fluid_name] = nil
  end

  input_transposer.transferItem(SIDES.INPUT, SIDES.OUTPUT_I)
end

local function main()
  while (true) do
    loop()
    os.sleep(0.5)
  end
end

main()
