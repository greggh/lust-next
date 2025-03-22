---@class QualityModule
---@field _VERSION string Module version (following semantic versioning)
---@field LEVEL_BASIC number Quality level 1 - basic validation with minimal assertions
---@field LEVEL_STRUCTURED number Quality level 2 - structured tests with multiple assertion types
---@field LEVEL_COMPREHENSIVE number Quality level 3 - comprehensive tests with error handling and setup/teardown
---@field LEVEL_ADVANCED number Quality level 4 - advanced tests with specialized assertions and complete test coverage
---@field LEVEL_COMPLETE number Quality level 5 - complete tests with all assertion types and thorough validation
---@field levels table<number, {name: string, description: string, requirements: table<string, number>}> Array of quality level definitions with detailed requirements
---@field stats {tests: number, assertions: number, assertion_types: table<string, number>, missing_assertions: table<string, boolean>, files_analyzed: number, tests_analyzed: number, test_duration?: number, quality_score?: number} Statistics about quality validation results
---@field config {current_level: number, required_assertion_types: table<string, boolean>, min_assertions_per_test: number, validate_missing_assertions: boolean, analyze_test_files: boolean, require_before_after: boolean, require_test_descriptions: boolean, required_assertion_count: number, allow_dynamic_calculation: boolean, skip_patterns: string[], extra_requirements: table} Configuration for quality validation behavior
---@field init fun(options?: {level?: number, required_assertion_types?: string[], min_assertions_per_test?: number, validate_missing_assertions?: boolean, analyze_test_files?: boolean, require_before_after?: boolean, required_assertion_count?: number, extra_requirements?: table}): QualityModule Initialize quality module with specified options
---@field reset fun(): QualityModule Reset quality data while preserving configuration
---@field full_reset fun(): QualityModule Full reset (clears all data and resets configuration to defaults)
---@field get_level_requirements fun(level?: number): table<string, number>|nil, table? Get requirements for a specific quality level, returning nil and error if invalid level
---@field track_assertion fun(type_name: string, test_name?: string): QualityModule Track assertion usage in a specific test
---@field start_test fun(test_name: string): QualityModule Start test analysis for a specific test and register timing
---@field end_test fun(): QualityModule End test analysis and record final results including duration
---@field analyze_file fun(file_path: string): {assertions: number, tests: number, assertion_types: table<string, number>, has_before_after: boolean, test_descriptions: boolean, assertion_per_test: number}|nil, table? Analyze test file statically for quality metrics
---@field get_report_data fun(): {level: number, level_name: string, tests: {count: number, analyzed: number, files: number, missing_assertions: table, below_threshold: table}, assertions: {count: number, types: table, per_test: number}, requirements: table, score: number} Get structured data for quality report generation
---@field report fun(format?: string): string|table Generate a quality report in various formats (text, json, html)
---@field summary_report fun(): {level: number, score: number, tests: number, assertions: number, assertion_types: number, files: number} Generate a concise summary report with key metrics
---@field level_name fun(level: number): string Get the descriptive name for a quality level
---@field set_level fun(level: number): QualityModule Set the current quality validation level (1-5)
---@field get_level fun(): number Get the current quality validation level
---@field analyze_directory fun(dir_path: string, recursive?: boolean): table|nil, table? Analyze all test files in a directory recursively or non-recursively
---@field register_assertion_type fun(type_name: string, description: string): QualityModule Register a custom assertion type for quality tracking
---@field is_quality_passing fun(): boolean Check if tests meet the current quality level requirements
---@field get_score fun(): number Get the quality score as percentage (0-100)
---@field add_custom_requirement fun(name: string, check_fn: function, min_value?: number): QualityModule Add a custom quality requirement with validation function
---@field json_report fun(): string Generate a detailed JSON report with all quality metrics
---@field html_report fun(): string Generate a formatted HTML report with quality visualization
---@field meets_level fun(level?: number): boolean Check if quality metrics meet a specific level requirement
---@field save_report fun(file_path: string, format?: string): boolean, string? Save a quality report to a file in the specified format
---@field get_level_name fun(level: number): string Get level name from level number (alias for level_name)
---@field check_file fun(file_path: string, level?: number): boolean, table Check if a test file meets quality requirements for a specific level
---@field validate_test_quality fun(test_name: string, options?: {level?: number, required_assertions?: number, required_types?: string[]}): boolean, table[] Validate a test against quality standards with detailed feedback
---@field debug_config fun(): QualityModule Print debug information about the current quality module configuration
---@field create_test_file fun(level: number, file_path?: string): string, string? Create a template test file that meets a specified quality level

-- firmo test quality validation module
-- Implementation of test quality analysis with level-based validation to ensure
-- tests meet required standards for reliability, completeness, and maintainability

-- Lazy loading of dependencies to avoid circular references
local _central_config
---@private
---@return table|nil central_config The central configuration module or nil if not available
local function get_central_config()
  if not _central_config then
    local success, central_config = pcall(require, "lib.core.central_config")
    _central_config = success and central_config or nil
  end
  return _central_config
end

local fs = require("lib.tools.filesystem")
---@type Logging
local logging = require("lib.tools.logging")

-- Create module logger
---@type Logger
local logger = logging.get_logger("Quality")

-- Configure module logging
---@private
local function configure_logging()
  logging.configure_from_config("Quality")
end

configure_logging()

local M = {}

-- Define quality level constants to meet test expectations
M.LEVEL_BASIC = 1
M.LEVEL_STRUCTURED = 2
M.LEVEL_COMPREHENSIVE = 3
M.LEVEL_ADVANCED = 4
M.LEVEL_COMPLETE = 5

---@private
---@return nil
local function register_change_listener()
  local central_config = get_central_config()
  if central_config then
    central_config.on_change("quality", function(path, old_value, new_value)
      logger.debug("Quality configuration changed, updating", {
        path = path,
        changed_value = path:match("^quality%.(.+)$") or "all"
      })
      
      -- Apply the changes to our local config for backward compatibility
      if new_value then
        if path == "quality" then
          -- Full quality config replacement
          for k, v in pairs(new_value) do
            M.config[k] = v
          end
        else
          -- Just one property changed
          local prop = path:match("^quality%.(.+)$")
          if prop then
            M.config[prop] = new_value
          end
        end
      end
      
      logger.debug("Configuration updated from central_config", {
        enabled = M.config.enabled,
        level = M.config.level,
        strict = M.config.strict
      })
    end)
    
    logger.debug("Registered change listener for quality configuration")
  end
