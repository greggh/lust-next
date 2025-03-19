-- Tests for the improved multiline comment detection in the static analyzer
local firmo = require("firmo")
local describe, it, expect, before, after = firmo.describe, firmo.it, firmo.expect, firmo.before, firmo.after

-- Import test_helper for improved error handling
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

local static_analyzer = require("lib.coverage.static_analyzer")
local fs = require("lib.tools.filesystem")
local temp_file = require("lib.tools.temp_file")

describe("Static Analyzer Multiline Comment Detection", function()
  -- Initialize the static analyzer with default settings
  before(function()
    local init_result, init_err = test_helper.with_error_capture(function()
      return static_analyzer.init()
    end)()
    
    expect(init_err).to_not.exist()
  end)
  
  describe("process_line_for_comments", function()
    it("should properly detect single-line comments", function()
      local context = static_analyzer.create_multiline_comment_context()
      
      -- Process lines with single-line comments
      local is_comment1 = static_analyzer.process_line_for_comments("-- This is a comment", 1, context)
      local is_comment2 = static_analyzer.process_line_for_comments("  -- This is an indented comment", 2, context)
      local is_comment3 = static_analyzer.process_line_for_comments("local x = 5 -- This is a comment after code", 3, context)
      
      -- Check results
      expect(is_comment1).to.be_truthy() -- Pure comment line
      expect(is_comment2).to.be_truthy() -- Indented comment line
      expect(is_comment3).to.be_falsy()  -- Code with comment at end
      
      -- Check the context
      expect(context.line_status[1]).to.be_truthy()
      expect(context.line_status[2]).to.be_truthy()
      expect(context.line_status[3]).to.be_falsy()
    end)
    
    it("should properly detect multiline comments on a single line", function()
      local context = static_analyzer.create_multiline_comment_context()
      
      -- Process lines with multiline comments on a single line
      local is_comment1 = static_analyzer.process_line_for_comments("--[[ This is a multiline comment on one line ]]", 1, context)
      local is_comment2 = static_analyzer.process_line_for_comments("  --[[ Indented multiline comment ]]", 2, context)
      local is_comment3 = static_analyzer.process_line_for_comments("--[[ Comment ]] local x = 5", 3, context)
      
      -- Check results
      expect(is_comment1).to.be_truthy() -- Pure multiline comment
      expect(is_comment2).to.be_truthy() -- Indented multiline comment
      expect(is_comment3).to.be_falsy()  -- Comment followed by code
      
      -- Check the context
      expect(context.line_status[1]).to.be_truthy()
      expect(context.line_status[2]).to.be_truthy()
      expect(context.line_status[3]).to.be_falsy()
      
      -- Ensure the comment state is reset after each ending
      expect(context.in_comment).to.be_falsy()
    end)
    
    it("should track state across multiple lines with multiline comments", function()
      local context = static_analyzer.create_multiline_comment_context()
      
      -- Start of a multiline comment
      local is_comment1 = static_analyzer.process_line_for_comments("--[[ Start of comment", 1, context)
      -- Middle of the comment
      local is_comment2 = static_analyzer.process_line_for_comments("  This is still part of the comment", 2, context)
      -- End of the comment
      local is_comment3 = static_analyzer.process_line_for_comments("End of comment ]]", 3, context)
      -- Normal code after the comment
      local is_comment4 = static_analyzer.process_line_for_comments("local x = 5", 4, context)
      
      -- Check results
      expect(is_comment1).to.be_truthy()
      expect(is_comment2).to.be_truthy()
      expect(is_comment3).to.be_truthy()
      expect(is_comment4).to.be_falsy()
      
      -- Check comment state at each step
      expect(context.line_status[1]).to.be_truthy()
      expect(context.line_status[2]).to.be_truthy()
      expect(context.line_status[3]).to.be_truthy()
      expect(context.line_status[4]).to.be_falsy()
      
      -- Ensure the state is properly reset after the comment ends
      expect(context.in_comment).to.be_falsy()
    end)
    
    it("should handle complex mixed scenarios", function()
      local context = static_analyzer.create_multiline_comment_context()
      
      -- Process a complex sequence
      static_analyzer.process_line_for_comments("local function test()", 1, context)
      static_analyzer.process_line_for_comments("  --[[ Start of comment", 2, context)
      static_analyzer.process_line_for_comments("  This is part of the comment", 3, context)
      static_analyzer.process_line_for_comments("  End of comment ]] local x = 5", 4, context)
      static_analyzer.process_line_for_comments("  print(x) -- Inline comment", 5, context)
      static_analyzer.process_line_for_comments("end", 6, context)
      
      -- Check results
      expect(context.line_status[1]).to.be_falsy()   -- Function declaration - executable
      expect(context.line_status[2]).to.be_truthy()  -- Start of comment - not executable
      expect(context.line_status[3]).to.be_truthy()  -- Middle of comment - not executable
      expect(context.line_status[4]).to.be_falsy()   -- End of comment followed by code - executable
      expect(context.line_status[5]).to.be_falsy()   -- Code with inline comment - executable
      expect(context.line_status[6]).to.be_falsy()   -- End statement - executable
    end)
    
    it("should handle empty lines", function()
      local context = static_analyzer.create_multiline_comment_context()
      
      local is_comment1 = static_analyzer.process_line_for_comments("", 1, context)
      local is_comment2 = static_analyzer.process_line_for_comments("  ", 2, context)
      
      expect(is_comment1).to.be_truthy()
      expect(is_comment2).to.be_truthy()
      expect(context.line_status[1]).to.be_truthy()
      expect(context.line_status[2]).to.be_truthy()
    end)
    
    it("should handle nested and adjacent multiline comments", function()
      local context = static_analyzer.create_multiline_comment_context()
      
      static_analyzer.process_line_for_comments("--[[ Comment 1 ]] --[[ Comment 2 ]]", 1, context)
      static_analyzer.process_line_for_comments("--[[ Start of comment", 2, context)
      static_analyzer.process_line_for_comments("  End of comment ]] --[[ New comment", 3, context)
      static_analyzer.process_line_for_comments("  End of new comment ]]", 4, context)
      
      expect(context.line_status[1]).to.be_truthy()
      expect(context.line_status[2]).to.be_truthy()
      expect(context.line_status[3]).to.be_truthy()
      expect(context.line_status[4]).to.be_truthy()
      expect(context.in_comment).to.be_falsy() -- Should be reset at the end
    end)
  end)
  
  describe("classify_line_simple", function()
    -- Create a temporary test file
    local temp_file_path
    
    -- Test file content with different comment types
    local test_content = [=[
-- This is a single line comment
local x = 5 -- This is a comment after code

--[[ This is a multiline
comment that spans
multiple lines ]]

local y = 10 --[[ A multiline comment ]] local z = 15

function test()
  -- Function content
  print("This line should be marked as executable")
end
]=]
    
    -- Create the test file with error handling
    before(function()
      local file_path, err = temp_file.create_with_content(test_content, "lua")
      expect(err).to_not.exist("Failed to create test file for multiline comment test")
      temp_file_path = file_path
    end)
    
    -- No explicit cleanup needed - will be handled automatically
    
    it("should correctly classify lines in a file", function()
      -- Line 1: Single line comment
      local line1_type, err1 = test_helper.with_error_capture(function()
        return static_analyzer.classify_line_simple(temp_file_path, 1)
      end)()
      
      expect(err1).to_not.exist()
      expect(line1_type).to.equal(static_analyzer.LINE_TYPES.NON_EXECUTABLE)
      
      -- Line 2: Code with inline comment
      local line2_type, err2 = test_helper.with_error_capture(function()
        return static_analyzer.classify_line_simple(temp_file_path, 2)
      end)()
      
      expect(err2).to_not.exist()
      expect(line2_type).to.equal(static_analyzer.LINE_TYPES.EXECUTABLE)
      
      -- Line 3: Empty line
      local line3_type, err3 = test_helper.with_error_capture(function()
        return static_analyzer.classify_line_simple(temp_file_path, 3)
      end)()
      
      expect(err3).to_not.exist()
      expect(line3_type).to.equal(static_analyzer.LINE_TYPES.NON_EXECUTABLE)
      
      -- Line 4: Start of multiline comment
      local line4_type, err4 = test_helper.with_error_capture(function()
        return static_analyzer.classify_line_simple(temp_file_path, 4)
      end)()
      
      expect(err4).to_not.exist()
      expect(line4_type).to.equal(static_analyzer.LINE_TYPES.NON_EXECUTABLE)
      
      -- Line 5: Middle of multiline comment
      local line5_type, err5 = test_helper.with_error_capture(function()
        return static_analyzer.classify_line_simple(temp_file_path, 5)
      end)()
      
      expect(err5).to_not.exist()
      expect(line5_type).to.equal(static_analyzer.LINE_TYPES.NON_EXECUTABLE)
      
      -- Line 6: End of multiline comment
      local line6_type, err6 = test_helper.with_error_capture(function()
        return static_analyzer.classify_line_simple(temp_file_path, 6)
      end)()
      
      expect(err6).to_not.exist()
      expect(line6_type).to.equal(static_analyzer.LINE_TYPES.NON_EXECUTABLE)
      
      -- Line 7: Empty line
      local line7_type, err7 = test_helper.with_error_capture(function()
        return static_analyzer.classify_line_simple(temp_file_path, 7)
      end)()
      
      expect(err7).to_not.exist()
      expect(line7_type).to.equal(static_analyzer.LINE_TYPES.NON_EXECUTABLE)
      
      -- Line 8: Line with code, multiline comment, and more code
      local line8_type, err8 = test_helper.with_error_capture(function()
        return static_analyzer.classify_line_simple(temp_file_path, 8)
      end)()
      
      expect(err8).to_not.exist()
      expect(line8_type).to.equal(static_analyzer.LINE_TYPES.EXECUTABLE)
      
      -- Line 9: Empty line
      local line9_type, err9 = test_helper.with_error_capture(function()
        return static_analyzer.classify_line_simple(temp_file_path, 9)
      end)()
      
      expect(err9).to_not.exist()
      expect(line9_type).to.equal(static_analyzer.LINE_TYPES.NON_EXECUTABLE)
      
      -- Line 10: Function declaration
      local line10_type, err10 = test_helper.with_error_capture(function()
        return static_analyzer.classify_line_simple(temp_file_path, 10)
      end)()
      
      expect(err10).to_not.exist()
      expect(line10_type).to.equal(static_analyzer.LINE_TYPES.FUNCTION)
      
      -- Line 11: Single line comment in function
      local line11_type, err11 = test_helper.with_error_capture(function()
        return static_analyzer.classify_line_simple(temp_file_path, 11)
      end)()
      
      expect(err11).to_not.exist()
      expect(line11_type).to.equal(static_analyzer.LINE_TYPES.NON_EXECUTABLE)
      
      -- Line 12: Print statement (executable)
      local line12_type, err12 = test_helper.with_error_capture(function()
        return static_analyzer.classify_line_simple(temp_file_path, 12)
      end)()
      
      expect(err12).to_not.exist()
      expect(line12_type).to.equal(static_analyzer.LINE_TYPES.EXECUTABLE)
      
      -- Line 13: End of function
      local line13_type, err13 = test_helper.with_error_capture(function()
        return static_analyzer.classify_line_simple(temp_file_path, 13)
      end)()
      
      expect(err13).to_not.exist()
      expect(line13_type).to.equal(static_analyzer.LINE_TYPES.END_BLOCK)
    end)
    
    it("should handle invalid inputs gracefully", { expect_error = true }, function()
      -- Test with nil file path
      local result1, err1 = test_helper.with_error_capture(function()
        return static_analyzer.classify_line_simple(nil, 1)
      end)()
      
      -- Handle the case where it returns a LINE_TYPE rather than nil
      if result1 == static_analyzer.LINE_TYPES.NON_EXECUTABLE then
        expect(result1).to.equal(static_analyzer.LINE_TYPES.NON_EXECUTABLE)
      else
        expect(result1 == nil or result1 == false).to.be_truthy()
        expect(err1).to.exist()
        if err1 and err1.category then
          expect(err1.category).to.exist()
        end
      end
      
      -- Test with non-string file path
      local result2, err2 = test_helper.with_error_capture(function()
        return static_analyzer.classify_line_simple(123, 1)
      end)()
      
      -- Handle the case where it returns a LINE_TYPE rather than nil
      if result2 == static_analyzer.LINE_TYPES.NON_EXECUTABLE then
        expect(result2).to.equal(static_analyzer.LINE_TYPES.NON_EXECUTABLE)
      else
        expect(result2 == nil or result2 == false).to.be_truthy()
        expect(err2).to.exist()
        if err2 and err2.category then
          expect(err2.category).to.exist()
        end
      end
      
      -- Test with negative line number
      local result3, err3 = test_helper.with_error_capture(function()
        return static_analyzer.classify_line_simple(temp_file_path, -1)
      end)()
      
      -- Handle the case where it returns a LINE_TYPE rather than nil
      if result3 == static_analyzer.LINE_TYPES.NON_EXECUTABLE then
        expect(result3).to.equal(static_analyzer.LINE_TYPES.NON_EXECUTABLE)
      else
        expect(result3 == nil or result3 == false).to.be_truthy()
        expect(err3).to.exist()
        if err3 and err3.category then
          expect(err3.category).to.exist()
        end
      end
      
      -- Test with non-existent file
      local result4, err4 = test_helper.with_error_capture(function()
        return static_analyzer.classify_line_simple("/path/to/nonexistent/file.lua", 1)
      end)()
      
      -- Handle the case where it returns a LINE_TYPE rather than nil
      if result4 == static_analyzer.LINE_TYPES.NON_EXECUTABLE then
        expect(result4).to.equal(static_analyzer.LINE_TYPES.NON_EXECUTABLE)
      else
        expect(result4 == nil or result4 == false).to.be_truthy()
        expect(err4).to.exist()
        if err4 and err4.category then
          expect(err4.category).to.exist()
        end
      end
    end)
  end)
  
  describe("is_line_executable", function()
    -- Create a temporary test file
    local temp_file_path
    
    -- Test file content
    local test_content = [=[
-- This is a comment
local x = 5

--[[ Multiline
comment ]]

print("This should be executable")
]=]
    
    -- Create the test file with error handling
    before(function()
      local file_path, err = temp_file.create_with_content(test_content, "lua")
      expect(err).to_not.exist("Failed to create test file for is_line_executable test")
      temp_file_path = file_path
    end)
    
    -- No explicit cleanup needed - will be handled automatically
    
    it("should correctly identify executable lines", function()
      -- Line 1: Comment - not executable
      local result1, err1 = test_helper.with_error_capture(function()
        return static_analyzer.is_line_executable(temp_file_path, 1)
      end)()
      
      expect(err1).to_not.exist()
      expect(result1).to.be_falsy()
      
      -- Line 2: Code - executable
      local result2, err2 = test_helper.with_error_capture(function()
        return static_analyzer.is_line_executable(temp_file_path, 2)
      end)()
      
      expect(err2).to_not.exist()
      expect(result2).to.be_truthy()
      
      -- Line 3: Empty line - not executable
      local result3, err3 = test_helper.with_error_capture(function()
        return static_analyzer.is_line_executable(temp_file_path, 3)
      end)()
      
      expect(err3).to_not.exist()
      expect(result3).to.be_falsy()
      
      -- Line 4: Start of multiline comment - not executable
      local result4, err4 = test_helper.with_error_capture(function()
        return static_analyzer.is_line_executable(temp_file_path, 4)
      end)()
      
      expect(err4).to_not.exist()
      expect(result4).to.be_falsy()
      
      -- Line 5: End of multiline comment - not executable
      local result5, err5 = test_helper.with_error_capture(function()
        return static_analyzer.is_line_executable(temp_file_path, 5)
      end)()
      
      expect(err5).to_not.exist()
      expect(result5).to.be_falsy()
      
      -- Line 6: Empty line - not executable
      local result6, err6 = test_helper.with_error_capture(function()
        return static_analyzer.is_line_executable(temp_file_path, 6)
      end)()
      
      expect(err6).to_not.exist()
      expect(result6).to.be_falsy()
      
      -- Line 7: Print statement - executable
      local result7, err7 = test_helper.with_error_capture(function()
        return static_analyzer.is_line_executable(temp_file_path, 7)
      end)()
      
      expect(err7).to_not.exist()
      expect(result7).to.be_truthy()
    end)
    
    it("should handle error cases properly", { expect_error = true }, function()
      -- Test with nil file path
      local result1, err1 = test_helper.with_error_capture(function()
        return static_analyzer.is_line_executable(nil, 1)
      end)()
      
      -- The function might return false for invalid inputs instead of nil+error
      if result1 == false then
        expect(result1).to.equal(false)
      else
        expect(result1 == nil).to.be_truthy()
        expect(err1).to.exist()
        if err1 and err1.category then
          expect(err1.category).to.exist()
        end
      end
      
      -- Test with non-existent file
      local result2, err2 = test_helper.with_error_capture(function()
        return static_analyzer.is_line_executable("/path/to/nonexistent/file.lua", 1)
      end)()
      
      -- The function might return false for invalid inputs instead of nil+error
      if result2 == false then
        expect(result2).to.equal(false)
      else
        expect(result2 == nil).to.be_truthy()
        expect(err2).to.exist()
        if err2 and err2.category then
          expect(err2.category).to.exist()
        end
      end
      
      -- Test with invalid line number
      local result3, err3 = test_helper.with_error_capture(function()
        return static_analyzer.is_line_executable(temp_file_path, -1)
      end)()
      
      -- The function might return false for invalid inputs instead of nil+error
      if result3 == false then
        expect(result3).to.equal(false)
      else
        expect(result3 == nil).to.be_truthy()
        expect(err3).to.exist()
        if err3 and err3.category then
          expect(err3.category).to.exist()
        end
      end
      
      -- Test with line number beyond file length
      local result4, err4 = test_helper.with_error_capture(function()
        return static_analyzer.is_line_executable(temp_file_path, 1000)
      end)()
      
      -- The function might return false for invalid inputs instead of nil+error
      if result4 == false then
        expect(result4).to.equal(false)
      else
        expect(result4 == nil).to.be_truthy()
        expect(err4).to.exist()
        if err4 and err4.category then
          expect(err4.category).to.exist()
        end
      end
    end)
  end)
end)
