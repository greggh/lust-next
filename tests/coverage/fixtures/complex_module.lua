-- Complex test module with advanced Lua features
local M = {}

-- Local function with multiline definition
local function process_data(
  data,
  options,
  callback
)
  local result = {}
  
  -- Table constructor with mixed notations
  local config = {
    enabled = options.enabled or false,
    max_items = options.max_items or 10,
    ["process_all"] = options.process_all or false,
    [1] = "first",
    [2] = "second"
  }
  
  -- Complex for loop
  for i, item in ipairs(data) do
    if i > config.max_items and not config.process_all then
      break
    end
    
    -- Nested if statements
    if type(item) == "table" then
      if item.active then
        -- Function calls with inline anonymous function
        table.insert(result, (function()
          local transformed = {}
          for k, v in pairs(item) do
            transformed[k] = type(v) == "string" and v:upper() or v
          end
          return transformed
        end)())
      end
    elseif type(item) == "string" then
      -- String manipulation
      table.insert(result, item:gsub("%s+", "_"))
    elseif type(item) == "number" then
      -- Complex arithmetic with precedence
      table.insert(result, item * 2 + (config.enabled and 10 or 0))
    end
  end
  
  -- Multiple returns
  if #result == 0 then
    return nil, "No items processed"
  end
  
  -- Closure over local variables
  local function get_summary()
    return {
      count = #result,
      config = config,
      timestamp = os.time()
    }
  end
  
  -- Callback with closure
  if callback then
    callback(result, get_summary())
  end
  
  return result, nil, get_summary
end

-- Export the function
M.process_data = process_data

-- Method with variable arguments
function M.format(template, ...)
  local args = {...}
  return template:gsub("%${(%d+)}", function(n)
    local index = tonumber(n)
    return args[index] or ""
  end)
end

-- Complex conditionals
function M.analyze(data, threshold)
  local count = 0
  local sum = 0
  
  for _, value in ipairs(data) do
    -- Compound conditions
    if (value > 0 and value < threshold) or 
       (value < 0 and -value < threshold/2) then
      count = count + 1
      sum = sum + value
    end
  end
  
  -- Multiline string with escapes
  local report = [[
Summary Report:
--------------
Total count: ]] .. count .. [[
Total sum: ]] .. sum .. [[
Average: ]] .. (count > 0 and sum/count or 0)
  
  return {
    count = count,
    sum = sum,
    average = count > 0 and sum/count or 0,
    report = report
  }
end

-- Table with methods
M.utils = {
  -- Method in a table
  clone = function(t)
    if type(t) ~= "table" then return t end
    local result = {}
    for k, v in pairs(t) do
      result[k] = type(v) == "table" and M.utils.clone(v) or v
    end
    return result
  end,
  
  -- Another method
  merge = function(t1, t2)
    local result = M.utils.clone(t1)
    for k, v in pairs(t2) do
      result[k] = v
    end
    return result
  end
}

-- Metatable usage
local calculator = {}
M.calculator = calculator

calculator.__index = calculator

function calculator.new(initial)
  return setmetatable({value = initial or 0}, calculator)
end

function calculator:add(n)
  self.value = self.value + n
  return self
end

function calculator:subtract(n)
  self.value = self.value - n
  return self
end

function calculator:multiply(n)
  self.value = self.value * n
  return self
end

function calculator:divide(n)
  assert(n ~= 0, "Division by zero")
  self.value = self.value / n
  return self
end

function calculator:result()
  return self.value
end

return M