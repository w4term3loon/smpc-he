# -- Written by Marijke and Barna
from math import lcm

from Crypto.Util.number import getRandomRange, getStrongPrime, getPrime
#---------------------------------------------------------------------
# Generate key
#---------------------------------------------------------------------
def key_gen(k: int):
    """
    This methode generates the keys for the pallier cryptosystem.
    :param k: is the length of the primes p,q
    :return:
    """
    p,q = getPrime(k), getPrime(k)
    n = p * q
    lambd = lcm(p - 1, q - 1)
    g = n + 1
    # lambd = (p-1)*(q-1)
    mu = pow(lambd, -1, n)
    return n, g, lambd, mu

def enc(n, g, m):
    assert m >= 0 and m < n
    r = getRandomRange(1,n)
    n2 = n**2
    c = (pow(g, m, n2) * pow(r, n, n2)) % n2
    return c

def dec(n, lambd, mu, c):
    m = (((pow(c, lambd, n**2) - 1) // n) * mu) % n
    return m
