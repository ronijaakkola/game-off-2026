"""Headless model of the solar system's passenger loop, for trying spawn rules.

Run: python3 tools/passenger_sim.py [experiment ...]   (no args lists the experiments)

Not the game: a 2D model with the numbers from solar_system.tscn, bus.gd, cabin.gd,
passenger.gd and waiting_passengers.gd as of November 2026. Bots play it so spawn rules can be
compared on the same seeds. docs/passenger-director.md has the findings.
"""

from __future__ import annotations

import itertools
import math
import random
import statistics
import sys
from dataclasses import dataclass, field
from multiprocessing import Pool

# --- The world, from solar_system.tscn -------------------------------------------------------

TAU = math.tau


@dataclass(frozen=True)
class Body:
    name: str
    radius: float
    orbit_radius: float
    period: float
    start_deg: float
    fuel_price: float  # credits per unit of fuel
    parent: str | None = None


BODIES = (
    Body("Ember", 0.39, 5.2, 70.0, 200.0, 0.10),
    Body("Terra", 0.5, 8.6, 120.0, 300.0, 0.12),
    Body("Moon", 0.15, 2.0, 30.0, 40.0, 0.15, parent="Terra"),
    Body("Giant", 1.0, 13.2, 220.0, 140.0, 0.06),
    Body("Frost", 0.425, 17.5, 320.0, 20.0, 0.08),
)
BY_NAME = {b.name: b for b in BODIES}
N = len(BODIES)

# bus.gd, cabin.gd, passenger.gd
MAX_SPEED = 1.2
ACCEL = 1.6
CHARGE = 3.0
DOCK_GAP = 0.35
PARK_SECONDS = 0.8  # the glide in and swing side-on; patience holds
STEP = 0.6  # each passenger getting off or on
SEATS = 4
FARE_PER_UNIT = 3.0
SLACK = 1.5
DOCKED_DRAIN = 0.5
FUEL_PER_UNIT = 2.5
PAY = {"happy": 1.2, "okay": 1.0, "annoyed": 0.5, "furious": 0.0}
STARS = {"happy": 5, "okay": 4, "annoyed": 2, "furious": 0}
# Needs: snack 15-40 s, drink 15-50 s, x3 drain while open. The player takes this long to serve.
NEED_MIN, NEED_MAX, NEED_SERVED, NEED_DRAIN = 15.0, 45.0, 6.0, 3.0
SERVE_REACTION = 2.0

DT = 0.1


def body_pos(i: int, t: float) -> tuple[float, float]:
    b = BODIES[i]
    a = math.radians(b.start_deg) + TAU * t / b.period
    x, z = math.cos(a) * b.orbit_radius, -math.sin(a) * b.orbit_radius
    if b.parent:
        px, pz = body_pos(names().index(b.parent), t)
        return px + x, pz + z
    return x, z


_NAMES = [b.name for b in BODIES]


def names() -> list[str]:
    return _NAMES


def dist(a: tuple[float, float], b: tuple[float, float]) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def travel_time(d: float) -> float:
    """From rest to rest over d at the bus's top speed and acceleration."""
    if d >= MAX_SPEED * MAX_SPEED / ACCEL:
        return d / MAX_SPEED + MAX_SPEED / ACCEL
    return 2.0 * math.sqrt(max(d, 0.0) / ACCEL)


def stop_point(i: int, t: float, toward: tuple[float, float]) -> tuple[float, float]:
    """The planet's near side, facing toward."""
    c = body_pos(i, t)
    dx, dz = toward[0] - c[0], toward[1] - c[1]
    n = math.hypot(dx, dz) or 1.0
    r = BODIES[i].radius + DOCK_GAP
    return c[0] + dx / n * r, c[1] + dz / n * r


def intercept(p: tuple[float, float], t: float, i: int) -> tuple[float, float]:
    """(flight seconds, distance) from p at time t to planet i, chasing it."""
    tt = travel_time(dist(p, body_pos(i, t)))
    d = 0.0
    for _ in range(6):
        d = dist(p, stop_point(i, t + tt, p))
        tt = travel_time(d)
    return tt, d


def body_distance(i: int, j: int, t: float) -> float:
    return dist(body_pos(i, t), body_pos(j, t))


def trip_seconds(d: float) -> float:
    """waiting_passengers.gd _trip_seconds."""
    return CHARGE + d / MAX_SPEED + MAX_SPEED / ACCEL


def mood(frac: float) -> str:
    if frac >= 0.6:
        return "happy"
    if frac >= 0.3:
        return "okay"
    if frac > 0.0:
        return "annoyed"
    return "furious"


# --- Passengers -----------------------------------------------------------------------------


