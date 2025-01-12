local libsocket = require("socket")

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
local function serve(ip, port, message, broadcast, callback)
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
  for i, client in ipairs(clients) do
    if callback ~= nil then
      callback(client, message, i)
    else
      local bytes, snderr, _ = client:send(tostring(message) .. "\n")
      if snderr or not bytes then
        error("* failed to send message: " .. snderr)
      end
    end
  end

  -- shutdown
  shutdown()
end

-- async serve function
local function serveAsync(ip, port, message, broadcast, callback)
  return coroutine.create(function()
    serve(ip, port, message, broadcast, callback)
  end)
end

-- eat one message from socket
local function eat(ip, port)
  -- init tcp object
  local client, tcperr = libsocket.tcp()
  if tcperr or not client then
    error("* failed to create client")
  end

  -- connect to server
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
  local weights = {}
  local processID = tonumber(public:match("([^/]+)"))
  public = public:gsub("%d+/", "")
  for c in public:gmatch("([^:]+)") do
    table.insert(weights, c)
  end
  return weights, processID
end

local function setup(ip, port, headcount)
  -- try to bind it as server
  local temp, tmperr = libsocket.bind(ip, port)
  local callback = function(client, message, context)
    local bytes, snderr, _ = client:send(tostring(context + 1) .. "/" .. tostring(message) .. "\n")
    if snderr or not bytes then
      error("* failed to send message: " .. snderr)
    end
  end

  if temp and not tmperr then
    temp:close()
    local weights = {}
    if headcount == nil then headcount = 3 end

    -- create weights
    for _ = 1, headcount do
      table.insert(weights, math.random(1, 10))
    end

    -- serve slaves with data
    local processID = 1
    local public = formatPublic(weights)
    serve(ip, port, public, headcount - 1, callback)
    print("> public parameters sent")

    -- return headcount
    return weights, headcount, processID
  else
    -- connect to master
    local public = retry(function() return eat(ip, port) end)

    -- process public parameters
    -- TODO: check validity
    print("> received public parameters: " .. public)
    local weights, processID = processPublic(public)

    -- return headcount and pid
    return weights, #weights, processID
  end
end

local function generateShares(secret, headcount, prime)
  local sum = 0
  local shares = {}
  -- generate n-1 random shares
  for _ = 1, headcount - 1 do
    local share = math.random(0, prime - 1)
    table.insert(shares, share)
    sum = (sum + share) % prime
  end

  -- compute the final share to ensure the sum is secret mod prime
  local lastShare = (secret - sum) % prime
  table.insert(shares, lastShare)

  print("> private shares generated")
  return shares
end

local function distributeShares(ip, port, processID, shares)
  local allShares = {}
  -- iterate shares
  for token = 1, #shares do
    -- share
    if token == processID then
      for i = 1, #shares do
        if i ~= processID then
          coroutine.resume(serveAsync(ip, port + i, shares[i]))
        else
          -- store own share at processID
          allShares[token] = shares[i]
        end
      end
    else -- collect
      local data = retry(function()
        return eat(ip, port + processID)
      end)
      allShares[token] = tonumber(data)
    end
  end

  print("> private shares distributed")
  return allShares
end

local function calculatePartialSum(allShares, public)
  local partialSum = 0
  for i, share in ipairs(allShares) do
    partialSum = partialSum + share * public["weights"][i]
    partialSum = partialSum % public["prime"]
  end
  return partialSum
end

local function distributePartialSum(ip, port, partialSum, headcount, processID)
  local partialSums = {}
  for token = 1, headcount do
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

local function calculateWeightedSum(partialSums, prime)
  local weightedSum = 0
  for _, s in ipairs(partialSums) do
    weightedSum = weightedSum + s
    weightedSum = weightedSum % prime
  end

  return weightedSum
end

-- public parameters
local public = {}
public["prime"] = 2 ^ 31 - 1 -- Mersenne prime
math.randomseed(os.time())

local ip, port = "127.0.0.1", 42424
local weights, headcount, processID = setup(ip, port, tonumber(arg[1]))
public["weights"] = weights

-- generate secret
math.randomseed(os.time() + processID)
local secret = math.random(0, public["prime"] - 1)

-- generate and distribute shares
local shares = generateShares(secret, #public["weights"], public["prime"])
local allShares = distributeShares(ip, port, processID, shares)

-- calculate and distribute partial sum
local partialSum = calculatePartialSum(allShares, public)
local allPartialSums = distributePartialSum(ip, port, partialSum, headcount, processID)

-- calculate weighted sum
local weightedSum = calculateWeightedSum(allPartialSums, public["prime"])
print("> calculated weighted sum: " .. weightedSum)
