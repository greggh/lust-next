--[[
  debug_hook_test.lua
  
  Tests for the debug hook implementation in the coverage module.
  This test verifies that the debug hook properly tracks:
  1. Line execution events
  2. Distinction between execution and coverage
  3. File initialization and tracking
]]

local firmo = require("firmo")
local describe, it, expect, before, after = firmo.describe, firmo.it, firmo.expect, firmo.before, firmo.after
local fs = require("lib.tools.filesystem")
local debug_hook = require("lib.coverage.debug_hook")
local coverage = require("lib.coverage")

describe("Debug Hook Implementation", function()
  -- Set up a temp file that we'll use for testing
  local temp_file_path
  
  before(function()
    -- Create a temp file for testing
    local tmp_dir = os.getenv("TMPDIR") or "/tmp"
    temp_file_path = fs.join_paths(tmp_dir, "debug_hook_test_" .. os.time() .. ".lua")
    local test_code = [[
      -- A simple function with different branches
      local function test_branches(x)
        local result
        
        if x > 10 then
          result = "large"
        elseif x == 0 then
          result = "zero" 
        else
          result = "small"
        end
        
        return result
      end
      
      return test_branches
    ]]
    
    fs.write_file(temp_file_path, test_code)
    
    -- Reset the debug hook before each test
    debug_hook.reset()
  end)
  
  after(function()
    -- Clean up the temp file
    if temp_file_path and fs.file_exists(temp_file_path) then
      os.remove(temp_file_path)
    end
    
    -- Reset the debug hook after each test
    debug_hook.reset()
  end)
  
  describe("Line tracking", function()
    it("should correctly initialize files for tracking", function()
      -- Configure debug hook
      debug_hook.set_config({
        enabled = true,
        track_blocks = true,
        debug = true,
        verbose = true
      })
      
      -- Initialize file tracking
      local file_data = debug_hook.initialize_file(temp_file_path)
      expect(file_data).to.exist()
      expect(debug_hook.has_file(temp_file_path)).to.be_truthy()
    end)
    
    it("should track line execution through track_line function", function()
      -- Configure debug hook
      debug_hook.set_config({
        enabled = true,
        track_blocks = true,
        debug = true,
        verbose = true
      })
      
      -- Initialize file tracking
      debug_hook.initialize_file(temp_file_path)
      
      -- Track a line execution
      debug_hook.track_line(temp_file_path, 5, {
        is_executable = true,
        is_covered = false
      })
      
      -- Verify line was executed but not covered
      expect(debug_hook.was_line_executed(temp_file_path, 5)).to.be_truthy()
      expect(debug_hook.was_line_covered(temp_file_path, 5)).to_not.be_truthy()
      
      -- Track another line with both execution and coverage
      debug_hook.track_line(temp_file_path, 7, {
        is_executable = true,
        is_covered = true
      })
      
      -- Verify line was both executed and covered
      expect(debug_hook.was_line_executed(temp_file_path, 7)).to.be_truthy()
      expect(debug_hook.was_line_covered(temp_file_path, 7)).to.be_truthy()
    end)
    
    it("should distinguish between execution and coverage", function()
      -- Configure debug hook
      debug_hook.set_config({
        enabled = true,
        track_blocks = true,
        debug = true,
        verbose = true
      })
      
      -- Initialize file tracking
      debug_hook.initialize_file(temp_file_path)
      
      -- Track execution of all lines
      for i = 1, 15 do
        debug_hook.track_line(temp_file_path, i, {
          is_executable = true,
          is_covered = false  -- Initially nothing is covered (validated)
        })
      end
      
      -- Verify all lines were executed
      for i = 1, 15 do
        expect(debug_hook.was_line_executed(temp_file_path, i)).to.be_truthy()
        expect(debug_hook.was_line_covered(temp_file_path, i)).to_not.be_truthy()
      end
      
      -- Mark some lines as covered (validated by assertions)
      debug_hook.mark_line_covered(temp_file_path, 5)
      debug_hook.mark_line_covered(temp_file_path, 7)
      debug_hook.mark_line_covered(temp_file_path, 9)
      
      -- Verify execution status is unchanged
      for i = 1, 15 do
        expect(debug_hook.was_line_executed(temp_file_path, i)).to.be_truthy()
      end
      
      -- Verify only the marked lines are considered covered
      expect(debug_hook.was_line_covered(temp_file_path, 5)).to.be_truthy()
      expect(debug_hook.was_line_covered(temp_file_path, 6)).to_not.be_truthy()
      expect(debug_hook.was_line_covered(temp_file_path, 7)).to.be_truthy()
      expect(debug_hook.was_line_covered(temp_file_path, 8)).to_not.be_truthy()
      expect(debug_hook.was_line_covered(temp_file_path, 9)).to.be_truthy()
      expect(debug_hook.was_line_covered(temp_file_path, 10)).to_not.be_truthy()
    end)
  end)
  
  describe("Execution vs coverage in real code", function()
    it("should correctly track execution and coverage in real code", function()
      -- Start coverage tracking
      coverage.start({
        include_patterns = {temp_file_path},
        track_blocks = true,
        debug = true
      })
      
      -- Load the test file
      local success, test_branches = pcall(function() 
        return dofile(temp_file_path)
      end)
      expect(success).to.be_truthy()
      expect(test_branches).to.be.a("function")
      
      -- Exercise different code paths
      local result1 = test_branches(20)  -- Takes the x > 10 branch
      expect(result1).to.equal("large")
      coverage.mark_line_covered(temp_file_path, 6)  -- Validate the line in the first branch
      
      local result2 = test_branches(0)   -- Takes the x == 0 branch
      -- No validation for this branch - execution but not coverage
      
      local result3 = test_branches(5)   -- Takes the else branch
      expect(result3).to.equal("small")
      coverage.mark_line_covered(temp_file_path, 10)  -- Validate the line in the else branch
      
      -- Stop coverage tracking
      coverage.stop()
      
      -- Verify line execution
      expect(coverage.was_line_executed(temp_file_path, 5)).to.be_truthy()   -- if x > 10
      expect(coverage.was_line_executed(temp_file_path, 6)).to.be_truthy()   -- result = "large"
      expect(coverage.was_line_executed(temp_file_path, 7)).to.be_truthy()   -- elseif x == 0
      expect(coverage.was_line_executed(temp_file_path, 8)).to.be_truthy()   -- result = "zero"
      expect(coverage.was_line_executed(temp_file_path, 9)).to.be_truthy()   -- else
      expect(coverage.was_line_executed(temp_file_path, 10)).to.be_truthy()  -- result = "small"
      
      -- Verify line coverage (validated by assertions)
      expect(coverage.was_line_covered(temp_file_path, 5)).to_not.be_truthy() -- if x > 10 - executed but not validated
      expect(coverage.was_line_covered(temp_file_path, 6)).to.be_truthy()     -- result = "large" - validated
      expect(coverage.was_line_covered(temp_file_path, 7)).to_not.be_truthy() -- elseif x == 0 - executed but not validated
      expect(coverage.was_line_covered(temp_file_path, 8)).to_not.be_truthy() -- result = "zero" - executed but not validated 
      expect(coverage.was_line_covered(temp_file_path, 9)).to_not.be_truthy() -- else - executed but not validated
      expect(coverage.was_line_covered(temp_file_path, 10)).to.be_truthy()    -- result = "small" - validated
    end)
  end)
end)
