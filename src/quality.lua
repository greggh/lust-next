-- lust-next test quality validation module
-- Implementation of test quality analysis with level-based validation

local M = {}

-- Helper function for testing if a value contains a pattern
local function contains_pattern(value, pattern)
  if type(value) ~= "string" then
    return false
  end
  return string.find(value, pattern) ~= nil
end

-- Helper function to check for any of multiple patterns
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
        require_coverage_threshold = 95,
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

-- Configuration
M.config = {
  enabled = false,
  level = 1,
  strict = false,
  custom_rules = {},
  coverage_data = nil, -- Will hold reference to coverage module data if available
}

-- File cache for source code analysis
local file_cache = {}

-- Read a file and return its contents as an array of lines
local function read_file(filename)
  if file_cache[filename] then
    return file_cache[filename]
  end
  
  local file = io.open(filename, "r")
  if not file then
    return {}
  end
  
  local lines = {}
  for line in file:lines() do
    table.insert(lines, line)
  end
  file:close()
  
  file_cache[filename] = lines
  return lines
end

-- Initialize quality module
function M.init(options)
  options = options or {}
  
  -- Apply options with defaults
  for k, v in pairs(options) do
    M.config[k] = v
  end
  
  -- Connect to coverage module if available
  if package.loaded["src.coverage"] then
    M.config.coverage_data = package.loaded["src.coverage"]
  end
  
  M.reset()
  return M
end

-- Reset quality data
function M.reset()
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
  
  return M
end

-- Get level requirements
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

-- Track assertion usage in a test
function M.track_assertion(type_name, test_name)
  if not M.config.enabled then
    return
  end
  
  -- Initialize test info if needed
  if not current_test then
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

-- Start test analysis for a specific test
function M.start_test(test_name)
  if not M.config.enabled then
    return M
  end
  
  current_test = test_name
  
  -- Initialize test data
  if not test_data[current_test] then
    test_data[current_test] = {
      name = test_name,
      assertion_count = 0,
      assertion_types = {},
      has_describe = false,
      has_it = false,
      has_proper_name = (test_name and test_name ~= "" and test_name ~= "unnamed_test"),
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
      end
      
      -- Check for different test types
      for pat_type, patterns_list in pairs(patterns) do
        for _, pattern in ipairs(patterns_list) do
          if contains_pattern(test_name, pattern) then
            test_data[current_test].patterns_found[pat_type] = true
            
            -- Mark special test types
            if pat_type == "performance" then
              test_data[current_test].has_performance_tests = true
            elseif pat_type == "security" then
              test_data[current_test].has_security_tests = true
            end
          end
        end
      end
    end
  end
  
  return M
end

-- End test analysis and record results
function M.end_test()
  if not M.config.enabled or not current_test then
    current_test = nil
    return M
  end
  
  -- Evaluate test quality
  local evaluation = evaluate_test_quality(test_data[current_test])
  test_data[current_test].quality_level = evaluation.level
  test_data[current_test].scores = evaluation.scores
  
  -- Update global statistics
  M.stats.tests_analyzed = M.stats.tests_analyzed + 1
  M.stats.assertions_total = M.stats.assertions_total + test_data[current_test].assertion_count
  
  if test_data[current_test].quality_level >= M.config.level then
    M.stats.tests_passing_quality = M.stats.tests_passing_quality + 1
  else
    -- Add issues to global issues list
    for _, issue in ipairs(test_data[current_test].issues) do
      table.insert(M.stats.issues, {
        test = current_test,
        issue = issue
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

-- Analyze test file statically
function M.analyze_file(file_path)
  if not M.config.enabled then
    return {}
  end
  
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
  
  return results
end

-- Get structured data for quality report
function M.get_report_data()
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
  else
    M.stats.quality_level_achieved = 0
  end
  
  -- Build structured data
  local structured_data = {
    level = M.stats.quality_level_achieved,
    level_name = M.get_level_name(M.stats.quality_level_achieved),
    tests = test_data,
    summary = {
      tests_analyzed = M.stats.tests_analyzed,
      tests_passing_quality = M.stats.tests_passing_quality,
      quality_percent = M.stats.tests_analyzed > 0 
        and (M.stats.tests_passing_quality / M.stats.tests_analyzed * 100) 
        or 0,
      assertions_total = M.stats.assertions_total,
      assertions_per_test_avg = M.stats.assertions_per_test_avg,
      assertion_types_found = M.stats.assertion_types_found,
      issues = M.stats.issues
    }
  }
  
  return structured_data
end

-- Get quality report
function M.report(format)
  format = format or "summary" -- summary, json, html
  
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
  <title>Lust-Next Test Quality Report</title>
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
  <h1>Lust-Next Test Quality Report</h1>
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

-- Check if quality meets level requirement
function M.meets_level(level)
  level = level or M.config.level
  local report = M.summary_report()
  return report.level >= level
end

-- Save a quality report to a file
function M.save_report(file_path, format)
  format = format or "html"
  
  -- Try to load the reporting module
  local reporting_module = package.loaded["src.reporting"] or require("src.reporting")
  
  if reporting_module then
    -- Get the data and use the reporting module to save it
    local data = M.get_report_data()
    return reporting_module.save_quality_report(file_path, data, format)
  else
    -- Fallback to directly saving the content
    local content = M.report(format)
    
    -- Open the file for writing
    local file, err = io.open(file_path, "w")
    if not file then
      return false, "Could not open file for writing: " .. tostring(err)
    end
    
    -- Write content and close
    local write_ok, write_err = pcall(function()
      file:write(content)
      file:close()
    end)
    
    if not write_ok then
      return false, "Error writing to file: " .. tostring(write_err)
    end
    
    return true
  end
end

-- Get level name from level number
function M.get_level_name(level)
  for _, level_def in ipairs(M.levels) do
    if level_def.level == level then
      return level_def.name
    end
  end
  return "unknown"
end

-- Return the module
return M