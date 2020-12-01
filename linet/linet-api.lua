--- The API backing the linet lighting control system
-- @module linet-api

require "parsers"
require "vendor/base64"
require "util"
local log = require "vendor/log"

--- Contains a mapping of api colours to their ComputerCraft colour API codes which can be used in the colour
-- manipulating functions
local colorMap = {
    white = 1,
    orange = 2,
    magenta = 4,
    lblue = 8,
    yellow = 16,
    lime = 32,
    pink = 64,
    grey = 128,
    lgrey = 256,
    cyan = 512,
    purple = 1024,
    blue = 2048,
    brown = 4096,
    green = 8192,
    red = 16384,
    black = 32768,
}

--- The export of the linet api system
li = {}

--- If this API is currently connected (has opened a port on a modem)
-- This is set via li.connect()
li._isConnected = false

--- If this API has had a modem mounted to
-- If true a modem has been wrapped as a peripheral and stored in li._mount
li._isMounted = false

--- If this API is currently acting as a controller
-- If true, RDM transmissions will be skipped and RDM messages will be read. If false
-- RDM transmissions will be sent and RDM messages ignored
li._isController = false

--- The modem wrapped as a peripheral
-- This is not verifies as being a modem so the API can be tricked
-- TODO: implement some protections around this
li._mount = nil

--- The ID of timers started via os.startTimer
-- This is used to compare timer instructions and make sure that the correct instruction
-- is executed.
li._timers = {}

--- The identifier for this entry. This defaults to the system label or ID but can be udpated
li._identifier = tostring(os.getComputerLabel() or os.getComputerID())

--- If in controller mode this will contain all the known devices on the network
-- This is structured as
-- _knownDevices = {
-- [key: clientID] = {
-- [key: light identifier] = <number, light count>
-- }
-- }
li._knownDevices = {}

--- The handler used to receive events that are undefined
-- Defaults to nil, can be reset at any time
li._handler = nil

--- Configuration of this system representing which lights are in use
-- Only required on a client system, structured as
-- _configuration = {
-- [key: LightIdentifier as per spec] = <number, light count>
-- }
li._configuration = nil

--- The wrapped peripherals of smart lights on this client
-- Only defined on a client system, ignored on controllers
li._smartLights = {}

--- Attempts to configure the current API session. This will parse the given configuration string via
-- parsers.lua#parseLightEntryList.
function li.configure(value)
    li._configuration = parseLightEntryList(value)

    if li._configuration == nil then
        error("Provided configuration value was invalid")
    end

    -- Once the configuration is loaded, we need to go through the configuration and wrap any specified
    -- 5 bit lights. We save these and we also want to ensure that the peripherals we have wrapped are of the right type
    -- Types and peripherals are a bit weird so just verify that it has the functions that we are going to use
    for index, config in pairs(li._configuration) do
        if index ~= "_count" and config["type"] == "5bit" then
            log.trace("Wrapping peripheral", config["locator"])
            li._smartLights[config["locator"]] = peripheral.wrap(config["locator"])

            if li._smartLights[config["locator"]].setLampColor == nil then
                error("The 5bit light located at " .. config["locator"] .. " was not valid (no color function)")
            end

            log.info(config["locator"], "was wrapped successfully")
        end
    end
end

--- Will encode a message into the standard linet message format
-- Value should be an array-like-table which will be base64 encoded and then delimited by a semicolon. It will return
-- the string ready to be sent on the network
-- @param value array-like-table the array of values which should be concatenated as the entries of message
-- @param to the identifier of the machine which should respond to this request
-- @return the network ready message
function li.encodeMessage(value, to)
    local output = enc("M") .. ":" .. enc(tostring(li._identifier)) .. ":" .. enc(tostring(to)) .. ":" ..
            enc(tostring(os.time()))
    local index = 1

    while not (value[index] == nil) do
        output = output .. ":" .. enc(value[index])
        index = index + 1
    end

    return output
end

