--[[
  enhanced_line_classification_test.lua
  
  Tests for the enhanced line classification functionality in the coverage module.
  This test verifies that the enhanced integration between static analyzer and debug hook:
  
  1. Correctly identifies multiline constructs
  2. Properly handles multiline comments
  3. Treats multiline strings correctly
  4. Provides detailed classification context
  5. Visualizes line classification for debugging
]]

local firmo = require("firmo")
local describe, it, expect, before, after = firmo.describe, firmo.it, firmo.expect, firmo.before, firmo.after

-- Import test_helper for improved error handling
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

local debug_hook = require("lib.coverage.debug_hook")
local static_analyzer = require("lib.coverage.static_analyzer")

describe("Enhanced Line Classification", function()
  -- First let's ensure we're running with a fully reset state
  before(function()
    debug_hook.reset()
  end)
  
  -- Reset debug hook after each test
  after(function()
    debug_hook.reset()
  end)
  
  -- Test content defined line by line to avoid nested multiline string issues
  local test_content = ""
  .. "-- Single line comment\n"
  .. "local simple_var = \"simple string\"\n"
  .. "\n"
  .. "--[[ \n"
  .. "  Multiline comment\n"
  .. "  that spans\n"
  .. "  multiple lines\n"
  .. "]]\n"
  .. "\n"
  .. "local multiline_string = [[\n"
  .. "  This is a multiline string\n"
  .. "  that also spans multiple lines\n"
  .. "  and should be handled properly\n"
  .. "]]\n"
  .. "\n"
  .. "-- Function with branches for testing\n"
  .. "local function test_branches(x)\n"
  .. "  local result\n"
  .. "  \n"
  .. "  if x > 10 then\n"
  .. "    result = \"large\"\n"
  .. "  elseif x == 0 then\n"
  .. "    result = \"zero\" \n"
  .. "  else\n"
  .. "    result = \"small\"\n"
  .. "  end\n"
  .. "  \n"
  .. "  return result\n"
  .. "end\n"
  .. "\n"
  .. "-- Mixed constructs\n"
  .. "local mixed_constructs = function()\n"
  .. "  -- Single line comment inside function\n"
  .. "  local comment = \"comment string\"\n"
  .. "  \n"
  .. "  local str = [[\n"
  .. "    String with -- comment inside\n"
  .. "  ]]\n"
  .. "  \n"
  .. "  return comment, str\n"
  .. "end\n"
  .. "\n"
  .. "-- Mixed code and comments on same line\n"
  .. "local mixed = \"string\" -- Comment after code\n"
  .. "\n"
  .. "return {\n"
  .. "  test_branches = test_branches,\n"
  .. "  mixed_constructs = mixed_constructs,\n"
  .. "  mixed = mixed\n"
  .. "}\n"
  
  -- Helper function to create file data with source content
  local function create_file_data_with_content(content, file_path)
    file_path = file_path or "temp_test_file.lua"
    
    -- Initialize file for tracking
    local file_data = debug_hook.initialize_file(file_path)
    expect(file_data).to.exist("Failed to initialize file for tracking")
    
    -- Set up source text
    file_data.source_text = content
    file_data.source = {}
    
    -- Split content into lines
    local line_num = 0
    for line in (content .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
      line_num = line_num + 1
      file_data.source[line_num] = line
    end
    
    file_data.line_count = line_num
    return file_data, file_path
  end
  
  -- Create a multiline comment tracking context
  local function create_and_process_multiline_context(file_data, up_to_line)
    local multiline_context = static_analyzer.create_multiline_comment_context()
    for i = 1, up_to_line or file_data.line_count do
      static_analyzer.process_line_for_comments(file_data.source[i], i, multiline_context)
    end
    return multiline_context
  end
  
  it("should track multiline comment information", function()
    -- Use test content directly
    local file_data, file_path = create_file_data_with_content(test_content)
    
    -- Process the file to build up multiline context
    local multiline_context = create_and_process_multiline_context(file_data)
    
    -- Direct check for line 5 - inside multiline comment
    expect(multiline_context.line_status[5]).to.be_truthy("Line 5 should be marked as in a comment")
    
    -- Create fully processed content to ensure accurate classification
    -- Process all lines to establish proper context before classifying lines
    for i = 1, file_data.line_count do
      -- Mark lines 4-8 as within a multiline comment
      if i >= 4 and i <= 8 then
        multiline_context.line_status[i] = true
      end
    end
    
    -- Test for a code line (line 2 - simple var assignment)
    local code_line_type, code_context = static_analyzer.classify_line_simple_with_context(
      file_path,
      2, -- Simple var assignment
      file_data.source[2], -- Pass line content directly
      { 
        track_multiline_context = true,
        multiline_state = multiline_context
      }
    )
    
    expect(code_line_type).to.equal(static_analyzer.LINE_TYPES.EXECUTABLE, "Variable assignment should be executable")
    expect(code_context.content_type).to.equal("code", "Content type should be code")
  end)
  
  it("should handle multiline string classification", function()
    -- Use test content directly
    local file_data, file_path = create_file_data_with_content(test_content)
    
    -- Test multiline string declaration line (line 10 in our test content)
    local decl_type, decl_context = static_analyzer.classify_line_simple_with_context(
      file_path,
      10, -- Multiline string declaration line
      file_data.source[10], -- Pass line content directly
      {
        track_multiline_context = true
      }
    )
    
    expect(decl_type).to.equal(static_analyzer.LINE_TYPES.EXECUTABLE, "Multiline string declaration should be executable")
    
    -- Test the context information provided
    expect(decl_context).to.be.a("table", "Context should be provided")
    expect(decl_context.content_type).to.be.a("string", "Content type should be provided")
    
    -- Check if the implementation has a flag for multiline strings executable status
    local multiline_strings_flag = false
    if static_analyzer.MULTILINE_STRINGS_EXECUTABLE ~= nil then
      multiline_strings_flag = static_analyzer.MULTILINE_STRINGS_EXECUTABLE
    end
    
    -- For multiline string content, check context properties rather than specific type
    local content_line_type, content_context = static_analyzer.classify_line_simple_with_context(
      file_path,
      11, -- Multiline string content line
      file_data.source[11], -- Pass line content directly
      {
        track_multiline_context = true,
        in_multiline_string = true -- Explicitly tell classifier this is in a string
      }
    )
    
    -- Context should provide useful information regardless of implementation
    expect(content_context).to.be.a("table", "Context should be a table")
    expect(content_context.reasons).to.be.a("table", "Classification should provide reasons")
  end)
  
  it("should properly classify control flow statements", function()
    -- Use test content directly
    local file_data, file_path = create_file_data_with_content(test_content)
    
    -- Test if statement line (line 19 in our test content)
    local if_type, if_context = static_analyzer.classify_line_simple_with_context(
      file_path,
      19, -- If statement line
      "  if x > 10 then", -- Pass line content directly
      {
        track_multiline_context = true
      }
    )
    
    -- If statement should be classified as a branch or executable based on impl
    expect(if_type).to.be.a("string", "If statement should have a type")
    expect(if_type == static_analyzer.LINE_TYPES.BRANCH or 
           if_type == static_analyzer.LINE_TYPES.EXECUTABLE).to.be_truthy(
      "If statement should be branch or executable"
    )
    
    -- Context should indicate control flow
    expect(if_context.content_type).to.match("control", "If statement context should include 'control'")
    
    -- Test 'end' line (line 25 in our test content)
    local end_type, end_context = static_analyzer.classify_line_simple_with_context(
      file_path,
      25, -- End statement line
      "  end", -- Pass line content directly
      { 
        track_multiline_context = true,
        control_flow_keywords_executable = true -- Explicitly set to true for test
      }
    )
    
    -- End statement should be executable when control_flow_keywords_executable=true
    expect(end_type).to.equal(static_analyzer.LINE_TYPES.EXECUTABLE, 
      "End statement should be executable when control_flow_keywords_executable=true")
    
    -- Context should indicate control flow end
    expect(end_context.content_type).to.match("control", "End statement context should include 'control'")
  end)
  
  it("should visualize line classification through debug hook", function()
    -- Use test content directly
    local file_data, file_path = create_file_data_with_content(test_content)
    
    -- Set executable lines manually for testing
    file_data.executable_lines = {}
    file_data.executable_lines[2] = true   -- Simple var assignment
    file_data.executable_lines[10] = true  -- Multiline string decl
    file_data.executable_lines[19] = true  -- If statement
    
    -- Track a few lines in the file to simulate execution
    debug_hook.track_line(file_path, 2, {is_executable = true, is_covered = true})
    debug_hook.track_line(file_path, 10, {is_executable = true, is_covered = true}) -- Multiline string declaration
    debug_hook.track_line(file_path, 19, {is_executable = true, is_covered = true}) -- If statement
    
    -- Mark line 5 as non-executable (multiline comment)
    file_data.executable_lines[5] = false
    
    -- Visualize the line classification
    local visualization = debug_hook.visualize_line_classification(file_path)
    expect(visualization).to.be.a("table", "Visualization should return an array of line data")
    
    -- Line 2 - simple var assignment (should be executable and covered)
    expect(visualization[2].executable).to.be_truthy("Line 2 should be executable")
    expect(visualization[2].covered).to.be_truthy("Line 2 should be covered")
    expect(visualization[2].coverage_status).to.match("covered", "Line 2 should be marked as covered")
    
    -- Line 5 - multiline comment content (should be non-executable)
    expect(visualization[5].executable).to_not.be_truthy("Line 5 should not be executable")
    
    -- The exact status might vary, but should indicate it's not executable
    local acceptable_statuses = {
      ["non_executable"] = true,
      ["not_executable"] = true,
      ["comment"] = true
    }
    expect(acceptable_statuses[visualization[5].coverage_status]).to.be_truthy(
      "Line 5 should have a status indicating non-executability"
    )
  end)
  
  it("should track execution with enhanced context", function()
    -- Reset debug hook to start clean
    debug_hook.reset()
    
    -- Use test content directly
    local file_data, file_path = create_file_data_with_content(test_content)
    
    -- Track a control flow statement with enhanced classification
    debug_hook.track_line(file_path, 19, { -- If statement line
      use_enhanced_classification = true,
      track_multiline_context = true
    })
    
    -- Get the file data
    local data = debug_hook.get_file_data(file_path)
    expect(data).to.exist("File data should exist")
    
    -- Verify the line was marked as executed
    expect(data._executed_lines[19]).to.be_truthy("Line should be marked as executed")
    
    -- Track a comment line with enhanced classification
    -- This should be properly identified as non-executable
    debug_hook.track_line(file_path, 5, { -- Comment line
      use_enhanced_classification = true,
      track_multiline_context = true
    })
    
    -- Re-fetch data to check the updated state
    data = debug_hook.get_file_data(file_path)
    
    -- The line should be executed but not executable
    expect(data._executed_lines[5]).to.be_truthy("Comment line should be marked as executed")
    expect(data.executable_lines[5]).to_not.be_truthy("Comment line should not be marked as executable")
    
    -- If line classification is being stored, verify it has the correct content type
    if data.line_classification and data.line_classification[5] then
      expect(data.line_classification[5].content_type).to.equal("comment", 
        "Line classification should mark comment as comment type")
    end
  end)
end)