#!/usr/bin/env python3

from srp import *
import sys
import six
import hashlib
import binascii
from io import open

user=sys.argv[1]
password=sys.argv[2]
saltFile=sys.argv[3]
verifierFile=sys.argv[4]
secret=bytes.fromhex(sys.stdin.read())

# http://tools.ietf.org/html/rfc5054#appendix-A 3072-bit Group
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

#def bytes_to_long(s):
#    n = 0
#    for b in six.iterbytes(s):
#        n = (n << 8) | b
#    return n
#
#def long_to_bytes(n):
#    l = list()
#    x = 0
#    off = 0
#    while x != n:
#        b = (n >> off) & 0xFF
#        l.append( chr(b) )
#        x = x | (b << off)
#        off += 8
#    l.reverse()
#    return six.b(''.join(l))
#
#def H( hash_class, *args, **kwargs ):
#    width = kwargs.get('width', None)
#
#    h = hash_class()
#
#    for s in args:
#        if s is not None:
#            data = long_to_bytes(s) if isinstance(s, six.integer_types) else s
#            if width is not None:
#                h.update( bytes(width - len(data)))
#            h.update( data )
#
#    return h.hexdigest()

srp.rfc5054_enable()
salt, vkey = srp.create_salted_verification_key(user, password, hash_alg=srp.SHA512, ng_type=srp.NG_CUSTOM, g_hex="05", n_hex=n, salt_len=16)
# vkey == pow(g,  gen_x( hash_class, _s, username, password ), N)                                   x = H( hash_class, salt, H( hash_class, username + six.b(':') + password ) )
# js: params.g.modPow(getx(params, salt, I, P), params.N).toBuffer(params.N_length_bits / 8);       x = H(s | H(I | ":" | P))

#usr      = srp.User(user, password, hash_alg=srp.SHA512, ng_type=srp.NG_CUSTOM, g_hex="05", n_hex=n, bytes_a=secret)
#uname, A = usr.start_authentication()
# A == pow(g, bytes_a, N)

#sys.stdout.write(salt.hex() + ',' + A.hex() + ',' + vkey.hex())
#vkey=bytes.fromhex('fa865deebdbfbf837adc160d994514b760d99a455734c77685e305beead31396f7d6f4cfe2bc3cfc7fb3958f7f6d4f1264dc81c46184d4e4f6471fa124d9e9aaef7eed129eda4a5a3b948f95c920d76290d7edaf81eff67b69963d551a69230bb5f9b2c77b938b2f7ffdd7d4c1b644be921c941d06434d1b852726d64a3a7189febce4daeb32049b9b4af6fbeedc7a6131e2476377c98748f2718c99d3f2abdc67a9504b456cda29292335928b938bd8b8c76553e3603c492b453a9a0527361896ee237037bf59ca12681c7141dfee9f4408dfb3d1c441131686faa38bf75875d565028976dc378505895a23468ca84f573ea63a29e86b97863a7fd5cfd44a6cb8c888b1ccd8f6b1f4ac212849acea035696168ee904c679982cb4a32814bc24426b0c9e3ee362a94cf506287c8e7da7032199cc60c32a5ba550394c76064a553b1fabb238ccba4c760f35cb508a51056e175449f0335fe6eb98b1aaf5c4ded8b7de803bead4a33b2798f27b6aaa72b577d66907a081df642bf0885ea94ff9f8')
#salt=bytes.fromhex('7bf8901894d511ca2d4eefcfe6358f2f')
svr      = srp.Verifier(user, salt, vkey, hash_alg=srp.SHA512, ng_type=srp.NG_CUSTOM, g_hex="05", n_hex=n, bytes_b=secret)
s,B      = svr.get_challenge()
# k == H( hash_class, N, g, width=len(long_to_bytes(N)) )
# js: crypto.createHash(params.hash).update(padToN(params.N, params)).update(padToN(params.g, params)).digest()
# B == (k*v + pow(g, secret, N)) % N
# js: k.multiply(v).add(params.g.modPow(b, params.N)).mod(params.N).toBuffer(params.N_length_bits / 8);

#k=H( hashlib.sha512, int(n,16), int("05",16), width=len(long_to_bytes(int(n,16))) )

#v=bytes_to_long(vkey)

#BB = long_to_bytes( (int( k, 16 )*v + pow(int("05",16), bytes_to_long(svr.get_ephemeral_secret()), int(n, 16))) % int(n, 16) ).hex()

open(saltFile, 'wb').write(salt);
open(verifierFile, 'wb').write(vkey);

sys.stdout.write(B.hex())
#sys.stdout.write(salt.hex() + ',' + B.hex() + ',' + vkey.hex())
#sys.stdout.write(H( hashlib.sha512, int(n, 16), int("05",16), width=len(long_to_bytes(int(n,16))) ))
#sys.stdout.write(str(v))
#sys.stdout.write(B.hex() + "\n")
#sys.stdout.write("\n" + BB)