--- Will encode a message into the standard linet broadcast format
-- Value should be an array-like-table which will be base64 encoded and then delimited by a semicolon. It will return
-- the string ready to be sent on the nework
-- @param value array-like-table the array of values which should be concatenated as the entries of the message
-- @return the network ready message
function li.encodeBroadcast(value)
    local output = enc("B") .. ":" .. enc(tostring(li._identifier)) .. ":" .. enc(tostring(os.time()))
    local index = 1

    while not (value[index] == nil) do
        output = output .. ":" .. enc(value[index])
        index = index + 1
    end

    return output
end

--- Will decode a message as formed by the li.encodeMessage or li.encodeBroadcast function and return it as a structured
-- table. This will split the message on semicolon and then decode the relevant portions. The table will have the
-- following properties <br>
-- "type" is one of "broadcast" or "message" <br>
-- "from" is the identifier of the machine that sent the message on to the network
-- "to" is the identifier of the client which is meant to read this message. For broadcast messages this equals the
-- current machines identier <br>
-- "time" is the time at which the message was sent on the receiving machine. as there is no easy global measure of
-- time this is the time since the machine started running<br>
-- "message" is the actual content pieces of the message. This is an array-like-table which has been base64 decoded
-- @param value the string as encoded by li.encodeBroadcast and li.encodeMessage
-- @return a table as described above.
function li.decodeMessage(value)
    local output = split(value, ":")
    local recreate = {}
    local index = 1

    while not (output[index] == nil) do
        recreate[index] = dec(output[index])
        index = index + 1
    end

    local result = {}

    if recreate[1] == "B" then
        result["type"] = "broadcast"
        result["from"] = recreate[2]
        result["to"] = li._identifier
        result["time"] = tonumber(recreate[3])
        result["message"] = {}

        log.trace("A broadcast from " .. result["from"] .. " was received")

        local inindex = 4
        local outindex = 1
        while not (recreate[inindex] == nil) do
            result["message"][outindex] = recreate[inindex]
            outindex = outindex + 1
            inindex = inindex + 1
        end
    elseif recreate[1] == "M" then
        result["type"] = "message"
        result["from"] = recreate[2]
        result["to"] = recreate[3]
        result["time"] = tonumber(recreate[4])
        result["message"] = {}

        log.trace("A direct message from " .. result["from"] .. " to " .. result["to"] .. " was received")

        local inindex = 5
        local outindex = 1
        while not (recreate[inindex] == nil) do
            result["message"][outindex] = recreate[inindex]
            outindex = outindex + 1
            inindex = inindex + 1
        end
    else
        return nil
    end

    return result
end

--- Launches the main event loop of the linet system.
-- The linet system is based around the OS event system. This will run forever in a loop until the terminate event
-- is pushed onto the OS system. This will dispatch messages to their relevant handlers (RDM and cleanups) and handle
-- processing of modem messages. On unknown events and unknown timers it will call the handler function which can be set
-- via li.setHandler.
function li._eventLoop()
    repeat
        -- timer <identifier>
        -- modem_message <modemSide> <senderChannel> <replyChannel> <message>
        local event, data, p2, p3, p4, p5, p6 = os.pullEvent()

        -- Quit on a terminate event
        if event == "terminate" then
            return

            -- Timer events are for anything that needs to run on a schedule. This could be RDM or checking
            -- for connected devices. 
        elseif event == "timer" then

            -- RDM needs to be executed continually to broadcast this devices existence on the network.
            -- this is how other devices will look at this device and figure out what to execute
            if data == li._timers["rdm"] then
                rdmRoutine()
            elseif data == li._timers["cleanup"] then
                cleanupKnown()
            else
                if not (li._handler == nil) then
                    li._handler("timer", data)
                else
                    log.trace("no handler has been specified for the timer event with id " .. data)
                end
            end

            -- Modem messages are when messages are received on the network, this can be basically anything at all
        elseif event == "modem_message" then
            local decoded = li.decodeMessage(p4)

            -- Only process events which are meant to be delivered to this machine. From is automatically set
            -- to this devices ID if it is a broadcast so this is automatically true for broadcasting
            if decoded["to"] == li._identifier then
                log.trace("The message was intended for this machine so we are handling it")
                -- RDM needs to be handled internally. For now we just want to populate known devices to hold
                -- the latest RDM message because we are not actually advertising anything else about the devices
                -- other than its existence. 
                if decoded["message"][1] == "rdm" then
                    handleRDMMessage(decoded)
                    -- Otherwise we want to pass off messages to the generic handler if one is specified. This will
                    -- be for any messages that do not ger processed by the API
                elseif decoded["message"][1] == "ctrl" then
                    handleControlMessage(decoded)
                else

                    if not (li._handler == nil) then
                        li._handler("message", decoded)
                    else
                        log.trace("Unknown message type and no handler has been specified")
                    end
                end
            end

            -- If there is an unknown event give it to the handler if one is specified
        else
            if not (li._handler == nil) then
                li._handler("unknown", event, data, p2, p3, p4, p5, p6)
            else
                log.trace("An unknown event type " .. event .. " was received but no handler has been specified")
            end
        end

    until false
