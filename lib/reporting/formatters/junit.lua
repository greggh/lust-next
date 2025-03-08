-- JUnit XML formatter for test results
local M = {}

-- Helper function to escape XML special characters
local function escape_xml(str)
  if type(str) ~= "string" then
    return tostring(str or "")
  end
  
  return str:gsub("&", "&amp;")
            :gsub("<", "&lt;")
            :gsub(">", "&gt;")
            :gsub("\"", "&quot;")
            :gsub("'", "&apos;")
end

-- Format test results as JUnit XML (commonly used for CI integration)
function M.format_results(results_data)
  -- Validate the input data
  if not results_data or not results_data.test_cases then
    return '<?xml version="1.0" encoding="UTF-8"?>\n<testsuites/>'
  end
  
  -- Start building XML
  local xml = {
    '<?xml version="1.0" encoding="UTF-8"?>',
    string.format('<testsuites name="%s" tests="%d" failures="%d" errors="%d" skipped="%d" time="%s">',
      escape_xml(results_data.name or "lust-next"),
      results_data.tests or 0,
      results_data.failures or 0,
      results_data.errors or 0,
      results_data.skipped or 0,
      results_data.time or 0
    ),
    string.format('  <testsuite name="%s" tests="%d" failures="%d" errors="%d" skipped="%d" time="%s" timestamp="%s">',
      escape_xml(results_data.name or "lust-next"),
      results_data.tests or 0,
      results_data.failures or 0,
      results_data.errors or 0,
      results_data.skipped or 0,
      results_data.time or 0,
      escape_xml(results_data.timestamp or os.date("!%Y-%m-%dT%H:%M:%S"))
    )
  }
  
  -- Add properties
  table.insert(xml, '    <properties>')
  table.insert(xml, '      <property name="lust_next_version" value="0.7.5"/>')
  table.insert(xml, '    </properties>')
  
  -- Add test cases
  for _, test_case in ipairs(results_data.test_cases) do
    local test_xml = string.format('    <testcase name="%s" classname="%s" time="%s"',
      escape_xml(test_case.name or ""),
      escape_xml(test_case.classname or "unknown"),
      test_case.time or 0
    )
    
    -- Handle different test statuses
    if test_case.status == "skipped" or test_case.status == "pending" then
      -- Skipped test
      test_xml = test_xml .. '>\n      <skipped'
      
      if test_case.skip_reason then
        test_xml = test_xml .. string.format(' message="%s"', escape_xml(test_case.skip_reason))
      end
      
      test_xml = test_xml .. '/>\n    </testcase>'
    
    elseif test_case.status == "fail" then
      -- Failed test
      test_xml = test_xml .. '>'
      
      if test_case.failure then
        test_xml = test_xml .. string.format(
          '\n      <failure message="%s" type="%s">%s</failure>',
          escape_xml(test_case.failure.message or "Assertion failed"),
          escape_xml(test_case.failure.type or "AssertionError"),
          escape_xml(test_case.failure.details or "")
        )
      end
      
      test_xml = test_xml .. '\n    </testcase>'
    
    elseif test_case.status == "error" then
      -- Error in test
      test_xml = test_xml .. '>'
      
      if test_case.error then
        test_xml = test_xml .. string.format(
          '\n      <error message="%s" type="%s">%s</error>',
          escape_xml(test_case.error.message or "Error occurred"),
          escape_xml(test_case.error.type or "Error"),
          escape_xml(test_case.error.details or "")
        )
      end
      
      test_xml = test_xml .. '\n    </testcase>'
    
    else
      -- Passed test
      test_xml = test_xml .. '/>'
    end
    
    table.insert(xml, test_xml)
  end
  
  -- Close XML
  table.insert(xml, '  </testsuite>')
  table.insert(xml, '</testsuites>')
  
  -- Join all lines
  return table.concat(xml, '\n')
end

-- Register formatter
return function(formatters)
  formatters.results.junit = M.format_results
end