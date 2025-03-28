-- Simple test module for coverage tests
local M = {}

function M.add(a, b)
  return a + b
end

function M.subtract(a, b)
  return a - b
end

function M.multiply(a, b)
  return a * b
end

function M.divide(a, b)
  if b == 0 then
    error("Division by zero")
  end
  return a / b
end

function M.power(a, b)
  return a ^ b
end

-- Function with conditional branches
function M.max(a, b)
  if a > b then
    return a
  else
    return b
  end
end

-- Function with loop
function M.sum(t)
  local result = 0
  for i, v in ipairs(t) do
    result = result + v
  end
  return result
end

-- Function with nested calls
function M.average(t)
  local sum = M.sum(t)
  return sum / #t
end

return M