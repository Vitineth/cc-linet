monitor = {}

local inspect = require "vendor/inspect"
local li = require "linet-api"

function monitor.init()
    monitor._screen = peripheral.wrap("back")

    li.mount("top")
    li.init(true)
    
    li.setHandler(monitor.event)
    os.startTimer(1)

    li.connect()
end

function monitor.event(event)
    if event == "timer" then
        monitor.write()
    end
end

function monitor.sumDevice(device)
    local total = 0

    for lightID, lightCount in pairs(device) do
        if not (lightID == "lastPing") then
            total = total + tonumber(lightCount["count"])
        end
    end

    return total
end

function monitor.writeDevice(identifier, device, y)
    monitor._screen.setCursorPos(1, y)

    -- write the device ID
    monitor._screen.write(identifier .. "  =  " .. monitor.sumDevice(device))
    y = y + 1

    -- then go through the devices and write them out
    for lightID, lightCount in pairs(device) do
        if not (lightID == "lastPing") then
            monitor._screen.setCursorPos(1, y)
            monitor._screen.write("  " .. lightID .. ": " .. lightCount["count"])
            monitor._screen.setCursorPos(1, y + 1)
            monitor._screen.write("    " .. lightCount["type"] .. " - " .. inspect.inspect(lightCount["locator"]))

            y = y + 2
        end
    end

    return y
end

function monitor.write()
    monitor._screen.clear()
    local level = 1
    for deviceID, configuration in pairs(li._knownDevices) do
        if not (deviceID == "_count") then                
            level = monitor.writeDevice(deviceID, configuration, level)
        end
    end
    os.startTimer(3)
end

return monitor