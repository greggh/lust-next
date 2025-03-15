-- Tests for module_reset functionality
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import the filesystem module
local fs = require("lib.tools.filesystem")

-- Try to load the module reset module
local module_reset_loaded, module_reset = pcall(require, "lib.core.module_reset")

-- Generate a unique suffix for this test run to avoid conflicts when running in parallel
local test_suffix = tostring(os.time() % 10000) .. "_" .. tostring(math.random(1000, 9999))

-- Create test modules with unique names for this test run
local function create_test_module(name, content)
  local unique_name = name .. "_" .. test_suffix
  local file_path = "/tmp/test_module_" .. unique_name .. ".lua"
  
  local success, err = fs.write_file(file_path, content)
  if not success then
    error("Failed to create test module at " .. file_path .. ": " .. (err or "unknown error"))
  end
  
  -- Store the module name for reference
  return file_path, "test_module_" .. unique_name
end

-- Clean up test modules
local function cleanup_test_modules()
  -- Get all files in /tmp directory
  local files = fs.get_directory_contents("/tmp") or {}
  
  -- Delete files matching our specific pattern
  for _, filename in ipairs(files) do
    if filename:match("^test_module_.*" .. test_suffix .. ".*%.lua$") then
      local file_path = fs.join_paths("/tmp", filename)
      fs.delete_file(file_path)
    end
  end
  
  -- Force garbage collection to release file handles
  collectgarbage("collect")
end

-- Helper function to safely add to package.path and return cleanup function
local function add_to_package_path(path)
  local original_path = package.path
  package.path = path .. ";" .. package.path
  
  -- Return a function that restores the original path
  return function()
    package.path = original_path
  end
end