@dataclass
class Passenger:
    origin: int
    dest: int
    spawned: float
    fare: float
    pmax: float
    leave_at: float = math.inf
    patience: float = 0.0
    departed: bool = False
    need_in: float = 0.0
    request_left: float = 0.0  # seconds until the player serves the open request
    boarded: float = 0.0

    def frac(self) -> float:
        return self.patience / self.pmax if self.pmax > 0 else 0.0


def make_passenger(origin: int, dest: int, t: float, rng: random.Random, slack: float = SLACK) -> Passenger:
    d = body_distance(origin, dest, t)
    pmax = trip_seconds(d) * slack
    return Passenger(origin, dest, t, d * FARE_PER_UNIT, pmax, need_in=rng.uniform(NEED_MIN, NEED_MAX))


def price_on_board(p: Passenger, t: float, mode: str, slack: float = SLACK) -> None:
    """Fare and patience: at spawn (the code today), at boarding (DESIGN.md), or from the
    flight the bus would really fly from here (a fairer estimate)."""
    if mode == "spawn":
        pass
    elif mode == "board":
        d = body_distance(p.origin, p.dest, t)
        p.fare, p.pmax = d * FARE_PER_UNIT, trip_seconds(d) * slack
    elif mode == "predicted":
        start = stop_point(p.origin, t, body_pos(p.dest, t))
        tt, d = intercept(start, t + CHARGE, p.dest)
        p.fare, p.pmax = d * FARE_PER_UNIT, (CHARGE + tt) * slack
    p.patience = p.pmax


# --- Spawn rules ----------------------------------------------------------------------------


@dataclass
class Rules:
    """One spawn rule set. Defaults are the game today."""

    name: str = "baseline"
    # "per_planet": each planet its own U(min,max) clock (today). "global": one stream for the
    # whole system at `rate` passengers a minute, the origin picked by `origin`.
    spawn: str = "per_planet"
    min_interval: float = 8.0
    max_interval: float = 20.0
    rate: float = 12.0
    origin: str = "uniform"  # "uniform" | "emptiest" (weight cap - waiting, bag-shuffled)
    cap: int = 3
    # "uniform" (today) | "bag" (each origin deals every other planet once per bag) |
    # "near" (weight 1/trip^near_power) | "near_bag"
    dest: str = "uniform"
    near_power: float = 1.0
    # Chance a new passenger goes where someone already waiting there goes, so a line tends
    # to share a way and Board all is less of a gamble.
    cluster: float = 0.0
    # Waiting passengers give up after U(a, b) seconds. None: they never do (today).
    leave_after: tuple[float, float] | None = None
    # When the bus sets off for a planet, make sure someone is waiting there by the time it
    # arrives, if it will have a free seat. combo: chance that person shares a rider's way.
    arrival_guarantee: bool = False
    combo: float = 0.0
    # Rate multiplier 1 + waves * sin(2 pi t / wave_period): rush hours.
    waves: float = 0.0
    wave_period: float = 150.0
    # Rate multiplier grows linearly from ramp_from to 1 over the run.
    ramp_from: float = 1.0
    # Ease off while riders are unhappy, speed up while the bus is starved.
    adaptive: bool = False
    patience: str = "spawn"  # "spawn" (today) | "board" | "predicted"
    slack: float = SLACK
    hold_docked: bool = True  # nobody turns up where the bus is docked (today)


