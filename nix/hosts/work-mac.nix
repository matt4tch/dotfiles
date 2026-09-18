{ homeDirectory, ... }:

{
  # This address is assigned to this work laptop. Other machines use #macos.
  networking.wg-quick.interfaces.wg0 = {
    autostart = true;
    address = [ "10.10.0.120/32" ];
    # Keep the private key out of Git and the Nix store; read it at runtime.
    privateKeyFile = "${homeDirectory}/.wg/laptop.key";
    peers = [
      {
        publicKey = "JRCwIm1MrwF4jC+eDGjI2E29+0NBnlyOP1pOZK7Adx0=";
        endpoint = "67.202.43.97:51820";
        allowedIPs = [ "10.10.0.0/24" "172.31.0.0/16" ];
        persistentKeepalive = 25;
      }
    ];
  };
}
