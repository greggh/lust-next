-- Compatibility layer for lust-next
-- This file allows existing code that requires "lust" to continue working
-- while providing a migration path to lust-next

print("\nNOTICE: You are using the compatibility layer for lust-next")
print("For best results, please update your code to require 'lust-next' instead of 'lust'\n")

return require("lust-next")