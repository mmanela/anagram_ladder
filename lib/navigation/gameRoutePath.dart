enum GameRoutePage {
  Unknown,
  Home,
  About,
  Pay,
  WorldSet,
  World,
  Level,
  Settings
}

class GameRoutePath {
  final int? world;
  final int? level;
  final GameRoutePage? source;
  final GameRoutePage page;

  GameRoutePath(
      {this.world, this.level, this.page = GameRoutePage.Unknown, this.source});

  GameRoutePath.home() : this(page: GameRoutePage.Home);
  GameRoutePath.about() : this(page: GameRoutePage.About);
  GameRoutePath.pay({GameRoutePage? source, int? world})
      : this(page: GameRoutePage.Pay, source: source, world: world);
  GameRoutePath.settings() : this(page: GameRoutePage.Settings);
  GameRoutePath.worldSet() : this(page: GameRoutePage.WorldSet);
  GameRoutePath.world(int world)
      : this(world: world, page: GameRoutePage.World);
  GameRoutePath.level(int world, int level)
      : this(world: world, level: level, page: GameRoutePage.Level);
  GameRoutePath.unknown() : this();
}
