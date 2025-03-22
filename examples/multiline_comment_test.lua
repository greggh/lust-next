-- Test file for multiline comment coverage
local firmo = require("firmo")
local describe, it, expect, before = firmo.describe, firmo.it, firmo.expect, firmo.before

-- Load the necessary modules
local debug_hook = require("lib.coverage.debug_hook")
local static_analyzer = require("lib.coverage.static_analyzer")

describe("Multiline Comment Coverage Test", function()
  -- Clean up environment
  before(function()
    debug_hook.reset()
  end)
  
  it("should properly detect multiline comments", function()
    -- Setup a test file with multiline comments
    local test_content = ""
    .. "local test = 1\n" -- Line 1: Executable code
    .. "\n" -- Line 2: Blank line
    .. "--[[ \n" -- Line 3: Multiline comment start
    .. "  This is a multiline comment\n" -- Line 4: Inside comment
    .. "  that spans multiple lines\n" -- Line 5: Inside comment
    .. "]]\n" -- Line 6: Multiline comment end
    .. "\n" -- Line 7: Blank line
    .. "local another_test = 2\n" -- Line 8: Executable code
    
    -- Create a temp path for our test
    local file_path = os.tmpname()
    
    -- Create a file data structure in the debug hook module
    local file_data = debug_hook.initialize_file(file_path)
    expect(file_data).to.exist("File data should be created")
    
    -- Set up the source text
    file_data.source_text = test_content
    file_data.source = {}
    
    -- Split content into lines
    local line_num = 0
    for line in (test_content .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
      line_num = line_num + 1
      file_data.source[line_num] = line
    end
    file_data.line_count = line_num
    
    -- First track lines to see if they're classified properly
    debug_hook.track_line(file_path, 1, { use_enhanced_classification = true, track_multiline_context = true })
    debug_hook.track_line(file_path, 3, { use_enhanced_classification = true, track_multiline_context = true })
    debug_hook.track_line(file_path, 4, { use_enhanced_classification = true, track_multiline_context = true })
    debug_hook.track_line(file_path, 5, { use_enhanced_classification = true, track_multiline_context = true })
    debug_hook.track_line(file_path, 6, { use_enhanced_classification = true, track_multiline_context = true })
    debug_hook.track_line(file_path, 8, { use_enhanced_classification = true, track_multiline_context = true })
    
    -- Get updated file data
    local data = debug_hook.get_file_data(file_path)
    expect(data).to.exist("File data should still exist")
    
    -- Print the executable lines table for debugging
    print("Executable lines table:")
    for i=1, 8 do
      print(string.format("Line %d: %s", i, tostring(data.executable_lines[i])))
    end
    
    -- Print line classification for debugging
    if data.line_classification then
      print("\nLine classification:")
      for i=1, 8 do
        if data.line_classification[i] then
          print(string.format("Line %d: content_type=%s, in_comment=%s", 
            i, 
            tostring(data.line_classification[i].content_type), 
            tostring(data.line_classification[i].in_comment)))
        else
          print(string.format("Line %d: no classification", i))
        end
      end
    end
    
    -- Now verify the line classifications
    expect(data.executable_lines[1]).to.be_truthy("Line 1 (code) should be executable")
    expect(data.executable_lines[3]).to_not.be_truthy("Line 3 (comment start) should not be executable")
    expect(data.executable_lines[4]).to_not.be_truthy("Line 4 (comment content) should not be executable")
    expect(data.executable_lines[5]).to_not.be_truthy("Line 5 (comment content) should not be executable")
    expect(data.executable_lines[6]).to_not.be_truthy("Line 6 (comment end) should not be executable")
    expect(data.executable_lines[8]).to.be_truthy("Line 8 (code) should be executable")
    
    -- Check line classification if available
    if data.line_classification then
      if data.line_classification[4] then
        expect(data.line_classification[4].content_type).to.equal("comment", 
          "Line 4 should be classified as comment type")
      end
      
      if data.line_classification[5] then
        expect(data.line_classification[5].content_type).to.equal("comment", 
          "Line 5 should be classified as comment type")
      end
    end
    
    -- Clean up
    os.remove(file_path)
  end)
end)

print("\nMultiline comment test completed!")