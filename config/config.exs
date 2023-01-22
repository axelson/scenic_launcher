import Config

config :scenic, :assets, module: Launcher.Assets

config :launcher, :viewport,
  name: :main_viewport,
  size: {800, 480},
  default_scene: {Launcher.Scene.Home, []},
  drivers: [
    [
      module: Scenic.Driver.Local,
      window: [
        title: "Launcher"
      ],
      on_close: :stop_system
    ]
  ]

case Mix.env() do
  :dev ->
    config :exsync,
      reload_timeout: 150,
      reload_callback: {ScenicLiveReload, :reload_current_scenes, []}

  _ ->
    nil
end
