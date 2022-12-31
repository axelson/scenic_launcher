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
