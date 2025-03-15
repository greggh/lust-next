-- A simple file to verify multiline comment detection in coverage

-- First, enable coverage tracking
local lust = require("lust-next")
local coverage = require("lib.coverage")
local describe, it, expect, before, after = lust.describe, lust.it, lust.expect, lust.before, lust.after

-- A function with print statements and multiline comments
local function func_with_comments()
  --[[ This is a multiline comment
  that spans across multiple
  lines and should be detected
  as non-executable ]]
  
  print("This line should be marked as executed")
  
  local x = 10 --[[ inline multiline comment ]] local y = 20
  
  print("This is another executed line")
  
  --[[ Another
  multiline comment ]]
  
  return x + y
end

describe("Multiline Comment Verification", function()
  before(function()
    coverage.start({
      output_dir = "./test-reports-tmp",
      include = {".*/multiline_comment_verification.lua$"},
      format = "html"
    })
  end)
  
  after(function()
    coverage.stop()
    coverage.report()
    print("Coverage report generated in ./test-reports-tmp")
  end)
  
  it("should execute all print statements", function()
    local result = func_with_comments()
    print("Result:", result)
    expect(result).to.equal(30)
  end)
end)