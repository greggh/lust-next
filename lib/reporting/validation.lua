-- Validation module for coverage reports
local M = {}

local logging = require("lib.tools.logging")

-- Create a logger for this module
local logger = logging.get_logger("Reporting:Validation")

-- Configure module logging
logging.configure_from_config("Reporting:Validation")

-- Default validation configuration
local DEFAULT_CONFIG = {
  validate_reports = true,
  validate_line_counts = true,
  validate_percentages = true,
  validate_file_paths = true,
  validate_function_counts = true,
  validate_block_counts = true, 
  validate_cross_module = true,
  validation_threshold = 0.5, -- 0.5% tolerance for percentage mismatches
  warn_on_validation_failure = true
}

-- Get configuration for validation
local function get_config()
  -- Try to load central_config module
  local success, central_config = pcall(require, "lib.core.central_config")
  if success then
    local validation_config = central_config.get("reporting.validation")
    if validation_config then
      return validation_config
    end
  end
  
  -- Fall back to default configuration
  return DEFAULT_CONFIG
end

-- Register validation configuration schema with central_config if available
local function register_config_schema()
  local success, central_config = pcall(require, "lib.core.central_config")
  if success then
    central_config.register_module("reporting.validation", {
      validate_reports = { type = "boolean", default = true },
      validate_line_counts = { type = "boolean", default = true },
      validate_percentages = { type = "boolean", default = true },
      validate_file_paths = { type = "boolean", default = true },
      validate_function_counts = { type = "boolean", default = true },
      validate_block_counts = { type = "boolean", default = true },
      validate_cross_module = { type = "boolean", default = true },
      validation_threshold = { type = "number", default = 0.5 },
      warn_on_validation_failure = { type = "boolean", default = true }
    })
  end
end

-- Try to register with central_config
register_config_schema()

-- List of validation issues
local validation_issues = {}

-- Add a validation issue
local function add_issue(category, message, severity, details)
  table.insert(validation_issues, {
    category = category,
    message = message,
    severity = severity or "warning",
    details = details or {}
  })
  
  -- Log the issue
  if severity == "error" then
    logger.error(message, details or {})
  else
    logger.warn(message, details or {})
  end
end

