-- Test for expected errors

local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

describe("Expected Error Tests", function()
  describe("With expect_error flag", function()
    it("should handle expected errors correctly", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        error("This is an expected error")
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(tostring(err)).to.match("This is an expected error")
    end)
    
    it("should detect wrong error messages", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        error("Actual error message")
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(tostring(err)).to.match("Actual error message")
      -- This would fail if uncommented:
      -- expect(tostring(err)).to.match("Wrong error message")
    end)
  end)
end)
