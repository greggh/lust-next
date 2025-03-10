-- Test script for coverage module with static analysis integration
local coverage = require("lib.coverage")

local function run_test()
  print("Testing Coverage Module with Static Analysis")
  print("--------------------------------------------")
  
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
  print("Add result: " .. add(5, 7))
  print("Multiply result: " .. multiply(5, 3))
  
  -- Stop coverage tracking
  coverage.stop()
  
  -- Show coverage report
  print("\nCoverage Report:")
  print(coverage.report("summary"))
  
  -- Debug dump
  print("\nCoverage Debug Dump:")
  coverage.debug_dump()
end

run_test()