class Director:
    def __init__(self, rules: Rules, world: World, rng: random.Random):
        self.r, self.w, self.rng = rules, world, rng
        self.until = [self._interval() for _ in range(N)]
        self.global_until = self._global_gap()
        self.bags: list[list[int]] = [[] for _ in range(N)]
        self.origin_bag: list[int] = []
        self.pending: list[tuple[float, int, int | None]] = []  # (time, origin, dest)
        self.blocked = 0

    def _mult(self) -> float:
        r, t = self.r, self.w.t
        m = 1.0 + r.waves * math.sin(TAU * t / r.wave_period)
        m *= r.ramp_from + (1.0 - r.ramp_from) * min(t / self.w.duration, 1.0)
        if r.adaptive:
            riders = self.w.riders
            if riders and statistics.mean(p.frac() for p in riders) < 0.45:
                m *= 0.6
            elif len(riders) < 2 and self.w.total_waiting() < 4:
                m *= 1.6
        return max(m, 0.05)

    def _interval(self) -> float:
        return self.rng.uniform(self.r.min_interval, max(self.r.min_interval, self.r.max_interval))

    def _global_gap(self) -> float:
        # Jittered rather than Poisson: +-50 % around the mean, so no long droughts.
        mean = 60.0 / self.r.rate
        return mean * self.rng.uniform(0.5, 1.5)

    def held(self) -> int | None:
        return self.w.docked_at if self.r.hold_docked else None

    def tick(self, dt: float) -> None:
        r, w = self.r, self.w
        held = self.held()
        for item in list(self.pending):
            if item[0] <= w.t:
                self.pending.remove(item)
                self.add(item[1], item[2])
        if r.spawn == "per_planet":
            m = self._mult()
            for i in range(N):
                if i == held:
                    continue
                self.until[i] -= dt * m
                if self.until[i] <= 0:
                    self.until[i] = self._interval()
                    self.add(i)
        else:
            self.global_until -= dt * self._mult()
            if self.global_until <= 0:
                self.global_until = self._global_gap()
                o = self.pick_origin(held)
                if o is not None:
                    self.add(o)
        if r.leave_after:
            for i in range(N):
                if i == held:
                    continue  # they don't walk off while the bus is right there
                w.waiting[i] = [p for p in w.waiting[i] if p.leave_at > w.t]

    def pick_origin(self, held: int | None) -> int | None:
        cands = [i for i in range(N) if i != held and len(self.w.waiting[i]) < self.r.cap]
        if not cands:
            self.blocked += 1
            return None
        if self.r.origin == "uniform":
            return self.rng.choice(cands)
        weights = [self.r.cap - len(self.w.waiting[i]) for i in cands]
        return self.rng.choices(cands, weights)[0]

    def pick_dest(self, o: int) -> int:
        r, rng = self.r, self.rng
        line = self.w.waiting[o]
        if line and rng.random() < r.cluster:
            return rng.choice(line).dest
        others = [j for j in range(N) if j != o]
        if r.dest in ("bag", "near_bag"):
            if not self.bags[o]:
                if r.dest == "bag":
                    self.bags[o] = others[:]
                else:
                    # A bag of 8 weighted toward near planets, so near ones come up more but
                    # every planet still comes up.
                    w = self._near_weights(o, others)
                    counts = [1 + round(3 * x / sum(w) * len(others) / 2) for x in w]
                    self.bags[o] = [j for j, c in zip(others, counts) for _ in range(c)]
                rng.shuffle(self.bags[o])
            return self.bags[o].pop()
        if r.dest == "near":
            return rng.choices(others, self._near_weights(o, others))[0]
        return rng.choice(others)

    def _near_weights(self, o: int, others: list[int]) -> list[float]:
        t = self.w.t
        return [1.0 / trip_seconds(body_distance(o, j, t)) ** self.r.near_power for j in others]

    def add(self, o: int, dest: int | None = None) -> bool:
        w = self.w
        if len(w.waiting[o]) >= self.r.cap:
            self.blocked += 1
            return False
        if dest is None or dest == o:
            dest = self.pick_dest(o)
        p = make_passenger(o, dest, w.t, self.rng, self.r.slack)
        if self.r.leave_after:
            p.leave_at = w.t + self.rng.uniform(*self.r.leave_after)
        w.waiting[o].append(p)
        w.spawned += 1
        return True

    def on_depart(self, target: int, flight: float, riders: list[Passenger]) -> None:
        """The bus has set off for target and will be there in flight seconds."""
        if not self.r.arrival_guarantee:
            return
        staying = [p for p in riders if p.dest != target]
        if len(staying) >= SEATS or self.w.waiting[target]:
            return
        dest = None
        if staying and self.rng.random() < self.r.combo:
            dest = self.rng.choice(staying).dest
        # Turn up partway through the flight, so it reads as a normal arrival.
        self.pending.append((self.w.t + self.rng.uniform(0.2, 0.7) * flight, target, dest))


# --- The bus and the players ----------------------------------------------------------------


@dataclass
class Stats:
    deliveries: int = 0
    credits: float = 0.0
    fuel_cost: float = 0.0
    stars: list[int] = field(default_factory=list)
    star_times: list[float] = field(default_factory=list)
    moods: dict[str, int] = field(default_factory=lambda: dict.fromkeys(PAY, 0))
    direct_moods: dict[str, int] = field(default_factory=lambda: dict.fromkeys(PAY, 0))
    delivery_times: list[float] = field(default_factory=list)
    income: list[tuple[float, float]] = field(default_factory=list)
    flight_time: float = 0.0
    empty_flight_time: float = 0.0
    seat_time: float = 0.0
    docks: int = 0
    dry_docks: int = 0  # free seats, nobody there
    choice_docks: int = 0  # 2+ different destinations on offer
    offered_docks: int = 0
    multi_drops: int = 0  # 2+ got off at one stop
    handovers: int = 0  # someone got off and someone got on
    left_behind: int = 0  # waiting passengers the bot chose not to take with seats free
    waits: list[float] = field(default_factory=list)
    drift: list[float] = field(default_factory=list)  # pmax at spawn vs at boarding
    sat_time: float = 0.0
    gave_up: int = 0