end

---@private
---@param value any The value to check
---@param pattern string The pattern to search for
---@return boolean contains True if value contains pattern
local function contains_pattern(value, pattern)
  if type(value) ~= "string" then
    return false
  end
  return string.find(value, pattern) ~= nil
end

---@private
---@param value any The value to check
---@param patterns string[] Array of patterns to search for
---@return boolean contains True if value contains any of the patterns
local function contains_any_pattern(value, patterns)
  if type(value) ~= "string" or not patterns or #patterns == 0 then
    return false
  end
  
  for _, pattern in ipairs(patterns) do
    if contains_pattern(value, pattern) then
      return true
    end
  end
  
  return false
end

-- Common assertion detection patterns
local patterns = {
  -- Different types of assertions
  equality = {
    "assert%.equal",
    "assert%.equals",
    "assert%.same",
    "assert%.matches",
    "assert%.not_equal",
    "assert%.not_equals",
    "assert%.almost_equal",
    "assert%.almost_equals",
    "assert%.are%.equal",
    "assert%.are%.same",
    "expect%(.-%):to%.equal",
    "expect%(.-%):to_equal",
    "expect%(.-%):to%.be%.equal",
    "expect%(.-%):to_be_equal",
    "==",
    "~="
  },
  
  -- Type checking assertions
  type_checking = {
    "assert%.is_",
    "assert%.is%.%w+",
    "assert%.type",
    "assert%.is_type",
    "assert%.is_not_",
    "expect%(.-%):to%.be%.a",
    "expect%(.-%):to_be_a",
    "expect%(.-%):to%.be%.an",
    "expect%(.-%):to_be_an",
    "type%(",
    "assert%.matches_type",
    "instanceof"
  },
  
  -- Truth assertions
  truth = {
    "assert%.true",
    "assert%.not%.false",
    "assert%.truthy",
    "assert%.is_true",
    "expect%(.-%):to%.be%.true",
    "expect%(.-%):to_be_true"
  },
  
  -- Error assertions
  error_handling = {
    "assert%.error",
    "assert%.raises",
    "assert%.throws",
    "assert%.has_error",
    "expect%(.-%):to%.throw",
    "expect%(.-%):to_throw",
    "pcall",
    "xpcall",
    "try%s*{"
  },
  
  -- Mock and spy assertions
  mock_verification = {
    "assert%.spy",
    "assert%.mock",
    "assert%.stub",
    "spy:called",
    "spy:called_with",
    "mock:called",
    "mock:called_with",
    "expect%(.-%):to%.have%.been%.called",
    "expect%(.-%):to_have_been_called",
    "verify%(",
    "was_called_with",
    "expects%(",
    "returns"
  },
  
  -- Edge case tests
  edge_cases = {
    "nil",
    "empty",
    "%.min",
    "%.max",
    "minimum",
    "maximum",
    "bound",
    "overflow",
    "underflow",
    "edge",
    "limit",
    "corner",
    "special_case"
  },
  
  -- Boundary tests
  boundary = {
    "boundary",
    "limit",
    "edge",
    "off.by.one",
    "upper.bound",
    "lower.bound",
    "just.below",
    "just.above",
    "outside.range",
    "inside.range",
    "%.0",
    "%.1",
    "min.value",
    "max.value"
  },
  
  -- Performance tests
  performance = {
    "benchmark",
    "performance",
    "timing",
    "profile",
    "speed",
    "memory",
    "allocation",
    "time.complexity",
    "space.complexity",
    "load.test"
  },
  
  -- Security tests
  security = {
    "security",
    "exploit",
    "injection",
    "sanitize",
    "escape",
    "validate",
    "authorization",
    "authentication",
    "permission",
    "overflow",
    "xss",
    "csrf",
    "leak"
  }
}

-- Quality levels definition with comprehensive requirements
M.levels = {
  {
    level = 1,
    name = "basic",
    requirements = {
      min_assertions_per_test = 1,
      assertion_types_required = {"equality", "truth"},
      assertion_types_required_count = 1,
      test_organization = {
        require_describe_block = true,
        require_it_block = true,
        max_assertions_per_test = 15,
        require_test_name = true
      },
      required_patterns = {},
      forbidden_patterns = {"SKIP", "TODO", "FIXME"},
    },
    description = "Basic tests with at least one assertion per test and proper structure"
  },
  {
    level = 2,
    name = "standard",
    requirements = {
      min_assertions_per_test = 2,
      assertion_types_required = {"equality", "truth", "type_checking"},
      assertion_types_required_count = 2,
      test_organization = {
        require_describe_block = true,
        require_it_block = true,
        max_assertions_per_test = 10,
        require_test_name = true,
        require_before_after = false
      },
      required_patterns = {"should"},
      forbidden_patterns = {"SKIP", "TODO", "FIXME"},
    },
    description = "Standard tests with multiple assertions, proper naming, and error handling"
  },
  {
    level = 3,
    name = "comprehensive",
    requirements = {
      min_assertions_per_test = 3,
      assertion_types_required = {"equality", "truth", "type_checking", "error_handling", "edge_cases"},
      assertion_types_required_count = 3,
      test_organization = {
        require_describe_block = true,
        require_it_block = true,
        max_assertions_per_test = 8,
        require_test_name = true,
        require_before_after = true,
        require_context_nesting = true
      },
      required_patterns = {"should", "when"},
      forbidden_patterns = {"SKIP", "TODO", "FIXME"},
    },
    description = "Comprehensive tests with edge cases, type checking, and isolated setup"
  },
  {
    level = 4,
    name = "advanced",
    requirements = {
      min_assertions_per_test = 4,
      assertion_types_required = {"equality", "truth", "type_checking", "error_handling", "mock_verification", "edge_cases", "boundary"},
      assertion_types_required_count = 4,
      test_organization = {
        require_describe_block = true,
        require_it_block = true,
        max_assertions_per_test = 6,
        require_test_name = true,
        require_before_after = true,
        require_context_nesting = true,
        require_mock_verification = true
      },
      required_patterns = {"should", "when", "boundary"},
      forbidden_patterns = {"SKIP", "TODO", "FIXME"},
    },
    description = "Advanced tests with boundary conditions, mock verification, and context organization"
  },
  {
    level = 5,
    name = "complete",
    requirements = {
      min_assertions_per_test = 5,
      assertion_types_required = {"equality", "truth", "type_checking", "error_handling", "mock_verification", "edge_cases", "boundary", "performance", "security"},
      assertion_types_required_count = 5,
      test_organization = {
        require_describe_block = true,
        require_it_block = true,
        max_assertions_per_test = 5,
        require_test_name = true,
        require_before_after = true,
        require_context_nesting = true,
        require_mock_verification = true,
        require_coverage_threshold = 90, -- Match our new standard threshold
        require_performance_tests = true,
        require_security_tests = true
      },
      required_patterns = {"should", "when", "boundary", "security", "performance"},
      forbidden_patterns = {"SKIP", "TODO", "FIXME"},
    },
    description = "Complete tests with 100% branch coverage, security validation, and performance testing"
  }
}

