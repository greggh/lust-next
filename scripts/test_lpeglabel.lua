-- Test script for lpeglabel integration
package.path = "/home/gregg/Projects/lua-library/lust-next/?.lua;" .. package.path

print("Attempting to load lpeglabel module...")
local ok, lpeglabel = pcall(function()
  return require("lib.tools.vendor.lpeglabel")
end)

if not ok then
  print("Failed to load lpeglabel: " .. tostring(lpeglabel))
  os.exit(1)
end

print("LPegLabel loaded successfully!")
print("Version: " .. (type(lpeglabel.version) == "function" and lpeglabel.version() or lpeglabel.version or "unknown"))

print("Testing basic pattern matching...")
local lpeg = lpeglabel
local P, V, C, Ct = lpeg.P, lpeg.V, lpeg.C, lpeg.Ct

-- Simple grammar test
local grammar = P{
  "S";
  S = Ct(C(P"a"^1) * P"," * C(P"b"^1))
}

local result = grammar:match("aaa,bbb")
if result then
  print("Grammar test passed: " .. table.concat(result, ", "))
else
  print("Grammar test failed!")
end

print("LPegLabel integration test completed successfully!")