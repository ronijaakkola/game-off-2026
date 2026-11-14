# /// script
# requires-python = ">=3.10"
# ///
"""Balance runs: the real game played headless by a scripted player, many seeds at once.

  uv run tools/balance.py run [--variants FILE] [--seeds N] [--minutes M] [--out DIR]
      Plays every variant on the same seeds and prints one table. A variants file is a
      JSON list of {"name", "policy", "overrides", "project"}: the policy is the scripted
      player's (tools/balance/player.gd), the overrides are exported numbers set without
      touching a file (tools/balance/run.gd), and "project" is another checkout to play,
      for a change to a constant. Without a file it plays the game as it is.
  uv run tools/balance.py play DIR [DECISION] [--seed N] [--minutes M] [--policy JSON]
      A game played turn by turn, one dock at a time, for a person or an agent. With no
      DECISION it starts the game in DIR (or shows where it stands). A DECISION is JSON:
      {"board": ["w1"], "research": ["Comfort#0"], "refuel": true, "next": "Terra"}.

The game is deterministic for a seed, so `play` replays the decisions so far each turn.
"""

import argparse
import json
import os
import statistics
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCENE = "res://tools/balance/run.tscn"
FPS = "30"


def godot() -> str:
    return os.environ.get("GODOT", "godot")


def play_game(config: dict, project: Path = ROOT) -> None:
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as file:
        json.dump(config, file)
    try:
        result = subprocess.run(
            [godot(), "--headless", "--path", str(project), "--fixed-fps", FPS,
             "--scene", SCENE, "--", file.name],
            capture_output=True, text=True, timeout=1800,
        )
        lines = result.stdout.splitlines() + result.stderr.splitlines()
        errors = [line for line in lines if "SCRIPT ERROR" in line or "Compile Error" in line]
        if errors:
            raise SystemExit("the run logged errors:\n" + "\n".join(errors[:10]))
        if result.returncode != 0:
            raise SystemExit(
                f"the run stopped with exit code {result.returncode}:\n" + "\n".join(lines[-10:])
            )
    finally:
        os.unlink(file.name)


def mean(values: list[float]) -> float:
    return statistics.fmean(values) if values else float("nan")


def share(rows: list, test) -> float:
    return 100.0 * sum(1 for row in rows if test(row)) / len(rows) if rows else float("nan")


def at_time(series: list[dict], seconds: float, key: str) -> float:
    value = 0.0
    for row in series:
        if row["t"] <= seconds:
            value = row[key]
    return value