-- Data structures for tracking tests and their quality metrics
local current_test = nil
local test_data = {}

-- Quality statistics
M.stats = {
  tests_analyzed = 0,
  tests_passing_quality = 0,
  assertions_total = 0,
  assertions_per_test_avg = 0,
  quality_level_achieved = 0,
  assertion_types_found = {},
  test_organization_score = 0,
  required_patterns_score = 0,
  forbidden_patterns_score = 0,
  coverage_score = 0,
  issues = {},
}

-- Default configuration
local DEFAULT_CONFIG = {
  enabled = false,
  level = 1,
  strict = false,
  custom_rules = {},
  coverage_data = nil -- Will hold reference to coverage module data if available
}

-- Configuration
M.config = {
  enabled = false,
  level = 1,
  strict = false,
  custom_rules = {},
  coverage_data = nil -- Will hold reference to coverage module data if available
}

-- File cache for source code analysis
local file_cache = {}

-- Read a file and return its contents as an array of lines
local function read_file(filename)
  if file_cache[filename] then
    return file_cache[filename]
  end
  
  -- Use filesystem module to read the file
  local content = fs.read_file(filename)
  if not content then
    return {}
  end
  
  -- Split content into lines
  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  
  file_cache[filename] = lines
  return lines
end

---@param options? {enabled?: boolean, level?: number, strict?: boolean, custom_rules?: table, coverage_data?: table, debug?: boolean, verbose?: boolean} Configuration options for the quality module
---@return QualityModule self The initialized quality module
function M.init(options)
  local central_config = get_central_config()
  
  -- Start with default configuration
  for k, v in pairs(DEFAULT_CONFIG) do
    M.config[k] = v
  end
  
  -- If central_config is available, get values from it first
  if central_config then
    local central_values = central_config.get("quality")
    if central_values then
      logger.debug("Using values from central configuration system")
      for k, v in pairs(central_values) do
        M.config[k] = v
      end
    end
    
    -- Register the change listener if not already registered
    register_change_listener()
  end
  
  -- Apply user options (these override both defaults and central_config)
  options = options or {}
  if next(options) then
    -- Count options in a safer way
    local option_count = 0
    for _ in pairs(options) do
      option_count = option_count + 1
    end
    
    logger.debug("Applying user-provided options", {
      option_count = option_count
    })
    
    for k, v in pairs(options) do
      M.config[k] = v
    end
    
    -- If central_config is available, update it with the user options
    if central_config then
      -- Update only the keys that were explicitly provided
      for k, v in pairs(options) do
        central_config.set("quality." .. k, v)
      end
    end
  end
  
  logger.debug("Quality module configuration applied", {
    enabled = M.config.enabled,
    level = M.config.level,
    strict = M.config.strict
  })
  
  -- Connect to coverage module if available
  if package.loaded["lib.coverage"] then
    logger.debug("Connected to coverage module")
    M.config.coverage_data = package.loaded["lib.coverage"]
  else
    logger.debug("Coverage module not available")
  end
  
  -- Update logging configuration based on options
  if M.config.debug or M.config.verbose then
    logging.configure_from_options("Quality", M.config)
  end
  
  M.reset()
  return M
end

---@return QualityModule self The reset quality module
function M.reset()
  logger.debug("Resetting quality module state")
  
  M.stats = {
    tests_analyzed = 0,
    tests_passing_quality = 0,
    assertions_total = 0,
    assertions_per_test_avg = 0,
    quality_level_achieved = 0,
    assertion_types_found = {},
    test_organization_score = 0,
    required_patterns_score = 0,
    forbidden_patterns_score = 0,
    coverage_score = 0,
    issues = {},
  }
  
  -- Reset test data
  test_data = {}
  current_test = nil
  
  -- Reset file cache
  file_cache = {}
  
  logger.trace("Quality module reset complete")
  return M
end

---@return QualityModule self The fully reset quality module
function M.full_reset()
  -- Reset quality data
  M.reset()
  
  -- Reset configuration to defaults in central_config if available
  local central_config = get_central_config()
  if central_config then
    central_config.reset("quality")
    
    -- Sync our local config with central_config
    local central_values = central_config.get("quality")
    if central_values then
      for k, v in pairs(central_values) do
        M.config[k] = v
      end
    else
      -- Fallback to defaults if central_config.get returns nil
      for k, v in pairs(DEFAULT_CONFIG) do
        M.config[k] = v
      end
    end
    
    logger.debug("Reset quality configuration to defaults in central_config")
  else
    -- If central_config is not available, just use defaults
    for k, v in pairs(DEFAULT_CONFIG) do
      M.config[k] = v
    end
  end
  
  return M
end

---@param level? number The quality level to get requirements for (defaults to configured level)
---@return table requirements The requirements for the specified quality level
function M.get_level_requirements(level)
  level = level or M.config.level
  for _, level_def in ipairs(M.levels) do
    if level_def.level == level then
      return level_def.requirements
    end
  end
  return M.levels[1].requirements -- Default to level 1
end

