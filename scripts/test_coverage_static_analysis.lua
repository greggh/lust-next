-- Test script for coverage module with static analysis integration

-- Initialize logging system
local logging
local ok, err = pcall(function() logging = require("lib.tools.logging") end)
if not ok or not logging then
  -- Fall back to standard print if logging module isn't available
  logging = {
    configure = function() end,
    get_logger = function() return {
      info = print,
      error = print,
      warn = print,
      debug = print,
      verbose = print
    } end
  }
end

-- Get logger for test_coverage_static_analysis module
local logger = logging.get_logger("test_coverage_static_analysis")
-- Configure from config if possible
logging.configure_from_config("test_coverage_static_analysis")

local coverage = require("lib.coverage")

local function run_test()
  logger.info("Testing Coverage Module with Static Analysis")
  logger.info("--------------------------------------------")
  
  -- Initialize coverage with static analysis enabled
  coverage.init({
    enabled = true,
    debug = false,  -- Set to false to reduce output
    use_static_analysis = true,
    cache_parsed_files = true,
    pre_analyze_files = false
  })
  
  -- Start coverage tracking
  coverage.start()
  
  -- Dummy function to track
  local function add(a, b)
    -- Comment line
    local result = a + b
    
    -- Control structures with non-executable lines
    if result > 10 then
      print("Result is greater than 10")
    else
      print("Result is not greater than 10")
    end
    
    -- Another comment
    return result
  end
  
  -- Dummy function with branches
  local function multiply(a, b)
    local result = a * b
    
    if result > 50 then
      print("Large result")
    elseif result > 20 then
      print("Medium result")
    else
      print("Small result")
    end
    
    return result
  end
  
  -- Call functions to track coverage
  logger.info("Add result: " .. add(5, 7))
  logger.info("Multiply result: " .. multiply(5, 3))
  
  -- Stop coverage tracking
  coverage.stop()
  
  -- Show coverage report
  logger.info("\nCoverage Report:")
  logger.info(coverage.report("summary"))
  
  -- Debug dump
  logger.info("\nCoverage Debug Dump:")
  coverage.debug_dump()
end

run_test()