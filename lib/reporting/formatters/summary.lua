-- Summary formatter for coverage reports
local M = {}

local logging = require("lib.tools.logging")
local logger = logging.get_logger("Reporting:Summary")

-- Configure module logging
logging.configure_from_config("Reporting:Summary")

-- Default formatter configuration
local DEFAULT_CONFIG = {
  detailed = false,
  show_files = true,
  colorize = true,
  min_coverage_warn = 70,
  min_coverage_ok = 80
}

-- Get configuration for Summary formatter
local function get_config()
  -- Try to load the reporting module for configuration access
  local ok, reporting = pcall(require, "lib.reporting")
  if ok and reporting.get_formatter_config then
    local formatter_config = reporting.get_formatter_config("summary")
    if formatter_config then
      logger.debug("Using configuration from reporting module")
      return formatter_config
    end
  end
  
  -- If we can't get from reporting module, try central_config directly
  local success, central_config = pcall(require, "lib.core.central_config")
  if success then
    local formatter_config = central_config.get("reporting.formatters.summary")
    if formatter_config then
      logger.debug("Using configuration from central_config")
      return formatter_config
    end
  end
  
  -- Fall back to default configuration
  logger.debug("Using default configuration")
  return DEFAULT_CONFIG
end

-- Function to colorize output if enabled
local function colorize(text, color_code, config)
  if not config or config.colorize == false then
    return text
  end
  
  local colors = {
    reset = "\27[0m",
    red = "\27[31m",
    green = "\27[32m",
    yellow = "\27[33m",
    blue = "\27[34m",
    magenta = "\27[35m",
    cyan = "\27[36m",
    white = "\27[37m",
    bold = "\27[1m"
  }
  
  return colors[color_code] .. text .. colors.reset
end

-- Generate a summary coverage report from coverage data
function M.format_coverage(coverage_data)
  -- Get formatter configuration
  local config = get_config()
  
  logger.debug("Formatting coverage summary", {
    has_files = coverage_data and coverage_data.files ~= nil,
    detailed = config.detailed,
    show_files = config.show_files,
    colorize = config.colorize
  })

  -- Validate the input data to prevent runtime errors
  if not coverage_data then
    logger.error("Missing coverage data", {
      formatter = "summary",
      data_type = type(coverage_data)
    })
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
  
  -- Count files in a safer way
  local file_count = 0
  if coverage_data.files then
    for _ in pairs(coverage_data.files) do
      file_count = file_count + 1
    end
  end
  
  logger.debug("Formatting coverage summary", {
    has_files = coverage_data.files ~= nil,
    has_summary = coverage_data.summary ~= nil,
    file_count = file_count
  })
  
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
  
  -- Prepare the summary data
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
  
  -- Format summary as a string based on configuration
  local output = {}
  
  -- Add header
  table.insert(output, colorize("Coverage Summary", "bold", config))
  table.insert(output, colorize("----------------", "bold", config))
  
  -- Make sure config has valid thresholds
  local min_coverage_ok = config.min_coverage_ok or DEFAULT_CONFIG.min_coverage_ok
  local min_coverage_warn = config.min_coverage_warn or DEFAULT_CONFIG.min_coverage_warn
  
  -- Color the overall percentage based on coverage level
  local overall_color = "red"
  if report.overall_pct >= min_coverage_ok then
    overall_color = "green"
  elseif report.overall_pct >= min_coverage_warn then
    overall_color = "yellow"
  end
  
  -- Add overall coverage percentage
  table.insert(output, string.format("Overall Coverage: %s", 
                                    colorize(string.format("%.1f%%", report.overall_pct), overall_color, config)))
  
  -- Add detailed stats
  table.insert(output, string.format("Files: %s/%s (%.1f%%)", 
    report.covered_files, report.total_files, report.files_pct))
  table.insert(output, string.format("Lines: %s/%s (%.1f%%)", 
    report.covered_lines, report.total_lines, report.lines_pct))
  table.insert(output, string.format("Functions: %s/%s (%.1f%%)", 
    report.covered_functions, report.total_functions, report.functions_pct))
  
  -- Add detailed file information if configured
  if config.show_files and config.detailed and report.files then
    table.insert(output, "")
    table.insert(output, colorize("File Details", "bold", config))
    table.insert(output, colorize("------------", "bold", config))
    
    local files_list = {}
    for file_path, file_data in pairs(report.files) do
      table.insert(files_list, {
        path = file_path,
        pct = file_data.line_coverage_percent or 0
      })
    end
    
    -- Sort files by coverage percentage (ascending)
    table.sort(files_list, function(a, b) return a.pct < b.pct end)
    
    for _, file in ipairs(files_list) do
      local file_color = "red"
      if file.pct >= config.min_coverage_ok then
        file_color = "green"
      elseif file.pct >= config.min_coverage_warn then
        file_color = "yellow"
      end
      
      table.insert(output, string.format("%s: %s", 
        file.path, colorize(string.format("%.1f%%", file.pct), file_color, config)))
    end
  end
  
  -- Prepare the formatted output string
  local formatted_output = table.concat(output, "\n")
  
  -- Return both the formatted string and structured data for programmatic use
  return {
    output = formatted_output,  -- String representation for display
    overall_pct = report.overall_pct,
    total_files = report.total_files,
    covered_files = report.covered_files,
    files_pct = report.files_pct, 
    total_lines = report.total_lines,
    covered_lines = report.covered_lines,
    lines_pct = report.lines_pct,
    total_functions = report.total_functions,
    covered_functions = report.covered_functions,
    functions_pct = report.functions_pct
  }
