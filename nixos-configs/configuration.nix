{ config, pkgs, lib, zen-browser, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];
  environment.localBinInPath = true;




  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 5;


hardware.i2c.enable = true;
services.udev.packages = [ pkgs.openrgb ];
boot.kernelModules = [ "i2c-dev" "i2c-i801" ];
hardware.opengl.driSupport32Bit = true; 


#battery charge thresholds
systemd.services.battery-threshold-init = {
  description = "Prime ASUS battery charge threshold before TLP";
  before = [ "tlp.service" ];
  wantedBy = [ "multi-user.target" ];
  serviceConfig = {
    Type = "oneshot";
    ExecStart = "${pkgs.bash}/bin/bash -c 'echo 80 > /sys/class/power_supply/BAT1/charge_control_end_threshold || true'";
    RemainAfterExit = true;
  };
};



systemd.services.tlp = {
  after = [ "battery-threshold-init.service" ];
  wants = [ "battery-threshold-init.service" ];
};

#flatpak 
services.flatpak.enable = true;


services.tlp = {
  enable = true;
  settings = {
    STOP_CHARGE_THRESH_BAT1 = 80;
  };
};

#cpu
  systemd.services.cpu-freq-limit = {
    description = "Set max CPU frequency limit";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.linuxPackages.cpupower}/bin/cpupower frequency-set -u 2.5GHz";
      RemainAfterExit = true;
    };
  };
  #bluetooh
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];


  # Use latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # AppImage support
  boot.binfmt.registrations.appimage = {
    wrapInterpreterInShell = false;
    interpreter = "${pkgs.appimage-run}/bin/appimage-run";
    recognitionType = "magic";
    offset = 0;
    mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
    magicOrExtension = ''\x7fELF....AI\x02'';
  };

  # Networking
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # Time zone
  time.timeZone = "Asia/Kolkata";

  # Locale
  i18n.defaultLocale = "en_IN";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_IN";
    LC_IDENTIFICATION = "en_IN";
    LC_MEASUREMENT = "en_IN";
    LC_MONETARY = "en_IN";
    LC_NAME = "en_IN";
    LC_NUMERIC = "en_IN";
    LC_PAPER = "en_IN";
    LC_TELEPHONE = "en_IN";
    LC_TIME = "en_IN";
  };

  # Keymap
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # User
  users.users."adi" = {
    isNormalUser = true;
    description = "adi";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
  };

  # Unfree packages
  nixpkgs.config.allowUnfree = true;

  # GPU
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = lib.mkForce false;
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
    nvidia-vaapi-driver
  ];
  };

  # EGL fix for Quickshell + NVML for MangoHud
    environment.variables = {
      __EGL_VENDOR_LIBRARY_DIRS = "/run/opengl-driver/share/glvnd/egl_vendor.d";
      LD_LIBRARY_PATH = "/run/opengl-driver/lib";
    };

  # Display manager
  services.displayManager.defaultSession = "niri";
   programs.niri.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # Power management
  services.upower.enable = true;
  services.power-profiles-daemon.enable = false;
  powerManagement.cpuFreqGovernor = "performance";

  # Firefox
  programs.firefox.enable = true;



  services.gvfs.enable = true;
  services.tumbler.enable = true;

  # Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
  };
  programs.gamemode.enable = true;

  # MPD (user service, config at ~/.config/mpd/mpd.conf)
  services.mpd.enable = false;

  #dolphin
  programs.dconf.enable = true;  # if you use GTK apps alongside it
  security.polkit.enable = true;

  # Packages
  environment.systemPackages = with pkgs; [
      kitty
      vscode
      overskride
      picard
      wofi
      rofi
      kdePackages.dolphin
       kdePackages.kio-extras
        kdePackages.ffmpegthumbs
         kdePackages.kdegraphics-thumbnailers
      rmpc
      wlogout
      file-roller
      git
      python3
      nvtopPackages.nvidia
      linuxPackages.cpupower
      mangohud
      brightnessctl
      gearlever
      qt6.qtwayland
      qt5.qtwayland
      lm_sensors
      cava
      yt-dlp
      tealdeer
      mpd-mpris
      swaynotificationcenter
      playerctl
      imv
      awww
      bat
      btop
      zed-editor
      appimage-run
      grim
      slurp
      grimblast
      libnotify
      fastfetch
      alacritty
      fuzzel
       xwayland-satellite #for niri
      zen-browser.packages.${pkgs.system}.default
      pkgs.openrgb
         discord-ptb
          lutris
           webcamoid
             gpu-screen-recorder-gtk # GUI app
             vlc
              android-tools
          
           
    ];
    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
    ];
  system.stateVersion = "26.05";
}
