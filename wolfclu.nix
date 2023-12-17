{ stdenv
, fetchFromGitHub
, autoreconfHook
, wolfssl
}:

stdenv.mkDerivation rec {
  pname = "wolfCLU";
  version = "0.1.4";

  src = fetchFromGitHub {
    owner = "wolfSSL";
    repo = "wolfCLU";
    rev = "refs/tags/v${version}-stable";
    hash = "sha256-t4mThJYbwCsQ8d1N6EooFZu3Jo9WnGamAZPxm2v+UDE=";
  };

  wolfSSLWithCLU = wolfssl.overrideAttrs (finalAttrs: previousAttrs: {
    configureFlags = previousAttrs.configureFlags ++ ["--enable-wolfclu"];
    doCheck = false;
  });

  nativeBuildInputs = [ autoreconfHook ];
  buildInputs = [ wolfSSLWithCLU ];
}