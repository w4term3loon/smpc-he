# -- Written by Marijke and Barna
from math import prod

from palier import *

from Crypto.Util.number import getPrime, getRandomInteger


def print_access(access: dict):
    print("All parties have access to the following:")
    # print(access)
# Simulate two parties computing an inner product
def main():
    print("Maximum bits k")
    k = 2048
    print("Vector size")
    vector_size = 5
    access ={}
    access["Alice"] = {}
    access["Bob"] = {}
    access["Trusted"] = {}
    print("Step 1 trusted authority generate keys and prime and send them to Alice and Bob")
    # Key generation for Paillier encryption
    n, g, dlambda, mu = key_gen(k)
    p = getPrime(k//2)
    access["Alice"] |= {"n": bin(n), "g": bin(g), "p": bin(p)}
    access["Bob"] |= {"n": bin(n), "g": bin(g), "p": bin(p)}
    access["Trusted"]  |= {"n": bin(n), "g": bin(g), "dlambda": bin(dlambda), "mu":bin(mu)}
    print_access(access)
    print("Step 2, Alice and Bob generate x1, y1 and x2, y2, respectively")
    x1 = getPrime(len(bin(p))//2-1)
    y1 = getPrime(len(bin(p))//2-1)
    x2 = getPrime(len(bin(p))//2-1)
    y2 = getPrime(len(bin(p))//2-1)
    access["Alice"] |= {"x1": bin(x1), "y1": bin(y1)}
    access["Bob"] |= {"x2": bin(x2), "y2": bin(y2)}
    print_access(access)
    print("Step 3, Alice send Bob the encrypted x1 and y1")
    enc_x1 = enc(n,g, x1)
    enc_y1 = enc(n,g, y1)
    access["Alice"] |= {"enc_x1": bin(enc(n,g, x1)), "enc_y1": bin(enc(n,g, y1))}
    access["Bob"] |=  {"enc_x1": bin(enc(n,g, x1)), "enc_y1": bin(enc(n,g, y1))}
    print_access(access)
    print("Step 4, Bob generate r and calculate, send p0, enc_y2 and obtain p2")
    r = getPrime(len(bin(p))//2-1)
    """This enc_y2 can be done different. But Bob knows Alice enc_x1 and enc_y1"""
    """This might cause the encryption to break, we can do it differently but then C and D are not calculated as complete."""
    enc_y2 = enc(n,g,y2)
    p0 = pow(enc_x1,y2, n^2) * pow(enc_y1,x2, n^2) * enc(n,g,n-r)
    p2 = enc(n,g,x2*y2 + r)
    access["Alice"] |= {"p0": bin(p0),"enc_y2": bin(enc_y2)}
    access["Bob"] |=  {"p0": bin(p0), "r": bin(r), "p2": bin(p2),"enc_y2": bin(enc_y2)}
    print_access(access)
    print("Step 6, Alice calcualte p1")
    p1 = enc(n,g, x1*y1)*p0 % (n^2)
    access["Alice"] |= {"p1": bin(p1)}
    print_access(access)
    print("Step 7, generate vector and determine C and D")
    vectAlice = [getRandomInteger(10) for _ in range(vector_size)]
    vectBob = [getRandomInteger(10) for _ in range(vector_size)]
    """Place to combine part A"""
    # Alice does
    c = [pow(enc(n,g,n+x-y1),enc_y2,n^2) for x in vectAlice]
    c_bin = [bin(x) for x in c]
    # Bob does
    d = [pow(enc(n,g,n+x-x2),enc_x1,n^2) for x in vectBob]
    d_bin = [bin(x) for x in d]
    access["Alice"] |= {"c_bin": c_bin, "d_bin": d_bin}
    access["Bob"] |= {"c_bin": c_bin, "d_bin": d_bin}
    print_access(access)
    print("Step 8, calculate sub total and send to each other")
    #ALice
    sub_a = prod([pow(c[i],d[i]+ y1+x1,n^2)*p1*pow(d[i],  y1+x1,n^2) for i in range(vector_size)])
    # Bob
    sub_b = prod([pow(c[i],y2+x2,n^2)*p2*pow(d[i], y2+x2,n^2) for i in range(vector_size)])
    access["Alice"] |= {"sub_a": bin(sub_a), "sub_b": bin(sub_b)}
    access["Bob"] |= {"sub_a": bin(sub_a), "sub_b": bin(sub_b)}
    print_access(access)
    print("Step 9, both send same multiplied version to trusted authority")
    total = sub_a * sub_b % n^2
    access["Trusted"] |= {"Total": total}
    print_access(access)
    print("Step 10, trusted authority, decrypt")
    result = dec(n,dlambda,mu, total)
    print(result)
    expected_inner_product = sum(x * y for x, y in zip(vectAlice, vectBob))
    print(expected_inner_product)
    assert expected_inner_product == result

if __name__ == "__main__":
    main()
