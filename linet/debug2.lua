local li = require "linet-api"
require "vendor/base64"

local modem = peripheral.wrap("top")
modem.open(6437)

repeat 
    write("Target >> ")
    local target = read()
    write("Control >> ")
    local control = read()

    modem.transmit(6437, 6437, li.encodeMessage({"ctrl", enc(control)}, target))
until false


repeat
    local event, modemSide, senderChannel, replyChannel, message, senderDistance = os.pullEvent("modem_message")
    print("Received " .. event .. " on linet port (" .. senderDistance .. " blocks away)")
    print("  Sent on " .. senderChannel .. " reply on " .. replyChannel)

    local decoded = li.decodeMessage(message)
    local index = 1

    if decoded["type"] == "broadcast" then
        print("   " .. decoded["from"] .. " -> everyone")
        print("   @ " .. decoded["time"])
    else
        print("   " .. decoded["from"] .. " -> " .. decoded["to"])
        print("   @ " .. decoded["time"])
    end

    while not (decoded["message"][index] == nill) do
        print("  => " .. decoded["message"][index])
        index = index + 1
    end
    print()
until false