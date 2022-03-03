-- Nuclear Reactor

local sides = require('sides')
local component = require('component')


--region SETUP
local SIDES = {
  INPUT                    = sides.east,
  OUTPUT                   = sides.bottom,
  NUCLEAR_REACTOR          = sides.south,
  NUCLEAR_REACTOR_REDSTONE = sides.south,
}
local ADDRESSES = {
  TRANSPOSER = '6258',
  REDSTONE   = 'a60c'
}
-- coolant cell
local C = {
  name = 'gregtech:gt.360k_NaK_Coolantcell'
}
-- fuel rod
local F = {
  name = 'gregtech:gt.reactorMOXQuad'
}
-- empty
local E = {}
local LAYOUT = {
  C, F, F, C, E, E, E, E, E,
  C, F, F, C, E, E, E, E, E,
  C, F, F, C, E, E, E, E, E,
  C, F, F, C, E, E, E, E, E,
  C, F, F, C, E, E, E, E, E,
  C, F, F, C, E, E, E, E, E,
}
--endregion SETUP

local transposer = component.proxy(component.get(ADDRESSES.TRANSPOSER))
local redstone = component.proxy(component.get(ADDRESSES.REDSTONE))

function find_input(what)
  for slot = 1, transposer.getInventorySize(SIDES.INPUT) do
    local stack = transposer.getStackInSlot(SIDES.INPUT, slot)
    if stack ~= nil and stack.name == what.name then
      return slot
    end
  end
  return -1
end

local reactor = {
  started = false,
}

function reactor:initialization_check()
  if transposer.getInventorySize(SIDES.NUCLEAR_REACTOR) ~= #LAYOUT then
    return false
  end
  for slot, preset in pairs(LAYOUT) do
    local stack = transposer.getStackInSlot(SIDES.NUCLEAR_REACTOR, slot)
    if preset == E and stack ~= nil then
      return false
    end
    if preset ~= E then
      if stack == nil then
        return false
      end
      if stack.name ~= preset.name then
        return false
      end
    end
  end
  return true
end

function reactor:start()
  if not self.started then
    redstone.setOutput(SIDES.NUCLEAR_REACTOR_REDSTONE, 15)
    self.started = true
  end
end

function reactor:stop()
  if self.started then
    redstone.setOutput(SIDES.NUCLEAR_REACTOR_REDSTONE, 0)
    os.sleep(1)
    self.started = false
  end
end

function reactor:filter(func --[[ function(slot: number): boolean ]])
  local result = {}
  for slot = 1, transposer.getInventorySize(SIDES.NUCLEAR_REACTOR) do
    if func(slot) then
      result[#result + 1] = slot
    end
  end
  return result
end

function reactor:discharge(slots)
  for _, slot in ipairs(slots) do
    while transposer.getSlotStackSize(SIDES.NUCLEAR_REACTOR, slot) ~= 0 do
      transposer.transferItem(SIDES.NUCLEAR_REACTOR, SIDES.OUTPUT, 1, slot)
      os.sleep(1)
    end
  end
end

function reactor:load(slots, what)
  while #slots > 0 do
    local input_slot = find_input(what)
    if input_slot ~= -1 then
      transposer.transferItem(SIDES.INPUT, SIDES.NUCLEAR_REACTOR, 1, input_slot, slots[1])
      table.remove(slots, 1)
    else
      os.sleep(1)
    end
  end
end

function reactor:ensure_coolant_cells()
  local damaged_coolant_cells = self:filter(
    function(slot)
      if LAYOUT[slot] ~= C then
        return false
      end
      local stack = transposer.getStackInSlot(SIDES.NUCLEAR_REACTOR, slot)
      if stack.maxDamage - 1 <= stack.damage then
        self:stop()
        return true
      end
      return false
    end
  )

  if #damaged_coolant_cells == 0 then return end

  self:stop()
  self:discharge(damaged_coolant_cells)
  self:load(damaged_coolant_cells, C)
end

function reactor:ensure_fuel_rods()
  local damaged_fuel_rods = self:filter(
    function(slot)
      if LAYOUT[slot] ~= F then
        return false
      end
      local stack = transposer.getStackInSlot(SIDES.NUCLEAR_REACTOR, slot)
      if stack.damage == stack.maxDamage then
        self:stop()
        return true
      end
      return false
    end
  )

  if #damaged_fuel_rods == 0 then return end

  self:stop()
  self:discharge(damaged_fuel_rods)
  self:load(damaged_fuel_rods, F)
end

function reactor:loop()
  self:ensure_coolant_cells()
  self:ensure_fuel_rods()
  self:start()
end

function reactor:run()
  if not self:initialization_check() then
    return
  end
  while true do
    self:loop()
    os.sleep(0.25)
  end
end

function main()
  reactor:run()
end

main()
