#!/usr/bin/env lua
-- Module reset example for firmo
-- This example demonstrates how to use the module reset functionality
-- to improve test isolation between test files.
--
-- This is a simple interactive demo that can be run directly.
-- For more comprehensive examples and testing patterns, see:
-- examples/module_reset_examples.md

local firmo = require("firmo")

print("firmo Module Reset Example")
print("----------------------------")

-- Check if module_reset is available
local module_reset_available = package.loaded["lib.core.module_reset"] ~= nil

-- If not specifically loaded, try other possible locations
if not module_reset_available then
  module_reset_available = (
    pcall(require, "lib.core.module_reset") or
    pcall(require, "src.module_reset") or
    pcall(require, "module_reset")
  )
end

local fs = require("lib.tools.filesystem")

-- Create test modules
local function create_test_module(name, content)
  local file_path = os.tmpname()
  local success, err = fs.write_file(file_path, content)
  if not success then
    error("Failed to create test module: " .. (err or "unknown error"))
  end
  
  -- Store module path for later requiring
  _G["_test_module_" .. name .. "_path"] = file_path
  
  return file_path
end

-- Create test module A
local module_a_path = create_test_module("a", [[
  local module_a = {}
  module_a.counter = 0
  module_a.name = "Module A"
  
  function module_a.increment()
    module_a.counter = module_a.counter + 1
    return module_a.counter
  end
  
  print("Module A loaded with counter = " .. module_a.counter)
  
  return module_a
]])

-- Load module_a using dofile (since it's not in the require path)
_G.module_a = dofile(module_a_path)

-- Function to simulate running test 1
local function run_test_1()
  print("\nRunning Test 1:")
  print("  Initial counter value: " .. _G.module_a.counter)
  print("  Incrementing counter")
  _G.module_a.increment()
  print("  Counter after test: " .. _G.module_a.counter)
end

-- Function to simulate running test 2
local function run_test_2()
  print("\nRunning Test 2:")
  print("  Initial counter value: " .. _G.module_a.counter)
  print("  Incrementing counter twice")
  _G.module_a.increment()
  _G.module_a.increment()
  print("  Counter after test: " .. _G.module_a.counter)
end

-- Function to simulate module reset between tests
local function reset_modules()
  print("\nResetting modules...")
  
  -- Basic reset method - just nullify global variable and reload
  _G.module_a = nil
  collectgarbage("collect")
  
  -- Reload module
  _G.module_a = dofile(_G._test_module_a_path)
end

-- Run test demo
print("\n== Demo: Running Tests Without Module Reset ==")
print("This demonstrates how state persists between tests when not using module reset.")

run_test_1()  -- Should start with counter = 0
run_test_2()  -- Will start with counter = 1 from previous test

print("\n== Demo: Running Tests With Module Reset ==")
print("This demonstrates how module reset ensures each test starts with fresh state.")

run_test_1()  -- Should start with counter = 0
reset_modules()
run_test_2()  -- Should also start with counter = 0 due to reset

-- Information about the enhanced module reset system
print("\n== Enhanced Module Reset System ==")
if module_reset_available then
  print("The enhanced module reset system is available in firmo.")
  print("This provides automatic module reset between test files when using run_all_tests.lua.")
  print("\nTo use it in your test runner:")
  print("1. Require the module: local module_reset = require('lib.core.module_reset')")
  print("2. Register with firmo: module_reset.register_with_firmo(firmo)")
  print("3. Configure options: module_reset.configure({ reset_modules = true })")
  print("\nThe run_all_tests.lua script does this automatically when available.")
else
  print("The enhanced module reset system is not available in this installation.")
  print("The demonstration above shows a simple manual method for module reset.")
  print("\nTo get the enhanced system, make sure lib/core/module_reset.lua is in your project.")
end

-- Clean up temporary files
local success, err = fs.delete_file(_G._test_module_a_path)
if not success then
  print("Warning: Failed to delete test module: " .. (err or "unknown error"))
end
_G._test_module_a_path = nil