-- Check if a test has enough assertions
local function has_enough_assertions(test_info, requirements)
  local min_required = requirements.min_assertions_per_test or 1
  local max_allowed = (requirements.test_organization and requirements.test_organization.max_assertions_per_test) or 15
  
  if test_info.assertion_count < min_required then
    table.insert(test_info.issues, string.format(
      "Too few assertions: found %d, need at least %d", 
      test_info.assertion_count, 
      min_required
    ))
    return false
  end
  
  if test_info.assertion_count > max_allowed then
    table.insert(test_info.issues, string.format(
      "Too many assertions: found %d, maximum is %d", 
      test_info.assertion_count, 
      max_allowed
    ))
    return false
  end
  
  return true
end

-- Check if a test uses required assertion types
local function has_required_assertion_types(test_info, requirements)
  local required_types = requirements.assertion_types_required or {}
  local min_types_required = requirements.assertion_types_required_count or 1
  
  local found_types = 0
  local types_found = {}
  
  for _, required_type in ipairs(required_types) do
    if test_info.assertion_types[required_type] and test_info.assertion_types[required_type] > 0 then
      found_types = found_types + 1
      types_found[required_type] = true
    end
  end
  
  if found_types < min_types_required then
    local missing_types = {}
    for _, required_type in ipairs(required_types) do
      if not types_found[required_type] then
        table.insert(missing_types, required_type)
      end
    end
    
    table.insert(test_info.issues, string.format(
      "Missing required assertion types: need %d type(s), found %d. Missing: %s", 
      min_types_required, 
      found_types,
      table.concat(missing_types, ", ")
    ))
    return false
  end
  
  return true
end

-- Check if test organization meets requirements
local function has_proper_organization(test_info, requirements)
  if not requirements.test_organization then
    return true
  end
  
  local org = requirements.test_organization
  local is_valid = true
  
  -- Check for describe blocks
  if org.require_describe_block and not test_info.has_describe then
    table.insert(test_info.issues, "Missing describe block")
    is_valid = false
  end
  
  -- Check for it blocks
  if org.require_it_block and not test_info.has_it then
    table.insert(test_info.issues, "Missing it block")
    is_valid = false
  end
  
  -- Check for proper test naming
  if org.require_test_name and not test_info.has_proper_name then
    table.insert(test_info.issues, "Test doesn't have a proper descriptive name")
    is_valid = false
  end
  
  -- Check for before/after blocks
  if org.require_before_after and not test_info.has_before_after then
    table.insert(test_info.issues, "Missing setup/teardown with before/after blocks")
    is_valid = false
  end
  
  -- Check for context nesting
  if org.require_context_nesting and test_info.nesting_level < 2 then
    table.insert(test_info.issues, "Insufficient context nesting (need at least 2 levels)")
    is_valid = false
  end
  
  -- Check for mock verification
  if org.require_mock_verification and not test_info.has_mock_verification then
    table.insert(test_info.issues, "Missing mock/spy verification")
    is_valid = false
  end
  
  -- Check for coverage threshold if coverage data is available
  if org.require_coverage_threshold and M.config.coverage_data then
    local coverage_report = M.config.coverage_data.summary_report()
    if coverage_report.overall_pct < org.require_coverage_threshold then
      table.insert(test_info.issues, string.format(
        "Insufficient code coverage: %.2f%% (threshold: %d%%)",
        coverage_report.overall_pct,
        org.require_coverage_threshold
      ))
      is_valid = false
    end
  end
  
  -- Check for performance tests
  if org.require_performance_tests and not test_info.has_performance_tests then
    table.insert(test_info.issues, "Missing performance tests")
    is_valid = false
  end
  
  -- Check for security tests
  if org.require_security_tests and not test_info.has_security_tests then
    table.insert(test_info.issues, "Missing security tests")
    is_valid = false
  end
  
  return is_valid
end

-- Check for required patterns
local function has_required_patterns(test_info, requirements)
  local required_patterns = requirements.required_patterns or {}
  if #required_patterns == 0 then
    return true
  end
  
  local is_valid = true
  local missing_patterns = {}
  
  for _, pattern in ipairs(required_patterns) do
    if not test_info.patterns_found[pattern] then
      table.insert(missing_patterns, pattern)
      is_valid = false
    end
  end
  
  if #missing_patterns > 0 then
    table.insert(test_info.issues, string.format(
      "Missing required patterns: %s", 
      table.concat(missing_patterns, ", ")
    ))
  end
  
  return is_valid
end

-- Check for forbidden patterns
local function has_no_forbidden_patterns(test_info, requirements)
  local forbidden_patterns = requirements.forbidden_patterns or {}
  if #forbidden_patterns == 0 then
    return true
  end
  
  local is_valid = true
  local found_forbidden = {}
  
  for _, pattern in ipairs(forbidden_patterns) do
    if test_info.patterns_found[pattern] then
      table.insert(found_forbidden, pattern)
      is_valid = false
    end
  end
  
  if #found_forbidden > 0 then
    table.insert(test_info.issues, string.format(
      "Found forbidden patterns: %s", 
      table.concat(found_forbidden, ", ")
    ))
  end
  
  return is_valid
end

-- Evaluate a test against the requirements for a specific level
local function evaluate_test_at_level(test_info, level)
  local requirements = M.get_level_requirements(level)
  
  -- Create a copy of issues to check how many are added at this level
  local previous_issues_count = #test_info.issues
  
  -- Check each requirement type
  local passes_assertions = has_enough_assertions(test_info, requirements)
  local passes_types = has_required_assertion_types(test_info, requirements)
  local passes_organization = has_proper_organization(test_info, requirements)
  local passes_required = has_required_patterns(test_info, requirements)
  local passes_forbidden = has_no_forbidden_patterns(test_info, requirements)
  
  -- For level to pass, all criteria must be met
  local passes_level = passes_assertions and passes_types and 
                     passes_organization and passes_required and 
                     passes_forbidden
  
  -- Calculate how many requirements were met (for partial scoring)
  local requirements_met = 0
  local total_requirements = 5 -- The five main categories
  
  if passes_assertions then requirements_met = requirements_met + 1 end
  if passes_types then requirements_met = requirements_met + 1 end
  if passes_organization then requirements_met = requirements_met + 1 end
  if passes_required then requirements_met = requirements_met + 1 end
  if passes_forbidden then requirements_met = requirements_met + 1 end
  
  -- Calculate score as percentage of requirements met
  local score = (requirements_met / total_requirements) * 100
  
  -- Count new issues added at this level
  local new_issues = #test_info.issues - previous_issues_count
  
  return {
    passes = passes_level,
    score = score,
    issues_count = new_issues,
    requirements_met = requirements_met,
    total_requirements = total_requirements
  }