end

--- Sets the handler for this system which will be called when unknown events and timers are received
-- @param handler the handler function which should be called as described
function li.setHandler(handler)
    li._handler = handler
end

--- Returns whether this locator is one registered in the current configuration. This will only work for static lights
-- as it compares the side and colour.
-- @param locator array-like-table it needs to contain the side as entry 2 and the colour as entry 3
-- @return if the locator is contained in teh current configuration
function isStaticLocatorValid(locator)
    for index, light in pairs(li._configuration) do
        if type(light) == "table" and type(light["locator"]) == "table" then
            if light["locator"]["side"] == locator[2] and light["locator"]["color"] == locator[3] then
                return true
            end
        end
    end

    return false
end

--- Handles a control message as decoded by li.decodeMessage
-- This will attempt to derive the control instructions contained within the message and execute the relevant controls
-- on the redpower and networked lights
-- @param decoded decoded-message the message as decoded by li.decodeMessage
function handleControlMessage(decoded)
    -- A control message can contain any number of intructions
    -- A single control message is defined as
    --    type.locator=value
    -- If type == "static" then value is 1 or 0
    -- If type == "5bit" then value is a 15 digit long binary number
    -- Control messages are delimited by -
    -- Each control message is base64 encoded
    local messages = split(decoded["message"][2], "-")

    for messageIndex, encodedControlInstruction in pairs(messages) do
        local decodedControlInstruction = dec(encodedControlInstruction)
        local instructionParts = split(decodedControlInstruction, "=")

        local locator = instructionParts[1]
        local value = instructionParts[2]

        log.trace("Control instruction received for " .. locator .. " to set them to the value " .. value)

        local locatorParts = split(locator, ".")
        local locatorType = locatorParts[1]

        if locatorType == "5bit" then
            log.trace("Setting 5bit light @ " .. locatorParts[2] .. " = " .. value .. " (b" .. tonumber(value, 2) .. ")")
            -- If it is a 5 bit instruction then locator is a peripheral name and the value should
            -- be 15 characters long and each of those should be a 0 or a 1
            if value:len() ~= 15 or tonumber(value, 2) == nil then
                log.trace("Invalid value for 5bit light, wasn't 15 long or wasnt binary")
            else
                li._smartLights[locatorParts[2]].setLampColor(tonumber(value, 2))
            end
        elseif locatorType == "static" then
            if isStaticLocatorValid(locatorParts) then
                log.trace("Setting static light @ " .. locatorParts[2] .. "-" .. locatorParts[3] .. " = " .. value)
                -- If it is a static instruction then locator is a two part string in the form of side.color
                -- and value should be 0 or 1
                -- In this case we want to get the bundled output on the side, update the bit mask and write it back
                local bitmap = redstone.getBundledOutput(locatorParts[2])

                log.trace("  -> " .. bitmap)

                if value == "1" then
                    bitmap = colors.combine(bitmap, colorMap[locatorParts[3]])
                elseif value == "0" then
                    bitmap = colors.subtract(bitmap, colorMap[locatorParts[3]])
                end

                log.trace("  <- " .. bitmap)

                redstone.setBundledOutput(locatorParts[2], bitmap)
            else
                log.warn("Invalid static locator")
            end
        end
    end
end

