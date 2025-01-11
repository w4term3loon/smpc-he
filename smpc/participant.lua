local libsocket = require("socket")

-- public parameters
local publicW = {}
local publicP = 2 ^ 31 - 1 -- mersenne prime
local processID = nil

-- retry wrapper for robust calls
local function retry(task, retries, delay)
  retries = retries or 4
  delay = delay or 1

  -- retry mechanism
  for attempt = 1, retries do
    local success, result = pcall(task)
    if success then
      return result
    else
      if attempt < retries then
        os.execute("sleep " .. delay)
      end
    end
  end

  error("* task failed after retiries")
end

-- serve message to socket for n clients
local function serve(ip, port, message, broadcast)
  -- default to one-to-one
  broadcast = broadcast or 1

  -- init tcp object as server
  local server, binerr = libsocket.bind(ip, port)
  if binerr or not server then
    error("* failed to create server: " .. binerr)
    return
  end

  -- shutdown method
  local clients = {}
  local function shutdown()
    print("> served data on " .. ip .. ":" .. port .. " for " .. broadcast)
    for _, client in ipairs(clients) do client:close() end
    server:close()
  end

  -- accept clients
  print("> waiting on participants")
  for _ = 1, broadcast do
    local client, accerr = server:accept()
    if accerr or not client then
      error("* failed to accept client: " .. accerr)
    end
    table.insert(clients, client)
  end

  -- serve clients with data
  for _, client in ipairs(clients) do
    local bytes, snderr, _ = client:send(tostring(message) .. "\n")
    if snderr or not bytes then
      error("* failed to send message: " .. snderr)
    end
  end

  -- shutdown
  shutdown()
end

-- eat one message from socket
local function eat(ip, port)
  -- init tcp object
  local client, tcperr = libsocket.tcp()
  if tcperr or not client then
    error("* failed to create client")
  end

  -- connect to server
  client:settimeout(5)
  local status, conerr = client:connect(ip, port)
  if conerr or not status then
    client:close()
    error("* failed to connect: " .. conerr)
  end

  -- read message from server
  local data, recerr, _ = client:receive()
  if recerr or not data then
    client:close()
    error("* failed to read: " .. recerr)
  end

  print("> read from " .. ip .. ":" .. port)

  client:close()
  return data
end

-- master
-- format public parameters
local function formatPublic(weights)
  local string = ""
  for _, w in ipairs(weights) do
    string = string .. w .. ":"
  end
  string = string:sub(1, #string - 1)
  return string
end

-- slave
-- extract public parameters
local function processPublic(public)
  processID = tonumber(public:match("([^/]+)"))
  public = public:gsub("%d+/", "")
  for c in public:gmatch("([^:]+)") do
    table.insert(publicW, c)
  end
end

local function setup(ip, port, headcount)
  -- try to bind it as server
  local master, binerr = libsocket.bind(ip, port)

  if master and not binerr then
    -- shutdown method
    local slaves = {}
    local function shutdown()
      print("> served data on " .. ip .. ":" .. port .. " for " .. headcount - 1)
      for _, client in ipairs(slaves) do client:close() end
      master:close()
    end

    -- accept slaves
    print("> waiting on participants")
    for n = 1, headcount - 1 do
      local slave, accerr = master:accept()
      if accerr or not slave then
        error("* failed to accept client: " .. accerr)
      end
      table.insert(slaves, slave)
      print("> " .. n .. " parties joined already")
    end

    -- create weights
    for _ = 1, headcount do
      table.insert(publicW, math.random(1, 10))
    end

    -- serve slaves with data
    processID = 1
    local public = formatPublic(publicW)
    for i, slave in ipairs(slaves) do
      local bytes, snderr, _ = slave:send(i + 1 .. "/" .. public .. "\n")
      if snderr or not bytes then
        error("* failed to send message: " .. snderr)
      end
    end

    shutdown()
    print("> public parameters sent")
  else
    -- connect to master
    local public = retry(function() return eat(ip, port) end)

    -- process public parameters
    -- TODO: check validity
    print("> received public parameters: " .. public)
    processPublic(public)
  end
end

local ownShares = {}
local function generateShares(secret, headcount, prime)
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
  print("> private shares generated")
end

local compoundShares = {}
local function distributeShares(ip, port)
  -- iterate shares
  for token = 1, #ownShares do
    -- share
    if token == processID then
      for i = 1, #ownShares do
        if i ~= processID then
          serve(ip, port + i, ownShares[i])
        else
          -- store own share at processID
          compoundShares[token] = ownShares[i]
        end
      end
    else -- collect
      local data = retry(function()
        return eat(ip, port + processID)
      end)
      compoundShares[token] = tonumber(data)
    end
  end
  print("> private shares distributed")
end

local function calculatePartialSum()
  local partialSum = 0
  for i, share in ipairs(compoundShares) do
    partialSum = partialSum + share * publicW[i]
    partialSum = partialSum % publicP
  end
  return partialSum
end

local function distributePartialSum(ip, port, partialSum, headcount)
  local partialSums = {}
  for token = 1, #publicW do
    if token == processID then
      serve(ip, port, partialSum, headcount - 1)
      table.insert(partialSums, partialSum)
      print("> partial sum revealed")
    else
      -- connect to master
      local partial = retry(function() return eat(ip, port) end)
      table.insert(partialSums, tonumber(partial))
      print("> received partial sum")
    end
  end
  return partialSums
end

local function calculateWeightedSum(partialSums)
  local weightedSum = 0
  for _, s in ipairs(partialSums) do
    weightedSum = weightedSum + s
    weightedSum = weightedSum % publicP
  end

  return weightedSum
end

-- set seed for random
math.randomseed(os.time())

-- generate secret
local secret = math.random(0, publicP - 1)
local headcount = 3
local ip, port = "127.0.0.1", 42424

setup(ip, port, headcount)
generateShares(secret, #publicW, publicP)
distributeShares(ip, port)
local partialSum = calculatePartialSum()
local partialSums = distributePartialSum(ip, port, partialSum, headcount)
local weightedSum = calculateWeightedSum(partialSums)
print("> calculated weighted sum: " .. weightedSum)
