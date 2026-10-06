{ config, pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./sddm.nix
  ];
  hardware.xone.enable = false;

  environment.localBinInPath = true;

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 5; #decides number of genration on bootmenu

  #open-rgb
  hardware.i2c.enable = true;
  services.udev.packages = [ pkgs.openrgb pkgs.game-devices-udev-rules ];
  boot.kernelModules = [ "i2c-dev" "i2c-i801" "uinput" "evdev" "rfcomm" ];

  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="users", MODE="0660", OPTIONS+="static_node=uinput"

    # Cosmic Byte Ares — grant hidraw access once it enumerates as Switch Pro Controller
    KERNEL=="hidraw*", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="2009", MODE="0666"
  '';

  # Battery charge thresholds
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

  # Flatpak
  services.flatpak.enable = true;
  services.tlp = {
    enable = true;
    settings = {
      STOP_CHARGE_THRESH_BAT1 = 80;
    };
  };

  # CPU
  systemd.services.cpu-freq-limit = {
    description = "Set max CPU frequency limit";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.linuxPackages.cpupower}/bin/cpupower frequency-set -u 2GHz";
      RemainAfterExit = true;
    };
  };

  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;
  hardware.bluetooth.settings = {
    Policy = {
      AutoEnable = false;
    };
  };
  services.blueman.enable = true;
  # Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Use latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "usbcore.old_scheme_first=1"
    "usbcore.autosuspend=-1"
  ];

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
  networking.networkmanager.wifi.backend = "iwd";
  networking.firewall.allowedTCPPorts = [ 8000 ];

  services.resolved.enable = true;

  networking.wireless.iwd.settings = {
    Network = {
      NameResolvingService = "systemd";
      EnableIPv6 = true;
    };
  };
  systemd.services.disable-wifi-on-boot = {
    description = "Disable Wi-Fi radio on boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "NetworkManager.service" ];
    script = ''
      /run/current-system/sw/bin/nmcli radio wifi off
    '';
  };

  # XDG Desktop Portals for Wayland Screen Sharing
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common.default = [ "gnome" "gtk" ];
  };

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

  # Sound
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # Users
  users.users."adi" = {
    isNormalUser = true;
    description = "adi";
    extraGroups = [ "wheel" "networkmanager" "input" ];
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
      intel-media-driver
    ];
  };

  # EGL fix for Quickshell + NVML for MangoHud
  environment.variables = {
    __EGL_VENDOR_LIBRARY_DIRS = "/run/opengl-driver/share/glvnd/egl_vendor.d";
    LD_LIBRARY_PATH = "/run/opengl-driver/lib";

    # Force Electron apps to use Wayland/PipeWire portals
    NIXOS_OZONE_WL = "1";
  };

  # Display manager
  services.displayManager.defaultSession = "niri";
  programs.niri.enable = true;

  # Power management
  services.upower.enable = true;
  services.power-profiles-daemon.enable = false;
  powerManagement.cpuFreqGovernor = "performance";

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


  #obs
  programs.obs-studio = {
    enable = true;

    package = (
      pkgs.obs-studio.override {
        cudaSupport = true;
      }
    );
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-backgroundremoval
      obs-pipewire-audio-capture
      obs-vaapi
      obs-gstreamer
      obs-vkcapture
    ];
  };

  services.mpd.enable = false;

  services.input-remapper.enable = true;

  #SCREEN-RECORDER
  programs.gpu-screen-recorder = {
     enable = true;

   };

  #thunar
  programs.thunar.enable = true;
  programs.thunar.plugins = with pkgs.xfce; [
    thunar-archive-plugin
    thunar-volman
    thunar-media-tags-plugin
    thunar-vcs-plugin
  ];
  programs.xfconf.enable = true;






  # Packages
  environment.systemPackages = with pkgs; [
    kitty #terminal
    unrar
    xarchiver
    zip
    localsend #file-transfer

    vscode #code-editor
    rofi #app and wallpaper-manager
    rmpc #music player
    wlogout #logout-app
    kdePackages.ark #file-extraction app
    git
    (python3.withPackages (ps: with ps; [
      pip
      yt-dlp
      mutagen
      requests
    ]))
    ffmpeg
    nvtopPackages.nvidia #gpu-stats
    linuxPackages.cpupower #cpu-freq app
    mangohud #mangohud
    brightnessctl #control-brightness
    gearlever #run exe files
    qt6.qtwayland
    qt5.qtwayland
    lm_sensors #shows stats
    cava #music bar
    yt-dlp #download yt mp3 or mp4
    mpd-mpris #mpd daemon
    ncmpcpp
    swaynotificationcenter #notification daemon
    playerctl #use to control media

    kdePackages.gwenview #image view
    awww #wallpaper daemon
    bat
    btop #stats of machine
    zed-editor #code editor
    appimage-run
    grim #Scrennshot daemon
    slurp #Scrennshot daemon
    grimblast #Scrennshot daemon
    libnotify #notification daemon
    fastfetch #shows-machine info
    xwayland-satellite # for niri
    openrgb #keyboard-backlight-control

    pkgs.faugus-launcher #game-launcher

    vlc #media player
    gcc
    iwgtk #wifi daemon
    pavucontrol #sound-control daemon
    scrcpy # Added for Android ADB connection support
    android-tools # Added for adb command utility
    betterdiscordctl
    deno
    vesktop
    goverlay
    gpu-screen-recorder-gtk
    gimp
    yazi
    zapzap #whatsapp
    kdePackages.kdenlive
    pkgs.librewolf #browser
     pkgs.fuzzel
      lutris
      vkd3d


  ] ++ (with pkgs.yaziPlugins; [
    allmytoes
    mime-ext
    duckdb
    mediainfo
    office
    rich-preview
    glow
    compress
    ouch
    lsar
    bookmarks
    easyjump
    close-and-restore-tab
    zoom
    full-border
    clipboard
    wl-clipboard
    drag
    kdeconnect-send
    sshfs
    recycle-bin
    restore
    mount
    chmod
    sudo
  ]);




  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];




  system.stateVersion = "26.05";
  programs.bash.shellAliases = {
    start-file-server = "python3 -m http.server";




  };

}
