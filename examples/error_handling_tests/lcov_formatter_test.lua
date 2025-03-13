-- Test script for LCOV formatter
local formatters = {
  coverage = {},
  quality = {},
  results = {}
}

-- Load formatter registry
local init = require("lib.reporting.formatters.init")
init.register_all(formatters)

-- Create minimal coverage data
local coverage_data = {
  files = {
    ["test.lua"] = {
      lines = {
        [1] = true, -- covered
        [2] = false -- not covered
      },
      functions = {
        ["test_func"] = true
      },
      functions_info = {
        ["test_func"] = {
          line = 1,
          execution_count = 5
        }
      }
    }
  }
}

-- Format the coverage data
local lcov_output = formatters.coverage.lcov(coverage_data)
print(lcov_output)

-- Test with invalid data
print("\n--- Testing with nil data ---")
local nil_output = formatters.coverage.lcov(nil)
print("Output length: " .. #nil_output)

-- Test with empty files
print("\n--- Testing with empty files ---")
local empty_output = formatters.coverage.lcov({files = {}})
print("Output length: " .. #empty_output)
