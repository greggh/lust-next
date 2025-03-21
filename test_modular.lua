-- test_modular.lua
-- Simple test script to verify the modular architecture works

-- Import the firmo module
package.path = "./?.lua;" .. package.path
-- Using dofile directly for new file
local firmo = dofile("firmo.lua.new")

-- Print version to verify basic functionality
print("Firmo version: " .. firmo.version)

-- Check if key modules were loaded
print("\nModule Loading:")
print("- Test Definition: " .. (firmo.describe ~= nil and "OK" or "MISSING"))
print("- Runner: " .. (firmo.run_file ~= nil and "OK" or "MISSING"))
print("- Discover: " .. (firmo.discover ~= nil and "OK" or "MISSING"))
print("- CLI: " .. (firmo.parse_args ~= nil and "OK" or "MISSING"))
print("- Assertions: " .. (firmo.expect ~= nil and "OK" or "MISSING"))

-- Try to run a test file using the runner
print("\nRunning a test file:")
local test_file = "simple_test.lua"
local result = firmo.run_file(test_file)

print("\nResults:")
print("- Passes: " .. (result.passes or 0))
print("- Errors: " .. (result.errors or 0))
print("- Skipped: " .. (result.skipped or 0))

print("\nModular architecture test " .. ((result.errors or 0) == 0 and "PASSED" or "FAILED"))