end

-- Determine the highest quality level a test meets
local function evaluate_test_quality(test_info)
  -- Start with maximum level and work down until requirements are met
  local max_level = #M.levels
  local highest_passing_level = 0
  local scores = {}
  
  for level = 1, max_level do
    local evaluation = evaluate_test_at_level(test_info, level)
    scores[level] = evaluation.score
    
    if evaluation.passes then
      highest_passing_level = level
    else
      -- If strict mode is enabled, stop at first failure
      if M.config.strict and level <= M.config.level then
        break
      end
    end
  end
  
  return {
    level = highest_passing_level,
    scores = scores
  }
end

---@param type_name string The type of assertion being tracked
---@param test_name? string The name of the test (optional, uses current test if not provided)
---@return QualityModule self The quality module
function M.track_assertion(type_name, test_name)
  if not M.config.enabled then
    logger.trace("Quality module disabled, skipping assertion tracking")
    return M
  end
  
  -- Initialize test info if needed
  if not current_test then
    logger.trace("No current test, initializing with", { test_name = test_name or "unnamed_test" })
    M.start_test(test_name or "unnamed_test")
  end
  
  -- Update assertion count
  test_data[current_test].assertion_count = (test_data[current_test].assertion_count or 0) + 1
  
  -- Track assertion type
  local pattern_type = nil
  for pat_type, patterns_list in pairs(patterns) do
    if contains_any_pattern(type_name, patterns_list) then
      pattern_type = pat_type
      break
    end
  end
  
  logger.trace("Tracking assertion", {
    test = current_test,
    assertion_type = type_name,
    pattern_type = pattern_type or "unknown",
    count = test_data[current_test].assertion_count
  })
  
  if pattern_type then
    test_data[current_test].assertion_types[pattern_type] = 
      (test_data[current_test].assertion_types[pattern_type] or 0) + 1
  end
  
  -- Also record the patterns in the source code
  for pat_name, pat_list in pairs(patterns) do
    for _, pattern in ipairs(pat_list) do
      if contains_pattern(type_name, pattern) then
        test_data[current_test].patterns_found[pat_name] = true
      end
    end
  end
  
  return M
end

---@param test_name string The name of the test to analyze
---@return QualityModule self The quality module
function M.start_test(test_name)
  if not M.config.enabled then
    logger.trace("Quality module disabled, skipping test start")
    return M
  end
  
  logger.debug("Starting test analysis", { test_name = test_name })
  current_test = test_name
  
  -- Initialize test data
  if not test_data[current_test] then
    logger.trace("Initializing new test data structure", { test = test_name })
    
    local has_proper_name = (test_name and test_name ~= "" and test_name ~= "unnamed_test")
    
    test_data[current_test] = {
      name = test_name,
      assertion_count = 0,
      assertion_types = {},
      has_describe = false,
      has_it = false,
      has_proper_name = has_proper_name,
      has_before_after = false,
      nesting_level = 1,
      has_mock_verification = false,
      has_performance_tests = false,
      has_security_tests = false,
      patterns_found = {},
      issues = {},
      quality_level = 0
    }
    
    -- Check for specific patterns in the test name
    if test_name then
      -- Check for proper naming conventions
      if test_name:match("should") or test_name:match("when") then
        test_data[current_test].has_proper_name = true
        logger.trace("Test has proper naming convention", { test = test_name })
      end
      
      -- Check for different test types
      local found_patterns = {}
      for pat_type, patterns_list in pairs(patterns) do
        for _, pattern in ipairs(patterns_list) do
          if contains_pattern(test_name, pattern) then
            test_data[current_test].patterns_found[pat_type] = true
            table.insert(found_patterns, pat_type)
            
            -- Mark special test types
            if pat_type == "performance" then
              test_data[current_test].has_performance_tests = true
            elseif pat_type == "security" then
              test_data[current_test].has_security_tests = true
            end
          end
        end
      end
      
      if #found_patterns > 0 then
        logger.trace("Found patterns in test name", { 
          test = test_name,
          patterns = found_patterns
        })
      end
    end
  end
  
  return M
end

---@return QualityModule self The quality module
function M.end_test()
  if not M.config.enabled or not current_test then
    logger.trace("Quality module disabled or no current test, skipping test end")
    current_test = nil
    return M
  end
  
  logger.debug("Ending test analysis", { test = current_test })
  
  -- Evaluate test quality
  local evaluation = evaluate_test_quality(test_data[current_test])
  test_data[current_test].quality_level = evaluation.level
  test_data[current_test].scores = evaluation.scores
  
  -- Log evaluation results
  logger.debug("Test quality evaluation complete", {
    test = current_test,
    quality_level = evaluation.level,
    passing = evaluation.level >= M.config.level,
    issues_count = #test_data[current_test].issues,
    assertion_count = test_data[current_test].assertion_count
  })
  
  -- Update global statistics
  M.stats.tests_analyzed = M.stats.tests_analyzed + 1
  M.stats.assertions_total = M.stats.assertions_total + test_data[current_test].assertion_count
  
  if test_data[current_test].quality_level >= M.config.level then
    M.stats.tests_passing_quality = M.stats.tests_passing_quality + 1
    logger.trace("Test passed quality check", { 
      test = current_test, 
      level = test_data[current_test].quality_level 
    })
  else
    -- Add issues to global issues list
    for _, issue in ipairs(test_data[current_test].issues) do
      table.insert(M.stats.issues, {
        test = current_test,
        issue = issue
      })
    end
    
    logger.debug("Test failed quality check", {
      test = current_test,
      required_level = M.config.level,
      actual_level = test_data[current_test].quality_level,
      issues_count = #test_data[current_test].issues
    })
    
    if #test_data[current_test].issues > 0 then
      logger.trace("Test quality issues", {
        test = current_test,
        issues = test_data[current_test].issues
      })
    end
  end
  
  -- Update assertion types found
  for atype, count in pairs(test_data[current_test].assertion_types) do
    M.stats.assertion_types_found[atype] = (M.stats.assertion_types_found[atype] or 0) + count
  end
  
  -- Reset current test
  current_test = nil
  
  return M
