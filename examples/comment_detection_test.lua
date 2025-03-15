-- Basic test for multiline comment detection with print statements

local function test_comments()
  -- Single line comment
  print("Line 4: This executable line should be marked as executed")
  
  --[[ This is a multiline comment
  spanning multiple lines
  it should be correctly identified
  as non-executable ]]
  
  print("Line 10: This is another executable line that should be marked as executed")
  
  local x = 5 --[[ Inline multiline comment ]] local y = 10
  
  --[[ Another
  multiline comment block ]]
  
  print("Line 16: Final executable line")
  
  return x + y
end

-- Run the function to ensure the print statements execute
test_comments()
print("Test completed successfully")