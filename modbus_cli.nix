{ python3Packages }:
with python3Packages;
buildPythonPackage rec {
  pname = "modbus_cli";
  version = "0.1.9";
  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-81mmeP3qXcUqnnNK33w1M2esfh9lQrdT3ydb1O+UUdw=";
  };
  propagatedBuildInputs = [ colorama umodbus ];
}