def summarize(reports: list[dict]) -> dict:
    """One variant's numbers over its seeds. Rides are pooled; the rest is a mean of runs."""
    rides = [ride for report in reports for ride in report["deliveries"]]
    business = [ride for ride in rides if ride["type"] == "Business"]
    minutes = mean([report["seconds"] / 60.0 for report in reports])
    row = {
        "delivered/min": mean([len(r["deliveries"]) for r in reports]) / minutes,
        "credits/min": mean([r["earned"] for r in reports]) / minutes,
        "unspent %": mean([100.0 * r["credits"] / max(r["earned"], 1) for r in reports]),
        "avg stars": mean([ride["stars"] for ride in rides]),
        "<=2* %": share(rides, lambda ride: ride["stars"] <= 2),
        "3* %": share(rides, lambda ride: ride["stars"] == 3),
        "4* %": share(rides, lambda ride: ride["stars"] == 4),
        "5* %": share(rides, lambda ride: ride["stars"] == 5),
        "ride s (median)": statistics.median([ride["ride"] for ride in rides]) if rides else 0,
        "requests/ride": mean([ride["requests"] for ride in rides]),
        "rides w/o request %": share(rides, lambda ride: ride["requests"] == 0),
        "requests/flight min": mean(
            [60.0 * r["requests"] / max(r["flight_seconds"], 1) for r in reports]
        ),
        "hand busy % of flight": mean(
            [100.0 * r["hand_seconds"] / max(r["flight_seconds"], 1) for r in reports]
        ),
        "request wait s": mean([r["request_seconds"] / max(r["requests"], 1) for r in reports]),
        "seats full %": mean(
            [100.0 * r["seat_seconds"] / max(r["capacity_seconds"], 1) for r in reports]
        ),
        "flying %": mean([100.0 * r["flight_seconds"] / r["seconds"] for r in reports]),
        "business %": share(rides, lambda ride: ride["type"] == "Business"),
        "business stars": mean([ride["stars"] for ride in business]),
        "avg stars at 10 rides": mean(
            [mean([ride["stars"] for ride in r["deliveries"][:10]]) for r in reports]
        ),
        "avg stars at 30 rides": mean(
            [mean([ride["stars"] for ride in r["deliveries"][:30]]) for r in reports]
        ),
        "deliveries goal at min": mean(
            [r["deliveries_goal_at"] / 60.0 for r in reports if r["deliveries_goal_at"] > 0]
        ),
        "rating goal at end %": share(
            reports, lambda r: r["recent_rating"] >= r["rating_goal"]
        ),
        "both goals met %": share(reports, lambda r: r["both_goals_at"] > 0),
        "both goals at min": mean(
            [r["both_goals_at"] / 60.0 for r in reports if r["both_goals_at"] > 0]
        ),
        "recent stars at end": mean([r["recent_rating"] for r in reports]),
        "first upgrade at min": mean(
            [r["upgrades"][0]["t"] / 60.0 for r in reports if r["upgrades"]]
        ),
        "upgrades at 5 min": mean([at_time(r["series"], 300, "upgrades") for r in reports]),
        "upgrades at 10 min": mean([at_time(r["series"], 600, "upgrades") for r in reports]),
        "upgrades at end": mean([len(r["upgrades"]) for r in reports]),
        "tows": mean([r["tows"] for r in reports]),
        "overheats": mean([r.get("overheats", 0) for r in reports]),
        "waiting at a dock": mean([r["waiting_at_dock"] for r in reports]),
        "empty seats leaving": mean([r["empty_seats_leaving"] for r in reports]),
        "seats at end": mean([r["seats"] for r in reports]),
        "points unspent %": mean(
            [100.0 * sum(r["points"].values()) / max(r["points_earned"], 1) for r in reports]
        ),
        "direct ride stars": mean([ride["stars"] for ride in rides if ride["stops"] == 0]),
        "1-2 stop ride stars": mean([ride["stars"] for ride in rides if ride["stops"] in (1, 2)]),
        "pay % of fare": 100.0 * sum(ride["payout"] for ride in rides)
        / max(sum(ride["fare"] for ride in rides), 1),
    }
    return row


def print_table(table: dict[str, dict]) -> None:
    names = list(table)
    keys = list(next(iter(table.values())))
    width = max(len(key) for key in keys)
    print(" " * width + "".join(f"{name:>16}" for name in names))
    for key in keys:
        print(f"{key:<{width}}" + "".join(f"{table[name][key]:>16.2f}" for name in names))


def command_run(args: argparse.Namespace) -> None:
    variants = [{"name": "as it is"}]
    if args.variants:
        variants = json.loads(Path(args.variants).read_text())
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    jobs = []
    for variant in variants:
        for seed in range(1, args.seeds + 1):
            path = out / f"{variant['name'].replace(' ', '_')}_{seed}.json"
            config = {
                "seed": seed,
                "minutes": variant.get("minutes", args.minutes),
                "out": str(path.resolve()),
                "policy": variant.get("policy", {}),
                "overrides": variant.get("overrides", {}),
            }
            jobs.append((variant, path, config))
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        list(pool.map(
            lambda job: play_game(job[2], Path(job[0].get("project", ROOT))), jobs
        ))
    table = {}
    for variant in variants:
        reports = [json.loads(path.read_text()) for owner, path, _ in jobs if owner is variant]
        table[variant["name"]] = summarize(reports)
    print(f"{args.seeds} seeds, {args.minutes:g} minutes each")
    print_table(table)
    (out / "summary.json").write_text(json.dumps(table, indent=2))


