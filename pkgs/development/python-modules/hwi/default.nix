{
  lib,
  bitbox02,
  buildPythonPackage,
  cbor,
  ecdsa,
  fetchFromGitHub,
  hidapi,
  libusb1,
  mnemonic,
  pyaes,
  pyserial,
  pythonOlder,
  typing-extensions,
}:

buildPythonPackage rec {
  pname = "hwi";
  version = "3.1.0";
  format = "setuptools";

  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    owner = "bitcoin-core";
    repo = "HWI";
    tag = version;
    hash = "sha256-sQqft+5M+X+91bFqpUrbDRrFzpe/l1+w+pnIHwqezR8=";
  };

  propagatedBuildInputs = [
    bitbox02
    cbor
    ecdsa
    hidapi
    libusb1
    mnemonic
    pyaes
    pyserial
    typing-extensions
  ];

  # Tests require to clone quite a few firmwares
  doCheck = false;

  pythonImportsCheck = [ "hwilib" ];

  meta = with lib; {
    description = "Bitcoin Hardware Wallet Interface";
    homepage = "https://github.com/bitcoin-core/hwi";
    changelog = "https://github.com/bitcoin-core/HWI/releases/tag/${version}";
    license = with licenses; [ mit ];
    maintainers = with maintainers; [ prusnak ];
  };
}
