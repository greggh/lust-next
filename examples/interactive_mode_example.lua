#!/usr/bin/env lua
-- Example demonstrating the interactive CLI mode of lust-next
-- This example shows how to use the interactive CLI for running and managing tests

-- Get the root directory of lust-next
local lust_dir = arg[0]:match("(.-)[^/\\]+$") or "./"
if lust_dir == "" then lust_dir = "./" end
lust_dir = lust_dir .. "../"

-- Add necessary directories to package path
package.path = lust_dir .. "?.lua;" .. lust_dir .. "scripts/?.lua;" .. lust_dir .. "src/?.lua;" .. package.path

-- Load lust-next and the interactive module
local lust = require("lust-next")
local interactive = require("src.interactive")

-- Define a simple set of tests
lust.describe("Example Tests for Interactive Mode", function()
  lust.before(function()
    -- Setup code runs before each test
    print("Setting up test environment...")
  end)

  lust.after(function()
    -- Cleanup code runs after each test
    print("Cleaning up test environment...")
  end)

  lust.it("should pass a simple test", function()
    lust.assert.equals(2 + 2, 4)
  end)

  lust.it("can be tagged with 'basic'", function()
    lust.tags('basic')
    lust.assert.is_true(true)
  end)

  lust.it("can be tagged with 'advanced'", function()
    lust.tags('advanced')
    lust.assert.is_false(false)
  end)

  lust.it("demonstrates expect assertions", function()
    lust.expect(5).to.be.a("number")
    lust.expect("test").to_not.be.a("number")
    lust.expect(true).to.be.truthy()
    lust.expect(false).to.be.falsey()
  end)

  lust.describe("Nested test group", function()
    lust.it("should support focused tests", function()
      lust.focus(true) -- This test can be specifically targeted with the focus command
      lust.assert.equals(4 * 4, 16)
    end)

    lust.it("demonstrates mocking", function()
      local original_func = function(x) return x * 2 end
      local mock = lust.mock(original_func)
      
      -- Setup the mock to return a specific value
      mock.returns(42)
      
      -- Call the mocked function
      local result = mock(10)
      
      -- Verify the mock worked
      lust.assert.equals(result, 42)
      lust.assert.is_true(mock.called)
      lust.assert.equals(mock.calls[1][1], 10)
    end)
  end)
end)

-- Start the interactive CLI
print("Starting interactive CLI for lust-next...")
interactive.start(lust, {
  test_dir = lust_dir .. "examples",
  pattern = "interactive_mode_example.lua",
})