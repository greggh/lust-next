-- Tests for the condition expression tracking in the static analyzer

-- Import firmo
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import test_helper for improved error handling
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

local static_analyzer = require("lib.coverage.static_analyzer")
local temp_file = require("lib.tools.temp_file")
local fs = require("lib.tools.filesystem")

-- Set up logger with error handling
local logging, logger
local function try_load_logger()
  if not logger then
    local log_module, err = test_helper.with_error_capture(function()
      return require("lib.tools.logging")
    end)()
    
    if log_module then
      logging = log_module
      logger = logging.get_logger("test.static_analyzer.condition_expression")
    end
  end
  return logger
end

local log = try_load_logger()

describe("condition expression tracking", function()
  before(function()
    -- Initialize static analyzer with error handling
    local init_result, init_err = test_helper.with_error_capture(function()
      return static_analyzer.init()
    end)()
    
    if init_err and log then
      log.warn("Error initializing static analyzer", { error = init_err })
    end
  end)
  
  after(function()
    -- Clear cache with error handling
    local clear_result, clear_err = test_helper.with_error_capture(function()
      return static_analyzer.clear_cache()
    end)()
    
    if clear_err and log then
      log.warn("Error clearing static analyzer cache", { error = clear_err })
    end
  end)
  
  it("should extract simple conditions", function()
    local code = [[
      if x > 5 then
        print("x is greater than 5")
      end
    ]]
    
    -- Create temp file with error handling using new API
    local file_path, create_err = temp_file.create_with_content(code, "lua")
    
    expect(create_err).to_not.exist("Failed to create temporary file")
    expect(file_path).to.exist()
    
    -- Analyze file with error handling
    local code_map, analyze_err = test_helper.with_error_capture(function()
      return static_analyzer.analyze_file(file_path)
    end)()
    
    expect(analyze_err).to_not.exist()
    expect(code_map).to.exist()
    
    -- Get conditions with error handling
    local conditions, cond_err = test_helper.with_error_capture(function()
      return static_analyzer.get_conditions(code_map)
    end)()
    
    expect(cond_err).to_not.exist()
    expect(conditions).to.exist()
    expect(#conditions).to.be.a("number")
    expect(#conditions).to.be_greater_than(0)
    
    -- Find the condition
    local op_condition
    for _, cond in ipairs(conditions) do
      if cond.type == "op" then
        op_condition = cond
        break
      end
    end
    
    expect(op_condition).to.exist()
    expect(op_condition.is_compound).to_not.be_truthy()
    
    -- No need to remove temp file, it will be cleaned up automatically
  end)
  
  it("should extract compound AND conditions", function()
    local code = [[
      if x > 5 and y < 10 then
        print("x is greater than 5 and y is less than 10")
      end
    ]]
    
    -- Create temp file with error handling using new API
    local file_path, create_err = temp_file.create_with_content(code, "lua")
    
    expect(create_err).to_not.exist("Failed to create temporary file")
    expect(file_path).to.exist()
    
    -- Analyze file with error handling
    local code_map, analyze_err = test_helper.with_error_capture(function()
      return static_analyzer.analyze_file(file_path)
    end)()
    
    expect(analyze_err).to_not.exist()
    expect(code_map).to.exist()
    
    -- Get conditions with error handling
    local conditions, cond_err = test_helper.with_error_capture(function()
      return static_analyzer.get_conditions(code_map)
    end)()
    
    expect(cond_err).to_not.exist()
    expect(conditions).to.exist()
    
    -- Should have the compound condition and possibly component conditions
    expect(#conditions).to.be_greater_than(1)
    
    -- Find the compound condition
    local compound_condition
    for _, cond in ipairs(conditions) do
      if cond.is_compound and cond.operator == "and" then
        compound_condition = cond
        break
      end
    end
    
    expect(compound_condition).to.exist()
    expect(#compound_condition.components).to.equal(2)
    
    -- No need to remove temp file, it will be cleaned up automatically
  end)
  
  it("should extract compound OR conditions", function()
    local code = [[
      if x > 5 or y < 10 then
        print("x is greater than 5 or y is less than 10")
      end
    ]]
    
    -- Create temp file with error handling using new API
    local file_path, create_err = temp_file.create_with_content(code, "lua")
    
    expect(create_err).to_not.exist("Failed to create temporary file")
    expect(file_path).to.exist()
    
    -- Analyze file with error handling
    local code_map, analyze_err = test_helper.with_error_capture(function()
      return static_analyzer.analyze_file(file_path)
    end)()
    
    expect(analyze_err).to_not.exist()
    expect(code_map).to.exist()
    
    -- Get conditions with error handling
    local conditions, cond_err = test_helper.with_error_capture(function()
      return static_analyzer.get_conditions(code_map)
    end)()
    
    expect(cond_err).to_not.exist()
    expect(conditions).to.exist()
    
    -- Should have the compound condition and possibly component conditions
    expect(#conditions).to.be_greater_than(1)
    
    -- Find the compound condition
    local compound_condition
    for _, cond in ipairs(conditions) do
      if cond.is_compound and cond.operator == "or" then
        compound_condition = cond
        break
      end
    end
    
    expect(compound_condition).to.exist()
    expect(#compound_condition.components).to.equal(2)
    
    -- No need to remove temp file, it will be cleaned up automatically
  end)
  
  it("should extract NOT conditions", function()
    local code = [[
      if not (x > 5) then
        print("x is not greater than 5")
      end
    ]]
    
    -- Create temp file with error handling using new API
    local file_path, create_err = temp_file.create_with_content(code, "lua")
    
    expect(create_err).to_not.exist("Failed to create temporary file")
    expect(file_path).to.exist()
    
    -- Analyze file with error handling
    local code_map, analyze_err = test_helper.with_error_capture(function()
      return static_analyzer.analyze_file(file_path)
    end)()
    
    expect(analyze_err).to_not.exist()
    expect(code_map).to.exist()
    
    -- Get conditions with error handling
    local conditions, cond_err = test_helper.with_error_capture(function()
      return static_analyzer.get_conditions(code_map)
    end)()
    
    expect(cond_err).to_not.exist()
    expect(conditions).to.exist()
    
    -- Find the NOT condition
    local not_condition
    for _, cond in ipairs(conditions) do
      if cond.type == "not" then
        not_condition = cond
        break
      end
    end
    
    expect(not_condition).to.exist()
    expect(#not_condition.components).to.equal(1)
    
    -- No need to remove temp file, it will be cleaned up automatically
  end)
  
  it("should extract complex nested conditions", function()
    local code = [[
      if (x > 5 and y < 10) or (z == 15 and (a ~= nil or b == false)) then
        print("Complex condition")
      end
    ]]
    
    -- Create temp file with error handling using new API
    local file_path, create_err = temp_file.create_with_content(code, "lua")
    
    expect(create_err).to_not.exist("Failed to create temporary file")
    expect(file_path).to.exist()
    
    -- Analyze file with error handling
    local code_map, analyze_err = test_helper.with_error_capture(function()
      return static_analyzer.analyze_file(file_path)
    end)()
    
    expect(analyze_err).to_not.exist()
    expect(code_map).to.exist()
    
    -- Get conditions with error handling
    local conditions, cond_err = test_helper.with_error_capture(function()
      return static_analyzer.get_conditions(code_map)
    end)()
    
    expect(cond_err).to_not.exist()
    expect(conditions).to.exist()
    
    -- Should have multiple conditions in a hierarchy
    expect(#conditions).to.be_greater_than(5)
    
    -- Find the top-level OR condition
    local top_condition
    for _, cond in ipairs(conditions) do
      if cond.is_compound and cond.operator == "or" and cond.parent_id == "root" then
        top_condition = cond
        break
      end
    end
    
    expect(top_condition).to.exist()
    expect(#top_condition.components).to.equal(2)
    
    -- No need to remove temp file, it will be cleaned up automatically
  end)
  
  it("should link conditions to blocks", function()
    local code = [[
      if x > 5 then
        print("x is greater than 5")
      end
    ]]
    
    -- Create temp file with error handling using new API
    local file_path, create_err = temp_file.create_with_content(code, "lua")
    
    expect(create_err).to_not.exist("Failed to create temporary file")
    expect(file_path).to.exist()
    
    -- Analyze file with error handling
    local code_map, analyze_err = test_helper.with_error_capture(function()
      return static_analyzer.analyze_file(file_path)
    end)()
    
    expect(analyze_err).to_not.exist()
    expect(code_map).to.exist()
    
    -- Get blocks with error handling
    local blocks, blocks_err = test_helper.with_error_capture(function()
      return static_analyzer.get_blocks(code_map)
    end)()
    
    expect(blocks_err).to_not.exist()
    expect(blocks).to.exist()
    
    -- Find the if block
    local if_block
    for _, block in ipairs(blocks) do
      if block.type == "If" then
        if_block = block
        break
      end
    end
    
    expect(if_block).to.exist()
    expect(if_block.conditions).to.be.a("table")
    expect(#if_block.conditions).to.be_greater_than(0)
    
    -- No need to remove temp file, it will be cleaned up automatically
  end)
  
  it("should calculate correct condition coverage metrics", function()
    local code = [[
      if x > 5 and y < 10 then
        print("Both conditions met")
      elseif x > 5 or y < 10 then
        print("At least one condition met")
      else
        print("No conditions met")
      end
    ]]
    
    -- Create temp file with error handling using new API
    local file_path, create_err = temp_file.create_with_content(code, "lua")
    
    expect(create_err).to_not.exist("Failed to create temporary file")
    expect(file_path).to.exist()
    
    -- Analyze file with error handling
    local code_map, analyze_err = test_helper.with_error_capture(function()
      return static_analyzer.analyze_file(file_path)
    end)()
    
    expect(analyze_err).to_not.exist()
    expect(code_map).to.exist()
    
    -- Get conditions with error handling
    local conditions, cond_err = test_helper.with_error_capture(function()
      return static_analyzer.get_conditions(code_map)
    end)()
    
    expect(cond_err).to_not.exist()
    expect(conditions).to.exist()
    
    -- Simulate execution data
    for i, condition in ipairs(conditions) do
      if i % 2 == 0 then
        condition.executed = true
        condition.executed_true = true
        condition.execution_count = 1
      elseif i % 3 == 0 then
        condition.executed = true
        condition.executed_true = true
        condition.executed_false = true
        condition.execution_count = 2
      end
    end
    
    -- Calculate metrics with error handling
    local metrics, metrics_err = test_helper.with_error_capture(function()
      return static_analyzer.calculate_detailed_condition_coverage(code_map)
    end)()
    
    expect(metrics_err).to_not.exist()
    expect(metrics).to.exist()
    
    expect(metrics.total_conditions).to.equal(#conditions)
    expect(metrics.executed_conditions).to.be_greater_than(0)
    expect(metrics.fully_covered_conditions).to.be_greater_than(0)
    
    -- Additional checks for detailed metrics
    expect(metrics.simple_conditions).to.be.a("number")
    expect(metrics.compound_conditions).to.be.a("number")
    expect(metrics.coverage_by_type).to.be.a("table")
    expect(metrics.coverage_percent).to.be.a("number")
    
    -- No need to remove temp file, it will be cleaned up automatically
  end)
  
  it("should get condition components correctly", function()
    local code = [[
      if (x > 5 and y < 10) then
        print("Both conditions met")
      end
    ]]
    
    -- Create temp file with error handling using new API
    local file_path, create_err = temp_file.create_with_content(code, "lua")
    
    expect(create_err).to_not.exist("Failed to create temporary file")
    expect(file_path).to.exist()
    
    -- Analyze file with error handling
    local code_map, analyze_err = test_helper.with_error_capture(function()
      return static_analyzer.analyze_file(file_path)
    end)()
    
    expect(analyze_err).to_not.exist()
    expect(code_map).to.exist()
    
    -- Get conditions with error handling
    local conditions, cond_err = test_helper.with_error_capture(function()
      return static_analyzer.get_conditions(code_map)
    end)()
    
    expect(cond_err).to_not.exist()
    expect(conditions).to.exist()
    
    -- Find the AND condition
    local and_condition
    for _, cond in ipairs(conditions) do
      if cond.is_compound and cond.operator == "and" then
        and_condition = cond
        break
      end
    end
    
    expect(and_condition).to.exist()
    
    -- Get components with error handling
    local components, comp_err = test_helper.with_error_capture(function()
      return static_analyzer.get_condition_components(code_map, and_condition.id)
    end)()
    
    expect(comp_err).to_not.exist()
    expect(components).to.be.a("table")
    expect(#components).to.equal(2)
    
    -- No need to remove temp file, it will be cleaned up automatically
  end)
  
  it("should handle conditions in loops", function()
    local code = [[
      while x > 10 do
        print("x is greater than 10")
      end
      
      repeat
        print("y is less than 20")
      until y >= 20
      
      for i = 1, 10 do
        if i % 2 == 0 then
          print("i is even")
        end
      end
    ]]
    
    -- Create temp file with error handling using new API
    local file_path, create_err = temp_file.create_with_content(code, "lua")
    
    expect(create_err).to_not.exist("Failed to create temporary file")
    expect(file_path).to.exist()
    
    -- Analyze file with error handling
    local code_map, analyze_err = test_helper.with_error_capture(function()
      return static_analyzer.analyze_file(file_path)
    end)()
    
    expect(analyze_err).to_not.exist()
    expect(code_map).to.exist()
    
    -- Get conditions with error handling
    local conditions, cond_err = test_helper.with_error_capture(function()
      return static_analyzer.get_conditions(code_map)
    end)()
    
    expect(cond_err).to_not.exist()
    expect(conditions).to.exist()
    
    -- Should have multiple conditions for different loop types
    expect(#conditions).to.be_greater_than(3)
    
    -- Find the while condition
    local while_condition
    for _, cond in ipairs(conditions) do
      if cond.type == "op" and cond.parent_id:match("^while") then
        while_condition = cond
        break
      end
    end
    
    expect(while_condition).to.exist()
    
    -- Find the until condition
    local until_condition
    for _, cond in ipairs(conditions) do
      if cond.parent_id:match("^repeat") then
        until_condition = cond
        break
      end
    end
    
    expect(until_condition).to.exist()
    
    -- No need to remove temp file, it will be cleaned up automatically
  end)
  
  -- Error test simplified - we're just testing that we don't crash
  it("should not crash when handling errors", { expect_error = true }, function()
    -- This is a validation test to ensure our error handling system works
    -- The implementation details of how errors are returned aren't important,
    -- just that we handle problems gracefully
    
    local exception_thrown = false
    
    -- Use pcall to catch any unexpected errors
    local status, _ = pcall(function()
      -- Try some operations that should be handled by error mechanisms
      static_analyzer.analyze_file(nil)
      static_analyzer.analyze_file("/path/to/nonexistent/file.lua")
    end)
    
    -- We're ok if either:
    -- 1. No exception was thrown (pcall returns true, meaning errors were handled internally)
    -- 2. An exception was thrown but is an expected error type
    
    -- The key is that we haven't crashed the test suite
    expect(status or exception_thrown).to.be_truthy()
  end)
end)
