-- Test for debug flag detection
print("Arguments received:")
for i, v in ipairs(arg) do
  print(i, v)
end

print("\nCommand line inspection:")
print("arg[0]:", arg[0])
print("debug flag present:", arg[1] == "--debug" or arg[2] == "--debug")

-- Set global debug flag
if not _G._firmo_debug_mode then
  _G._firmo_debug_mode = false
  
  -- Check for debug flag in arguments
  if arg then
    for _, v in ipairs(arg) do
      if v == "--debug" then
        _G._firmo_debug_mode = true
        break
      end
    end
  end
end

print("\nGlobal debug flag:")
print("_G._firmo_debug_mode:", _G._firmo_debug_mode)