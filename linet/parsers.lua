inspect = require "vendor/inspect"
require "util"

--- Forms a new light table with keys "type", "locator" and "count"
-- Types are confirmed (type=string|table, count=number) and the value of form is double
-- checked to be one of "static" or "5bit"
function new_light(form, locator, count)
    local obj = {}

    if form ~= "static" and form ~= "5bit" then
        print("[parsers/new_light] invalid type for form")
        return nil
    end

    if type(locator) ~= "string" and type(locator) ~= "table" then
        print("[parsers/new_light] invalid type for locator")
        return nil
    end

    if type(count) ~= "number" then
        print("[parsers/new_light] invalid type for count")
        return nil
    end

    obj["type"] = form
    obj["locator"] = locator
    obj["count"] = count

    return obj
end

function lightTableToEntryString(light) 

    -- assert everything we need _before_ we start appending things so we can bail early
    if type(light) ~= "table" then
        print("[parsers/buildRDMString] invalid light table, value was not table")
        return nil
    end

    if type(light["count"]) ~= "number" then
        print("[parsers/buildRDMString] invalid light table, count was not a number")
        return nil
    end

    if light["type"] ~= "5bit" and light["type"] ~= "static" then
        print("[parsers/buildRDMString] invalid light table, type was not valid")
        return nil
    end

    if type(light["locator"]) ~= "table" and type(light["locator"]) ~= "string" then
        print("[parsers/buildRDMString] invalid light table, locator not table and not string")
        return nil
    end

    -- Now that we have a light that is valid, processor the locator
    local locator = ""

    if type(light["locator"]) == "table" then
        if type(light["locator"]["color"]) == nil or type(light["locator"]["side"]) == nil then
            print("[parsers/buildRDMString] invalid light table, locator table did not contain required values")
            return nil
        end

        locator = light["locator"]["side"] .. "." .. light["locator"]["color"]
    else
        locator = light["locator"]
    end

    return light["type"] .. "." .. locator .. "=" .. light["count"]
end

--- Builds an RDM string from a light system produced by parseLightEntryList
-- This generally assumes that this is correct, it will validate some things but it will
-- generally trust the structure
function buildLightString(lights)
    if type(lights) ~= "table" then
        print("[parsers/buildLightString] failed to build rdm string, lights was not a table")
        return nil
    end

    local entryString = ""

    for lightIndex, light in pairs(lights) do
        -- lightIndex is ignored because indexes don't exist in an RDM string. We need
        -- to convert the light struct to a string

        local entry = lightTableToEntryString(light)
        if entry == nil then
            print("[parsers/buildLightString] got an invalid entry string")
            return
        end

        -- Then attach this information to the output string because everything is valid
        entryString = entryString .. "-" .. entry
    end

    -- Then finally attach this on to the output because we can substring it now
    return entryString:sub(2)
end

--- Parses an RDM string and returns the client ID and the list of lights associated with it
-- RDM constant is checked and the rest is parsed with the light entry
function parseRDMString(rdm)
    -- rdm schema: "rdm":[client id]:[light string]
    local rdm = split(rdm, ":")

    if rdm[1] == nil or rdm[2] == nil or rdm[3] == nil then
        print("[parsers/parseRDMString] invalid rdm string, not enough elements")
        return nil
    end

    if rdm[1] ~= "rdm" then
        print("[parsers/parseRDMString] invalid rdm string, constant not valid")
        return nil
    end

    return rdm[2], parseLightEntryList(rdm[3])
end

--- Parses a list of slights delimited with a -
-- Each light is parsed via parseLightEntry and then the array table is returned
function parseLightEntryList(config)
    local lightEntries = split(config, "-")
    local entryList = {}

    for index, entry in pairs(lightEntries) do
        entryList[index] = parseLightEntry(entry)
    end

    return entryList
end

function parseLightEntry(entry)
    local entities = split(entry, "=")

    -- verify entities.length >= 2
    if entities[1] == nil or entities[2] == nil then
        print("[parsers/parseLightEntry] invalid result from split")
        return nil
    end

    local lightIdentifier = split(entities[1], ".")
    local lightCount = tonumber(entities[2], 10)

    -- verify light count was a valid number
    if lightCount == nil then
        print("[parsers/parseLightEntry] invalid light count, not number :: " .. entities[2])
        return nil
    end

    -- verify lightIdentifier.length >= 2
    if lightIdentifier[1] == nil or lightIdentifier[2] == nil then
        print("[parsers/parseLightEntry] invalid light identifier")
        return nil
    end

    if lightIdentifier[1] == "static" then
        -- verify lightIdentifier.length >= 3 (third == colour)
        if lightIdentifier[3] == nil then
            print("[parsers/parseLightEntry] invalid light identifier configuration (static without third)")
            return nil
        end

        -- build locator, formed as a table for easy detection
        local locator = {}
        locator["side"] = lightIdentifier[2]
        locator["color"] = lightIdentifier[3]

        -- return new object
        return new_light("static", locator, lightCount)
    end

    if lightIdentifier[1] == "5bit" then
        return new_light("5bit", lightIdentifier[2], lightCount)
    end

    print("[parsers/parseLightEntry] invalid identifier type")
    return nil
end