class World:
    def __init__(self, rules: Rules, bot: str, seed: int, duration: float = 600.0):
        self.rng = random.Random(seed)
        self.t = 0.0
        self.duration = duration
        self.rules = rules
        self.bot = bot
        self.waiting: list[list[Passenger]] = [[] for _ in range(N)]
        self.riders: list[Passenger] = []
        self.spawned = 0
        self.docked_at: int | None = 0  # starts docked at Ember
        self.pos = stop_point(0, 0.0, (0.0, 0.0))
        self.s = Stats()
        self.director = Director(rules, self, random.Random(seed * 7919 + 1))
        # The plan: a list of (seconds, state) segments, and what to do when they run out.
        self.segments: list[tuple[float, str]] = []
        self.flying_to: int | None = None

    def total_waiting(self) -> int:
        return sum(len(q) for q in self.waiting)

    # -- ticking --

    def tick_riders(self, dt: float, state: str) -> None:
        for p in self.riders:
            if p.departed and state != "parking":
                drain = dt * (DOCKED_DRAIN if state == "docked" else 1.0)
                if p.request_left > 0:
                    drain *= NEED_DRAIN
                p.patience = max(p.patience - drain, 0.0)
            if p.request_left > 0:
                p.request_left -= dt
                if p.request_left <= 0:
                    p.need_in = NEED_SERVED + self.rng.uniform(NEED_MIN, NEED_MAX)
            else:
                p.need_in -= dt
                if p.need_in <= 0:
                    p.request_left = SERVE_REACTION

    def run(self) -> Stats:
        self.arrive(0, first=True)
        while self.t < self.duration:
            if not self.segments:
                self.next_action()
            secs, state = self.segments[0]
            if state == "fly_start":
                # Leaving: the dock's clock starts again, and everyone on board has departed.
                self.docked_at = None
                for p in self.riders:
                    p.departed = True
                self.director.on_depart(self.flying_to, secs, self.riders)
                state = "fly"
                self.segments[0] = (secs, state)
            self.director.tick(DT)
            self.tick_riders(DT, state)
            if state == "fly":
                self.s.flight_time += DT
                self.s.seat_time += DT * len(self.riders)
                if not self.riders:
                    self.s.empty_flight_time += DT
            cap_total = self.rules.cap * (N - (1 if self.docked_at is not None else 0))
            if self.total_waiting() >= 0.8 * cap_total:
                self.s.sat_time += DT
            secs -= DT
            self.t += DT
            if secs <= 1e-9:
                self.segments.pop(0)
                if state == "fly":
                    self.arrive(self.flying_to)
            else:
                self.segments[0] = (secs, state)
        self.s.gave_up = self.spawned - self.total_waiting() - len(self.riders) - self.s.deliveries
        return self.s

    # -- stops --

    def arrive(self, planet: int, first: bool = False) -> None:
        s = self.s
        self.docked_at = planet
        self.flying_to = None
        if not first:
            s.docks += 1
        off = [p for p in self.riders if p.dest == planet]
        for p in off:
            m = mood(p.frac())
            pay = round(p.fare * PAY[m])
            s.deliveries += 1
            s.credits += pay
            s.stars.append(STARS[m])
            s.star_times.append(self.t)
            s.moods[m] += 1
            if getattr(p, "direct", False):
                s.direct_moods[m] += 1
            s.delivery_times.append(self.t)
            s.income.append((self.t, pay))
        self.riders = [p for p in self.riders if p.dest != planet]
        if len(off) >= 2:
            s.multi_drops += 1
        self.just_dropped = len(off)
        segs = [] if first else [(PARK_SECONDS, "parking")]
        if off:
            segs.append((STEP * len(off), "docked"))
        self.segments = segs

    def next_action(self) -> None:
        """Called when the stop's unloading is over: board and leave."""
        s, here = self.s, self.docked_at
        assert here is not None
        line = self.waiting[here]
        free = SEATS - len(self.riders)
        dests = {p.dest for p in line}
        if line:
            s.offered_docks += 1
            if len(dests) >= 2:
                s.choice_docks += 1
        elif free > 0:
            s.dry_docks += 1
        board, target = BOTS[self.bot](self, here, line, free)
        if len(board) < min(free, len(line)):
            s.left_behind += min(free, len(line)) - len(board)
        for p in board:
            line.remove(p)
            s.waits.append(self.t - p.spawned)
            spawn_pmax = p.pmax
            price_on_board(p, self.t, self.rules.patience, self.rules.slack)
            fresh = trip_seconds(body_distance(p.origin, p.dest, self.t)) * self.rules.slack
            s.drift.append(spawn_pmax / fresh - 1.0)
            p.boarded = self.t
            self.riders.append(p)
        if board and self.just_dropped:
            s.handovers += 1
        depart_at = self.t + STEP * len(board) + CHARGE
        start = stop_point(here, depart_at, body_pos(target, depart_at))
        flight, d = intercept(start, depart_at, target)
        for p in self.riders:
            # Whether this passenger's whole ride is one direct leg: boarded now, going there.
            p.direct = (p.boarded == self.t and p.dest == target) or (getattr(p, "direct", False) and p.dest == target)
        cost = d * FUEL_PER_UNIT * BODIES[here].fuel_price
        s.fuel_cost += cost
        s.credits -= cost
        # Board, then charge, then fly. "fly_start" departs everyone on its first tick.
        self.segments = [(STEP * len(board) + CHARGE, "docked"), (flight, "fly_start")]
        self.flying_to = target





