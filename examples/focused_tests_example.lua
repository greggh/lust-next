-- Example of using focus and exclude features in lust-next
package.path = "../?.lua;" .. package.path
local lust_next = require("lust-next")

-- Extract the functions we need
local describe = lust_next.describe
local fdescribe = lust_next.fdescribe
local xdescribe = lust_next.xdescribe
local it = lust_next.it
local fit = lust_next.fit
local xit = lust_next.xit
local expect = lust_next.expect

-- Set formatting options (these can be overridden by command line args)
-- Check if we're running directly or through the test runner
local is_direct = not arg or not arg[0]:match("lust%-next%.lua$")
-- Create a counter to verify excluded tests don't run
local excluded_test_ran = false

if is_direct then
  -- Reset state when running directly
  lust_next.focus_mode = false
  lust_next.skipped = 0
  
  lust_next.format({
    use_color = true,
    indent_char = '  ', -- use 2 spaces instead of tabs
    indent_size = 1,
    show_success_detail = true
  })
end

-- Standard describe block
describe("Standard tests", function()
  it("runs normally", function()
    expect(1 + 1).to.equal(2)
  end)
  
  it("also runs normally", function()
    expect("test").to.be.a("string")
  end)
  
  -- Focused test - only this will run if we're in focus mode
  fit("is focused and will always run", function()
    expect(true).to.be.truthy()
  end)
  
  -- Excluded test - this will be skipped
  xit("is excluded and will not run", function()
    excluded_test_ran = true
    expect(false).to.be.truthy() -- This would fail if it ran
  end)
end)

-- Focused describe block - all tests inside will run even in focus mode
fdescribe("Focused test group", function()
  it("will run because parent is focused", function()
    expect({1, 2, 3}).to.contain(2)
  end)
  
  it("also runs because parent is focused", function()
    expect("hello").to.match("he..o")
  end)
  
  -- Excluded test still doesn't run even in focused parent
  xit("is excluded despite focused parent", function()
    expect(nil).to.exist() -- Would fail if it ran
  end)
end)

-- Excluded describe block - none of these tests will run
xdescribe("Excluded test group", function()
  it("will not run because parent is excluded", function()
    expect(1).to.be(2) -- Would fail if it ran
  end)
  
  fit("focused but parent is excluded so still won't run", function()
    expect(false).to.be.truthy() -- Would fail if it ran
  end)
end)

-- Example of better error messages
describe("Enhanced error messages", function()
  it("shows detailed diffs for tables", function()
    local expected = {
      name = "example",
      values = {1, 2, 3, 4},
      nested = {
        key = "value",
        another = true
      }
    }
    
    local actual = {
      name = "example",
      values = {1, 2, 3, 5},  -- Different value here (5 instead of 4)
      nested = {
        key = "wrong",        -- Different value here
        extra = "field"       -- Extra field here
      }
    }
    
    expect(actual).to.equal(expected) -- This will fail with a detailed diff
  end)
end)

-- Only show the instruction message if we're running the file directly
if is_direct then
  print("\n-- Example complete --")
  print("Excluded test execution check: " .. 
    (excluded_test_ran and "FAILED - excluded test was run!" or "PASSED - excluded test was properly skipped"))
  print("Try running this file with: lua lust-next.lua examples/focused_tests_example.lua --format dot")
  print("Or try other format options: --format compact, --format summary, etc.")
end