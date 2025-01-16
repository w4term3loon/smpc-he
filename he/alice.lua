local ipc = dofile("../minipc.lua")

local pallier = require("pallier")
local tools = require("tools")

local alice = {}

function alice.pack(msg)
  local pack = ""
  for _, elem in ipairs(msg) do
    pack = pack .. elem .. ":"
  end
  return pack:sub(1, #pack - 1)
end

function alice:setup()
  local pack = self.pack({ pallier.p, pallier.q })
  ipc.retry(function()
    return ipc:serve(pack)
  end)
end

function alice:beaver()
  -- random beaver shares
  self.x = math.random(0, pallier.n - 1)
  self.y = math.random(0, pallier.n - 1)
  self.enc_x = pallier:encrypt(self.x)
  self.enc_y = pallier:encrypt(self.y)

  -- pack and send msg
  local pack = self.pack({ self.enc_x, self.enc_y })
  ipc.retry(function()
    return ipc:serve(pack)
  end)

  -- bob shares calculation
  self.enc_xy_yx_r = tonumber(ipc.retry(function()
    return ipc:eat()
  end))
  self.z = (self.x * self.y + pallier:decrypt(self.enc_xy_yx_r)) % pallier.n
  ipc.log("beaver triplets shared")
end

function alice:vector(dim)
  self.vec = 12 -- tools.genVec(dim, pallier.n)
  ipc.retry(function()
    return ipc:serve(dim)
  end)
end

function alice:de()
  self.enc_d_share = pallier:encrypt(self.vec - self.x)

  -- serve share to bob
  ipc.retry(function()
    return ipc:serve(self.enc_d_share)
  end)

  -- eat bob's share
  self.enc_e_share = tonumber(ipc.retry(function()
    return ipc:eat()
  end))

  -- eat bob's d (xd)
  self.enc_d = tonumber(ipc.retry(function()
    return ipc:eat()
  end))

  -- calculate d and e
  self.d = pallier:decrypt(self.enc_d)
  self.e = (pallier:decrypt(self.enc_e_share) - self.y) % pallier.n

  -- public params
  -- TODO: could be encrypted since bob could
  -- make use of the homomorphism of pallier (?)
  ipc.retry(function()
    return ipc:serve(self.pack({ self.d, self.e }))
  end)

  ipc.log("de: " .. self.d .. ":" .. self.e)
end

function alice:final()
  -- bob's final share
  self.enc_bob_w = tonumber(ipc.retry(function()
    return ipc:eat()
  end))
  self.bob_w = pallier:decrypt(self.enc_bob_w)

  -- alice's final share
  self.w = (self.d * self.e + self.d * self.y + self.e * self.x + self.z) % pallier.n

  -- mul
  self.mul = (self.w + self.bob_w) % pallier.n
  ipc.retry(function()
    return ipc:serve(self.mul)
  end)

  ipc.log("mul is: " .. self.mul)
end

local function protocol(ip, port)
  ipc.ip = ip
  ipc.port = port

  math.randomseed(os.time())
  pallier:init(13, 73)

  alice:setup()
  alice:vector(69)
  alice:beaver()
  alice:de()
  alice:final()
end

protocol("127.0.0.1", 44242)

-- TODO: move to pallier
-- Basic encryption/decryption test
local function test_basic()
  print("\nBasic encryption/decryption test:")
  local m = 42
  local c = pallier:encrypt(m)
  local d = pallier:decrypt(c)
  print("Original:", m)
  print("Decrypted:", d)
  assert(m == d, "Basic encryption/decryption failed")
end

-- Homomorphic addition test
local function test_addition()
  print("\nHomomorphic addition test:")
  local m1 = 30
  local m2 = 40
  print("m1:", m1)
  print("m2:", m2)

  local c1 = pallier:encrypt(m1)
  local c2 = pallier:encrypt(m2)

  local c_sum = (c1 * c2) % pallier.n_squared
  local sum = pallier:decrypt(c_sum)

  print("Decrypted sum:", sum)
  assert(sum == (m1 + m2) % pallier.n, "Homomorphic addition failed")
end

-- Homomorphic multiplication by constant test
local function test_mult_constant()
  print("\nHomomorphic multiplication by constant test:")
  local m = 30
  local k = 40
  print("m:", m)
  print("k:", k)

  local c = pallier:encrypt(m)
  local c_mult = tools.modularExp(c, k, pallier.n_squared)
  local result = pallier:decrypt(c_mult)

  print("Decrypted result:", result)
  assert(result == (m * k) % pallier.n, "Homomorphic multiplication failed")
end

-- Run tests
local function test()
  test_basic()
  test_addition()
  test_mult_constant()
end

--test()