def show_state(state: dict) -> None:
    if state.get("done"):
        print("The game is over. See report.json in the game's folder.")
        return
    fuel = state["fuel"]
    print(f"=== Decision {state['decision']}: docked at {state['planet']}, "
          f"{state['time']} s of {state['ends_at']} s played ===")
    for line in state["news"]:
        print(f"  * {line}")
    points = ", ".join(f"{count} {race.lower()}" for race, count in state["points"].items())
    print(f"Credits {state['credits']}. Research points: {points}.")
    print(f"Rating (last 10 rides) {state['rating']} stars, all-time {state['average_rating']}; "
          f"{state['delivered']} delivered.")
    print(f"Fuel {fuel['fuel']}/{fuel['capacity']} (flies {fuel['range']} units); "
          f"filling up here costs {fuel['fill_costs']} credits.")
    print(f"On board ({len(state['on_board'])} of {state['seats']} seats):")
    for p in state["on_board"]:
        print(f"  - {p['name']} ({p['type']}, {p['race'].lower()}) to {p['to']}: happiness "
              f"{p['happiness']}/100, would rate {p['stars_now']:g} stars and pay "
              f"{p['pays_now']} now (fare {p['fare']}; expected a {p['expected_seconds']} s ride)")
    print("Waiting here:" if state["waiting"] else "Nobody waits here.")
    for p in state["waiting"]:
        print(f"  - {p['id']}: {p['name']} ({p['type']}, {p['race'].lower()}) to {p['to']}, "
              f"{p['distance']} units away: fare {p['fare']}, direct trip {p['trip_seconds']} s, "
              f"expects {p['expected_seconds']} s")
    print("Planets:")
    for planet in state["planets"]:
        if planet["here"]:
            continue
        extras = []
        if "waiting" in planet:
            extras.append(f"{planet['waiting']} waiting")
        if planet["research"]:
            extras.append("has a lab")
        print(f"  - {planet['name']}: {planet['distance']} units, about "
              f"{planet['flight_seconds']} s; full tank costs {planet['full_tank_costs']}"
              + (" (" + ", ".join(extras) + ")" if extras else ""))
    print("Upgrades (researched only while docked at a planet with a lab):")
    for upgrade in state["upgrades"]:
        if upgrade["state"] in ("researched", "locked"):
            continue
        cost = ", ".join(f"{n} {race.lower()}" for race, n in upgrade["points"].items())
        print(f"  - {upgrade['id']} {upgrade['title']} ({upgrade['state']}): "
              f"{upgrade['credits']} credits + {cost}. {upgrade['does']}")
    done = [u["title"] for u in state["upgrades"] if u["state"] == "researched"]
    print("Researched so far: " + (", ".join(done) if done else "nothing"))


def command_play(args: argparse.Namespace) -> None:
    folder = Path(args.dir)
    folder.mkdir(parents=True, exist_ok=True)
    game_path = folder / "game.json"
    if game_path.exists():
        game = json.loads(game_path.read_text())
    else:
        game = {"seed": args.seed, "minutes": args.minutes, "decisions": [],
                "policy": json.loads(args.policy), "overrides": json.loads(args.overrides),
                "project": args.project}
    if args.decision:
        decision = json.loads(args.decision)
        if not isinstance(decision, dict) or not decision.get("next"):
            raise SystemExit('A decision needs "next": the planet to fly to.')
        game["decisions"].append(decision)
    config = dict(game, out=str((folder / "report.json").resolve()),
                  state_out=str((folder / "state.json").resolve()))
    play_game(config, Path(game.get("project") or ROOT))
    game_path.write_text(json.dumps(game, indent=1))
    show_state(json.loads((folder / "state.json").read_text()))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    run = commands.add_parser("run")
    run.add_argument("--variants")
    run.add_argument("--seeds", type=int, default=8)
    run.add_argument("--minutes", type=float, default=15.0)
    run.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    run.add_argument("--out", default=str(ROOT / "build" / "balance"))
    play = commands.add_parser("play")
    play.add_argument("dir")
    play.add_argument("decision", nargs="?")
    play.add_argument("--seed", type=int, default=1)
    play.add_argument("--minutes", type=float, default=12.0)
    play.add_argument("--policy", default="{}")
    play.add_argument("--overrides", default="{}")
    play.add_argument("--project", default="")
    args = parser.parse_args()
    {"run": command_run, "play": command_play}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
