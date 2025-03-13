-- Test script for all formatters with edge cases
local formatters = {
  coverage = {},
  quality = {},
  results = {}
}

-- Load formatter registry
local init = require("lib.reporting.formatters.init")
init.register_all(formatters)

print("Successfully loaded formatters:")
for type, formatters_by_type in pairs(formatters) do
  local formatter_names = {}
  for name, _ in pairs(formatters_by_type) do
    table.insert(formatter_names, name)
  end
  print("  " .. type .. ": " .. table.concat(formatter_names, ", "))
end

-- Create minimal valid test data
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
  },
  summary = {
    total_files = 1,
    covered_files = 1,
    total_lines = 2,
    covered_lines = 1,
    total_functions = 1,
    covered_functions = 1,
    overall_percent = 50.0
  }
}

local results_data = {
  total = 2,
  failures = 1,
  errors = 0,
  skipped = 0,
  duration = 0.01,
  test_cases = {
    {
      name = "test_success",
      status = "pass",
      duration = 0.005
    },
    {
      name = "test_failure",
      status = "fail",
      duration = 0.005,
      message = "Expected 2 to equal 3",
      trace = "test.lua:123"
    }
  }
}

print("\n--- Testing with valid data ---")
-- Test all coverage formatters
for name, formatter in pairs(formatters.coverage) do
  local success, result
  success, result = pcall(function() return formatter(coverage_data) end)
  print("  Coverage formatter '" .. name .. "': " .. (success and "OK" or "FAILED") .. 
        " (output length: " .. (success and #result or 0) .. ")")
end

-- Test all results formatters
for name, formatter in pairs(formatters.results) do
  local success, result
  success, result = pcall(function() return formatter(results_data) end)
  print("  Results formatter '" .. name .. "': " .. (success and "OK" or "FAILED") .. 
        " (output length: " .. (success and #result or 0) .. ")")
end

print("\n--- Testing with nil data ---")
-- Test all coverage formatters with nil data
for name, formatter in pairs(formatters.coverage) do
  local success, result
  success, result = pcall(function() return formatter(nil) end)
  print("  Coverage formatter '" .. name .. "' with nil data: " .. 
        (success and "OK" or "FAILED") .. 
        " (output length: " .. (success and #result or 0) .. ")")
end

-- Test all results formatters with nil data
for name, formatter in pairs(formatters.results) do
  local success, result
  success, result = pcall(function() return formatter(nil) end)
  print("  Results formatter '" .. name .. "' with nil data: " .. 
        (success and "OK" or "FAILED") .. 
        " (output length: " .. (success and #result or 0) .. ")")
end
