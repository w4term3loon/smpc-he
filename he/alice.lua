local libipc = dofile("../minipc.lua")

local function gcd(a, b)
  while b ~= 0 do
    a, b = b, a % b
  end
  return math.abs(a)
end

local function lcm(a, b)
  return math.abs(a * b) // gcd(a, b)
end

local pallier = {}
pallier.p = 23
pallier.q = 73
pallier.n = pallier.p * pallier.q
print("n: " .. pallier.n)
pallier.n_squared = pallier.n * pallier.n
pallier.lam = lcm(pallier.p - 1, pallier.q - 1)
pallier.g = pallier.n + 1

local function modularExp(base, exponent, modulus)
  if modulus == 1 then
    return 0
  end

  local result = 1
  base = base % modulus

  while exponent > 0 do
    if exponent % 2 == 1 then
      result = (result * base) % modulus
    end
    base = (base * base) % modulus
    exponent = math.floor(exponent / 2)
  end

  return result
end

local function modInverse(a, m)
  local m0, x0, x1 = m, 0, 1

  while a > 1 do
    local q = math.floor(a / m)
    a, m = m, a % m
    x0, x1 = x1 - q * x0, x0
  end

  if x1 < 0 then
    x1 = x1 + m0
  end

  return x1
end

function pallier:L(x)
  return math.floor((x - 1) / self.n)
end

function pallier:encrypt(m)
  -- reduce
  m = m % self.n

  local r = math.random(2, self.n - 1)
  while gcd(r, self.n) ~= 1 do
    r = math.random(2, self.n - 1)
  end

  -- Calculate c = (g^m * r^n) mod n^2
  local g_m = modularExp(self.g, m, self.n_squared)
  local r_n = modularExp(r, self.n, self.n_squared)
  return (g_m * r_n) % self.n_squared
end

function pallier:decrypt(c)
  local c_lambda = modularExp(c, self.lam, self.n_squared)
  local L_c = self:L(c_lambda)

  local g_lambda = modularExp(self.g, self.lam, self.n_squared)
  local L_g = self:L(g_lambda)

  -- Use modular multiplicative inverse instead of division
  local mu = modInverse(L_g, self.n)
  return (L_c * mu) % self.n
end

local function test()
  -- mul c
  local m = 42
  local c = pallier:encrypt(m)
  local p = modularExp(c, 2, pallier.n_squared)
  local r = pallier:decrypt(p)
  assert(m * 2 == r)

  -- add
  local m1 = 42
  local m2 = 42
  local c1 = pallier:encrypt(m1)
  local c2 = pallier:encrypt(m2)
  local pd = c1 * c2
  local rd = pallier:decrypt(pd)
  assert(m1 + m2 == rd)

  -- combo
  local c1e = modularExp(c1, 2, pallier.n_squared)
  local pde = c1e * c2
  local pre = pallier:decrypt(pde)
  assert(m1 * 2 + m2 == pre)
  print("perfect test!")
end

test()

-- beaver triplets
math.randomseed(os.time())
local beaver = {}
beaver.a = math.random(2, pallier.n - 1)
beaver.b = math.random(2, pallier.n - 1)
beaver.c_a = pallier:encrypt(beaver.a)
beaver.c_b = pallier:encrypt(beaver.b)
-- send it to bob
local bob = {}
bob.c_a = beaver.c_a
bob.c_b = beaver.c_b
assert(beaver.a == pallier:decrypt(bob.c_a))
assert(beaver.b == pallier:decrypt(bob.c_b))

bob.a = math.random(2, pallier.n - 1)
bob.b = math.random(2, pallier.n - 1)
bob.r = math.random(2, pallier.n - 1)
bob.c_r = pallier:encrypt(bob.r)
assert(bob.r == pallier:decrypt(bob.c_r))

-- a_A * b_B
local first = modularExp(bob.c_a, bob.b, pallier.n_squared)
assert(beaver.a * bob.b % pallier.n == pallier:decrypt(first))
-- b_A * a_B
local second = modularExp(bob.c_b, bob.a, pallier.n_squared)
assert(beaver.b * bob.a % pallier.n == pallier:decrypt(second))

-- a_A * b_B + b_A * a_B + r
bob.s = first * second * bob.c_r
assert((beaver.a * bob.b + beaver.b * bob.a + bob.r) % pallier.n == pallier:decrypt(bob.s))

bob.c = bob.a * bob.b - bob.r
-- bob sends back
beaver.c = beaver.a * beaver.b + pallier:decrypt(bob.s)
local ab = (bob.a + beaver.a) * (bob.b + beaver.b) % pallier.n
local cc = (bob.c + beaver.c) % pallier.n
print("ab is: " .. ab)
print("cc is: " .. cc)
