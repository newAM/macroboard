{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.macroboard;
in {
  options.services.macroboard = with lib; {
    enable = mkEnableOption "macro keyboard";

    device = mkOption {
      type = types.str;
      example = "/dev/input/by-id/usb-Keyboard";
      description = "Path to the keyboard device file.";
    };

    devicePid = mkOption {
      type = types.str;
      description = "Keyboard USB product ID.";
    };

    deviceVid = mkOption {
      type = types.str;
      description = "Keyboard USB vendor ID.";
    };

    # https://github.com/torvalds/linux/blob/34e047aa16c0123bbae8e2f6df33e5ecc1f56601/include/uapi/linux/input-event-codes.h#L75
    keys = mkOption {
      default = {};
      type = types.attrsOf types.str;
      description = "Maps key codes to programs.";
    };
  };

  config = lib.mkIf cfg.enable {
    # cannot be called "macroboard" to avoid name clash with DynamicUser
    users.groups.mbgroup = {};

    services.udev.extraRules = ''
      SUBSYSTEM=="input", \
        ATTRS{idVendor}=="${cfg.deviceVid}", \
        ATTRS{idProduct}=="${cfg.devicePid}", \
        TAG+="systemd", \
        ENV{SYSTEMD_ALIAS}+="/dev/macroboard", \
        ENV{SYSTEMD_WANTS}+="macroboard.service", \
        GROUP="mbgroup", \
        MODE="0660"
    '';

    systemd.services.macroboard = let
      configFile = pkgs.writeText "macroboard-config.json" (builtins.toJSON {
        inherit (cfg) keys;
        dev = cfg.device;
      });
    in {
      wantedBy = ["multi-user.target"];
      after = ["dev-macroboard.device"];
      requires = ["dev-macroboard.device"];
      description = "macro keyboard";
      unitConfig.ReloadPropagatedFrom = "dev-macroboard.device";
      serviceConfig = {
        Type = "idle";
        KillSignal = "SIGINT";
        ExecStart = "${pkgs.macroboard}/bin/macroboard ${configFile}";
        Restart = "on-failure";
        RestartSec = 10;

        # hardening
        SupplementaryGroups = ["mbgroup"];
        DynamicUser = true;
        DevicePolicy = "closed";
        CapabilityBoundingSet = "";
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
        DeviceAllow = [
          "char-usb_device rwm"
          "${cfg.device} rwm"
        ];
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateMounts = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        BindPaths = ["${cfg.device}"];
        MemoryDenyWriteExecute = true;
        LockPersonality = true;
        RemoveIPC = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
          "~@resources"
        ];
        ProtectProc = "invisible";
        ProtectHostname = true;
        ProcSubset = "pid";
      };
    };
  };
}
