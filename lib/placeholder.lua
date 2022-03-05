--- @class Placeholder
--- @field prefix string
local placeholder = {}

--- @param str string
function placeholder:match(str)
  return string.sub(str, 1, string.len(self.prefix)) == self.prefix
end

--- @param str string
function placeholder:removePrefix(str)
  if self:match(str) then
    return string.sub(str, string.len(self.prefix) + 1)
  end
  return ''
end

--- @param prefix string
--- @return Placeholder
local function newPlaceholder(prefix)
  return setmetatable({ prefix = prefix }, { __index = placeholder })
end

return newPlaceholder
