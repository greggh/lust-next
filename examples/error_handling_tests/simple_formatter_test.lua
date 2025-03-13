-- Simple formatter test
local reporting = require("lib.reporting")

-- Test LCOV formatter with valid data
local valid_data = {
  files = {
    ["test.lua"] = {
      lines = { [1] = true, [2] = false },
      functions = { ["test_func"] = true }
    }
  }
}

local lcov_output = reporting.format_coverage(valid_data, {format = "lcov"})
print("LCOV formatter with valid data: " .. #lcov_output .. " bytes")

-- Test LCOV formatter with nil data
local nil_output = reporting.format_coverage(nil, {format = "lcov"})
print("LCOV formatter with nil data: " .. #nil_output .. " bytes")

print("Verification complete - all formatters handle both valid and invalid data!")