end

-- Generate a text summary of quality data
function M.format_quality(quality_data)
  -- Get formatter configuration
  local config = get_config()
  
  logger.debug("Formatting quality summary", {
    level = quality_data and quality_data.level or 0,
    level_name = quality_data and quality_data.level_name or "unknown",
    has_summary = quality_data and quality_data.summary ~= nil,
    detailed = config.detailed,
    colorize = config.colorize
  })
  
  -- Validate input
  if not quality_data then
    logger.error("Missing quality data", {
      formatter = "summary",
      data_type = type(quality_data)
    })
    
    local output = {}
    table.insert(output, colorize("Quality Summary", "bold", config))
    table.insert(output, colorize("--------------", "bold", config))
    table.insert(output, "No quality data available")
    return table.concat(output, "\n")
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
  
  -- Format quality as a string based on configuration
  local output = {}
  
  -- Add header
  table.insert(output, colorize("Quality Summary", "bold", config))
  table.insert(output, colorize("--------------", "bold", config))
  
  -- Make sure config has valid thresholds
  local min_coverage_ok = config.min_coverage_ok or DEFAULT_CONFIG.min_coverage_ok
  local min_coverage_warn = config.min_coverage_warn or DEFAULT_CONFIG.min_coverage_warn
  
  -- Color the quality percentage based on level
  local quality_color = "red"
  if report.quality_pct >= min_coverage_ok then
    quality_color = "green"
  elseif report.quality_pct >= min_coverage_warn then
    quality_color = "yellow"
  end
  
  -- Add quality level and percentage
  table.insert(output, string.format("Quality Level: %s (%s)", 
    report.level_name, colorize(string.format("Level %d", report.level), "cyan", config)))
  table.insert(output, string.format("Quality Rating: %s", 
    colorize(string.format("%.1f%%", report.quality_pct), quality_color, config)))
  
  -- Add test stats
  table.insert(output, string.format("Tests Analyzed: %d", report.tests_analyzed))
  table.insert(output, string.format("Tests Passing Quality Validation: %d/%d (%.1f%%)", 
    report.tests_passing, report.tests_analyzed, 
    report.tests_analyzed > 0 and (report.tests_passing/report.tests_analyzed*100) or 0))
  
  -- Add issues if detailed mode is enabled
  if config.detailed and report.issues and #report.issues > 0 then
    table.insert(output, "")
    table.insert(output, colorize("Quality Issues", "bold", config))
    table.insert(output, colorize("-------------", "bold", config))
    
    for _, issue in ipairs(report.issues) do
      local issue_text = string.format("%s: %s", 
        colorize(issue.test or "Unknown", "bold", config),
        issue.issue or "Unknown issue")
      table.insert(output, issue_text)
    end
  end
  
  -- Prepare the formatted output string
  local formatted_output = table.concat(output, "\n")
  
  -- Return both the formatted string and structured data for programmatic use
  return {
    output = formatted_output,  -- String representation for display
    level = report.level,
    level_name = report.level_name,
    tests_analyzed = report.tests_analyzed,
    tests_passing = report.tests_passing,
    quality_pct = report.quality_pct,
    issues = report.issues
  }
end

-- Register formatters
return function(formatters)
  formatters.coverage.summary = M.format_coverage
  formatters.quality.summary = M.format_quality
end