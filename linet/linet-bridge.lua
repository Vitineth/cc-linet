bridge = {}

require "util"
local li = require "linet-api"
local inspect = require "vendor/inspect"
local json = require "vendor/json"

function bridge.pushRDM()
    bridge._ws.send(json.encode(li._knownDevices))
end

function bridge.poll()
    local recv = bridge._ws.receive(5)
    if recv == nil then
        return
    end

    local entries = split(recv, "@@")
    local messageParts = split(entries[2], "==")

    li._mount.transmit(6437, 6437, li.encodeMessage(messageParts, entries[1]))
end

function bridge.event(event)
    if event == "timer" then
        if bridge._por == "rdm" then
            bridge.pushRDM()
        end

        if bridge._por == "poll" then
            bridge.poll()
        end
        
        os.startTimer(0)
    end
end

function bridge.init(address, pollOrRDM)
    bridge._ws = http.websocket(address)
    bridge._por = pollOrRDM

    li.mount("top")
    li.init(true)
    
    li.setHandler(bridge.event)
    os.startTimer(1)

    li.connect()
end

return bridge