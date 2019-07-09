defmodule Launcher.LauncherConfig do
  def backlight_module do
    Application.get_env(:launcher, :backlight_module)
  end

  def reboot_mfa do
    Application.get_env(:launcher, :reboot_mfa)
  end
end