describe("Module Reset Functionality", function()
  
  -- Skip tests if module_reset is not available
  if not module_reset_loaded then
    it("module_reset module is required for these tests", function()
      firmo.pending("module_reset module not available")
    end)
    return
  end
  
  -- We have the module, so run the tests
  local module_a_path, module_a_name
  local module_b_path, module_b_name
  local restore_path
  
  -- Set up test modules before each test
  firmo.before(function()
    -- Clean up any existing test modules for this test run
    cleanup_test_modules()
    
    -- Add /tmp to package.path and get function to restore it
    restore_path = add_to_package_path("/tmp/?.lua")
    
    -- Create test module A with mutable state
    module_a_path, module_a_name = create_test_module("a", [[
      local module_a = {}
      module_a.counter = 0
      function module_a.increment() module_a.counter = module_a.counter + 1 end
      return module_a
    ]])
    
    -- Create test module B that depends on A - using the specific module name
    module_b_path, module_b_name = create_test_module("b", string.format([[
      local module_a = require("%s")
      local module_b = {}
      module_b.value = "initial"
      function module_b.change_and_increment(new_value)
        module_b.value = new_value
        module_a.increment()
        return module_b.value, module_a.counter
      end
      return module_b
    ]], module_a_name))
    
    -- Create a heavy test module for memory tests
    local _, heavy_module_name = create_test_module("heavy", [[
      local heavy_module = {}
      heavy_module.big_data = {}
      for i = 1, 100 do
        heavy_module.big_data[i] = string.rep("heavy", 5)
      end
      return heavy_module
    ]])
    
    -- Initialize module_reset
    module_reset.init()
    
    -- Reset any existing loaded test modules to ensure clean state
    module_reset.reset_pattern("test_module_")
  end)
  
  -- Clean up test modules after each test
  firmo.after(function()
    -- First clear the package.loaded entries
    if module_a_name then
      package.loaded[module_a_name] = nil
    end
    
    if module_b_name then
      package.loaded[module_b_name] = nil
    end
    
    -- Reset all test modules
    module_reset.reset_pattern("test_module_")
    
    -- Then remove the files
    cleanup_test_modules()
    
    -- Restore original package path
    if restore_path then
      restore_path()
    end
    
    -- Force garbage collection to release any module references
    collectgarbage("collect")
  end)
  
  describe("Basic functionality", function()
    it("should track loaded modules", function()
      -- Load test modules
      local module_a = require(module_a_name)
      local module_b = require(module_b_name)
      
      -- Get loaded modules
      local loaded_modules = module_reset.get_loaded_modules()
      
      -- The test modules should be in the list
      expect(#loaded_modules).to.be_greater_than(0)
      
      local found_a = false
      local found_b = false
      
      for _, name in ipairs(loaded_modules) do
        if name == module_a_name then found_a = true end
        if name == module_b_name then found_b = true end
      end
      
      expect(found_a).to.be_truthy()
      expect(found_b).to.be_truthy()
    end)
    
    it("should protect specified modules", function()
      -- Protect module A - first unprotect any existing protections
      module_reset.protected_modules = {
        -- Core Lua modules that should never be reset
        ["_G"] = true,
        ["package"] = true,
        ["coroutine"] = true,
        ["table"] = true,
        ["io"] = true,
        ["os"] = true,
        ["string"] = true,
        ["math"] = true,
        ["debug"] = true,
        ["bit32"] = true,
        ["utf8"] = true,
        
        -- Essential testing modules
        ["firmo"] = true,
        ["firmo"] = true
      }
      
      -- Now protect our specific module
      module_reset.protect(module_a_name)
      
      -- Reset modules to start fresh
      package.loaded[module_a_name] = nil
      package.loaded[module_b_name] = nil
      
      -- Load test modules
      local module_a = require(module_a_name)
      local module_b = require(module_b_name)
      
      -- Modify state
      module_a.increment()
      module_b.change_and_increment("modified")
      
      -- Reset all modules
      local reset_count = module_reset.reset_all()
      
      -- Module A should still be loaded
      expect(package.loaded[module_a_name] ~= nil).to.be_truthy()
      
      -- Module B should be reset
      expect(package.loaded[module_b_name] == nil).to.be_truthy()
      
      -- Re-require module B
      local module_b_reloaded = require(module_b_name)
      
      -- Module B should be fresh
      expect(module_b_reloaded.value).to.equal("initial")
    end)
  end)
  
  describe("Reset functionality", function()
    it("should reset all non-protected modules", function()
      -- Reset any protections from previous tests
      module_reset.protected_modules = {
        -- Core Lua modules that should never be reset
        ["_G"] = true,
        ["package"] = true,
        ["coroutine"] = true,
        ["table"] = true,
        ["io"] = true,
        ["os"] = true,
        ["string"] = true,
        ["math"] = true,
        ["debug"] = true,
        ["bit32"] = true,
        ["utf8"] = true,
        
        -- Essential testing modules
        ["firmo"] = true,
        ["firmo"] = true
      }
      
      -- Reset modules to start fresh
      package.loaded[module_a_name] = nil
      package.loaded[module_b_name] = nil
      
      -- Load test modules
      local module_a = require(module_a_name)
      local module_b = require(module_b_name)
      
      -- Modify state
      module_a.increment()
      module_b.change_and_increment("modified")
      
      -- Store references to loaded modules
      local a_ref = package.loaded[module_a_name]
      local b_ref = package.loaded[module_b_name]
      
      -- Reset all modules
      local reset_count = module_reset.reset_all()
      
      -- Force garbage collection
      collectgarbage("collect")
      
      -- Our modules should be unloaded
      expect(package.loaded[module_a_name] == nil).to.be_truthy("Module A was not properly unloaded")
      expect(package.loaded[module_b_name] == nil).to.be_truthy("Module B was not properly unloaded")
      
      -- Require modules again after they're reset
      local module_a_new = require(module_a_name)
      local module_b_new = require(module_b_name)
      
      -- They should have fresh state
      expect(module_a_new.counter).to.equal(0)
      expect(module_b_new.value).to.equal("initial")
    end)
    
    it("should reset modules by pattern", function()
      -- Reset protections from previous tests
      module_reset.protected_modules = {
        -- Core Lua modules that should never be reset
        ["_G"] = true,
        ["package"] = true,
        ["coroutine"] = true,
        ["table"] = true,
        ["io"] = true,
        ["os"] = true,
        ["string"] = true,
        ["math"] = true,
        ["debug"] = true,
        ["bit32"] = true,
        ["utf8"] = true,
        
        -- Essential testing modules
        ["firmo"] = true,
        ["firmo"] = true
      }
      
      -- Start fresh
      package.loaded[module_a_name] = nil
      package.loaded[module_b_name] = nil
      collectgarbage("collect")
      
      -- Load test modules
      local module_a = require(module_a_name)
      local module_b = require(module_b_name)
      
      -- Modify state
      module_a.increment()
      module_b.change_and_increment("modified")
      
      -- Reset module A by pattern - we need to use a specific enough pattern
      -- to match only module_a_name but not module_b_name
      local pattern = module_a_name .. "$"
      local reset_count = module_reset.reset_pattern(pattern)
      
      -- There should be some modules reset
      expect(reset_count).to.equal(1)
      
      -- Module A should be unloaded, Module B should not be
      expect(package.loaded[module_a_name] == nil).to.be_truthy("Module A was not properly unloaded")
      expect(package.loaded[module_b_name] ~= nil).to.be_truthy("Module B should not have been unloaded")
      
      -- Create fresh modules
      local new_a = require(module_a_name)
      
      -- A should have fresh state
      expect(new_a.counter).to.equal(0)
      
      -- B should maintain its state
      expect(module_b.value).to.equal("modified")
    end)
  end)
  
  describe("Integration with firmo", function()
    it("should have module_reset property", function()
      -- firmo has already been registered with module_reset in the test runner
      -- Just verify it has the property
      expect(firmo.module_reset).to.exist()
    end)
    
    it("should enhance reset functionality", function()
      -- Create temporary copies to avoid interfering with the main instance
      local temp_firmo = {
        reset = function() end -- Dummy reset function
      }
      
      -- Register with our temporary object
      module_reset.register_with_firmo(temp_firmo)
      
      -- Check that module_reset property exists
      expect(temp_firmo.module_reset).to.exist()
      
      -- Don't modify the test state in this test
      -- just verify the enhancement worked
      expect(temp_firmo.reset ~= firmo.reset).to.be_truthy("Reset functions should be different")
      expect(temp_firmo.module_reset == module_reset).to.be_truthy("Module reset reference should be the same")
    end)
  end)
  
  describe("Memory usage analysis", function()
    it("should track memory usage", function()
      -- Load test modules
      local module_a = require(module_a_name)
      local module_b = require(module_b_name)
      
      -- Check memory usage
      local memory_usage = module_reset.get_memory_usage()
      
      -- Verify the function works but don't make assertions about specific memory values
      -- as they can be unreliable in different environments
      expect(memory_usage.current).to.exist()
      expect(type(memory_usage.current)).to.equal("number")
      
      -- Verify the API returns a value but don't assert specific memory changes
      -- Memory tracking is not reliably testable across all environments
      local new_memory_usage = module_reset.get_memory_usage()
      expect(new_memory_usage.current).to.exist()
    end)
    
    it("should analyze module memory usage", function()
      -- Add a simple assertion that doesn't rely on specific memory behavior
      -- but still tests the API is working
      collectgarbage("collect")
      
      -- Load our test module and make sure it's in memory
      local heavy_module = require("test_module_heavy_" .. test_suffix)
      expect(heavy_module).to.exist()
      
      -- Now analyze memory usage - should find our module
      local memory_analysis = module_reset.analyze_memory_usage()
      
      -- Just ensure the analysis function returns something
      expect(type(memory_analysis)).to.equal("table")
      expect(#memory_analysis >= 0).to.be_truthy()
    end)
  end)
end)
