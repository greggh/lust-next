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
local interactive = require("lib.tools.interactive")

-- Extract test functions for cleaner code
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
local tags, focus = firmo.tags, firmo.focus

-- Define a simple set of tests
describe("Example Tests for Interactive Mode", function()
  before(function()
    -- Setup code runs before each test
    print("Setting up test environment...")
  end)

  after(function()
    -- Cleanup code runs after each test
    print("Cleaning up test environment...")
  end)

  it("should pass a simple test", function()
    expect(2 + 2).to.equal(4)
  end)

  it("can be tagged with 'basic'", function()
    tags('basic')
    expect(true).to.be_truthy()
  end)

  it("can be tagged with 'advanced'", function()
    tags('advanced')
    expect(false).to_not.be_truthy()
  end)

  it("demonstrates expect assertions", function()
    expect(5).to.be.a("number")
    expect("test").to_not.be.a("number")
    expect(true).to.be_truthy()
    expect(false).to_not.be_truthy()
  end)

  describe("Nested test group", function()
    it("should support focused tests", function()
      focus(true) -- This test can be specifically targeted with the focus command
      expect(4 * 4).to.equal(16)
    end)

    it("demonstrates mocking", function()
      local original_func = function(x) return x * 2 end
      local mock = firmo.mock(original_func)
      
      -- Setup the mock to return a specific value
      mock.returns(42)
      
      -- Call the mocked function
      local result = mock(10)
      
      -- Verify the mock worked
      expect(result).to.equal(42)
      expect(mock.called).to.be_truthy()
      expect(mock.calls[1][1]).to.equal(10)
    end)
  end)
end)

-- Note: Run this example using the standard test runner:
-- lua test.lua --interactive examples/interactive_mode_example.lua

-- Start the interactive CLI when run directly
if not arg or #arg < 1 or arg[1] ~= "--no-interactive" then
  print("Starting interactive CLI for firmo...")
  interactive.start(firmo, {
    test_dir = firmo_dir .. "examples",
    pattern = "interactive_mode_example.lua",
  })
end
