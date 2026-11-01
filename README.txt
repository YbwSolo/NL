NO LICENSE RANKS - server version
=================================

This runs on the server side of things: every player gets it automatically when they
join, no app to install. 27 ranks (Rookie to NO LICENSE) with prestige badges, XP for
driving, speed bonus 1x-10x, near misses with streaks, a run counter, rank-up animation,
police chase rings and race rings.

The HUD is clean: nothing on screen while you cruise. It slides in at the top middle when
you earn something (badge, rank, progress line, run score, multiplier), stays while you
are in a run, and fades away when you crash or stop.


SET UP (10 minutes)
-------------------
1. Host the files somewhere with direct links. Easiest: a GitHub repo, or your own
   web host. Upload:
      nl_ranks_online.lua
      icons/rank_01.png ... rank_27.png
   so that e.g.  https://YOUR-HOST/nl_ranks/icons/rank_01.png  opens the picture.

2. Open nl_ranks_online.lua and set at the top:
      ICON_BASE = 'https://YOUR-HOST/nl_ranks/icons/'
   Set the zones (police chase rings, race rings) in the ZONES table. In game, the
   "No License Ranks" entry in the CSP online extras menu has "Copy my position".

3. On the server, in cfg/csp_extra_options.ini add:
      [SCRIPT_...]
      SCRIPT = https://YOUR-HOST/nl_ranks/nl_ranks_online.lua
   Restart the server. Done.

4. Optional - server-side saved progress (so XP follows players between PCs and you
   can pull a leaderboard):
   Make a Cloudflare Worker, paste worker.js, add a KV namespace bound as RANKS.
   Put the worker URL in the script:  BACKEND = 'https://your-worker.workers.dev'
   GET /top on the worker gives you the top 50 as JSON (for a Discord bot / website).
   Without it, progress saves on each player's own PC.


NOTES
-----
- Change XP values at the top of the script, players get the new version on next join.
- If the Golf R from the car pack is installed on a player's PC the police units use it
  (painted white with lights); otherwise they see the flashing lights only.
nolicense