# -- bots --


def eta_from(world: World, here: int, target: int, extra: float = 0.0) -> float:
    t0 = world.t + extra
    start = stop_point(here, t0, body_pos(target, t0))
    return intercept(start, t0, target)[0]


def bot_casual(world: World, here: int, line: list[Passenger], free: int):
    """Board all (longest waiting first), then go where the least patient rider is going.
    Empty: the nearest planet with someone waiting."""
    board = line[:free]
    riders = world.riders + board
    if riders:
        # Unboarded riders have full patience; treat them by fraction like the card shows.
        urgent = min(riders, key=lambda p: (p.frac() if p.departed else 1.0, p.pmax))
        return board, urgent.dest
    return board, _nearest_with_waiting(world, here)


def bot_nearest(world: World, here: int, line: list[Passenger], free: int):
    """Board all, then go to the nearest destination on board."""
    board = line[:free]
    riders = world.riders + board
    if riders:
        extra = STEP * len(board) + CHARGE
        return board, min({p.dest for p in riders}, key=lambda d: eta_from(world, here, d, extra))
    return board, _nearest_with_waiting(world, here)


def _nearest_with_waiting(world: World, here: int) -> int:
    cands = [i for i in range(N) if i != here and world.waiting[i]] or [i for i in range(N) if i != here]
    return min(cands, key=lambda i: eta_from(world, here, i, CHARGE) / (1 + len(world.waiting[i])))


def bot_planner(world: World, here: int, line: list[Passenger], free: int):
    """Tries every choice of who to board and every order of drops, with the planets'
    future positions, and takes the best credits-and-stars per second. Commits to the
    first stop only and plans again at the next."""
    best = (-1e9, [], None)
    for k in range(min(free, len(line)), -1, -1):
        for board in itertools.combinations(line, k):
            riders = world.riders + list(board)
            dests = sorted({p.dest for p in riders})
            if not dests:
                continue
            for order in itertools.permutations(dests):
                v = _plan_value(world, here, list(board), riders, order)
                if v > best[0]:
                    best = (v, list(board), order[0])
    if best[2] is None:
        # Empty bus: go for the best line, valued by its fares per second of flying there.
        def value(i: int) -> float:
            q = world.waiting[i]
            gain = sum(sorted((p.fare for p in q), reverse=True)[:SEATS]) + 8 * len(q)
            return gain / (eta_from(world, here, i, CHARGE) + 10.0)

        target = max((i for i in range(N) if i != here), key=value)
        return [], target
    return best[1], best[2]


def _plan_value(world: World, here: int, board: list[Passenger], riders: list[Passenger], order) -> float:
    t = world.t + STEP * len(board) + CHARGE
    pos = stop_point(here, t, body_pos(order[0], t))
    pat = {id(p): (p.patience if p.departed else _pmax_if_boarded(world, p)) for p in riders}
    pmax = {id(p): (p.pmax if p.departed else _pmax_if_boarded(world, p)) for p in riders}
    fare = {id(p): (p.fare if p.departed else _fare_if_boarded(world, p)) for p in riders}
    gain = 0.0
    start = world.t
    for stop in order:
        flight, d = intercept(pos, t, stop)
        gain -= d * FUEL_PER_UNIT * 0.1
        for p in riders:
            pat[id(p)] -= flight
        t += flight + PARK_SECONDS
        pos = stop_point(stop, t, pos)
        off = [p for p in riders if p.dest == stop]
        for p in off:
            m = mood(pat[id(p)] / pmax[id(p)])
            gain += fare[id(p)] * PAY[m] + 3.0 * STARS[m]
        riders = [p for p in riders if p.dest != stop]
        docked = STEP * len(off) + CHARGE
        for p in riders:
            pat[id(p)] -= docked * DOCKED_DRAIN
        t += docked
    return gain / (t - start)


def _pmax_if_boarded(world: World, p: Passenger) -> float:
    mode = world.rules.patience
    if mode == "spawn":
        return p.pmax
    q = Passenger(p.origin, p.dest, p.spawned, p.fare, p.pmax)
    price_on_board(q, world.t, mode, world.rules.slack)
    return q.pmax


def _fare_if_boarded(world: World, p: Passenger) -> float:
    if world.rules.patience == "spawn":
        return p.fare
    return body_distance(p.origin, p.dest, world.t) * FARE_PER_UNIT


