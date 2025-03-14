--[[
  execution_vs_coverage_test.lua
  
  Tests for verifying the distinction between execution (code that runs) and 
  coverage (code validated by tests) in the lust-next coverage module.
--]]

local lust = require("lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect
local before, after = lust.before, lust.after

local coverage = require("lib.coverage")
local debug_hook = require("lib.coverage.debug_hook")
local fs = require("lib.tools.filesystem")

-- Create a temporary file for testing
local function create_temp_test_file(content)
  local file_path = os.tmpname() .. ".lua"
  local file = io.open(file_path, "w")
  file:write(content)
  file:close()
  return file_path
end

-- Remove a temporary file
local function remove_temp_file(file_path)
  os.remove(file_path)
end

-- Sample code with conditionals for testing execution vs. coverage
local sample_code = [[
local M = {}

-- Function with conditional branches
function M.evaluate(value)
  local result = ""
  
  -- Branch 1
  if value < 0 then
    result = "negative"
  -- Branch 2
  elseif value == 0 then
    result = "zero"
  -- Branch 3
  else
    result = "positive"
  end
  
  -- This line always executes
  return result
end

return M
]]

describe("Execution vs. Coverage Distinction", function()
  local test_file_path
  
  before(function()
    -- Create a temp file for testing
    test_file_path = create_temp_test_file(sample_code)
    
    -- Initialize coverage for just this file
    coverage.init({
      enabled = true,
      debug = true,
      include = {test_file_path},
      exclude = {},
      track_blocks = true,
      track_conditions = true,
    })
    
    -- Start coverage
    coverage.start()
  end)
  
  after(function()
    -- Stop coverage tracking
    coverage.stop()
    
    -- Clean up temp file
    remove_temp_file(test_file_path)
  end)
  
  it("should properly initialize _executed_lines in file data", function()
    -- Load the test module
    local chunk, err = loadfile(test_file_path)
    expect(chunk).to.exist()
    
    local test_module = chunk()
    
    -- Call the function but don't validate result (only execution)
    local result = test_module.evaluate(5)
    
    -- Check that file data was initialized with _executed_lines
    local file_data = debug_hook.get_file_data(test_file_path)
    expect(file_data).to.exist()
    expect(file_data._executed_lines).to.exist()
    expect(type(file_data._executed_lines)).to.equal("table")
  end)
  
  it("should track lines as executed when code runs", function()
    -- Reset coverage for clean state
    coverage.reset()
    coverage.start()
    
    -- Load the test module
    local chunk, err = loadfile(test_file_path)
    local test_module = chunk()
    
    -- Call the function with a positive value (should execute the 'else' branch)
    local result = test_module.evaluate(5)
    
    -- Check that lines were marked as executed
    local executed_lines = debug_hook.get_file_executed_lines(test_file_path)
    expect(executed_lines).to.exist()
    
    -- The function declaration and the 'else' branch should be executed
    expect(executed_lines[4]).to.be_truthy() -- function declaration
    expect(executed_lines[14]).to.be_truthy() -- else branch
    expect(executed_lines[15]).to.be_truthy() -- result = "positive"
    expect(executed_lines[19]).to.be_truthy() -- return statement
    
    -- The negative and zero branches should not be executed
    expect(executed_lines[8]).to_not.be_truthy() -- negative branch
    expect(executed_lines[11]).to_not.be_truthy() -- zero branch
  end)
  
  it("should track lines as covered only when they're validated by tests", function()
    -- Reset coverage for clean state
    coverage.reset()
    coverage.start()
    
    -- Load the test module
    local chunk, err = loadfile(test_file_path)
    local test_module = chunk()
    
    -- Execute with a positive value but don't validate
    local result1 = test_module.evaluate(5)
    
    -- Execute with a negative value and validate with a test assertion
    local result2 = test_module.evaluate(-10)
    expect(result2).to.equal("negative")
    
    -- Explicitly track the negative branch as covered using track_line
    -- This simulates what a test framework would do
    coverage.track_line(test_file_path, 8) -- if value < 0 then
    coverage.track_line(test_file_path, 9) -- result = "negative"
    
    -- Get both executed and covered lines
    local executed_lines = debug_hook.get_file_executed_lines(test_file_path)
    local covered_lines = debug_hook.get_file_covered_lines(test_file_path)
    
    -- Both branches should be executed
    expect(executed_lines[8]).to.be_truthy() -- negative branch
    expect(executed_lines[9]).to.be_truthy() -- result = "negative"
    expect(executed_lines[14]).to.be_truthy() -- else branch
    expect(executed_lines[15]).to.be_truthy() -- result = "positive"
    
    -- Only the negative branch should be covered (validated by test)
    expect(covered_lines[8]).to.be_truthy() -- negative branch (covered)
    expect(covered_lines[9]).to.be_truthy() -- result = "negative" (covered)
    
    -- The positive branch should be executed but not covered
    expect(covered_lines[14]).to_not.be_truthy() -- else branch (not covered)
    expect(covered_lines[15]).to_not.be_truthy() -- result = "positive" (not covered)
  end)
  
  it("should correctly distinguish 'was_line_executed' from 'was_line_covered'", function()
    -- Reset coverage for clean state
    coverage.reset()
    coverage.start()
    
    -- Load the test module
    local chunk, err = loadfile(test_file_path)
    local test_module = chunk()
    
    -- Execute the zero branch but don't validate
    local result = test_module.evaluate(0)
    
    -- The zero branch should be executed but not covered
    expect(debug_hook.was_line_executed(test_file_path, 11)).to.be_truthy()
    expect(debug_hook.was_line_covered(test_file_path, 11)).to_not.be_truthy()
    
    -- Now mark the zero branch as covered
    coverage.track_line(test_file_path, 11)
    
    -- The zero branch should now be both executed and covered
    expect(debug_hook.was_line_executed(test_file_path, 11)).to.be_truthy()
    expect(debug_hook.was_line_covered(test_file_path, 11)).to.be_truthy()
  end)
  
  it("should properly track different branches through multiple executions", function()
    -- Reset coverage for clean state
    coverage.reset()
    coverage.start()
    
    -- Load the test module
    local chunk, err = loadfile(test_file_path)
    local test_module = chunk()
    
    -- Execute each branch once
    local result1 = test_module.evaluate(-5) -- negative branch
    local result2 = test_module.evaluate(0)  -- zero branch
    local result3 = test_module.evaluate(5)  -- positive branch
    
    -- Verify all branches were executed
    expect(debug_hook.was_line_executed(test_file_path, 8)).to.be_truthy()  -- negative branch
    expect(debug_hook.was_line_executed(test_file_path, 11)).to.be_truthy() -- zero branch
    expect(debug_hook.was_line_executed(test_file_path, 14)).to.be_truthy() -- positive branch
    
    -- Only validate the negative and positive branches
    coverage.track_line(test_file_path, 8)  -- if value < 0
    coverage.track_line(test_file_path, 9)  -- result = "negative"
    coverage.track_line(test_file_path, 14) -- else
    coverage.track_line(test_file_path, 15) -- result = "positive"
    
    -- Verify only validated branches are marked as covered
    expect(debug_hook.was_line_covered(test_file_path, 8)).to.be_truthy()  -- negative branch (covered)
    expect(debug_hook.was_line_covered(test_file_path, 11)).to_not.be_truthy() -- zero branch (not covered)
    expect(debug_hook.was_line_covered(test_file_path, 14)).to.be_truthy() -- positive branch (covered)
  end)
  
  it("should track execution even when using explicit track_execution API", function()
    -- Reset coverage for clean state
    coverage.reset()
    coverage.start()
    
    -- Load the test module
    local chunk, err = loadfile(test_file_path)
    local test_module = chunk()
    
    -- Don't execute any code, but use explicit tracking API
    
    -- Use track_execution API to mark the zero branch as executed
    -- This is useful when debug hook might miss certain executions
    if coverage.track_execution then -- Check if function exists
      coverage.track_execution(test_file_path, 11) -- zero branch
      coverage.track_execution(test_file_path, 12) -- result = "zero"
    else
      -- Fall back to the debug hook API for marking execution
      debug_hook.set_line_executed(test_file_path, 11, true)
      debug_hook.set_line_executed(test_file_path, 12, true)
    end
    
    -- Verify the lines are marked as executed
    expect(debug_hook.was_line_executed(test_file_path, 11)).to.be_truthy() -- zero branch
    expect(debug_hook.was_line_executed(test_file_path, 12)).to.be_truthy() -- result = "zero"
    
    -- But they should not be marked as covered
    expect(debug_hook.was_line_covered(test_file_path, 11)).to_not.be_truthy() -- zero branch
    expect(debug_hook.was_line_covered(test_file_path, 12)).to_not.be_truthy() -- result = "zero"
  end)
  
  it("should handle non-executable lines correctly", function()
    -- Reset coverage for clean state
    coverage.reset()
    coverage.start()
    
    -- Load the test module
    local chunk, err = loadfile(test_file_path)
    local test_module = chunk()
    
    -- Execute the function once
    local result = test_module.evaluate(5)
    
    -- Ensure comment lines are not marked as executed or covered
    expect(debug_hook.was_line_executed(test_file_path, 2)).to_not.be_truthy() -- comment line
    expect(debug_hook.was_line_covered(test_file_path, 2)).to_not.be_truthy() -- comment line
    
    -- Check function header line - should be executable and executed, but not covered
    expect(debug_hook.was_line_executed(test_file_path, 4)).to.be_truthy() -- function definition
    -- Function declarations are not considered "covered" in the traditional sense
    -- but they are counted as executed
  end)
  
  it("should expose a clear API for distinguishing execution vs. coverage", function()
    -- This test verifies the public API exists for distinguishing execution vs. coverage
    expect(debug_hook.get_file_executed_lines).to.exist()
    expect(debug_hook.get_file_covered_lines).to.exist()
    expect(debug_hook.was_line_executed).to.exist()
    expect(debug_hook.was_line_covered).to.exist()
    
    -- If track_execution API exists, verify it
    if coverage.track_execution then
      expect(coverage.track_execution).to.exist()
    end
    
    -- The track_line API should always exist
    expect(coverage.track_line).to.exist()
  end)
  
  it("should provide separate execution and coverage states in coverage data", function()
    -- Reset coverage for clean state
    coverage.reset()
    coverage.start()
    
    -- Load the test module
    local chunk, err = loadfile(test_file_path)
    local test_module = chunk()
    
    -- Execute all branches
    test_module.evaluate(-5)
    test_module.evaluate(0)
    test_module.evaluate(5)
    
    -- Mark the negative branch as covered
    coverage.track_line(test_file_path, 8)
    coverage.track_line(test_file_path, 9)
    
    -- Get the raw coverage data
    local raw_data = coverage.get_raw_data()
    
    -- Should have separate tracking for executed and covered
    expect(raw_data.executed_lines).to.exist()
    expect(raw_data.covered_lines).to.exist()
    
    -- Validate a few examples
    local normalized_path = fs.normalize_path(test_file_path)
    expect(raw_data.executed_lines[normalized_path .. ":8"]).to.be_truthy() -- negative branch executed
    
    -- Only the negative branch should be marked as covered
    expect(raw_data.covered_lines[normalized_path .. ":8"]).to.be_truthy() -- negative branch covered
    expect(raw_data.covered_lines[normalized_path .. ":11"]).to_not.be_truthy() -- zero branch not covered
  end)
end)