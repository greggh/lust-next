#!/usr/bin/env lua
-- Example demonstrating the interactive CLI mode of firmo
-- This example shows how to use the interactive CLI for running and managing tests

-- Get the root directory of firmo
local firmo_dir = arg[0]:match("(.-)[^/\\]+$") or "./"
if firmo_dir == "" then firmo_dir = "./" end
firmo_dir = firmo_dir .. "../"

-- Add necessary directories to package path
package.path = firmo_dir .. "?.lua;" .. firmo_dir .. "scripts/?.lua;" .. firmo_dir .. "src/?.lua;" .. package.path

-- Load firmo and the interactive module
local firmo = require("firmo")
local interactive = require("src.interactive")

-- Define a simple set of tests
firmo.describe("Example Tests for Interactive Mode", function()
  firmo.before(function()
    -- Setup code runs before each test
    print("Setting up test environment...")
  end)

  firmo.after(function()
    -- Cleanup code runs after each test
    print("Cleaning up test environment...")
  end)

  firmo.it("should pass a simple test", function()
    firmo.assert.equals(2 + 2, 4)
  end)

  firmo.it("can be tagged with 'basic'", function()
    firmo.tags('basic')
    firmo.assert.is_true(true)
  end)

  firmo.it("can be tagged with 'advanced'", function()
    firmo.tags('advanced')
    firmo.assert.is_false(false)
  end)

  firmo.it("demonstrates expect assertions", function()
    firmo.expect(5).to.be.a("number")
    firmo.expect("test").to_not.be.a("number")
    firmo.expect(true).to.be.truthy()
    firmo.expect(false).to.be.falsey()
  end)

  firmo.describe("Nested test group", function()
    firmo.it("should support focused tests", function()
      firmo.focus(true) -- This test can be specifically targeted with the focus command
      firmo.assert.equals(4 * 4, 16)
    end)

    firmo.it("demonstrates mocking", function()
      local original_func = function(x) return x * 2 end
      local mock = firmo.mock(original_func)
      
      -- Setup the mock to return a specific value
      mock.returns(42)
      
      -- Call the mocked function
      local result = mock(10)
      
      -- Verify the mock worked
      firmo.assert.equals(result, 42)
      firmo.assert.is_true(mock.called)
      firmo.assert.equals(mock.calls[1][1], 10)
    end)
  end)
end)

-- Start the interactive CLI
print("Starting interactive CLI for firmo...")
interactive.start(firmo, {
  test_dir = firmo_dir .. "examples",
  pattern = "interactive_mode_example.lua",
})