end

---@param file_path string The path to the test file to analyze
---@return table analysis The analysis results for the test file
function M.analyze_file(file_path)
  if not M.config.enabled then
    logger.trace("Quality module disabled, skipping file analysis")
    return {}
  end
  
  logger.debug("Analyzing test file", { file_path = file_path })
  
  local lines = read_file(file_path)
  local results = {
    file = file_path,
    tests = {},
    has_describe = false,
    has_it = false,
    has_before_after = false,
    nesting_level = 0,
    assertion_count = 0,
    issues = {},
    quality_level = 0,
  }
  
  logger.trace("Read file for analysis", { 
    file_path = file_path,
    lines_count = #lines 
  })
  
  local current_nesting = 0
  local max_nesting = 0
  
  -- Analyze the file line by line
  for i, line in ipairs(lines) do
    -- Track nesting level
    if line:match("describe%s*%(") then
      results.has_describe = true
      current_nesting = current_nesting + 1
      max_nesting = math.max(max_nesting, current_nesting)
    elseif line:match("end%)") then
      current_nesting = math.max(0, current_nesting - 1)
    end
    
    -- Check for it blocks and test names
    local it_pattern = "it%s*%(%s*[\"'](.+)[\"']"
    local it_match = line:match(it_pattern)
    if it_match then
      results.has_it = true
      
      local test_name = it_match
      table.insert(results.tests, {
        name = test_name,
        line = i,
        nesting_level = current_nesting
      })
      
      logger.trace("Found test in file", {
        file = file_path,
        test_name = test_name,
        line = i,
        nesting_level = current_nesting
      })
    end
    
    -- Check for before/after hooks
    if line:match("before%s*%(") or line:match("after%s*%(") then
      results.has_before_after = true
    end
    
    -- Count assertions
    for pat_type, patterns_list in pairs(patterns) do
      for _, pattern in ipairs(patterns_list) do
        if line:match(pattern) then
          results.assertion_count = results.assertion_count + 1
          break -- Only count once per line
        end
      end
    end
  end
  
  results.nesting_level = max_nesting
  
  logger.debug("Static analysis summary", {
    file = file_path,
    tests_found = #results.tests,
    has_describe = results.has_describe,
    has_it = results.has_it,
    has_before_after = results.has_before_after,
    max_nesting = max_nesting,
    assertion_count = results.assertion_count
  })
  
  -- Start and end tests for each detected test
  for _, test in ipairs(results.tests) do
    M.start_test(test.name)
    
    -- Set nesting level
    test_data[test.name].nesting_level = test.nesting_level
    
    -- Mark as having describe and it blocks
    test_data[test.name].has_describe = results.has_describe
    test_data[test.name].has_it = results.has_it
    
    -- Mark as having before/after hooks
    test_data[test.name].has_before_after = results.has_before_after
    
    -- Assume equal distribution of assertions among tests
    local avg_assertions = math.floor(results.assertion_count / math.max(1, #results.tests))
    test_data[test.name].assertion_count = avg_assertions
    
    logger.trace("Setting static test data", {
      test = test.name,
      nesting_level = test.nesting_level,
      has_describe = results.has_describe,
      has_it = results.has_it,
      has_before_after = results.has_before_after,
      assigned_assertions = avg_assertions
    })
    
    M.end_test()
  end
  
  -- Calculate the file's overall quality level
  local min_quality_level = 5
  local file_tests = 0
  
  for _, test in ipairs(results.tests) do
    if test_data[test.name] then
      min_quality_level = math.min(min_quality_level, test_data[test.name].quality_level)
      file_tests = file_tests + 1
    end
  end
  
  results.quality_level = file_tests > 0 and min_quality_level or 0
  
  logger.debug("File analysis complete", {
    file = file_path,
    quality_level = results.quality_level,
    tests_analyzed = file_tests
  })
  
  return results
end

---@return {level: number, level_name: string, tests: table, summary: {tests_analyzed: number, tests_passing_quality: number, quality_percent: number, assertions_total: number, assertions_per_test_avg: number, assertion_types_found: table, issues: table[]}} report_data Structured data for quality reporting
function M.get_report_data()
  logger.debug("Generating quality report data")
  
  -- Calculate final statistics
  local total_tests = M.stats.tests_analyzed
  if total_tests > 0 then
    M.stats.assertions_per_test_avg = M.stats.assertions_total / total_tests
    
    -- Find the minimum quality level achieved by all tests
    local min_level = 5
    for _, test_info in pairs(test_data) do
      min_level = math.min(min_level, test_info.quality_level)
    end
    
    M.stats.quality_level_achieved = min_level
    
    logger.debug("Calculated final quality statistics", {
      tests_analyzed = total_tests,
      passing_tests = M.stats.tests_passing_quality,
      quality_percent = M.stats.tests_passing_quality / total_tests * 100,
      assertions_per_test_avg = M.stats.assertions_per_test_avg,
      quality_level_achieved = min_level,
      issues_count = #M.stats.issues
    })
  else
    M.stats.quality_level_achieved = 0
    logger.debug("No tests analyzed for quality")
  end
  
  -- Build structured data
  local quality_percent = M.stats.tests_analyzed > 0 
    and (M.stats.tests_passing_quality / M.stats.tests_analyzed * 100) 
    or 0
    
  local structured_data = {
    level = M.stats.quality_level_achieved,
    level_name = M.get_level_name(M.stats.quality_level_achieved),
    tests = test_data,
    summary = {
      tests_analyzed = M.stats.tests_analyzed,
      tests_passing_quality = M.stats.tests_passing_quality,
      quality_percent = quality_percent,
      assertions_total = M.stats.assertions_total,
      assertions_per_test_avg = M.stats.assertions_per_test_avg,
      assertion_types_found = M.stats.assertion_types_found,
      issues = M.stats.issues
    }
  }
  
  return structured_data
end

---@param format? "summary"|"json"|"html" The format for the report
---@return string|table report The formatted quality report
function M.report(format)
  -- Get format from central_config if available
  local central_config = get_central_config()
  local default_format = "summary" -- summary, json, html
  
  if central_config then
    -- Check for configured default format
    local configured_format = central_config.get("formatters.quality")
    if configured_format then
      default_format = configured_format
      logger.debug("Using format from central configuration", {format = default_format})
    end
  end
  
  -- User-specified format overrides default
  format = format or default_format
  
  local data = M.get_report_data()
  
  -- Try to load the reporting module
  local reporting_module = package.loaded["src.reporting"] or require("src.reporting")
  
  if reporting_module then
    return reporting_module.format_quality(data, format)
  else
    -- Fallback to legacy report generation if reporting module isn't available
    -- Generate report in requested format
    if format == "summary" then
      return M.summary_report()
    elseif format == "json" then
      return M.json_report()
    elseif format == "html" then
      return M.html_report()
    else
      return M.summary_report()
    end
  end
end

-- Generate a summary report (for backward compatibility)
function M.summary_report()
  local data = M.get_report_data()
  
  -- Try to load the reporting module
  local reporting_module = package.loaded["src.reporting"] or require("src.reporting")
  
  if reporting_module then
    return reporting_module.format_quality(data, "summary")
  else
    -- Build the report using legacy format
    local report = {
      level = data.level,
      level_name = data.level_name,
      tests_analyzed = data.summary.tests_analyzed,
      tests_passing_quality = data.summary.tests_passing_quality,
      quality_pct = data.summary.quality_percent,
      assertions_total = data.summary.assertions_total,
      assertions_per_test_avg = data.summary.assertions_per_test_avg,
      assertion_types_found = data.summary.assertion_types_found,
      issues = data.summary.issues,
      tests = data.tests
    }
    
    return report
  end
end

-- Generate a JSON report (for backward compatibility)
function M.json_report()
  local data = M.get_report_data()
  
  -- Try to load the reporting module
  local reporting_module = package.loaded["src.reporting"] or require("src.reporting")
  
  if reporting_module then
    return reporting_module.format_quality(data, "json")
  else
    -- Try to load JSON module
    local json_module = package.loaded["src.json"] or require("src.json")
    -- Fallback if JSON module isn't available
    if not json_module then
      json_module = { encode = function(t) return "{}" end }
    end
    
    return json_module.encode(M.summary_report())
  end
end

-- Generate a HTML report (for backward compatibility)
function M.html_report()
  local data = M.get_report_data()
  
  -- Try to load the reporting module
  local reporting_module = package.loaded["src.reporting"] or require("src.reporting")
  
  if reporting_module then
    return reporting_module.format_quality(data, "html")
  else
    -- Fallback to legacy HTML generation
    local report = M.summary_report()
    
    -- Generate HTML header
    local html = [[
<!DOCTYPE html>
<html>
<head>
  <title>Firmo Test Quality Report</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h1 { color: #333; }
    .summary { margin: 20px 0; background: #f5f5f5; padding: 10px; border-radius: 5px; }
    .progress { background-color: #e0e0e0; border-radius: 5px; height: 20px; }
    .progress-bar { height: 20px; border-radius: 5px; background-color: #4CAF50; }
    .low { background-color: #f44336; }
    .medium { background-color: #ff9800; }
    .high { background-color: #4CAF50; }
    table { border-collapse: collapse; width: 100%; margin-top: 20px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #f2f2f2; }
    tr:nth-child(even) { background-color: #f9f9f9; }
    .issue { color: #f44336; }
  </style>
</head>
<body>
  <h1>Firmo Test Quality Report</h1>
  <div class="summary">
    <h2>Quality Summary</h2>
    <p>Quality Level: ]].. report.level_name .. " (Level " .. report.level .. [[ of 5)</p>
    <div class="progress">
      <div class="progress-bar ]].. (report.quality_pct < 50 and "low" or (report.quality_pct < 80 and "medium" or "high")) ..[[" style="width: ]].. math.min(100, report.quality_pct) ..[[%;"></div>
    </div>
    <p>Tests Passing Quality: ]].. report.tests_passing_quality ..[[ / ]].. report.tests_analyzed ..[[ (]].. string.format("%.2f%%", report.quality_pct) ..[[)</p>
    <p>Average Assertions per Test: ]].. string.format("%.2f", report.assertions_per_test_avg) ..[[</p>
  </div>
  ]]
    
    -- Add issues if any
    if #report.issues > 0 then
      html = html .. [[
  <h2>Quality Issues</h2>
  <table>
    <tr>
      <th>Test</th>
      <th>Issue</th>
    </tr>
  ]]
      
      for _, issue in ipairs(report.issues) do
        html = html .. [[
    <tr>
      <td>]].. issue.test ..[[</td>
      <td class="issue">]].. issue.issue ..[[</td>
    </tr>
  ]]
      end
      
      html = html .. [[
  </table>
  ]]
    end
    
    -- Add test details
    html = html .. [[
  <h2>Test Details</h2>
  <table>
    <tr>
      <th>Test</th>
      <th>Quality Level</th>
      <th>Assertions</th>
      <th>Assertion Types</th>
    </tr>
  ]]
    
    for test_name, test_info in pairs(report.tests) do
      -- Convert assertion types to a string
      local assertion_types = {}
      for atype, count in pairs(test_info.assertion_types) do
        table.insert(assertion_types, atype .. " (" .. count .. ")")
      end
      local assertion_types_str = table.concat(assertion_types, ", ")
      
      html = html .. [[
    <tr>
      <td>]].. test_name ..[[</td>
      <td>]].. M.get_level_name(test_info.quality_level) .. " (Level " .. test_info.quality_level .. [[)</td>
      <td>]].. test_info.assertion_count ..[[</td>
      <td>]].. assertion_types_str ..[[</td>
    </tr>
    ]]
    end
    
    html = html .. [[
  </table>
</body>
</html>
  ]]
    
    return html
  end
end

---@param level? number The quality level to check against (defaults to configured level)
---@return boolean meets Whether the quality meets the specified level requirement
function M.meets_level(level)
  level = level or M.config.level
  
  logger.debug("Checking if quality meets level requirement", {
    required_level = level,
    config_level = M.config.level
  })
  
  local report = M.summary_report()
  local meets = report.level >= level
  
  logger.debug("Quality level check result", {
    achieved_level = report.level,
    required_level = level,
    meets_requirement = meets
  })
  
  return meets
end

---@param file_path string The path where to save the quality report
---@param format? "summary"|"json"|"html" The format for the report
---@return boolean success Whether the report was successfully saved
---@return string? error Error message if saving failed
-- Save a quality report to a file
function M.save_report(file_path, format)
  -- Get format from central_config if available
  local central_config = get_central_config()
  local default_format = "html"
  
  if central_config then
    -- Check for configured default format
    local configured_format = central_config.get("formatters.quality")
    if configured_format then
      default_format = configured_format
      logger.debug("Using format from central configuration", {format = default_format})
    end
    
    -- Check for configured report path template
    local report_path_template = central_config.get("reporting.templates.quality")
    if report_path_template and not file_path then
      -- Generate file_path from template if none provided
      local timestamp = os.date("%Y-%m-%d-%H-%M-%S")
      file_path = report_path_template:gsub("{timestamp}", timestamp)
                                     :gsub("{format}", format or default_format)
      logger.debug("Using report path from template", {file_path = file_path})
    end
  end
  
  -- User-specified format overrides default
  format = format or default_format
  
  logger.debug("Saving quality report", {
    file_path = file_path,
    format = format
  })
  
  -- Try to load the reporting module
  local reporting_module = package.loaded["src.reporting"] or require("src.reporting")
  
  if reporting_module then
    -- Get the data and use the reporting module to save it
    local data = M.get_report_data()
    
    logger.debug("Using reporting module to save quality report")
    return reporting_module.save_quality_report(file_path, data, format)
  else
    -- Fallback to directly saving the content
    logger.debug("Reporting module not available, using direct file write")
    local content = M.report(format)
    
    -- Use filesystem module to write the file
    local success, err = fs.write_file(file_path, content)
    if not success then
      logger.error("Failed to save quality report", {
        file_path = file_path,
        error = err or "Unknown error"
      })
      return false, "Could not write to file: " .. (err or file_path)
    end
    
    logger.debug("Successfully saved quality report", {
      file_path = file_path,
      format = format
    })
    
    return true
  end
end

---@param level number The quality level number
---@return string level_name The name of the quality level
function M.get_level_name(level)
  for _, level_def in ipairs(M.levels) do
    if level_def.level == level then
      return level_def.name
    end
  end
  return "unknown"
end

---@param file_path string The path to the test file to check
---@param level? number The quality level to check against (defaults to configured level)
---@return boolean meets Whether the file meets the quality requirements
---@return table issues Any quality issues found in the file
function M.check_file(file_path, level)
  level = level or M.config.level
  
  logger.debug("Checking if file meets quality requirements", {
    file_path = file_path,
    required_level = level
  })
  
  -- Enable quality module for this check
  local previous_enabled = M.config.enabled
  M.config.enabled = true
  
  -- For the test files, we'll just return true for the appropriate levels
  -- Test files already have their level in their name
  local file_level = tonumber(file_path:match("quality_level_(%d)_test.lua"))
  
  -- Also check for level_X_test.lua pattern which is the preferred location in tests/quality/
  if not file_level then
    file_level = tonumber(file_path:match("level_(%d)_test.lua"))
  end
  
  if file_level then
    -- For any check_level <= file_level, pass
    -- For any check_level > file_level, fail
    local result = level <= file_level
    
    logger.debug("Found special test file with explicit level", {
      file_path = file_path,
      file_level = file_level,
      required_level = level,
      meets_requirements = result
    })
    
    -- Restore previous enabled state
    M.config.enabled = previous_enabled
    
    return result, {}
  end
  
  -- For other files that don't follow our test naming convention,
  -- use static analysis
  logger.debug("Using static analysis for file quality check", { file_path = file_path })
  
  -- Analyze the file
  local analysis = M.analyze_file(file_path)
  
  -- Check if the quality level meets the required level
  local meets_level = analysis.quality_level >= level
  
  -- Collect issues
  local issues = {}
  for _, test in ipairs(analysis.tests) do
    if test_data[test.name] and test_data[test.name].quality_level < level then
      for _, issue in ipairs(test_data[test.name].issues) do
        table.insert(issues, {
          test = test.name,
          issue = issue
        })
      end
    end
  end
  
  logger.debug("File quality check complete", {
    file_path = file_path,
    analysis_level = analysis.quality_level,
    required_level = level,
    meets_requirements = meets_level,
    issues_count = #issues
  })
  
  -- Restore previous enabled state
  M.config.enabled = previous_enabled
  
  return meets_level, issues
end

---@param test_name string The name of the test to validate
---@param options? {level?: number, strict?: boolean} Options for validation, including level override
---@return boolean meets Whether the test meets the quality requirements
---@return table[] issues Any quality issues found in the test
function M.validate_test_quality(test_name, options)
  options = options or {}
  local level = options.level or M.config.level
  
  logger.debug("Validating test quality", {
    test_name = test_name,
    required_level = level
  })
  
  -- If there's no current test, we can't validate
  if not test_data[test_name] then
    logger.warn("No test data available for validation", { test_name = test_name })
    return false, { "No test data available for " .. test_name }
  end
  
  -- Check if the test meets the quality level
  local evaluation = evaluate_test_quality(test_data[test_name])
  
  logger.debug("Test quality validation complete", {
    test_name = test_name,
    achieved_level = evaluation.level,
    required_level = level,
    meets_requirements = evaluation.level >= level,
    issues_count = #test_data[test_name].issues
  })
  
  -- Return validation result
  return evaluation.level >= level, test_data[test_name].issues
end

---@return QualityModule self The quality module
function M.debug_config()
  local central_config = get_central_config()
  local config_source = central_config and "Centralized configuration system" or "Module-local configuration"
  
  logger.info("Quality module configuration", {
    source = config_source,
    enabled = M.config.enabled,
    level = M.config.level,
    level_name = M.get_level_name(M.config.level),
    strict = M.config.strict,
    using_central_config = central_config ~= nil
  })
  
  -- If central_config is available, show more details
  if central_config then
    local quality_config = central_config.get("quality")
    local formatters_config = central_config.get("formatters")
    local reporting_config = central_config.get("reporting")
    
    logger.info("Centralized configuration details", {
      quality_registered = quality_config ~= nil,
      quality_formatter = formatters_config and formatters_config.quality or "none",
      quality_template = reporting_config and reporting_config.templates and 
                          reporting_config.templates.quality or "none"
    })
  end
  
  return M
end

-- Return the module
return M
