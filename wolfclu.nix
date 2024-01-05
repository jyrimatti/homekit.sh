{ stdenv
, fetchFromGitHub
, autoreconfHook
, wolfssl
}:

stdenv.mkDerivation rec {
  pname = "wolfCLU";
  version = "0.1.5";

  src = fetchFromGitHub {
    owner = "wolfSSL";
    repo = "wolfCLU";
    rev = "refs/tags/v${version}-stable";
    hash = "sha256-MD3g99tbcviYbXBAzEaW8H2oBMdFDg8N094aR0NAm3U=";
  };

  wolfSSLWithCLU = wolfssl.overrideAttrs (finalAttrs: previousAttrs: {
    configureFlags = previousAttrs.configureFlags ++ ["--enable-wolfclu"];
    doCheck = false;
  });

  nativeBuildInputs = [ autoreconfHook ];
  buildInputs = [ wolfSSLWithCLU ];
}