-- Validate line counts in a coverage report
local function validate_line_counts(coverage_data)
  local config = get_config()
  if not config.validate_line_counts then return true end
  
  local valid = true
  
  -- Validate summary line counts
  if coverage_data and coverage_data.summary then
    local summary = coverage_data.summary
    
    -- Count files and lines directly to validate the summary
    local total_files = 0
    local total_lines = 0
    local covered_lines = 0
    local total_functions = 0
    local covered_functions = 0
    local total_blocks = 0
    local covered_blocks = 0
    
    -- Validate files data
    if coverage_data.files then
      for filename, file_data in pairs(coverage_data.files) do
        total_files = total_files + 1
        
        -- Validate line counts
        if file_data.total_lines then
          total_lines = total_lines + file_data.total_lines
        end
        
        if file_data.covered_lines then
          covered_lines = covered_lines + file_data.covered_lines
        end
        
        -- Validate function counts
        if file_data.total_functions then
          total_functions = total_functions + file_data.total_functions
        end
        
        if file_data.covered_functions then
          covered_functions = covered_functions + file_data.covered_functions
        end
        
        -- Validate block counts
        if file_data.total_blocks then
          total_blocks = total_blocks + file_data.total_blocks
        end
        
        if file_data.covered_blocks then
          covered_blocks = covered_blocks + file_data.covered_blocks
        end
        
        -- Validate per-file percentages
        if file_data.line_coverage_percent and file_data.total_lines > 0 then
          local calculated_pct = (file_data.covered_lines / file_data.total_lines) * 100
          local diff = math.abs(calculated_pct - file_data.line_coverage_percent)
          
          if diff > config.validation_threshold then
            add_issue("line_percentage", "Line coverage percentage doesn't match calculation", "warning", {
              file = filename,
              reported = file_data.line_coverage_percent,
              calculated = calculated_pct,
              difference = diff
            })
            valid = false
          end
        end
      end
      
      -- Validate summary against calculated totals
      if math.abs(total_files - (summary.total_files or 0)) > 0 then
        add_issue("file_count", "Total file count doesn't match actual file count", "warning", {
          reported = summary.total_files,
          calculated = total_files
        })
        valid = false
      end
      
      if math.abs(total_lines - (summary.total_lines or 0)) > 0 then
        add_issue("line_count", "Total line count doesn't match sum of file line counts", "warning", {
          reported = summary.total_lines,
          calculated = total_lines
        })
        valid = false
      end
      
      if math.abs(covered_lines - (summary.covered_lines or 0)) > 0 then
        add_issue("covered_lines", "Covered line count doesn't match sum of file covered lines", "warning", {
          reported = summary.covered_lines,
          calculated = covered_lines
        })
        valid = false
      end
      
      -- Validate function counts
      if summary.total_functions and math.abs(total_functions - summary.total_functions) > 0 then
        add_issue("function_count", "Total function count doesn't match sum of file function counts", "warning", {
          reported = summary.total_functions,
          calculated = total_functions
        })
        valid = false
      end
      
      if summary.covered_functions and math.abs(covered_functions - summary.covered_functions) > 0 then
        add_issue("covered_functions", "Covered function count doesn't match sum of file covered functions", "warning", {
          reported = summary.covered_functions,
          calculated = covered_functions
        })
        valid = false
      end
      
      -- Validate block counts if present
      if summary.total_blocks and math.abs(total_blocks - summary.total_blocks) > 0 then
        add_issue("block_count", "Total block count doesn't match sum of file block counts", "warning", {
          reported = summary.total_blocks,
          calculated = total_blocks
        })
        valid = false
      end
      
      if summary.covered_blocks and math.abs(covered_blocks - summary.covered_blocks) > 0 then
        add_issue("covered_blocks", "Covered block count doesn't match sum of file covered blocks", "warning", {
          reported = summary.covered_blocks,
          calculated = covered_blocks
        })
        valid = false
      end
    end
  else
    add_issue("missing_summary", "Coverage report is missing summary data", "error")
    valid = false
  end
  
  return valid
end

-- Validate percentage calculations in a coverage report
local function validate_percentages(coverage_data)
  local config = get_config()
  if not config.validate_percentages then return true end
  
  local valid = true
  
  -- Validate summary percentages
  if coverage_data and coverage_data.summary then
    local summary = coverage_data.summary
    
    -- Validate line coverage percentage
    if summary.total_lines and summary.total_lines > 0 and summary.covered_lines then
      local calculated_pct = (summary.covered_lines / summary.total_lines) * 100
      
      if summary.line_coverage_percent and 
         math.abs(calculated_pct - summary.line_coverage_percent) > config.validation_threshold then
        add_issue("line_percentage", "Line coverage percentage doesn't match calculation", "warning", {
          reported = summary.line_coverage_percent,
          calculated = calculated_pct
        })
        valid = false
      end
    end
    
    -- Validate function coverage percentage
    if summary.total_functions and summary.total_functions > 0 and summary.covered_functions then
      local calculated_pct = (summary.covered_functions / summary.total_functions) * 100
      
      if summary.function_coverage_percent and 
         math.abs(calculated_pct - summary.function_coverage_percent) > config.validation_threshold then
        add_issue("function_percentage", "Function coverage percentage doesn't match calculation", "warning", {
          reported = summary.function_coverage_percent,
          calculated = calculated_pct
        })
        valid = false
      end
    end
    
    -- Validate block coverage percentage
    if summary.total_blocks and summary.total_blocks > 0 and summary.covered_blocks then
      local calculated_pct = (summary.covered_blocks / summary.total_blocks) * 100
      
      if summary.block_coverage_percent and 
         math.abs(calculated_pct - summary.block_coverage_percent) > config.validation_threshold then
        add_issue("block_percentage", "Block coverage percentage doesn't match calculation", "warning", {
          reported = summary.block_coverage_percent,
          calculated = calculated_pct
        })
        valid = false
      end
    end
    
    -- Validate overall percentage (weighted average)
    if summary.overall_percent then
      -- Calculate weighted average based on available metrics
      local has_blocks = summary.total_blocks and summary.total_blocks > 0
      local line_weight = has_blocks and 0.4 or 0.8
      local function_weight = has_blocks and 0.2 or 0.2
      local block_weight = has_blocks and 0.4 or 0
      
      local line_pct = summary.line_coverage_percent or 
                      (summary.total_lines > 0 and 
                      (summary.covered_lines / summary.total_lines * 100) or 0)
                      
      local function_pct = summary.function_coverage_percent or 
                          (summary.total_functions > 0 and 
                          (summary.covered_functions / summary.total_functions * 100) or 0)
                          
      local block_pct = summary.block_coverage_percent or 
                       (summary.total_blocks > 0 and 
                       (summary.covered_blocks / summary.total_blocks * 100) or 0)
      
      local calculated_overall = (line_pct * line_weight) + 
                                (function_pct * function_weight) + 
                                (block_pct * block_weight)
      
      if math.abs(calculated_overall - summary.overall_percent) > config.validation_threshold then
        add_issue("overall_percentage", "Overall coverage percentage doesn't match weighted calculation", "warning", {
          reported = summary.overall_percent,
          calculated = calculated_overall,
          line_pct = line_pct,
          function_pct = function_pct,
          block_pct = block_pct,
          weights = {
            line = line_weight,
            func = function_weight,
            block = block_weight
          }
        })
        valid = false
      end
    end
  else
    -- This issue would already be reported by validate_line_counts
    valid = false
  end
  
  return valid
