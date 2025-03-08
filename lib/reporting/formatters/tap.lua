-- TAP (Test Anything Protocol) formatter
local M = {}

-- Helper function to format test case result
local function format_test_case(test_case, test_number)
  -- Basic TAP test line
  local line
  
  if test_case.status == "pass" then
    line = string.format("ok %d - %s", test_number, test_case.name)
  elseif test_case.status == "pending" or test_case.status == "skipped" then
    line = string.format("ok %d - %s # SKIP %s", 
      test_number, 
      test_case.name,
      test_case.skip_reason or "Not implemented yet")
  else
    -- Failed or errored test
    line = string.format("not ok %d - %s", test_number, test_case.name)
    
    -- Add diagnostic info if available
    if test_case.failure or test_case.error then
      local message = test_case.failure and test_case.failure.message or 
                      test_case.error and test_case.error.message or "Test failed"
      
      local details = test_case.failure and test_case.failure.details or 
                      test_case.error and test_case.error.details or ""
      
      local diag = {
        "  ---",
        "  message: " .. (message or ""),
        "  severity: " .. (test_case.status == "error" and "error" or "fail"),
        "  ..."
      }
      
      if details and details ~= "" then
        diag[3] = "  data: |"
        local detail_lines = {}
        for line in details:gmatch("([^\n]+)") do
          table.insert(detail_lines, "    " .. line)
        end
        table.insert(diag, 3, table.concat(detail_lines, "\n"))
      end
      
      -- Append diagnostic lines
      line = line .. "\n" .. table.concat(diag, "\n")
    end
  end
  
  return line
end

-- Format test results as TAP (Test Anything Protocol)
function M.format_results(results_data)
  -- Validate the input data
  if not results_data or not results_data.test_cases then
    return "1..0\n# No tests run"
  end
  
  local lines = {}
  
  -- TAP version header
  table.insert(lines, "TAP version 13")
  
  -- Plan line with total number of tests
  local test_count = #results_data.test_cases
  table.insert(lines, string.format("1..%d", test_count))
  
  -- Add test case results
  for i, test_case in ipairs(results_data.test_cases) do
    table.insert(lines, format_test_case(test_case, i))
  end
  
  -- Add summary line
  table.insert(lines, string.format("# tests %d", test_count))
  table.insert(lines, string.format("# pass %d", test_count - (results_data.failures or 0) - (results_data.errors or 0)))
  
  if results_data.failures and results_data.failures > 0 then
    table.insert(lines, string.format("# fail %d", results_data.failures))
  end
  
  if results_data.errors and results_data.errors > 0 then
    table.insert(lines, string.format("# error %d", results_data.errors))
  end
  
  if results_data.skipped and results_data.skipped > 0 then
    table.insert(lines, string.format("# skip %d", results_data.skipped))
  end
  
  -- Join all lines with newlines
  return table.concat(lines, "\n")
end

-- Register formatter
return function(formatters)
  formatters.results.tap = M.format_results
end