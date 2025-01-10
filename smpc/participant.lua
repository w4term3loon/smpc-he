local libsocket = require("socket")

-- public parameters
local publicW = {}
local publicP = 2 ^ 31 - 1 -- mersenne prime

local function send(ip, port, message)
  -- open tcp socket
  local server = libsocket.bind(ip, port)
  print("> accepting connection on " .. ip .. " port " .. port)

  -- accept incoming connection
  local client = server:accept()

  -- send message
  local bytes, senderr = client:send(message .. "\n")
  if not senderr then
    print("> sent " .. string.format("%d", bytes) .. " bytes: " .. message)
  else
    print("* failed to send message: " .. senderr)
  end

  client:close()
  server:close()
end

local function read(ip, port)
  -- init tcp object
  local client = libsocket.tcp()

  -- connect to socket
  local success, connErr = client:connect(ip, port)
  if not success then
    print("* failed to connect socket: " .. connErr)
    return
  else
    print("> connected to " .. ip .. " on port " .. port)
  end

  -- read message from server
  local message, recErr = client:receive()
  if not recErr then
    print("> read message: " .. message)
  else
    print("* failed to read message: " .. recErr)
  end

  client:close()
end

local function formatPublic(weights)
  local string = ""
  for _, w in ipairs(weights) do
    string = string .. w .. ":"
  end
  string = string:sub(1, #string - 1)
  return string
end

local serial = nil
local function processPublic(public)
  -- TODO: extract serial number
  for c in public:gmatch("([^:]+)") do
    table.insert(publicW, c)
  end
end

local function setup()
  print("SETUP")
  -- try to bind it as server
  local headcount = nil
  local ip, port = "127.0.0.1", 42424
  local master, _ = libsocket.bind(ip, port)
  if master then -- this process is master
    -- check if master has headcount
    if not (tonumber(arg[1]) ~= nil and tonumber(arg[1]) > 1) then
      print("* first participant should declare number of participants")
      return
    else
      headcount = tonumber(arg[1])
    end

    -- accept incoming connections
    -- and create weight for each participant
    local parties = {}
    print("> master waiting for parties to join on " .. ip .. " port " .. port)
    for n = 1, headcount - 1 do
      table.insert(publicW, math.random(1, 10))
      table.insert(parties, master:accept())
      print("> accepted participant number " .. n)
    end

    -- create a weight for master
    -- (actually last party will use it)
    table.insert(publicW, math.random(1, 10))

    -- distribute the public parameters
    local public = formatPublic(publicW)
    for i, p in ipairs(parties) do
      -- TODO: add serial
      p:send(public .. "\n")
    end

    -- close parties
    for _, p in ipairs(parties) do
      p:close()
    end
    print("> public parameters were sent to paties")

    master:close()
  else -- master is already runnning, this is slave
    -- create tcp object
    local slave = libsocket.tcp()

    -- connect to socket
    local success, connErr = slave:connect(ip, port)
    if not success then
      print("* failed to connect to master: " .. connErr)
      return
    else
      print("> connected to master " .. ip .. " on port " .. port)
    end

    -- receive public parameters
    print("> waiting for others to connect")
    local public, rcvErr = slave:receive()
    if not rcvErr then
      print("> received public params: " .. public)
    else
      print("* failed to receive public params: " .. rcvErr)
    end

    -- process public parameters
    processPublic(public)

    slave:close()
  end
end

local ownShares = {}
local function generateShares(secret, headcount, prime)
  print("GENERATE SHARES")
  local sum = 0
  -- generate n-1 random shares
  for _ = 1, headcount - 1 do
    local share = math.random(0, prime - 1)
    table.insert(ownShares, share)
    sum = (sum + share) % prime
  end

  -- compute the final share to ensure the sum is secret mod prime
  local lastShare = (secret - sum) % prime
  table.insert(ownShares, lastShare)

  print("> shares are generated")
end

local partyShares = {}
local function distributeShares()
  print("DISTRIBUTE SHARES")
  -- TODO: based on shares and serial number
  -- create a sequence for everyone sharing
  -- their shares in order
end

local partialSum = 0
local function calculatePartialSum()
  print("CALCULATE PARTIAL SUM")
  for i, w in ipairs(publicW) do
    print("weight: " .. w)
    -- partialSum = partialSum + partyShares[i] * w
  end
end

local function distributePartialSum()
  print("DISTRIBUTE PARTIAL SUM")
  -- TODO: based serial number create a sequence
  -- for everyone sharing their partialsums in order
end


local function calculateWeightedSum()
  print("CALCULATE WEIGHTED SUM")
  -- TODO: based on the received partial sums
  -- sum up the whole wighted sum
end

-- set seed for random
math.randomseed(os.time())

-- generate secret
local secret = math.random(0, publicP - 1)

setup()
generateShares(secret, #publicW, publicP)
distributeShares()

print("unimplemented")

calculatePartialSum()
distributePartialSum()
calculateWeightedSum()
