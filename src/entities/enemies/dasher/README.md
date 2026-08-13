# Dasher

Enemies with a telegraphed, fast dashing attack. Add them here as
`dasher/<enemy_name>/`.

- **Bat** (`bat/`) — a tiny flying enemy that flutters toward the player and
  dashes sharply at them when close, overshooting slightly BEHIND the player.
  Spawns in swarms that form a cluster. A flying enemy: it lives on its own
  physics layer so bats collide with each other but not walking enemies. As rare
  as a brute, min difficulty 3.