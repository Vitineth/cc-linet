local li = require "linet-api"

client = {}

function client.loadConfigFromFile(file)
    -- Check the config file exists, if not print a warning and return
    if not fs.exists(filename) then
        print("[main] File does not exist")
        return false
    end

    -- Load the configuration file from disk
    local configFile = fs.open(filename, "r")
    local configuration = configFile.readAll()
    configFile.close()

    -- Pass the configuration
    li.configure(configuration)

    return true
end

function client.loadConfig(configuration)
    if arg[3]:sub(1, 1) == ":" then
        return client.loadConfigFromFile(arg[3]:sub(2))
    else
        li.configure(arg[3])
        return true
    end
end

function client.init(configuration)
    li.mount("top")
    li.identify(arg[2])
    li.init(false)

    if not client.loadConfig(arg[3]) then
        return false
    end

    li.connect()
end

return client