--- Attempts to parse an RDM message received on the network
-- This will update li._knownDevices which will contain every known device on the network. RDM strings are parsed via
-- parseLightEntryList. Each known device will also have a lastPing entry attached to it with the current os clock value
-- which can be used to determine out of date rdm messages via cleanupKnown
-- @param decoded decoded-message the RDM message as decoded by li.decodeMessage
function handleRDMMessage(decoded)
    log.trace("RDM message, updating entries")

    local deviceID = decoded["message"][2]
    local rdmConfig = dec(decoded["message"][3])

    local count = li._knownDevices["_count"] or 0
    if li._knownDevices[deviceID] == nil then
        count = count + 1
    end

    li._knownDevices[deviceID] = parseLightEntryList(rdmConfig)

    li._knownDevices[deviceID]["lastPing"] = os.clock()
    li._knownDevices["_count"] = count

    log.info("RDM: I now know of " .. count .. " devices")
end

--- Routine to send the rdm message on to the network. The rdm string is generated via buildLightString and then
-- transmitted on 6437. This reschedules the function to be called in 2 seconds time
function rdmRoutine()
    -- An RDM signal requires us to be connected
    if not li._isMounted then
        return false
    end
    if not li._isMounted then
        return false
    end

    local lightString = buildLightString(li._configuration)

    -- Transmit an RDM message with this computers ID on the network, this will eventually
    -- be populated with information about this device such as detected cables and systems
    li._mount.transmit(6437, 6437, li.encodeBroadcast({ "rdm", tostring(li._identifier), enc(lightString) }))

    -- Queue a timer event and save the index
    li._timers["rdm"] = os.startTimer(2)
end

--- Routine to cleanup the known RDM messages. This checks the list of known devices and if any sent their last ping
-- more than 5 seconds ago it will remove them from the known devices array
function cleanupKnown()
    local now = os.clock()
    local start = li._knownDevices["_count"] or 0

    -- For every device we know about, we want to check if they have checked in
    for key, value in pairs(li._knownDevices) do

        -- Skip the _count entry because that's not a device
        if not (key == "_count") then

            -- Any system that has not pinged in 5 seconds needs to be removed
            if now - value["lastPing"] > 5 then
                li._knownDevices[key] = nil
                li._knownDevices["_count"] = (li._knownDevices["_count"] or 1) - 1
                log.trace("Removed " .. key .. " for being out of date")

            end
        end
    end

    if li._knownDevices["_count"] or 0 ~= start then
        log.info("RDM: I now know of " .. (li._knownDevices["_count"] or 0) .. " devices")
    end

    -- Queue a timer event and save the index
    li._timers["cleanup"] = os.startTimer(2)
end

--- Initialises the current system with the controller status. If controller is true then it will not send an RDM
-- configurations and will process the RDM messages it receives as broadcasts. If false it will send RDM messages and
-- not process any RDM messages received
-- @param controller if this system should parse RDM messages
function li.init(controller)
    li._isController = controller
end

--- Mounts a modem on the given side and marks this linet system as mounted. This will allow you to call li.connect.
-- If the side is invalid, it will raise an error.
-- @param side te side on which the modem is attached
-- @return true
function li.mount(side)
    if peripheral.getType(side) ~= "modem" then
        error("This is not a valid modem")
    end

    li._mount = peripheral.wrap(side)
    li._isMounted = true

    return true
end

--- Sets the identifier of this machine which will overwrite the current saved identifier.
-- @param identifier the identifier which should overwrite the currently set identifier
function li.identify(identifier)
    li._identifier = identifier or li._identifier
end

--- Connects to the modem and begins the event loop. This will open the modem listening on channel 6437 and mark it as
-- connected. If its a controller is will schedule the RDM loop to run and the cleanup loop. Then begin the event loop
function li.connect()
    if not li._isMounted then
        return false
    end

    li._mount.open(6437)
    li._isConnected = true

    -- Queue a timer event and save the index
    if not li._isController then
        li._timers["rdm"] = os.startTimer(2)
    end

    li._timers["cleanup"] = os.startTimer(2)

    li._eventLoop()
end

return li
