--- The linet command line script
-- @module linet
-- This will dispatch instructions to one of the following modules:
-- * linet-client.lua
-- * linet-bridge.lua
-- * linet-monitor.lua

-- Double check that the instruction is one of client, bridge, monitor or help

--- Prints a help message to the standard output and returns
function printHelp()
    print("linet - Lighting Control in CC")
    print(" linet < client | bridge | monitor | help >")
    print()
    print(" Client: ")
    print("   linet client < address > < configuration >")
    print()
    print(" Bridge:")
    print("   linet bridge < ws address > < poll | rdm >")
    print()
    print(" Monitor:")
    print("   linet monitor < side >")
end

-- The first argument is required in all cases, if not specified, print the help message
-- Or if they specify help then print the same message
if arg[1] == nil or arg[1] == "help" then
    printHelp()
    return
end

-- ================================= --
--   VERIFY COMMAND LINE ARGUMENTS   --
-- ================================= --

-- If the first argument is not a valid instruction then just print the help message
if arg[1] ~= "client" and arg[1] ~= "bridge" and arg[1] ~= "monitor" then
    printHelp()
    return
end

-- Verify client instruction matches the configuration required
if arg[1] == "client" and (arg[2] == nil or arg[3] == nil) then 
    print("luanet client < address > < configuration >")
    return
end

-- Verify the bridge instruction matches the configuration required
if arg[1] == "bridge" and arg[2] == nil and (arg[3] == nil or (arg[3] ~= "poll" and arg[3] ~= "rdm"))  then
    print("luanet bridge < ws address > < poll | rdm >")
    return
end

-- Verify the monitor instruction matches the configuration required
if arg[1] == "monitor" and arg[2] == nil then
    print("luanet monitor < side >")
    return
end

-- ==================== --
--   EXECUTE COMMANDS   --
-- ==================== --

if arg[1] == "monitor" then
    local monitor = require "linet-monitor"
    monitor.init(arg[2])
    return
end

if arg[1] == "bridge" then
    local bridge = require "linet-bridge"
    bridge.init(arg[2], arg[3])
    return
end

if arg[1] == "client" then
    local client = require "linet-client"
    client.init(arg[3])
end