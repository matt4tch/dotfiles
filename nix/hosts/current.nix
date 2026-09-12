# Resolve the local macOS account at evaluation time. This module is impure by
# design so one shared flake can configure any standard macOS user without a
# per-machine host record or rebuild wrapper.
let
  sudoUser = builtins.getEnv "SUDO_USER";
  invokingUser = builtins.getEnv "USER";
  invokingHome = builtins.getEnv "HOME";
  username =
    if sudoUser != "" then
      sudoUser
    else if invokingUser != "" && invokingUser != "root" then
      invokingUser
    else
      throw "Could not determine the invoking macOS user; evaluate this flake with --impure.";
  homeDirectory =
    if sudoUser != "" then
      "/Users/${sudoUser}"
    else if invokingHome != "" then
      invokingHome
    else
      "/Users/${username}";
in
{
  system = builtins.currentSystem;
  inherit username homeDirectory;
}
