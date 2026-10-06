{ config, pkgs, ... }:
{
  home.username = "adi";
  home.homeDirectory = "/home/adi";
  home.stateVersion = "24.05";

  gtk = {
    enable = true;
    theme.name = "Dracula";
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
      size = 24;
    };
  };

  home.sessionVariables.GTK_THEME = "Dracula";

  programs.home-manager.enable = true;

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };
}
