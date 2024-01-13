#!/usr/bin/env python3

from srp import *
import sys
import six
import hashlib
from io import open

user=sys.argv[1]
vkey=bytes.fromhex(sys.argv[2])
salt=bytes.fromhex(sys.argv[3])
secret=bytes.fromhex(sys.argv[4])
A=bytes.fromhex(sys.argv[5])
proof=bytes.fromhex(sys.argv[6])

n='''\
FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E08\
8A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B\
302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9\
A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE6\
49286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8\
FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D\
670C354E4ABC9804F1746C08CA18217C32905E462E36CE3BE39E772C\
180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF695581718\
3995497CEA956AE515D2261898FA051015728E5A8AAAC42DAD33170D\
04507A33A85521ABDF1CBA64ECFB850458DBEF0A8AEA71575D060C7D\
B3970F85A6E1E4C7ABF5AE8CDB0933D71E8C94E04A25619DCEE3D226\
1AD2EE6BF12FFA06D98A0864D87602733EC86A64521F2B18177B200C\
BBE117577A615D6C770988C0BAD946E208E24FA074E5AB3143DB5BFC\
E0FD108E4B82D120A93AD2CAFFFFFFFFFFFFFFFF'''

def long_to_bytes(n):
    l = list()
    x = 0
    off = 0
    while x != n:
        b = (n >> off) & 0xFF
        l.append( chr(b) )
        x = x | (b << off)
        off += 8
    l.reverse()
    return six.b(''.join(l))

#usr = srp.User(user, password, hash_alg=srp.SHA512, ng_type=srp.NG_CUSTOM, g_hex="05", n_hex=n, bytes_a=secret)
#M = usr.process_challenge(salt, proof)
#
#if M is None:
#    sys.stderr.write("Authentication failed")
#    raise AuthenticationFailed()

class MyVerifier(srp.Verifier):
    pass
    def _derive_H_AMK(self):
        super()._derive_H_AMK()
        _u = self.u
        srp.rfc5054_enable(False)
        super()._derive_H_AMK()
        self.u = _u

    def getU(self):
        return self.u
    def getS(self):
        return self.S
    def getK(self):
        return self.K
    def getM(self):
        return self.M

def HNxorg( hash_class, N, g ):
    bin_N = long_to_bytes(N)
    bin_g = long_to_bytes(g)

    padding = 0 #len(bin_N) - len(bin_g) #if _rfc5054_compat else 0

    hN = hash_class( bin_N ).digest()
    hg = hash_class( b''.join( [b'\0'*padding, bin_g] ) ).digest()
    hg2 = hash_class( bin_g ).digest()

    ret = six.b( ''.join( chr( six.indexbytes(hN, i) ^ six.indexbytes(hg, i) ) for i in range(0,len(hN)) ) )
    return (ret, hN, hg, hg2)

srp.rfc5054_enable()
svr  = MyVerifier( user, salt, vkey, A, hash_alg=srp.SHA512, ng_type=srp.NG_CUSTOM, g_hex="05", n_hex=n, bytes_b=secret)

HAMK = svr.verify_session(proof)

class AuthenticationFailed (Exception):
    pass

if HAMK is None:
    (hnxorg, hN, hg, hg2) = HNxorg(hashlib.sha512, int(n, 16), int("05",16))

    sys.stderr.write("Authentication failed. M1_user: " + proof.hex() + ", U: " + long_to_bytes(svr.getU()).hex() + ", S: " + long_to_bytes(svr.getS()).hex() + ", K: " + svr.getK().hex() + ", M: " + svr.getM().hex() + ", HNxorg: " + hnxorg.hex() + ", hN: " + hN.hex() + ", hg: " + hg.hex() + ", hg2: " + hg2.hex())
    raise AuthenticationFailed()

sys.stdout.write(HAMK.hex())
