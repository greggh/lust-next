-- Fix for the firmo expect assertion system
local firmo = require('firmo')
local logging = require("lib.tools.logging")

-- Initialize module logger
local logger = logging.get_logger("fix_expect")
logging.configure_from_config("fix_expect")

-- Function to check if a path is properly set up
local function validate_path(path_key, path_elements)
  -- Check if the path exists
  if not firmo.paths[path_key] then
    logger.warn("Path not found", {path = path_key})
    return false
  end

  -- Check if all expected elements are in the path
  for _, element in ipairs(path_elements) do
    local found = false
    for _, existing in ipairs(firmo.paths[path_key]) do
      if existing == element then
        found = true
        break
      end
    end

    if not found then
      logger.warn("Element missing in path", {path = path_key, element = element})
      return false
    end
  end

  return true
end

-- Function to debug paths
local function inspect_paths()
  logger.debug("Inspecting paths")
  for k, v in pairs(firmo.paths) do
    if type(v) == "table" then
      local elements = {}
      for ek, ev in pairs(v) do
        if type(ek) == "number" then
          table.insert(elements, ev)
        elseif ek ~= "chain" and ek ~= "test" then
          table.insert(elements, ek .. ":" .. type(ev))
        end
      end
      logger.debug("Path contents", {path = k, elements = table.concat(elements, ", ")})
    else
      logger.debug("Path value", {path = k, value = tostring(v)})
    end
  end
end

-- Function to verify has() works as expected
local function test_has()
  local test_table = {"a", "b", "c"}
  assert(firmo.has(test_table, "a"), "has() function should return true for 'a'")
  assert(not firmo.has(test_table, "d"), "has() function should return false for 'd'")
  logger.debug("has() function verified")
end

-- Function to fix expect assertion system
local function fix_expect_system()
  logger.info("Fixing expect assertion system")

  -- Make sure the has function exists
  local has_fn = firmo.has
  if not has_fn then
    logger.warn("has function missing")
    -- Define a has function if it doesn't exist
    firmo.has = function(t, x)
      for _, v in pairs(t) do
        if v == x then return true end
      end
      return false
    end
    logger.info("Added has function")
  else
    logger.debug("has function exists")
  end

  -- Ensure paths table exists
  if not firmo.paths then
    logger.warn("paths table missing", {action = "creating new table"})
    firmo.paths = {}
  end

  -- Make sure the be path is properly set up with truthy
  if not firmo.paths.be then
    logger.info("Creating be path", {elements = "a, an, truthy, falsey, greater, less"})
    firmo.paths.be = { 'a', 'an', 'truthy', 'falsey', 'greater', 'less' }
  else
    -- Make sure truthy is in the be path
    if not firmo.has(firmo.paths.be, 'truthy') then
      logger.info("Adding truthy element", {path = "be"})
      table.insert(firmo.paths.be, 'truthy')
    end

    -- Make sure falsey is in the be path
    if not firmo.has(firmo.paths.be, 'falsey') then
      logger.info("Adding falsey element", {path = "be"})
      table.insert(firmo.paths.be, 'falsey')
    end

    -- Make sure greater is in the be path
    if not firmo.has(firmo.paths.be, 'greater') then
      logger.info("Adding greater element", {path = "be"})
      table.insert(firmo.paths.be, 'greater')
    end

    -- Make sure less is in the be path
    if not firmo.has(firmo.paths.be, 'less') then
      logger.info("Adding less element", {path = "be"})
      table.insert(firmo.paths.be, 'less')
    end
  end

  -- Make sure be_truthy is defined
  if not firmo.paths.be_truthy then
    logger.info("Adding path", {path = "be_truthy"})
    firmo.paths.be_truthy = {
      test = function(v)
        return v ~= false and v ~= nil,
          'expected ' .. tostring(v) .. ' to be truthy',
          'expected ' .. tostring(v) .. ' to not be truthy'
      end
    }
  end

  -- Make sure be_falsey is defined
  if not firmo.paths.be_falsey then
    logger.info("Adding path", {path = "be_falsey"})
    firmo.paths.be_falsey = {
      test = function(v)
        return v == false or v == nil,
          'expected ' .. tostring(v) .. ' to be falsey',
          'expected ' .. tostring(v) .. ' to not be falsey'
      end
    }
  end

  -- Make sure be_greater is defined
  if not firmo.paths.be_greater then
    logger.info("Adding path", {path = "be_greater"})
    firmo.paths.be_greater = {
      than = function(a, b)
        return a > b,
          'expected ' .. tostring(a) .. ' to be greater than ' .. tostring(b),
          'expected ' .. tostring(a) .. ' to not be greater than ' .. tostring(b)
      end
    }
  end

  -- Make sure be_less is defined
  if not firmo.paths.be_less then
    logger.info("Adding path", {path = "be_less"})
    firmo.paths.be_less = {
      than = function(a, b)
        return a < b,
          'expected ' .. tostring(a) .. ' to be less than ' .. tostring(b),
          'expected ' .. tostring(a) .. ' to not be less than ' .. tostring(b)
      end
    }
  end

  -- Check for to_not and to.not
  if not firmo.paths.to_not then
    logger.info("Adding path", {path = "to_not"})
    firmo.paths.to_not = {
      'have', 'equal', 'be', 'exist', 'fail', 'match', 'contain', 'start_with', 'end_with',
      'be_type', 'be_greater_than', 'be_less_than', 'be_between', 'be_approximately',
      'throw', 'be_truthy', 'be_falsey', 'satisfy',
      chain = function(a) a.negate = not a.negate end
    }
  end

  -- Add to.not as an alias for to_not if it doesn't exist
  if not firmo.paths.to.not then
    logger.info("Adding alias", {alias = "to.not", target = "to_not"})
    firmo.paths.to.not = firmo.paths.to_not
  end

  -- Test path validation
  local root_valid = validate_path('', {'to', 'to_not'})
  local to_valid = validate_path('to', {'be', 'equal', 'truthy', 'falsey'})
  local be_valid = validate_path('be', {'truthy', 'falsey'})

  -- Final validation
  if root_valid and to_valid and be_valid then
    logger.info("Expect assertion paths successfully fixed")
    return true
  else
    logger.warn("Path validation failed", {status = "expect assertion system may have issues"})
    return false
  end
end

-- Apply the fix
local success = fix_expect_system()

-- Debug paths after fix
inspect_paths()

-- Test has function
test_has()

-- Return success status
return success
