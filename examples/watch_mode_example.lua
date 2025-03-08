-- Example of using watch mode in lust-next
-- Run with: env -C /home/gregg/Projects/lua-library/lust-next lua scripts/run_tests.lua --watch examples/watch_mode_example.lua

-- Add paths for proper module loading
local script_path = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
package.path = script_path .. "../?.lua;" .. script_path .. "../scripts/?.lua;" .. script_path .. "../src/?.lua;" .. package.path

-- Load lust-next
local lust = require("lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect

-- Create a simple test suite
describe("Watch Mode Example", function()
  
  -- Simple passing test
  it("should pass a simple test", function()
    expect(1 + 1).to.equal(2)
  end)
  
  -- Another passing test
  it("should handle string operations", function()
    expect("hello").to.match("^h")
    expect("hello").to.contain("ell")
    expect(#"hello").to.equal(5)
  end)
  
  -- Test that will fail (uncomment to see watch mode detect failures)
  -- it("should fail when uncommented", function()
  --   expect(true).to.be(false)
  -- end)
  
  describe("Nested tests", function()
    it("should support nesting", function()
      expect(true).to.be(true)
    end)
    
    it("should handle tables", function()
      local t = {a = 1, b = 2}
      expect(t.a).to.equal(1)
      expect(t.b).to.equal(2)
      expect(t).to.have_field("a")
    end)
  end)
end)

-- If running this file directly, print usage instructions
if arg[0]:match("watch_mode_example%.lua$") then
  print("\nWatch Mode Example")
  print("=================")
  print("This file demonstrates the watch mode functionality for continuous testing.")
  print("")
  print("To run with watch mode, use:")
  print("  env -C /home/gregg/Projects/lua-library/lust-next lua scripts/run_tests.lua --watch examples/watch_mode_example.lua")
  print("")
  print("Watch mode will:")
  print("1. Run the tests in this file")
  print("2. Watch for changes to any files")
  print("3. Automatically re-run tests when changes are detected")
  print("4. Continue until you press Ctrl+C")
  print("")
  print("Try editing this file while watch mode is running to see the tests automatically re-run.")
  print("")
  print("Tips:")
  print("- Uncomment the 'failing test' sections to see failure detection")
  print("- Add new tests to see them get picked up automatically")
  print("- Try changing test assertions to see how the system responds")
end