local function isEmpty(transposer, side)
  for slot = 1, transposer.getInventorySize(side) do
    if transposer.getSlotStackSize(side, slot) > 0 then
      return false
    end
  end
  return true
end

local function transferSlotStack(transposer, sourceSide, sinkSide, slot)
  transposer.transferItem(sourceSide, sinkSide, transposer.getSlotStackSize(sourceSide, slot), slot)
end

local function waitTransferSlotStack(transposer, sourceSide, sinkSide, slot)
  while transposer.getSlotStackSize(sourceSide, slot) > 0 do
    transferSlotStack(transposer, sourceSide, sinkSide, slot)
  end
end

local function transferAllSlotStacks(transposer, sourceSide, sinkSide)
  while ture do
    if transposer.transferItem(sourceSide, sinkSide) == 0 then return end
  end
end

return {
  isEmpty               = isEmpty,
  transferSlotStack     = transferSlotStack,
  waitTransferSlotStack = waitTransferSlotStack,
  transferAllSlotStacks = transferAllSlotStacks
}
