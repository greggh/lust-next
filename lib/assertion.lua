-- Assertion module for firmo
-- This is a standalone module for assertions that resolves circular dependencies
-- and provides consistent error handling patterns.

local M = {}

-- Compatibility function for table unpacking (works with both Lua 5.1 and 5.2+)
local unpack = table.unpack or _G.unpack

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler, _logging, _firmo
local function get_error_handler()
  if not _error_handler then
    local success, error_handler = pcall(require, "lib.tools.error_handler")
    _error_handler = success and error_handler or nil
  end
  return _error_handler
end

local function get_logging()
  if not _logging then
    local success, logging = pcall(require, "lib.tools.logging")
    _logging = success and logging or nil
  end
  return _logging
end

-- Logger for this module
local function get_logger()
  local logging = get_logging()
  if logging then
    return logging.get_logger("assertion")
  end
  -- Return a stub logger if logging module isn't available
  return {
    error = function(msg)
      print("[ERROR] " .. msg)
    end,
    warn = function(msg)
      print("[WARN] " .. msg)
    end,
    info = function(msg)
      print("[INFO] " .. msg)
    end,
    debug = function(msg)
      print("[DEBUG] " .. msg)
    end,
    trace = function(msg)
      print("[TRACE] " .. msg)
    end,
  }
end

---@diagnostic disable-next-line: unused-local
local logger = get_logger()

-- Utility functions
local function has(t, x)
  for _, v in pairs(t) do
    if v == x then
      return true
    end
  end
  return false
end

