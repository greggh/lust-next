-- Test for the new tagging and filtering functionality
package.path = "../?.lua;" .. package.path
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Import test_helper for improved error handling
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

describe("Tagging and Filtering", function()
  it("basic test with no tags", function()
    expect(true).to.be.truthy()
  end)

  firmo.tags("unit")
  it("test with unit tag", function()
    expect(1 + 1).to.equal(2)
  end)

  firmo.tags("integration", "slow")
  it("test with integration and slow tags", function()
    expect("integration").to.be.a("string")
  end)

  firmo.tags("unit", "fast")
  it("test with unit and fast tags", function()
    expect({}).to.be.a("table")
  end)

  -- Testing filter pattern matching
  it("test with numeric value 12345", function()
    expect(12345).to.be.a("number")
  end)

  it("test with different numeric value 67890", function()
    expect(67890).to.be.a("number")
  end)
  
  it("should validate tag types", { expect_error = true }, function()
    -- Test with non-string tag
    local result, err = test_helper.with_error_capture(function()
      firmo.tags(123)
    end)()
    
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("Tag must be a string")
  end)
  
  it("should validate filter pattern types", { expect_error = true }, function()
    -- We need to create a temporary testing function since the actual filtering
    -- happens in the runner, not directly callable here
    local function apply_filter(pattern, test_name)
      if type(pattern) ~= "string" then
        error(error_handler.validation_error(
          "Filter pattern must be a string",
          {provided_type = type(pattern)}
        ))
      end
      
      return string.find(test_name, pattern) ~= nil
    end
    
    -- Test with valid pattern
    expect(apply_filter("numeric", "test with numeric value")).to.be_truthy()
    
    -- Test with invalid pattern type
    local result, err = test_helper.with_error_capture(function()
      apply_filter(123, "test with numeric value")
    end)()
    
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
    expect(err.message).to.match("Filter pattern must be a string")
  end)
end)

-- These tests demonstrate how to use the tagging functionality
-- Run with different filters to see how it works:
--
-- Run only unit tests:
--   lua firmo.lua --tags unit tests/tagging_test.lua
--
-- Run only integration tests:
--   lua firmo.lua --tags integration tests/tagging_test.lua
--
-- Run tests with numeric pattern in the name:
--   lua firmo.lua --filter "numeric" tests/tagging_test.lua
--
-- Run tests with specific number pattern:
--   lua firmo.lua --filter "12345" tests/tagging_test.lu
