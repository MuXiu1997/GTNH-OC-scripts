-- Nuclear Reactor

local component = require('component')
local computer = require('computer')
local sides = require('sides')

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
  name       = 'gregtech:gt.360k_NaK_Coolantcell',
  is_damaged = function(stack)
    return stack.maxDamage - 1 <= stack.damage
  end
}
-- fuel rod
local F = {
  name       = 'gregtech:gt.reactorMOXQuad',
  is_damaged = function(stack)
    return stack.damage == stack.maxDamage
  end
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

local reactor = {
  started       = false,
  damaged_slots = {},
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
    self.started = false
  end
end

function reactor:find_input(what)
  while true do
    for slot = 1, transposer.getInventorySize(SIDES.INPUT) do
      local stack = transposer.getStackInSlot(SIDES.INPUT, slot)
      if stack ~= nil and stack.name == what.name then
        return slot
      end
    end
    -- missing items, waiting
    os.sleep(5)
  end
end

function reactor:discharge()
  for _, slot in ipairs(self.damaged_slots) do
    while transposer.getSlotStackSize(SIDES.NUCLEAR_REACTOR, slot) ~= 0 do
      -- output is blocked, waiting
      if transposer.transferItem(SIDES.NUCLEAR_REACTOR, SIDES.OUTPUT, 1, slot) == 0 then
        os.sleep(5)
      end
    end
  end
end

function reactor:load()
  while #self.damaged_slots > 0 do
    local slot = self.damaged_slots[1]
    local what = LAYOUT[slot]
    local input_slot = find_input(what)
    transposer.transferItem(SIDES.INPUT, SIDES.NUCLEAR_REACTOR, 1, input_slot, slot)
    table.remove(self.damaged_slots, 1)
  end
end

function reactor:has_damaged()
  for slot = 1, transposer.getInventorySize(SIDES.NUCLEAR_REACTOR) do
    local stack = transposer.getStackInSlot(SIDES.NUCLEAR_REACTOR, slot)
    if stack ~= nil then
      if LAYOUT[slot].is_damaged(stack) then
        return true
      end
    end
  end
  return false
end

function reactor:ensure()
  if not self:has_damaged() then
    return
  end

  self:stop()
  os.sleep(1)

  for slot = 1, transposer.getInventorySize(SIDES.NUCLEAR_REACTOR) do
    local stack = transposer.getStackInSlot(SIDES.NUCLEAR_REACTOR, slot)
    if stack ~= nil then
      if LAYOUT[slot].is_damaged(stack) then
        table.insert(self.damaged_slots, slot)
      end
    end
  end

  self:discharge()
  self:load()
end

function reactor:loop()
  self:ensure()
  self:start()
end

function reactor:run()
  if not self:initialization_check() then
    for _ = 1, 3 do
      computer.beep('.')
      os.sleep(1)
    end
    return
  end
  while true do
    self:loop()
    os.sleep(0.25)
  end
end

local function main()
  reactor:run()
end

main()
