-- Summary formatter for coverage reports
local M = {}

-- Generate a summary coverage report from coverage data
function M.format_coverage(coverage_data)
  -- Validate the input data to prevent runtime errors
  if not coverage_data then
    print("ERROR [Reporting] Missing coverage data")
    return {
      files = {},
      total_files = 0,
      covered_files = 0,
      files_pct = 0,
      total_lines = 0,
      covered_lines = 0,
      lines_pct = 0,
      total_functions = 0,
      covered_functions = 0,
      functions_pct = 0,
      overall_pct = 0
    }
  end
  
  -- Make sure we have summary data
  local summary = coverage_data.summary or {
    total_files = 0,
    covered_files = 0,
    total_lines = 0,
    covered_lines = 0,
    total_functions = 0,
    covered_functions = 0,
    line_coverage_percent = 0,
    function_coverage_percent = 0,
    overall_percent = 0
  }
  
  -- Debug output handled by reporting module
  -- Configuration is managed by the main reporting module
  
  local report = {
    files = coverage_data.files or {},
    total_files = summary.total_files or 0,
    covered_files = summary.covered_files or 0,
    files_pct = summary.total_files > 0 and 
                ((summary.covered_files or 0) / summary.total_files * 100) or 0,
    
    total_lines = summary.total_lines or 0,
    covered_lines = summary.covered_lines or 0,
    lines_pct = summary.total_lines > 0 and 
               ((summary.covered_lines or 0) / summary.total_lines * 100) or 0,
    
    total_functions = summary.total_functions or 0,
    covered_functions = summary.covered_functions or 0,
    functions_pct = summary.total_functions > 0 and 
                   ((summary.covered_functions or 0) / summary.total_functions * 100) or 0,
    
    overall_pct = summary.overall_percent or 0,
  }
  
  return report
end

-- Generate a text summary of quality data
function M.format_quality(quality_data)
  -- Validate input
  if not quality_data then
    print("ERROR [Reporting] Missing quality data")
    return {
      level = 0,
      level_name = "unknown",
      tests_analyzed = 0,
      tests_passing = 0,
      quality_pct = 0,
      issues = {}
    }
  end
  
  -- Extract useful data for report
  local report = {
    level = quality_data.level or 0,
    level_name = quality_data.level_name or "unknown",
    tests_analyzed = quality_data.summary and quality_data.summary.tests_analyzed or 0,
    tests_passing = quality_data.summary and quality_data.summary.tests_passing_quality or 0,
    quality_pct = quality_data.summary and quality_data.summary.quality_percent or 0,
    issues = quality_data.summary and quality_data.summary.issues or {}
  }
  
  return report
end

-- Register formatters
return function(formatters)
  formatters.coverage.summary = M.format_coverage
  formatters.quality.summary = M.format_quality
end