end

-- Validate file paths in a coverage report
local function validate_file_paths(coverage_data)
  local config = get_config()
  if not config.validate_file_paths then return true end
  
  local valid = true
  
  -- Check if we have fs module available
  local fs_available, fs = pcall(require, "lib.tools.filesystem")
  if not fs_available then
    logger.warn("Filesystem module not available, skipping file path validation")
    return true
  end
  
  -- Check that files exist
  if coverage_data and coverage_data.files then
    for filename, _ in pairs(coverage_data.files) do
      -- Only validate absolute paths
      if filename:match("^/") then
        if not fs.file_exists(filename) then
          add_issue("file_path", "Coverage report references file that doesn't exist", "warning", {
            file = filename
          })
          valid = false
        end
      end
    end
  end
  
  return valid
end

-- Validate cross-module references
local function validate_cross_module(coverage_data)
  local config = get_config()
  if not config.validate_cross_module then return true end
  
  local valid = true
  
  -- Check if original_files data matches files data
  if coverage_data and coverage_data.files and coverage_data.original_files then
    local files_count = 0
    local orig_files_count = 0
    
    -- Count files
    for _ in pairs(coverage_data.files) do
      files_count = files_count + 1
    end
    
    for _ in pairs(coverage_data.original_files) do
      orig_files_count = orig_files_count + 1
    end
    
    if files_count ~= orig_files_count then
      add_issue("cross_module", "File count mismatch between files and original_files", "warning", {
        files_count = files_count,
        original_files_count = orig_files_count
      })
      valid = false
    end
    
    -- Check for files that don't have matching original_files data
    for filename, _ in pairs(coverage_data.files) do
      if not coverage_data.original_files[filename] then
        add_issue("cross_module", "Coverage file missing from original_files data", "warning", {
          file = filename
        })
        valid = false
      end
    end
  end
  
  return valid
end

