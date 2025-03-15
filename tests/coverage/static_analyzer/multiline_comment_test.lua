-- Tests for the improved multiline comment detection in the static analyzer
local firmo = require("firmo")
local describe, it, expect, before, after = firmo.describe, firmo.it, firmo.expect, firmo.before, firmo.after

local static_analyzer = require("lib.coverage.static_analyzer")

describe("Static Analyzer Multiline Comment Detection", function()
  -- Initialize the static analyzer with default settings
  static_analyzer.init()
  
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
    local fs = require("lib.tools.filesystem")
    local temp_file_path = "/tmp/multiline_comment_test.lua"
    
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
    
    -- Create the test file
    before(function()
      fs.write_file(temp_file_path, test_content)
    end)
    
    it("should correctly classify lines in a file", function()
      -- Line 1: Single line comment
      local line1_type = static_analyzer.classify_line_simple(temp_file_path, 1)
      expect(line1_type).to.equal(static_analyzer.LINE_TYPES.NON_EXECUTABLE)
      
      -- Line 2: Code with inline comment
      local line2_type = static_analyzer.classify_line_simple(temp_file_path, 2)
      expect(line2_type).to.equal(static_analyzer.LINE_TYPES.EXECUTABLE)
      
      -- Line 3: Empty line
      local line3_type = static_analyzer.classify_line_simple(temp_file_path, 3)
      expect(line3_type).to.equal(static_analyzer.LINE_TYPES.NON_EXECUTABLE)
      
      -- Line 4: Start of multiline comment
      local line4_type = static_analyzer.classify_line_simple(temp_file_path, 4)
      expect(line4_type).to.equal(static_analyzer.LINE_TYPES.NON_EXECUTABLE)
      
      -- Line 5: Middle of multiline comment
      local line5_type = static_analyzer.classify_line_simple(temp_file_path, 5)
      expect(line5_type).to.equal(static_analyzer.LINE_TYPES.NON_EXECUTABLE)
      
      -- Line 6: End of multiline comment
      local line6_type = static_analyzer.classify_line_simple(temp_file_path, 6)
      expect(line6_type).to.equal(static_analyzer.LINE_TYPES.NON_EXECUTABLE)
      
      -- Line 7: Empty line
      local line7_type = static_analyzer.classify_line_simple(temp_file_path, 7)
      expect(line7_type).to.equal(static_analyzer.LINE_TYPES.NON_EXECUTABLE)
      
      -- Line 8: Line with code, multiline comment, and more code
      local line8_type = static_analyzer.classify_line_simple(temp_file_path, 8)
      expect(line8_type).to.equal(static_analyzer.LINE_TYPES.EXECUTABLE)
      
      -- Line 9: Empty line
      local line9_type = static_analyzer.classify_line_simple(temp_file_path, 9)
      expect(line9_type).to.equal(static_analyzer.LINE_TYPES.NON_EXECUTABLE)
      
      -- Line 10: Function declaration
      local line10_type = static_analyzer.classify_line_simple(temp_file_path, 10)
      expect(line10_type).to.equal(static_analyzer.LINE_TYPES.FUNCTION)
      
      -- Line 11: Single line comment in function
      local line11_type = static_analyzer.classify_line_simple(temp_file_path, 11)
      expect(line11_type).to.equal(static_analyzer.LINE_TYPES.NON_EXECUTABLE)
      
      -- Line 12: Print statement (executable)
      local line12_type = static_analyzer.classify_line_simple(temp_file_path, 12)
      expect(line12_type).to.equal(static_analyzer.LINE_TYPES.EXECUTABLE)
      
      -- Line 13: End of function
      local line13_type = static_analyzer.classify_line_simple(temp_file_path, 13)
      expect(line13_type).to.equal(static_analyzer.LINE_TYPES.END_BLOCK)
      
      -- Clean up
      os.remove(temp_file_path)
    end)
  end)
  
  describe("is_line_executable", function()
    -- Create a temporary test file
    local fs = require("lib.tools.filesystem")
    local temp_file_path = "/tmp/executable_line_test.lua"
    
    -- Test file content
    local test_content = [=[
-- This is a comment
local x = 5

--[[ Multiline
comment ]]

print("This should be executable")
]=]
    
    -- Create the test file
    before(function()
      fs.write_file(temp_file_path, test_content)
    end)
    
    it("should correctly identify executable lines", function()
      -- Line 1: Comment - not executable
      expect(static_analyzer.is_line_executable(temp_file_path, 1)).to.be_falsy()
      
      -- Line 2: Code - executable
      expect(static_analyzer.is_line_executable(temp_file_path, 2)).to.be_truthy()
      
      -- Line 3: Empty line - not executable
      expect(static_analyzer.is_line_executable(temp_file_path, 3)).to.be_falsy()
      
      -- Line 4: Start of multiline comment - not executable
      expect(static_analyzer.is_line_executable(temp_file_path, 4)).to.be_falsy()
      
      -- Line 5: End of multiline comment - not executable
      expect(static_analyzer.is_line_executable(temp_file_path, 5)).to.be_falsy()
      
      -- Line 6: Empty line - not executable
      expect(static_analyzer.is_line_executable(temp_file_path, 6)).to.be_falsy()
      
      -- Line 7: Print statement - executable
      expect(static_analyzer.is_line_executable(temp_file_path, 7)).to.be_truthy()
      
      -- Clean up
      os.remove(temp_file_path)
    end)
  end)
end)
