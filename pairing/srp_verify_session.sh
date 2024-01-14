#!/usr/bin/env python3

from srp import *
import sys
from io import open

user=sys.argv[1]
vkey=bytes.fromhex(sys.argv[2])
salt=bytes.fromhex(sys.argv[3])
secret=bytes.fromhex(sys.argv[4])
A=bytes.fromhex(sys.argv[5])
srpSharedSecretFile=sys.argv[6]
proof=bytes.fromhex(sys.stdin.read())

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

class MyVerifier(srp.Verifier):
    pass
    def _derive_H_AMK(self):
        super()._derive_H_AMK()
        _u = self.u
        # need to disable rfc5054 for the duration of calculation of M, but not for the calculation of u...
        srp.rfc5054_enable(False)
        super()._derive_H_AMK()
        self.u = _u

srp.rfc5054_enable()
svr  = MyVerifier( user, salt, vkey, A, hash_alg=srp.SHA512, ng_type=srp.NG_CUSTOM, g_hex="05", n_hex=n, bytes_b=secret)

HAMK = svr.verify_session(proof)

class AuthenticationFailed (Exception):
    pass

if HAMK is None:
    sys.stderr.write("Authentication failed. M1_user: " + proof.hex())
    raise AuthenticationFailed()

open(srpSharedSecretFile, 'wb').write(svr.get_session_key())
sys.stdout.write(HAMK.hex())