-- Main validation function for coverage data
function M.validate_coverage_data(coverage_data)
  -- Reset issues list
  validation_issues = {}
  
  logger.debug("Starting coverage report validation", {
    has_data = coverage_data ~= nil,
    has_summary = coverage_data and coverage_data.summary ~= nil,
    has_files = coverage_data and coverage_data.files ~= nil,
    file_count = coverage_data and coverage_data.files and table.getn and table.getn(coverage_data.files) or 0
  })
  
  local config = get_config()
  
  -- Skip validation if disabled
  if not config.validate_reports then
    logger.info("Coverage report validation is disabled in configuration")
    return true, {}
  end
  
  -- Basic data structure validation
  if not coverage_data then
    add_issue("data_structure", "Coverage data is nil", "error")
    return false, validation_issues
  end
  
  if not coverage_data.summary then
    add_issue("data_structure", "Coverage data is missing summary section", "error")
    return false, validation_issues
  end
  
  if not coverage_data.files then
    add_issue("data_structure", "Coverage data is missing files section", "error")
    return false, validation_issues
  end
  
  -- Run specific validation checks
  local line_counts_valid = validate_line_counts(coverage_data)
  local percentages_valid = validate_percentages(coverage_data)
  local file_paths_valid = validate_file_paths(coverage_data)
  local cross_module_valid = validate_cross_module(coverage_data)
  
  -- All validations must pass for the data to be considered valid
  local is_valid = line_counts_valid and percentages_valid and 
                   file_paths_valid and cross_module_valid
  
  logger.info("Coverage report validation complete", {
    valid = is_valid,
    issues_found = #validation_issues,
    line_counts_valid = line_counts_valid,
    percentages_valid = percentages_valid,
    file_paths_valid = file_paths_valid,
    cross_module_valid = cross_module_valid
  })
  
  -- Return validation result and issues
  return is_valid, validation_issues
end