-- Enhanced stringify function with better formatting for different types
-- and protection against cyclic references
local function stringify(t, depth, visited)
  depth = depth or 0
  visited = visited or {}
  local indent_str = string.rep("  ", depth)

  -- Handle basic types directly
  if type(t) == "string" then
    return "'" .. tostring(t) .. "'"
  elseif type(t) == "number" or type(t) == "boolean" or type(t) == "nil" then
    return tostring(t)
  elseif type(t) ~= "table" or (getmetatable(t) and getmetatable(t).__tostring) then
    return tostring(t)
  end
  
  -- Handle cyclic references
  if visited[t] then
    return "[Circular Reference]"
  end
  
  -- Mark this table as visited
  visited[t] = true

  -- Handle empty tables
  if next(t) == nil then
    return "{}"
  end

  -- Handle tables with careful formatting
  local strings = {}
  local multiline = false

  -- Format array part first
  ---@diagnostic disable-next-line: unused-local
  for i, v in ipairs(t) do
    if type(v) == "table" and next(v) ~= nil and depth < 2 then
      multiline = true
      strings[#strings + 1] = indent_str .. "  " .. stringify(v, depth + 1, visited)
    else
      strings[#strings + 1] = stringify(v, depth + 1, visited)
    end
  end

  -- Format hash part next
  local hash_entries = {}
  for k, v in pairs(t) do
    if type(k) ~= "number" or k > #t or k < 1 then
      local key_str = type(k) == "string" and k or "[" .. stringify(k, depth + 1, visited) .. "]"

      if type(v) == "table" and next(v) ~= nil and depth < 2 then
        multiline = true
        hash_entries[#hash_entries + 1] = indent_str .. "  " .. key_str .. " = " .. stringify(v, depth + 1, visited)
      else
        hash_entries[#hash_entries + 1] = key_str .. " = " .. stringify(v, depth + 1, visited)
      end
    end
  end

  -- Combine array and hash parts
  for _, entry in ipairs(hash_entries) do
    strings[#strings + 1] = entry
  end

  -- Format based on content complexity
  if multiline and depth == 0 then
    return "{\n  " .. table.concat(strings, ",\n  ") .. "\n" .. indent_str .. "}"
  elseif #strings > 5 or multiline then
    return "{ " .. table.concat(strings, ", ") .. " }"
  else
    return "{ " .. table.concat(strings, ", ") .. " }"
  end
end

-- Generate a simple diff between two values
local function diff_values(v1, v2)
  -- Create a shared visited table for cyclic reference detection
  local visited = {}
  
  if type(v1) ~= "table" or type(v2) ~= "table" then
    return "Expected: " .. stringify(v2, 0, visited) .. "\nGot:      " .. stringify(v1, 0, visited)
  end

  local differences = {}

  -- Check for missing keys in v1
  for k, v in pairs(v2) do
    if v1[k] == nil then
      table.insert(differences, "Missing key: " .. stringify(k, 0, visited) .. " (expected " .. stringify(v, 0, visited) .. ")")
    elseif not M.eq(v1[k], v, 0) then
      table.insert(
        differences,
        "Different value for key "
          .. stringify(k, 0, visited)
          .. ":\n  Expected: "
          .. stringify(v, 0, visited)
          .. "\n  Got:      "
          .. stringify(v1[k], 0, visited)
      )
    end
  end

  -- Check for extra keys in v1
  for k, v in pairs(v1) do
    if v2[k] == nil then
      table.insert(differences, "Extra key: " .. stringify(k, 0, visited) .. " = " .. stringify(v, 0, visited))
    end
  end

  if #differences == 0 then
    return "Values appear equal but are not identical (may be due to metatable differences)"
  end

  return "Differences:\n  " .. table.concat(differences, "\n  ")
end

-- Deep equality check function with cycle detection
function M.eq(t1, t2, eps, visited)
  -- Initialize visited tables on first call
  visited = visited or {}
  
  -- Direct reference equality check for identical tables
  if t1 == t2 then
    return true
  end
  
  -- Create a unique key for this comparison pair to detect cycles
  local pair_key
  if type(t1) == "table" and type(t2) == "table" then
    -- Create a string that uniquely identifies this pair
    pair_key = tostring(t1) .. ":" .. tostring(t2)
    
    -- If we've seen this pair before, we're in a cycle
    if visited[pair_key] then
      return true -- Assume equality for cyclic structures
    end
    
    -- Mark this pair as visited
    visited[pair_key] = true
  end
  
  -- Special case for strings and numbers
  if (type(t1) == "string" and type(t2) == "number") or (type(t1) == "number" and type(t2) == "string") then
    -- Try string comparison
    if tostring(t1) == tostring(t2) then
      return true
    end

    -- Try number comparison if possible
    local n1 = type(t1) == "string" and tonumber(t1) or t1
    local n2 = type(t2) == "string" and tonumber(t2) or t2

    if type(n1) == "number" and type(n2) == "number" then
      local ok, result = pcall(function()
        return math.abs(n1 - n2) <= (eps or 0)
      end)
      if ok then
        return result
      end
    end

    return false
  end

  -- If types are different, return false
  if type(t1) ~= type(t2) then
    return false
  end

  -- For numbers, do epsilon comparison
  if type(t1) == "number" then
    local ok, result = pcall(function()
      return math.abs(t1 - t2) <= (eps or 0)
    end)

    -- If comparison failed (e.g., NaN), fall back to direct equality
    if not ok then
      return t1 == t2
    end

    return result
  end

  -- For non-tables, simple equality
  if type(t1) ~= "table" then
    return t1 == t2
  end

  -- For tables, recursive equality check
  for k, v in pairs(t1) do
    if not M.eq(v, t2[k], eps, visited) then
      return false
    end
  end

  ---@diagnostic disable-next-line: unused-local
  for k, v in pairs(t2) do
    if t1[k] == nil then
      return false
    end
  end

  return true
end

-- Type checking function
function M.isa(v, x)
  if type(x) == "string" then
    return type(v) == x,
      "expected " .. tostring(v) .. " to be a " .. x,
      "expected " .. tostring(v) .. " to not be a " .. x
  elseif type(x) == "table" then
    if type(v) ~= "table" then
      return false,
        "expected " .. tostring(v) .. " to be a " .. tostring(x),
        "expected " .. tostring(v) .. " to not be a " .. tostring(x)
    end

    local seen = {}
    local meta = v
    while meta and not seen[meta] do
      if meta == x then
        return true
      end
      seen[meta] = true
      meta = getmetatable(meta) and getmetatable(meta).__index
    end

    return false,
      "expected " .. tostring(v) .. " to be a " .. tostring(x),
      "expected " .. tostring(v) .. " to not be a " .. tostring(x)
  end

  error("invalid type " .. tostring(x))
end

-- ==========================================
-- Assertion Path Definitions
-- ==========================================

-- Define all the assertion paths
local paths = {
  [""] = { "to", "to_not" },
  to = {
    "have",
    "equal",
    "be",
    "exist",
    "fail",
    "match",
    "contain",
    "start_with",
    "end_with",
    "be_type",
    "be_greater_than",
    "be_less_than",
    "be_between",
    "be_approximately",
    "throw",
    "satisfy",
    "implement_interface",
    "be_truthy",
    "be_falsy",
    "be_falsey",
    "is_exact_type",
    "is_instance_of",
    "implements",
  },
  to_not = {
    "have",
    "equal",
    "be",
    "exist",
    "fail",
    "match",
    "contain",
    "start_with",
    "end_with",
    "be_type",
    "be_greater_than",
    "be_less_than",
    "be_between",
    "be_approximately",
    "throw",
    "satisfy",
    "implement_interface",
    "be_truthy",
    "be_falsy",
    "be_falsey",
    "is_exact_type",
    "is_instance_of",
    "implements",
    chain = function(a)
      a.negate = not a.negate
    end,
  },
  a = { test = M.isa },
  an = { test = M.isa },
  falsey = {
    test = function(v)
      return not v, "expected " .. tostring(v) .. " to be falsey", "expected " .. tostring(v) .. " to not be falsey"
    end,
  },
  be = {
    "a",
    "an",
    "truthy",
    "falsy",
    "falsey",
    "nil",
    "type",
    "at_least",
    "greater_than",
    "less_than",
    test = function(v, x)
      return v == x,
        "expected " .. tostring(v) .. " and " .. tostring(x) .. " to be the same",
        "expected " .. tostring(v) .. " and " .. tostring(x) .. " to not be the same"
    end,
  },

  at_least = {
    test = function(v, x)
      if type(v) ~= "number" or type(x) ~= "number" then
        error("expected both values to be numbers for at_least comparison")
      end
      return v >= x,
        "expected " .. tostring(v) .. " to be at least " .. tostring(x),
        "expected " .. tostring(v) .. " to not be at least " .. tostring(x)
    end,
  },

  greater_than = {
    test = function(v, x)
      if type(v) ~= "number" or type(x) ~= "number" then
        error("expected both values to be numbers for greater_than comparison")
      end
      return v > x,
        "expected " .. tostring(v) .. " to be greater than " .. tostring(x),
        "expected " .. tostring(v) .. " to not be greater than " .. tostring(x)
    end,
  },

  less_than = {
    test = function(v, x)
      if type(v) ~= "number" or type(x) ~= "number" then
        error("expected both values to be numbers for less_than comparison")
      end
      return v < x,
        "expected " .. tostring(v) .. " to be less than " .. tostring(x),
        "expected " .. tostring(v) .. " to not be less than " .. tostring(x)
    end,
  },
  exist = {
    test = function(v)
      return v ~= nil, "expected " .. tostring(v) .. " to exist", "expected " .. tostring(v) .. " to not exist"
    end,
  },
  truthy = {
    test = function(v)
      return v and true or false,
        "expected " .. tostring(v) .. " to be truthy",
        "expected " .. tostring(v) .. " to not be truthy"
    end,
  },
  falsy = {
    test = function(v)
      return not v and true or false,
        "expected " .. tostring(v) .. " to be falsy",
        "expected " .. tostring(v) .. " to not be falsy"
    end,
  },
  ["nil"] = {
    test = function(v)
      return v == nil, "expected " .. tostring(v) .. " to be nil", "expected " .. tostring(v) .. " to not be nil"
    end,
  },
  type = {
    test = function(v, expected_type)
      return type(v) == expected_type,
        "expected " .. tostring(v) .. " to be of type " .. expected_type .. ", got " .. type(v),
        "expected " .. tostring(v) .. " to not be of type " .. expected_type
    end,
  },
  equal = {
    test = function(v, x, eps)
      local equal = M.eq(v, x, eps)
      local comparison = ""

      if not equal then
        if type(v) == "table" or type(x) == "table" then
          -- For tables, generate a detailed diff
          comparison = "\n" .. diff_values(v, x)
        else
          -- For primitive types, show a simple comparison
          comparison = "\n" .. "Expected: " .. stringify(x) .. "\n" .. "Got:      " .. stringify(v)
        end
      end

      return equal,
        "Values are not equal: " .. comparison,
        "expected " .. stringify(v) .. " and " .. stringify(x) .. " to not be equal"
    end,
  },
  have = {
    test = function(v, x)
      if type(v) ~= "table" then
        error("expected " .. stringify(v) .. " to be a table")
      end

      -- Create a formatted table representation for better error messages
      local table_str = stringify(v)
      local content_preview = #table_str > 70 and table_str:sub(1, 67) .. "..." or table_str

      return has(v, x),
        "expected table to contain " .. stringify(x) .. "\nTable contents: " .. content_preview,
        "expected table not to contain " .. stringify(x) .. " but it was found\nTable contents: " .. content_preview
    end,
  },
  fail = {
    "with",
    test = function(v)
      return not pcall(v), "expected " .. tostring(v) .. " to fail", "expected " .. tostring(v) .. " to not fail"
    end,
  },
  with = {
    test = function(v, pattern)
      local ok, message = pcall(v)
      return not ok and message:match(pattern),
        "expected " .. tostring(v) .. ' to fail with error matching "' .. pattern .. '"',
        "expected " .. tostring(v) .. ' to not fail with error matching "' .. pattern .. '"'
    end,
  },
  match = {
    test = function(v, p)
      if type(v) ~= "string" then
        v = tostring(v)
      end
      local result = string.find(v, p) ~= nil
      return result,
        'expected "' .. v .. '" to match pattern "' .. p .. '"',
        'expected "' .. v .. '" to not match pattern "' .. p .. '"'
    end,
  },

  -- Interface implementation checking
  implement_interface = {
    test = function(v, interface)
      if type(v) ~= "table" then
        return false, "expected " .. tostring(v) .. " to be a table", nil
      end

      if type(interface) ~= "table" then
        return false, "expected interface to be a table", nil
      end

      local missing_keys = {}
      local wrong_types = {}

      for key, expected in pairs(interface) do
        local actual = v[key]

        if actual == nil then
          table.insert(missing_keys, key)
        elseif type(expected) == "function" and type(actual) ~= "function" then
          table.insert(wrong_types, key .. " (expected function, got " .. type(actual) .. ")")
        end
      end

      if #missing_keys > 0 or #wrong_types > 0 then
        local msg = "expected object to implement interface, but: "
        if #missing_keys > 0 then
          msg = msg .. "missing: " .. table.concat(missing_keys, ", ")
        end
        if #wrong_types > 0 then
          if #missing_keys > 0 then
            msg = msg .. "; "
          end
          msg = msg .. "wrong types: " .. table.concat(wrong_types, ", ")
        end

        return false, msg, "expected object not to implement interface"
      end

      return true, "expected object to implement interface", "expected object not to implement interface"
    end,
  },

  -- Table inspection assertions
  contain = {
    "keys",
    "values",
    "key",
    "value",
    "subset",
    "exactly",
    test = function(v, x)
      -- Simple implementation first
      if type(v) == "string" then
        -- Handle string containment
        local x_str = tostring(x)
        return string.find(v, x_str, 1, true) ~= nil,
          'expected string "' .. v .. '" to contain "' .. x_str .. '"',
          'expected string "' .. v .. '" to not contain "' .. x_str .. '"'
      elseif type(v) == "table" then
        -- Handle table containment
        return has(v, x),
          "expected " .. tostring(v) .. " to contain " .. tostring(x),
          "expected " .. tostring(v) .. " to not contain " .. tostring(x)
      else
        -- Error for unsupported types
        error("cannot check containment in a " .. type(v))
      end
    end,
  },

  -- Check if a table contains all specified keys
  keys = {
    test = function(v, x)
      if type(v) ~= "table" then
        error("expected " .. tostring(v) .. " to be a table")
      end

      if type(x) ~= "table" then
        error("expected " .. tostring(x) .. " to be a table containing keys to check for")
      end

      for _, key in ipairs(x) do
        if v[key] == nil then
          return false,
            "expected " .. stringify(v) .. " to contain key " .. tostring(key),
            "expected " .. stringify(v) .. " to not contain key " .. tostring(key)
        end
      end

      return true,
        "expected " .. stringify(v) .. " to contain keys " .. stringify(x),
        "expected " .. stringify(v) .. " to not contain keys " .. stringify(x)
    end,
  },

  -- Check if a table contains a specific key
  key = {
    test = function(v, x)
      if type(v) ~= "table" then
        error("expected " .. tostring(v) .. " to be a table")
      end

      return v[x] ~= nil,
        "expected " .. stringify(v) .. " to contain key " .. tostring(x),
        "expected " .. stringify(v) .. " to not contain key " .. tostring(x)
    end,
  },

  -- Numeric comparison assertions
  be_greater_than = {
    test = function(v, x)
      if type(v) ~= "number" then
        error("expected " .. tostring(v) .. " to be a number")
      end

      if type(x) ~= "number" then
        error("expected " .. tostring(x) .. " to be a number")
      end

      return v > x,
        "expected " .. tostring(v) .. " to be greater than " .. tostring(x),
        "expected " .. tostring(v) .. " to not be greater than " .. tostring(x)
    end,
  },
  be_less_than = {
    test = function(v, x)
      if type(v) ~= "number" then
        error("expected " .. tostring(v) .. " to be a number")
      end

      if type(x) ~= "number" then
        error("expected " .. tostring(x) .. " to be a number")
      end

      return v < x,
        "expected " .. tostring(v) .. " to be less than " .. tostring(x),
        "expected " .. tostring(v) .. " to not be less than " .. tostring(x)
    end,
  },

  be_between = {
    test = function(v, min, max)
      if type(v) ~= "number" then
        error("expected " .. tostring(v) .. " to be a number")
      end

      if type(min) ~= "number" or type(max) ~= "number" then
        error("expected min and max to be numbers")
      end

      return v >= min and v <= max,
        "expected " .. tostring(v) .. " to be between " .. tostring(min) .. " and " .. tostring(max),
        "expected " .. tostring(v) .. " to not be between " .. tostring(min) .. " and " .. tostring(max)
    end,
  },

  be_truthy = {
    test = function(v)
      return v and true or false,
        "expected " .. tostring(v) .. " to be truthy",
        "expected " .. tostring(v) .. " to not be truthy"
    end,
  },

  be_falsy = {
    test = function(v)
      return not v, "expected " .. tostring(v) .. " to be falsy", "expected " .. tostring(v) .. " to not be falsy"
    end,
  },

  be_falsey = {
    test = function(v)
      return not v, "expected " .. tostring(v) .. " to be falsey", "expected " .. tostring(v) .. " to not be falsey"
    end,
  },

  be_approximately = {
    test = function(v, x, delta)
      if type(v) ~= "number" then
        error("expected " .. tostring(v) .. " to be a number")
      end

      if type(x) ~= "number" then
        error("expected " .. tostring(x) .. " to be a number")
      end

      delta = delta or 0.0001

      return math.abs(v - x) <= delta,
        "expected " .. tostring(v) .. " to be approximately " .. tostring(x) .. " (±" .. tostring(delta) .. ")",
        "expected " .. tostring(v) .. " to not be approximately " .. tostring(x) .. " (±" .. tostring(delta) .. ")"
    end,
  },

  -- Satisfy assertion for custom predicates
  satisfy = {
    test = function(v, predicate)
      if type(predicate) ~= "function" then
        error("expected predicate to be a function, got " .. type(predicate))
      end

      local success, result = pcall(predicate, v)
      if not success then
        error("predicate function failed with error: " .. tostring(result))
      end

      return result,
        "expected value to satisfy the given predicate function",
        "expected value to not satisfy the given predicate function"
    end,
  },

  -- String assertions
  start_with = {
    test = function(v, x)
      if type(v) ~= "string" then
        error("expected " .. tostring(v) .. " to be a string")
      end

      if type(x) ~= "string" then
        error("expected " .. tostring(x) .. " to be a string")
      end

      return v:sub(1, #x) == x,
        'expected "' .. v .. '" to start with "' .. x .. '"',
        'expected "' .. v .. '" to not start with "' .. x .. '"'
    end,
  },

  end_with = {
    test = function(v, x)
      if type(v) ~= "string" then
        error("expected " .. tostring(v) .. " to be a string")
      end

      if type(x) ~= "string" then
        error("expected " .. tostring(x) .. " to be a string")
      end

      return v:sub(-#x) == x,
        'expected "' .. v .. '" to end with "' .. x .. '"',
        'expected "' .. v .. '" to not end with "' .. x .. '"'
    end,
  },

  -- Type checking assertions
  be_type = {
    "callable",
    "comparable",
    "iterable",
    test = function(v, expected_type)
      if expected_type == "callable" then
        local is_callable = type(v) == "function" or (type(v) == "table" and getmetatable(v) and getmetatable(v).__call)
        return is_callable,
          "expected " .. tostring(v) .. " to be callable",
          "expected " .. tostring(v) .. " to not be callable"
      elseif expected_type == "comparable" then
        local success = pcall(function()
          return v < v
        end)
        return success,
          "expected " .. tostring(v) .. " to be comparable",
          "expected " .. tostring(v) .. " to not be comparable"
      elseif expected_type == "iterable" then
        local success = pcall(function()
          for _ in pairs(v) do
            break
          end
        end)
        return success,
          "expected " .. tostring(v) .. " to be iterable",
          "expected " .. tostring(v) .. " to not be iterable"
      else
        error("unknown type check: " .. tostring(expected_type))
      end
    end,
  },

  -- Enhanced error assertions
  throw = {
    "error",
    "error_matching",
    "error_type",
    test = function(v)
      if type(v) ~= "function" then
        error("expected " .. tostring(v) .. " to be a function")
      end

      ---@diagnostic disable-next-line: unused-local
      local ok, err = pcall(v)
      return not ok, "expected function to throw an error", "expected function to not throw an error"
    end,
  },

  error = {
    test = function(v)
      if type(v) ~= "function" then
        error("expected " .. tostring(v) .. " to be a function")
      end

      ---@diagnostic disable-next-line: unused-local
      local ok, err = pcall(v)
      return not ok, "expected function to throw an error", "expected function to not throw an error"
    end,
  },

  error_matching = {
    test = function(v, pattern)
      if type(v) ~= "function" then
        error("expected " .. tostring(v) .. " to be a function")
      end

      if type(pattern) ~= "string" then
        error("expected pattern to be a string")
      end

      local ok, err = pcall(v)
      if ok then
        return false,
          'expected function to throw an error matching pattern "' .. pattern .. '"',
          'expected function to not throw an error matching pattern "' .. pattern .. '"'
      end

      err = tostring(err)
      return err:match(pattern) ~= nil,
        'expected error "' .. err .. '" to match pattern "' .. pattern .. '"',
        'expected error "' .. err .. '" to not match pattern "' .. pattern .. '"'
    end,
  },

  error_type = {
    test = function(v, expected_type)
      if type(v) ~= "function" then
        error("expected " .. tostring(v) .. " to be a function")
      end

      local ok, err = pcall(v)
      if ok then
        return false,
          "expected function to throw an error of type " .. tostring(expected_type),
          "expected function to not throw an error of type " .. tostring(expected_type)
      end

      -- Try to determine the error type
      local error_type
      if type(err) == "string" then
        error_type = "string"
      elseif type(err) == "table" then
        error_type = err.__name or "table"
      else
        error_type = type(err)
      end

      return error_type == expected_type,
        "expected error of type " .. error_type .. " to be of type " .. expected_type,
        "expected error of type " .. error_type .. " to not be of type " .. expected_type
    end,
  },
}

-- Main expect function
function M.expect(v)
  ---@diagnostic disable-next-line: unused-local
  local error_handler = get_error_handler()
  local logger = get_logger()

  -- Track assertion count (for test quality metrics)
  M.assertion_count = (M.assertion_count or 0) + 1

  logger.trace("Assertion started", {
    value = tostring(v),
    type = type(v),
    assertion_count = M.assertion_count,
  })

  local assertion = {}
  assertion.val = v
  assertion.action = ""
  assertion.negate = false

  setmetatable(assertion, {
    __index = function(t, k)
      if has(paths[rawget(t, "action")], k) then
        rawset(t, "action", k)
        local chain = paths[rawget(t, "action")].chain
        if chain then
          chain(t)
        end
        return t
      end
      return rawget(t, k)
    end,
    __call = function(t, ...)
      if paths[t.action].test then
        local success, err, nerr

        -- Use error_handler.try if available for structured error handling
        local error_handler = get_error_handler()
        if error_handler then
          local args = { ... }
          local try_success, try_result = error_handler.try(function()
            local res, e, ne = paths[t.action].test(t.val, unpack(args))
            return { res = res, err = e, nerr = ne }
          end)

          if try_success then
            success, err, nerr = try_result.res, try_result.err, try_result.nerr
          else
            -- Handle error in test function
            logger.error("Error in assertion test function", {
              action = t.action,
              error = error_handler.format_error(try_result),
            })
            error(try_result.message or "Error in assertion test function", 2)
          end
        else
          -- Fallback if error_handler is not available
          local args = { ... }
          success, err, nerr = paths[t.action].test(t.val, unpack(args))
        end

        if assertion.negate then
          success = not success
          err = nerr or err
        end

        if not success then
          if error_handler then
            -- Create a structured error
            local context = {
              expected = select(1, ...),
              actual = t.val,
              action = t.action,
              negate = assertion.negate,
            }

            local error_obj = error_handler.create(
              err or "Assertion failed",
              error_handler.CATEGORY.VALIDATION,
              error_handler.SEVERITY.ERROR,
              context
            )

            logger.debug("Assertion failed", {
              error = error_handler.format_error(error_obj, false),
            })

            error(error_handler.format_error(error_obj, false), 2)
          else
            -- Fallback without error_handler
            error(err or "unknown failure", 2)
          end
        else
          logger.trace("Assertion passed", {
            action = t.action,
            value = tostring(t.val),
          })
        end
      end
    end,
  })

  return assertion
end

-- Export paths to allow extensions
M.paths = paths

-- Return the module
return M