BOTS = {"casual": bot_casual, "nearest": bot_nearest, "planner": bot_planner}

# --- Runs and summaries ---------------------------------------------------------------------


def summarize(s: Stats, duration: float) -> dict[str, float]:
    gaps = [b - a for a, b in zip([0.0] + s.delivery_times, s.delivery_times + [duration])]
    windows = [0.0] * int(duration // 60)
    for t, pay in s.income:
        idx = min(int(t // 60), len(windows) - 1)
        windows[idx] += pay
    cv = statistics.pstdev(windows) / statistics.mean(windows) if sum(windows) > 0 else 0.0
    total = max(sum(s.moods.values()), 1)
    dtotal = max(sum(s.direct_moods.values()), 1)
    return {
        "deliv": s.deliveries,
        "credits": s.credits,
        "stars": statistics.mean(s.stars) if s.stars else 0.0,
        "happy%": 100 * s.moods["happy"] / total,
        "okay%": 100 * s.moods["okay"] / total,
        "bad%": 100 * (s.moods["annoyed"] + s.moods["furious"]) / total,
        "furious%": 100 * s.moods["furious"] / total,
        "direct_happy%": 100 * s.direct_moods["happy"] / dtotal,
        "direct_n": sum(s.direct_moods.values()),
        "seats": s.seat_time / max(s.flight_time, 1e-9),
        "empty_fly%": 100 * s.empty_flight_time / max(s.flight_time, 1e-9),
        "dry%": 100 * s.dry_docks / max(s.docks, 1),
        "choice%": 100 * s.choice_docks / max(s.offered_docks, 1),
        "multi%": 100 * s.multi_drops / max(s.docks, 1),
        "handover%": 100 * s.handovers / max(s.docks, 1),
        "max_gap": max(gaps),
        "income_cv": cv,
        "wait_med": statistics.median(s.waits) if s.waits else 0.0,
        "stale%": 100 * sum(1 for w in s.waits if w > 60) / max(len(s.waits), 1),
        "drift%": 100 * statistics.mean(abs(x) for x in s.drift) if s.drift else 0.0,
        "drift_big%": 100 * sum(1 for x in s.drift if abs(x) > 0.2) / max(len(s.drift), 1),
        "sat%": 100 * s.sat_time / duration,
        "stars_early": _mean_between(s, 0, 180),
        "stars_late": _mean_between(s, 420, 600),
        "deliv_early": sum(1 for t in s.delivery_times if t < 180),
        "deliv_late": sum(1 for t in s.delivery_times if t >= 420),
        "first30": s.delivery_times[29] if len(s.delivery_times) >= 30 else math.inf,
        "gave_up": s.gave_up,
        "left_behind": s.left_behind,
    }


def _mean_between(s: Stats, a: float, b: float) -> float:
    xs = [x for x, t in zip(s.stars, s.star_times) if a <= t < b]
    return statistics.mean(xs) if xs else math.nan


def _one(args: tuple[Rules, str, int, float]) -> dict[str, float]:
    rules, bot, seed, duration = args
    return summarize(World(rules, bot, seed, duration).run(), duration)


SEEDS = 40


def evaluate(rule_sets: list[Rules], bots=("casual", "nearest", "planner"), seeds=SEEDS, duration=600.0):
    jobs = [(r, b, s, duration) for r in rule_sets for b in bots for s in range(seeds)]
    with Pool() as pool:
        results = pool.map(_one, jobs, chunksize=4)
    out: dict[tuple[str, str], list[dict[str, float]]] = {}
    for (r, b, _, _), res in zip(jobs, results):
        out.setdefault((r.name, b), []).append(res)
    return out


def agg(rows: list[dict[str, float]], key: str) -> tuple[float, float]:
    vals = [r[key] for r in rows if not math.isnan(r[key]) and math.isfinite(r[key])]
    if not vals:
        return math.inf, 0.0
    return statistics.mean(vals), statistics.pstdev(vals)


COLUMNS = [
    ("deliv", "deliv", "{:5.1f}"),
    ("credits", "cr", "{:5.0f}"),
    ("stars", "stars", "{:4.2f}"),
    ("happy%", "happy", "{:4.0f}"),
    ("bad%", "bad", "{:4.0f}"),
    ("seats", "seats", "{:4.2f}"),
    ("empty_fly%", "emptyfly", "{:4.0f}"),
    ("dry%", "dry", "{:4.0f}"),
    ("choice%", "choice", "{:4.0f}"),
    ("multi%", "multi", "{:4.0f}"),
    ("max_gap", "maxgap", "{:4.0f}"),
    ("income_cv", "cv", "{:4.2f}"),
    ("stale%", "stale", "{:4.0f}"),
    ("drift_big%", "drift", "{:4.0f}"),
    ("sat%", "sat", "{:4.0f}"),
    ("first30", "t30", "{:4.0f}"),
]


def report(title: str, rule_sets: list[Rules], bots=("casual", "nearest", "planner"), seeds=SEEDS, extra=()):
    out = evaluate(rule_sets, bots, seeds)
    cols = COLUMNS + [c for c in extra]
    print(f"\n## {title}\n")
    print("| rules | bot | " + " | ".join(c[1] for c in cols) + " | cr sd |")
    print("|---|---|" + "---|" * (len(cols) + 1))
    for r in rule_sets:
        for b in bots:
            rows = out[(r.name, b)]
            cells = [c[2].format(agg(rows, c[0])[0]) for c in cols]
            print(f"| {r.name} | {b} | " + " | ".join(cells) + f" | {agg(rows, 'credits')[1]:.0f} |")
    # Skill gap and luck: planner over casual, and seed spread of the casual bot's credits.
    if "planner" in bots and "casual" in bots:
        print("\n| rules | skill gap (planner/casual credits) | luck (casual credits CV) | luck (planner CV) |")
        print("|---|---|---|---|")
        for r in rule_sets:
            pm, ps = agg(out[(r.name, "planner")], "credits")
            cm, cs = agg(out[(r.name, "casual")], "credits")
            print(f"| {r.name} | {pm / cm:.2f}x | {cs / cm:.2f} | {ps / pm:.2f} |")
    return out


# --- Experiments ----------------------------------------------------------------------------

BASE = Rules()


def r(name: str, **kw) -> Rules:
    return Rules(name=name, **kw)


def exp_baseline():
    report("Baseline: the game today", [BASE])


def exp_direct():
    """What a direct trip gives, by distance, with no detours and no requests."""
    print("\n## Direct trips: mood on arrival with patience = 1.5 x trip estimate\n")
    print("| straight distance | trip estimate s | flight s | patience left | mood |")
    print("|---|---|---|---|---|")
    for d in (2, 4, 4.5, 6, 8, 12, 16, 20, 25, 30):
        pmax = trip_seconds(d) * SLACK
        fly = travel_time(d)
        left = 1 - fly / pmax
        print(f"| {d} | {trip_seconds(d):.1f} | {fly:.1f} | {100 * left:.0f}% | {mood(left)} |")
    print("\nWith one request served after 2 s on the way (+4 s of drain):\n")
    print("| straight distance | patience left | mood |")
    print("|---|---|---|")
    for d in (4, 8, 12, 20):
        pmax = trip_seconds(d) * SLACK
        left = 1 - (travel_time(d) + 4) / pmax
        print(f"| {d} | {100 * left:.0f}% | {mood(left)} |")


def exp_geometry():
    """How far apart the planets are over a long stretch: what the destination mix offers."""
    print("\n## Planet pair distances over 20 minutes (min / median / max)\n")
    print("| from \\ to | " + " | ".join(names()) + " |")
    print("|---|" + "---|" * N)
    for i in range(N):
        cells = []
        for j in range(N):
            if i == j:
                cells.append("-")
                continue
            ds = sorted(body_distance(i, j, t) for t in range(0, 1200, 2))
            cells.append(f"{ds[0]:.0f} / {ds[len(ds) // 2]:.0f} / {ds[-1]:.0f}")
        print(f"| {names()[i]} | " + " | ".join(cells) + " |")


def exp_supply():
    report(
        "Supply: how fast passengers turn up",
        [
            BASE,
            r("slow 20-40", min_interval=20, max_interval=40),
            r("slower 30-60", min_interval=30, max_interval=60),
            r("global 12/min", spawn="global", rate=12),
            r("global 8/min", spawn="global", rate=8),
            r("global 6/min", spawn="global", rate=6),
            r("global 4/min", spawn="global", rate=4),
        ],
    )


def exp_freshness():
    report(
        "Freshness: waiting passengers give up, and patience priced at boarding",
        [
            BASE,
            r("price at boarding", patience="board"),
            r("leave 45-75", leave_after=(45, 75)),
            r("leave 45-75 + board", leave_after=(45, 75), patience="board"),
            r("leave 30-50 + board", leave_after=(30, 50), patience="board"),
        ],
    )


def exp_destinations():
    g = dict(spawn="global", rate=8, patience="board", leave_after=(45, 75))
    report(
        "Destinations (on global 8/min, leave 45-75, priced at boarding)",
        [
            r("uniform", **g),
            r("bag", dest="bag", **g),
            r("near p1", dest="near", near_power=1.0, **g),
            r("near p2", dest="near", near_power=2.0, **g),
            r("near bag", dest="near_bag", **g),
            r("cluster 0.3", cluster=0.3, **g),
            r("cluster 0.5", cluster=0.5, **g),
            r("bag + cluster 0.4", dest="bag", cluster=0.4, **g),
            r("near bag + cluster 0.4", dest="near_bag", cluster=0.4, **g),
        ],
    )


def exp_slack():
    g = dict(spawn="global", rate=8, patience="board", leave_after=(45, 75))
    report(
        "Patience slack (on global 8/min, leave 45-75, priced at boarding)",
        [r(f"slack {x}", slack=x, **g) for x in (1.5, 1.75, 2.0, 2.25)],
    )


def exp_rate():
    g = dict(spawn="global", patience="board", leave_after=(45, 75), cluster=0.3)
    report(
        "Rate with give-ups (leave 45-75, cluster 0.3, priced at boarding)",
        [r(f"{x}/min", rate=x, **g) for x in (8, 10, 12, 14, 16)],
    )


def exp_origins():
    g = dict(spawn="global", rate=12, patience="board", leave_after=(45, 75), cluster=0.3)
    report(
        "Origins and arrival help (on global 12/min, cluster 0.3, leave 45-75, priced at boarding)",
        [
            r("uniform origin", **g),
            r("emptiest origin", origin="emptiest", **g),
            r("arrival guarantee", origin="emptiest", arrival_guarantee=True, **g),
            r("guarantee + combo 0.5", origin="emptiest", arrival_guarantee=True, combo=0.5, **g),
            r("guarantee + combo 1.0", origin="emptiest", arrival_guarantee=True, combo=1.0, **g),
        ],
    )


PACE_COLUMNS = (
    ("deliv_early", "deliv 0-3m", "{:4.1f}"),
    ("deliv_late", "deliv 7-10m", "{:4.1f}"),
    ("stars_early", "stars 0-3m", "{:4.2f}"),
    ("stars_late", "stars 7-10m", "{:4.2f}"),
)


def exp_pacing():
    g = dict(spawn="global", rate=12, patience="board", leave_after=(45, 75), cluster=0.3, arrival_guarantee=True)
    report(
        "Pacing (on global 12/min, cluster 0.3, leave 45-75, arrival guarantee, priced at boarding)",
        [
            r("steady 12", **g),
            r("waves +-40% / 150 s", waves=0.4, wave_period=150, **g),
            r("ramp 8 -> 16", ramp_from=0.5, **{**g, "rate": 16}),
            r("ramp 6 -> 14", ramp_from=6 / 14, **{**g, "rate": 14}),
            r("adaptive", adaptive=True, **g),
        ],
        extra=PACE_COLUMNS,
    )


DIRECTOR = dict(
    spawn="global",
    rate=14,
    ramp_from=6 / 14,
    patience="board",
    leave_after=(60, 100),
    cluster=0.4,
    arrival_guarantee=True,
)


def exp_candidates():
    report(
        "Candidates side by side (80 seeds)",
        [
            BASE,
            r("minimal fix", patience="board", leave_after=(60, 100)),
            r("director", **DIRECTOR),
            r("director + slack 1.75", slack=1.75, **DIRECTOR),
        ],
        seeds=80,
        extra=PACE_COLUMNS,
    )


def exp_robust():
    """Each part of the director taken out on its own, to see what it buys."""
    report(
        "Ablation: each part of the director taken out on its own",
        [
            r("director", **DIRECTOR),
            r("director - cluster", **{**DIRECTOR, "cluster": 0.0}),
            r("director - guarantee", **{**DIRECTOR, "arrival_guarantee": False}),
            r("director - leave", **{**DIRECTOR, "leave_after": None}),
            r("director - ramp", **{**DIRECTOR, "ramp_from": 1.0, "rate": 12}),
            r("director cap 4", cap=4, **DIRECTOR),
        ],
        seeds=60,
        extra=PACE_COLUMNS,
    )


def exp_tune():
    rows = []
    for leave in ((45, 75), (60, 100), (90, 150)):
        for cluster in (0.2, 0.3, 0.4):
            rows.append(r(f"leave {leave[0]}-{leave[1]}, cluster {cluster}", **{**DIRECTOR, "leave_after": leave, "cluster": cluster}))
    report("Tuning give-up time against clustering (director otherwise)", rows, extra=PACE_COLUMNS)


EXPERIMENTS = {
    "direct": exp_direct,
    "geometry": exp_geometry,
    "baseline": exp_baseline,
    "supply": exp_supply,
    "freshness": exp_freshness,
    "destinations": exp_destinations,
    "slack": exp_slack,
    "rate": exp_rate,
    "origins": exp_origins,
    "pacing": exp_pacing,
    "candidates": exp_candidates,
    "robust": exp_robust,
    "tune": exp_tune,
}


if __name__ == "__main__":
    picked = sys.argv[1:]
    if not picked:
        print("Experiments: " + ", ".join(EXPERIMENTS) + ", or all")
        sys.exit(0)
    if picked == ["all"]:
        picked = list(EXPERIMENTS)
    for name in picked:
        EXPERIMENTS[name]()