-- Statistical analysis of coverage data for anomaly detection
function M.analyze_coverage_statistics(coverage_data)
  local stats = {
    median_line_coverage = 0,
    mean_line_coverage = 0,
    std_dev_line_coverage = 0,
    outliers = {},
    anomalies = {}
  }
  
  if not coverage_data or not coverage_data.files then
    return stats
  end
  
  -- Collect line coverage percentages for all files
  local percentages = {}
  local sum = 0
  
  for filename, file_data in pairs(coverage_data.files) do
    if file_data.line_coverage_percent then
      table.insert(percentages, {
        file = filename,
        pct = file_data.line_coverage_percent
      })
      sum = sum + file_data.line_coverage_percent
    end
  end
  
  -- Calculate mean
  if #percentages > 0 then
    stats.mean_line_coverage = sum / #percentages
    
    -- Sort percentages for median calculation
    table.sort(percentages, function(a, b) return a.pct < b.pct end)
    
    -- Calculate median
    if #percentages % 2 == 0 then
      local mid = #percentages / 2
      stats.median_line_coverage = (percentages[mid].pct + percentages[mid + 1].pct) / 2
    else
      stats.median_line_coverage = percentages[math.ceil(#percentages / 2)].pct
    end
    
    -- Calculate standard deviation
    local variance_sum = 0
    for _, entry in ipairs(percentages) do
      variance_sum = variance_sum + (entry.pct - stats.mean_line_coverage)^2
    end
    
    stats.std_dev_line_coverage = math.sqrt(variance_sum / #percentages)
    
    -- Identify outliers (more than 2 standard deviations from mean)
    for _, entry in ipairs(percentages) do
      local z_score = math.abs(entry.pct - stats.mean_line_coverage) / stats.std_dev_line_coverage
      if z_score > 2 then
        table.insert(stats.outliers, {
          file = entry.file,
          coverage = entry.pct,
          z_score = z_score
        })
      end
    end
    
    -- Identify potential anomalies based on heuristics
    for filename, file_data in pairs(coverage_data.files) do
      -- Files with high line count but low coverage might need attention
      if file_data.total_lines and file_data.total_lines > 100 and 
         file_data.line_coverage_percent and file_data.line_coverage_percent < 20 then
        table.insert(stats.anomalies, {
          file = filename,
          reason = "Large file with low coverage",
          details = {
            lines = file_data.total_lines,
            coverage = file_data.line_coverage_percent
          }
        })
      end
      
      -- Check for odd ratios between line and function coverage
      if file_data.line_coverage_percent and file_data.function_coverage_percent and
         math.abs(file_data.line_coverage_percent - file_data.function_coverage_percent) > 50 then
        table.insert(stats.anomalies, {
          file = filename,
          reason = "Large discrepancy between line and function coverage",
          details = {
            line_coverage = file_data.line_coverage_percent,
            function_coverage = file_data.function_coverage_percent,
            difference = math.abs(file_data.line_coverage_percent - file_data.function_coverage_percent)
          }
        })
      end
    end
  end
  
  logger.info("Statistical analysis complete", {
    files_analyzed = #percentages,
    mean = stats.mean_line_coverage,
    median = stats.median_line_coverage,
    std_dev = stats.std_dev_line_coverage,
    outliers = #stats.outliers,
    anomalies = #stats.anomalies
  })
  
  return stats
end

-- Cross-check with static analysis results
function M.cross_check_with_static_analysis(coverage_data)
  local results = {
    files_checked = 0,
    discrepancies = {},
    unanalyzed_files = {},
    analysis_success = false
  }
  
  -- Get static analyzer if available
  local analyzer_available, static_analyzer = pcall(require, "lib.coverage.static_analyzer")
  if not analyzer_available then
    logger.warn("Static analyzer not available, skipping cross-check")
    return results
  end
  
  logger.info("Starting cross-check with static analysis")
  
  results.analysis_success = true
  
  if not coverage_data or not coverage_data.files then
    logger.warn("No coverage data available for cross-check")
    return results
  end
  
  -- Check each file against static analysis
  for filename, file_data in pairs(coverage_data.files) do
    -- Skip files with no source code
    if not coverage_data.original_files or not coverage_data.original_files[filename] then
      table.insert(results.unanalyzed_files, filename)
      goto continue
    end
    
    local original_file = coverage_data.original_files[filename]
    if not original_file.source then
      table.insert(results.unanalyzed_files, filename)
      goto continue
    end
    
    -- Run static analysis on the file
    local source = original_file.source
    if type(source) == "table" then
      source = table.concat(source, "\n")
    end
    
    local analysis_result, err = static_analyzer.analyze_source(source, filename)
    if not analysis_result then
      logger.warn("Static analysis failed for file", {
        file = filename,
        error = err
      })
      results.analysis_success = false
      goto continue
    end
    
    results.files_checked = results.files_checked + 1
    
    -- Compare static analysis with coverage data
    local discrepancies = {}
    
    -- Check executable lines
    for line_num, is_executable in pairs(analysis_result.executable_lines or {}) do
      local coverage_executable = original_file.executable_lines and original_file.executable_lines[line_num]
      
      if is_executable ~= coverage_executable then
        table.insert(discrepancies, {
          line = line_num,
          type = "executable_line",
          static_analysis = is_executable,
          coverage_data = coverage_executable
        })
      end
    end
    
    -- Check function positions
    for _, func in ipairs(analysis_result.functions or {}) do
      local found = false
      for _, coverage_func in ipairs(original_file.functions or {}) do
        if func.start_line == coverage_func.start_line and
           func.name == coverage_func.name then
          found = true
          break
        end
      end
      
      if not found then
        table.insert(discrepancies, {
          type = "function",
          name = func.name,
          start_line = func.start_line,
          end_line = func.end_line,
          issue = "Function found by static analysis but not in coverage data"
        })
      end
    end
    
    -- Add discrepancies to results if any were found
    if #discrepancies > 0 then
      results.discrepancies[filename] = discrepancies
    end
    
    ::continue::
  end
  
  logger.info("Static analysis cross-check complete", {
    files_checked = results.files_checked,
    files_with_discrepancies = table.getn and table.getn(results.discrepancies) or 0,
    unanalyzed_files = #results.unanalyzed_files
  })
  
  return results
end

-- Get validation issues
function M.get_validation_issues()
  return validation_issues
end

-- Reset validation issues
function M.reset_validation_issues()
  validation_issues = {}
end

-- Complete report validation
function M.validate_report(coverage_data)
  -- Start with basic validation
  local is_valid, issues = M.validate_coverage_data(coverage_data)
  
  -- Run statistical analysis
  local stats = M.analyze_coverage_statistics(coverage_data)
  
  -- Cross-check with static analysis
  local cross_check = M.cross_check_with_static_analysis(coverage_data)
  
  -- Combine all results
  local result = {
    validation = {
      is_valid = is_valid,
      issues = issues
    },
    statistics = stats,
    cross_check = cross_check
  }
  
  return result
end

-- Return the module
return M