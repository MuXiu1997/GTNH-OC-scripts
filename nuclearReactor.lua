-- Nuclear Reactor

local component = require('component')
local computer = require('computer')
local sides = require('sides')

--- @alias What { name: string, isDamaged: fun(stack):boolean }

--region SETUP
local SIDES = {
  INPUT                    = sides.top,
  OUTPUT                   = sides.top,
  NUCLEAR_REACTOR          = sides.top,
  NUCLEAR_REACTOR_REDSTONE = sides.top,
}
local ADDRESSES = {
  TRANSPOSER = '',
  REDSTONE   = ''
}
--- coolant cell
--- @type What
local C = {
  name      = 'gregtech:gt.360k_NaK_Coolantcell',
  isDamaged = function(stack)
    return stack.maxDamage - 1 <= stack.damage
  end
}
--- fuel rod
--- @type What
local F = {
  name      = 'gregtech:gt.reactorMOXQuad',
  isDamaged = function(stack)
    return stack.damage == stack.maxDamage
  end
}
--- empty
--- @type What
local E = {
  name      = '',
  isDamaged = function(_)
    return false
  end
}
--- @type What[]
local LAYOUT = {
  C, F, F, C, E, E, E, E, E,
  C, F, F, C, E, E, E, E, E,
  C, F, F, C, E, E, E, E, E,
  C, F, F, C, E, E, E, E, E,
  C, F, F, C, E, E, E, E, E,
  C, F, F, C, E, E, E, E, E,
}
--endregion SETUP

local redstone = component.proxy(component.get(ADDRESSES.REDSTONE))
local transposer = component.proxy(component.get(ADDRESSES.TRANSPOSER))

local reactor = {
  started      = false,
  --- @type number[]
  damagedSlots = {},
}

--- @return boolean
function reactor:initializationCheck()
  if transposer.getInventorySize(SIDES.NUCLEAR_REACTOR) ~= #LAYOUT then
    return false
  end
  for slot, preset in pairs(LAYOUT) do
    local stack = transposer.getStackInSlot(SIDES.NUCLEAR_REACTOR, slot)
    if preset.name == '' and stack ~= nil then
      return false
    end
    if preset.name ~= '' then
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

--- @param what What
--- @return number slot
function reactor:findInput(what)
  while true do
    local slot = 1
    local stacksIterator = transposer.getAllStack(SIDES.INPUT)
    for stack in stacksIterator do
      if stack.name == what then
        return slot
      end
      slot = slot + 1
    end
    -- missing item, waiting
    os.sleep(5)
  end
end

function reactor:discharge()
  for _, slot in ipairs(self.damagedSlots) do
    while transposer.getSlotStackSize(SIDES.NUCLEAR_REACTOR, slot) ~= 0 do
      -- output is blocked, waiting
      if transposer.transferItem(SIDES.NUCLEAR_REACTOR, SIDES.OUTPUT, 1, slot) == 0 then
        os.sleep(5)
      end
    end
  end
end

function reactor:load()
  while #self.damagedSlots > 0 do
    local slot = self.damagedSlots[1]
    local what = LAYOUT[slot]
    local inputSlot = self:findInput(what)
    transposer.transferItem(SIDES.INPUT, SIDES.NUCLEAR_REACTOR, 1, inputSlot, slot)
    table.remove(self.damagedSlots, 1)
  end
end

--- @return boolean
function reactor:hasDamaged()
  local slot = 1
  local stacksIterator = transposer.getAllStack(SIDES.NUCLEAR_REACTOR)
  for stack in stacksIterator do
    if LAYOUT[slot].isDamaged(stack) then
      return true
    end
    slot = slot + 1
  end
  return false
end

function reactor:ensure()
  if not self:hasDamaged() then
    return
  end

  self:stop()
  os.sleep(1)

  local slot = 1
  local stacksIterator = transposer.getAllStack(SIDES.NUCLEAR_REACTOR)
  for stack in stacksIterator do
    if LAYOUT[slot].isDamaged(stack) then
      table.insert(self.damagedSlots, slot)
    end
    slot = slot + 1
  end

  self:discharge()
  self:load()
end

function reactor:loop()
  self:ensure()
  self:start()
end

function reactor:run()
  if not self:initializationCheck() then
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

function start()
  reactor:run()
end
