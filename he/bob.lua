local ipc = dofile("../minipc.lua")

local pallier = require("pallier")
local tools = require("tools")

local function setup()
  local primes = ipc:eat()
  print("got primes: " .. primes)
end

local function protocol(ip, port)
  ipc.ip = ip
  ipc.port = port

  setup()
end

protocol("127.0.0.1", 44242)

-- define p and q
pallier.p = 23
pallier.q = 73

-- beaver triplets
math.randomseed(os.time())
local alice = {}
alice.x = math.random(0, pallier.n - 1)
alice.y = math.random(0, pallier.n - 1)
alice.enc_x = pallier:encrypt(alice.x)
alice.enc_y = pallier:encrypt(alice.y)

-- send it to bob
local bob = {}
bob.enc_alice_x = alice.enc_x
bob.enc_alice_y = alice.enc_y
assert(alice.x == pallier:decrypt(bob.enc_alice_x))
assert(alice.y == pallier:decrypt(bob.enc_alice_y))

bob.x = math.random(0, pallier.n - 1)
bob.y = math.random(0, pallier.n - 1)
bob.r = math.random(0, pallier.n - 1)
bob.enc_r = pallier:encrypt(bob.r)
assert(bob.r == pallier:decrypt(bob.enc_r))

-- x_A * y_B
bob.enc_xy = tools.modularExp(bob.enc_alice_x, bob.y, pallier.n_squared)
assert((alice.x * bob.y) % pallier.n == pallier:decrypt(bob.enc_xy))
-- y_A * x_B
bob.enc_yx = tools.modularExp(bob.enc_alice_y, bob.x, pallier.n_squared)
assert((alice.y * bob.x) % pallier.n == pallier:decrypt(bob.enc_yx))

-- x_A * y_B + y_A * x_B + r
bob.enc_xy_yx_r = (bob.enc_xy * bob.enc_yx * bob.enc_r) % pallier.n_squared
assert((alice.x * bob.y + alice.y * bob.x + bob.r) % pallier.n == pallier:decrypt(bob.enc_xy_yx_r))

bob.z = bob.x * bob.y - bob.r
-- bob sends back
alice.z = alice.x * alice.y + pallier:decrypt(bob.enc_xy_yx_r)

-- test
local xy = (bob.x + alice.x) * (bob.y + alice.y) % pallier.n
local zz = (bob.z + alice.z) % pallier.n
assert(xy == zz)

-- vector mul
alice.u = io.read("*n")
bob.v = io.read("*n")

-- create d and e
alice.enc_d_share = pallier:encrypt(alice.u - alice.x)
bob.enc_e_share = pallier:encrypt(bob.v - bob.y)

-- trade
bob.enc_d_share = alice.enc_d_share
alice.enc_e_share = bob.enc_e_share

-- bob
bob.enc_d = (bob.enc_d_share * pallier:encrypt((-1) * bob.x)) % pallier.n_squared
alice.enc_d = bob.enc_d -- share

-- alice
alice.e = (pallier:decrypt(alice.enc_e_share) - alice.y) % pallier.n
alice.d = pallier:decrypt(alice.enc_d)
assert((bob.v - (alice.y + bob.y)) % pallier.n == alice.e)
assert((alice.u - (alice.x + bob.x)) % pallier.n == alice.d)

-- correctness
local left = (alice.u * bob.v) % pallier.n
local right = ((alice.d + alice.x + bob.x) * (alice.e + alice.y + bob.y)) % pallier.n
assert(left == right)

-- public
bob.e = alice.e
bob.d = alice.d

-- bob
bob.w = (bob.d * bob.y + bob.e * bob.x + bob.z) % pallier.n
bob.enc_w = pallier:encrypt(bob.w) -- ?
alice.enc_bob_w = bob.enc_w        -- share

-- alice
alice.bob_w = pallier:decrypt(alice.enc_bob_w)
assert(alice.bob_w == bob.w)
alice.w = (alice.d * alice.e + alice.d * alice.y + alice.e * alice.x + alice.z) % pallier.n
alice.ww = (alice.w + alice.bob_w) % pallier.n
bob.ww = alice.ww --share

print("mul is: " .. alice.ww)

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
