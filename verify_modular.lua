-- Single test file to verify modular architecture
local firmo = dofile("firmo.lua")

-- Run simple assertions directly
local expect = firmo.expect
expect(1 + 1).to.equal(2)
expect(true).to.be_truthy()
print("Assertions work!")

-- Define and run a simple test block
local describe, it = firmo.describe, firmo.it
describe("Simple test", function()
  it("should pass", function()
    expect(2 * 2).to.equal(4)
  end)
end)
print("Test blocks work!")

-- Verify the runner module works
local test_files = firmo.discover(".", "simple_test.lua")
if test_files and #test_files.files > 0 then
  print("Discover module works!")
end

-- Try running a test file
local result = firmo.run_file("simple_test.lua")
if result and result.success then
  print("Runner module works!")
end

-- Print the current version
print("Firmo version: " .. firmo.version)
print("Modular architecture verified!")