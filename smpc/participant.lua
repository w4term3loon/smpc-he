local ipc = dofile("../minipc.lua")
local soc = require("socket")

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

local function setup(headcount)
  -- try to bind it as server
  local temp, tmperr = soc.bind(ipc.ip, ipc.port)
  local callback = function(clients, message)
    for i, client in ipairs(clients) do
      local bytes, snderr, _ = client:send(tostring(i + 1) .. "/" .. tostring(message) .. "\n")
      if snderr or not bytes then
        error("* failed to send message: " .. snderr)
      end
    end
  end

  -- master
  if temp and not tmperr then
    ipc.log("starting setup as master")

    temp:close()
    local weights = {}
    headcount = headcount or 3

    -- create weights
    for _ = 1, headcount do
      table.insert(weights, math.random(1, 10))
    end

    -- serve slaves with data
    local processID = 1
    local public = formatPublic(weights)
    ipc.retry(function()
      return ipc:serve(public, headcount - 1, callback)
    end)

    ipc.log("public parameters are sent to participants")

    -- return headcount
    return weights, headcount, processID
  else
    ipc.log("joining setup as slave")
    -- connect to master
    local public = ipc.retry(function() return ipc:eat() end)

    -- process public parameters
    -- TODO: check validity
    local weights, processID = processPublic(public)
    ipc.log("received public parameters [pid/weights]: " .. public)

    -- return headcount and pid
    return weights, #weights, processID
  end
end

-- generate shares form secret
local function generateShares(secret, public, headcount)
  ipc.log("generating shares from secret")
  local sum = 0
  local shares = {}
  -- generate n-1 random shares
  for _ = 1, headcount - 1 do
    local share = math.random(0, public["prime"] - 1)
    ipc.sec("generated share " .. share)
    table.insert(shares, share)
    sum = (sum + share) % public["prime"]
  end

  -- compute the final share to ensure the sum is secret mod prime
  local lastShare = (secret - sum) % public["prime"]
  table.insert(shares, lastShare)
  ipc.sec("final share is " .. lastShare)

  ipc.log("private shares are generated")
  return shares
end

local function distributeShares(processID, shares, headcount)
  ipc.log("distributing private shares")
  local collectedShares = {}
  for token = 1, headcount do
    if token == processID then
      -- callback
      local masterCb = function(clients, _)
        for i, client in ipairs(clients) do
          local share = shares[i]
          local bytes, snderr, _ = ipc.retry(function()
            return client:send(processID .. "/" .. tostring(share) .. "\n")
          end)
          if snderr or not bytes then
            error("* failed to send message: " .. snderr)
          end
        end
      end

      -- call server function
      ipc.retry(function()
        return ipc:serve(shares, headcount - 1, masterCb)
      end)
      collectedShares[processID] = shares[processID]
    else
      -- callback
      local slaveCb = function(client)
        local data, recerr, _ = client:receive()
        if recerr or not data then
          client:close()
          error("* failed to read: " .. recerr)
        end

        -- parse the return value
        for pid, share in string.gmatch(data, "(%d+)/(%d+)") do
          return pid, share -- TODO: verify data
        end
      end

      -- call client function
      local pid, share = ipc.retry(function()
        return ipc:eat(slaveCb)
      end)

      -- store received data
      -- TODO: maybe closure
      collectedShares[pid] = tonumber(share)
    end
  end

  ipc.log("private shares are distributed")
  return collectedShares
end

-- calcualte partial sum from shares
local function calculatePartialSum(collectedShares, public)
  ipc.log("calculating partial sum with collected shares")
  local partialSum = 0
  for i, share in ipairs(collectedShares) do
    partialSum = partialSum + share * public["weights"][i]
    partialSum = partialSum % public["prime"]
  end

  ipc.log("partial sum is calculated")
  return partialSum
end

-- serve partial sum to all participants
local function distributePartialSum(processID, partialSum, headcount)
  ipc.log("distributing partial sums")
  local partialSums = {}
  for token = 1, headcount do
    if token == processID then
      ipc.retry(function()
        return ipc:serve(partialSum, headcount - 1)
      end)
      table.insert(partialSums, partialSum)
      ipc.log("partial sum is revealed")
    else
      -- connect to master
      local partial = ipc.retry(function() return ipc:eat() end)
      table.insert(partialSums, tonumber(partial))
      ipc.log("received partial sum from " .. token)
    end
  end

  ipc.log("partial sums are distributed")
  return partialSums
end

-- calculate weighted sum from partial sums
local function calculateWeightedSum(partialSums, public)
  ipc.log("calculating weighted sum")
  local weightedSum = 0
  for _, s in ipairs(partialSums) do
    weightedSum = weightedSum + s
    weightedSum = weightedSum % public["prime"]
  end

  ipc.log("weighted sum is calculated")
  return weightedSum
end

-- main skeleton for communication
local function protocol(ip, port)
  -- public parameters
  local public = {}
  local headcount, processID = nil, nil
  math.randomseed(os.time())

  ipc.ip = ip
  ipc.port = port

  -- initialize public parameters
  public["prime"] = 2 ^ 31 - 1 -- Mersenne prime
  public["weights"], headcount, processID = setup(tonumber(arg[1]))

  -- generate secret
  math.randomseed(os.time() + processID)
  local secret = math.random(0, public["prime"] - 1)
  ipc.sec("prime used for protocol is " .. public["prime"])
  ipc.sec("generated secret is " .. secret)

  -- generate and distribute shares
  local shares = generateShares(secret, public, headcount)
  local collectedShares = distributeShares(processID, shares, headcount)

  -- calculate and distribute partial sum
  local partialSum = calculatePartialSum(collectedShares, public)
  local collectedPartialSums = distributePartialSum(processID, partialSum, headcount)

  -- calculate weighted sum
  local weightedSum = calculateWeightedSum(collectedPartialSums, public)
  ipc.log("weighted sum: " .. weightedSum)
end

-- start protocol
protocol("127.0.0.1", 53709)
