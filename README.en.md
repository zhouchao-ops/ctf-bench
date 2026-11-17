# CTF Bench

[中文](README.md) | English

A local, extensible CTF benchmark platform that exposes the API used by
Qiming's `tsec-benchmark` skill. An agent runs the loop
`list → pick → start → solve → submit → close`, then reads the final score
from `/scoreboard`.

It ships with six challenges under `challenges/` (including `hengyuan-01`, a
multi-container enterprise network range). Adding a challenge means dropping in
a directory or editing `challenges.json`; `server.py` does not need to change.
The judge itself is standard library only — no Docker SDK, no dependencies; but
the `hengyuan-01` service challenge needs Docker + Docker Compose on the host at
`start` (the first run builds images and takes a while).

> **Public-repository warning**: in a public repository,
> `challenges/*/instructor/flag.txt`, `solve.py`, and `walkthrough.md` are
> public, so anyone can read the answers. Use a private repository, or keep
> flags and reference solutions outside the repository, if the challenges are
> meant to be a scored contest.

## Repository layout

```text
ctf-bench/
├── server.py                    # judge implementation
├── challenges.json              # challenge manifest (extensible)
├── start.sh                     # launcher
├── test_api.py                  # end-to-end API test (binds 127.0.0.1 only)
├── README.md                    # 中文
├── README.en.md                 # English
├── .gitignore                   # ignores data/ and __pycache__
├── .github/workflows/test.yml   # CI: run test_api.py on push/PR
├── challenges/                  # challenge package (default source)
│   ├── README.md
│   ├── verify_all.py
│   ├── web/
│   │   ├── challenge.md
│   │   ├── public/
│   │   ├── instructor/          # flag.txt, server.py, walkthrough.md
│   │   ├── solve.py
│   │   └── start.sh / stop.sh
│   ├── crypto/  reverse/  pwn/  forensics/
│   ├── hengyuan/              # multi-container network range (service, needs Docker Compose)
│   └── ...
└── data/                        # created at runtime: state.json (token), logs/
```

`--challenges-dir` defaults to the in-repo `challenges/`. The package is
self-contained, so a fresh clone runs immediately. `data/` is not tracked and
holds the contest token and scores.

## Starting

Qiming runs inside Docker, so the judge binds to the `qiming_default` bridge
gateway by default (commonly `172.18.0.1`), which both the host and the agent
container can reach:

```bash
cd ctf-bench
./start.sh
```

The startup banner prints:

```text
BENCHMARK_BASE_URL=http://172.18.0.1:9000
BENCHMARK_TOKEN=<random on first run, then persisted>
BENCHMARK_VPN_CHECK_URL=http://172.18.0.1:9000/vpn-check
scoreboard: http://172.18.0.1:9000/scoreboard
```

Common options:

```bash
./start.sh --reset                # clear scores/hints/instances, keep the token
./start.sh --port 9000            # change the port
./start.sh --bind 0.0.0.0         # listen on all interfaces (LAN-visible; be careful)
./start.sh --time-limit-minutes 120
./start.sh --hint-ratio 0.7 --max-active 3
./start.sh --challenges-dir ./challenges
./start.sh --list-challenges      # validate the config and print the resolved list; do not serve
```

If binding to `172.18.0.1` fails, first check that the network exists:

```bash
docker network inspect qiming_default --format '{{(index .IPAM.Config 0).Gateway}}'
```

Use `--bind <address>` on another machine or network. With `--bind 0.0.0.0`,
agent-facing URLs still use the auto-detected gateway address.

To open the scoreboard from another machine, start with `--bind 0.0.0.0` and
visit `http://<server>:9000/scoreboard`; agent-facing URLs still use the
gateway address.

Rotate the token:

```bash
./start.sh --token '<new-token>'    # override and persist
# or delete data/state.json and restart
```

Run in the background:

```bash
mkdir -p data
nohup ./start.sh > data/judge.out 2>&1 &
tail -f data/judge.out       # token and addresses
```

Stop with `kill <pid>` or `pkill -f ctf-bench/server.py`. SIGTERM also stops
spawned service instances.

## Adding challenges / extending

The challenge root is set by `--challenges-dir` (default: in-repo
`challenges/`). The minimal layout is:

```text
<challenges-dir>/newchal/
├── challenge.md                 # statement
├── public/                      # files handed to the agent
└── instructor/
    └── flag.txt                 # expected answer, host-only
```

`instructor/flag.txt` may contain one flag per line; a multi-flag challenge
gets `flag_count` from the number of non-empty lines and awards points
proportionally.

Restart the judge after adding a challenge. `challenges.json` defaults to
`"auto_discover": true`, which picks up every directory containing both
`challenge.md` and `instructor/flag.txt` and infers:

- `title`: the first `# ` heading;
- `category`: `方向：...` (direction);
- `total_score`: `分值：...` (score), default 100;
- `difficulty` / `level`: `难度：...` (difficulty; easy=1, medium=2,
  medium-hard=3, hard=4, very hard=5), default 3;
- `kind`: `service` if `instructor/server.py` exists, otherwise `artifact`.

For full control, add an entry to `challenges.json`:

```json
{
  "code": "newchal",
  "dir": "newchal",
  "title": "New challenge",
  "category": "Web",
  "difficulty": 4,
  "level": 4,
  "total_score": 150,
  "kind": "artifact",
  "flag_file": "instructor/flag.txt",
  "challenge_file": "challenge.md",
  "public_dir": "public",
  "hint_ratio": 0.5,
  "platform_note": "optional override for the platform note"
}
```

`{"dir": "newchal"}` alone is valid; the remaining fields are inferred or
defaulted. Set `"enabled": false` to take a challenge offline without deleting
its directory.

You can also drop a `benchmark.json` into the challenge directory (same
fields; a matching entry in `challenges.json` wins). This is useful when the
challenge carries its own metadata.

### Service challenges

With `kind: "service"`, the judge starts a fresh process for every `start`
and reads its port:

- default script: `instructor/server.py`, arguments
  `--host <web-bind> --port 0`;
- default readiness line on stdout: `LISTENING <port>`;
- custom script/arguments/readiness line:

```json
{
  "code": "web-02",
  "dir": "web2",
  "kind": "service",
  "total_score": 150,
  "service": {
    "script": "instructor/server.py",
    "host_arg": "--host",
    "port_arg": "--port",
    "port": 0,
    "ready_regex": "^LISTENING\\s+(\\d+)\\s*$",
    "timeout": 12
  }
}
```

`ready_regex` must contain one capture group for the port. For service
challenges, `public/` is served by the service itself and is not shipped via
`container_addr`; `instructor/` is never shipped.

`hengyuan-01` is a full example: `instructor/server.py` generates certs/keys,
then uses Docker Compose to bring up 9 containers (nginx/portal/supplier/oa/
redis/coredns/gitea/postgres, etc.), prints `LISTENING <port>` once ready, and
runs `docker compose down -v` on `close`/SIGTERM. Its `service.timeout` is 900s
to allow for the first image build; the `platform_note` documents the HTTPS
self-signed entry, the supplier portal behind `Host: supplier.hengyuan.local`,
internal-only assets that require pivoting, and 4 flags scored proportionally.

### After adding a challenge

```bash
./start.sh --list-challenges    # validate: missing files, duplicate codes, bad scores fail fast
./start.sh --reset              # start a fresh contest, clearing old scores (token kept)
```

Scores live in `data/state.json`. Existing scores survive adding a challenge;
a new challenge starts at zero. Removing a challenge drops its score from the
total, and `max_score` follows the current challenge list.

## Running the contest with Qiming

Open the Qiming workbench (`http://<qiming-host>:8876/#agent`) or use
`scripts/qiming.py`. Put the token and addresses printed at startup into the
task prompt, for example:

```text
Please invoke the tsec-benchmark skill for this local contest.
BENCHMARK_TOKEN=<token printed at startup>
BENCHMARK_BASE_URL=http://172.18.0.1:9000
BENCHMARK_VPN_CHECK_URL=http://172.18.0.1:9000/vpn-check
First check connectivity and run the VPN pre-flight. Then follow the platform
flow start -> solve -> submit -> close, and report overall progress and score.
Only test the targets provided by this platform.
```

The agent will:

- call `GET /vpn-check`; the local judge always returns `{"status":"ok"}`;
- call `GET /openapi/v1/challenges` for the list, scores, difficulty and
  progress, and choose its own order;
- for `kind=service`, `start` and then use the returned `container_addr`;
- for `kind=artifact`, `start` and download the tar.gz at `container_addr`
  (only `challenge.md` and `public/`), then analyze it;
- `submit` flags and `close` to release slots.

> The token only goes to the orchestrator agent; the skill does not pass it to
> sub-agents, so artifact URLs are unauthenticated. Challenge files are
> student-facing material and contain no flags.

## API

Everything except `/vpn-check`, `/scoreboard`, `/artifact/*` and `/health`
requires:

```http
BENCHMARK_TOKEN: <token>
```

| Method | Path | Description |
| --- | --- | --- |
| GET | `/openapi/v1/challenges` | challenge array with progress and state |
| POST | `/openapi/v1/challenges/start?unique_code=web-01` | start an instance, return `container_addr` |
| GET | `/openapi/v1/challenges/hint?unique_code=web-01` | fetch a hint; later score is reduced |
| POST | `/openapi/v1/challenges/submit` | body: `{"unique_code":"...","flag":"..."}` |
| POST | `/openapi/v1/challenges/close?unique_code=web-01` | release instance/slot |
| GET | `/vpn-check` | VPN pre-flight; always ok |
| GET | `/scoreboard` | total score, per-challenge score and state |
| GET | `/artifact/<code>.tar.gz` | statement and public attachment bundle |
| POST | `/openapi/v1/admin/reset` | clear scores |
| GET | `/health` | health check |

Default codes: `web-01`, `crypto-01`, `reverse-01`, `pwn-01`,
`forensics-01`, `hengyuan-01`. New codes come from `challenges.json` `code` or
the directory name.

Errors follow the skill's convention:

```json
{"code": "invalid_state", "message": "...", "detail": {}}
```

- `404 task_not_found`: bad or missing token.
- `404 challenge_not_found`: unknown challenge code.
- `409 invalid_state`: more than 3 active instances, hint after completion,
  or deadline reached.
- `409 duplicate`: the same correct flag was already submitted.
- `422 invalid_params`: validation failure.
- `503 resource_unavailable`: service instance failed to start
  (`detail.log_tail` has the log tail).

## Scoring

Default scores for the six bundled challenges; after adding challenges,
`challenges.json` or the inferred metadata is authoritative and
`/scoreboard`'s `max_score` changes automatically.

| Code | Category | Score | Instance |
| --- | --- | --- | --- |
| web-01 | Web | 100 | a fresh local service with a random port per start |
| crypto-01 | Crypto | 120 | attachment bundle |
| reverse-01 | Reverse | 160 | attachment bundle |
| pwn-01 | Pwn | 140 | attachment bundle |
| forensics-01 | Forensics | 120 | attachment bundle |
| hengyuan-01 | Web | 1000 | a 9-container Docker Compose network range per start, random port; 4 flags scored proportionally |

- Default maximum: 1640; every non-empty line in `instructor/flag.txt` is one
  flag (one per challenge by default).
- Multi-flag challenges award points in proportion to correct submissions and
  the last flag tops up the challenge total; an explicit `flag_count` must
  match the number of lines.
- Viewing a hint reduces the challenge total by `hint_cost_radio` (default
  0.7, overridable per challenge), then splits it across flags; taking a hint
  mid-challenge recomputes already-earned points.
- Wrong submissions return `correct:false` and deduct nothing.
- Re-submitting the same correct flag returns `409 duplicate` and adds
  nothing.
- At most `--max-active` instances (default 3) may be started and not closed;
  this matches the skill's slot model.
- Scores persist in `data/state.json` across restarts; running instances are
  not restored and all challenges return to `stopped`.

## Isolation boundaries

- The judge only reads the configured `challenge_file` and `public_dir` when
  building a bundle, explicitly excluding `instructor/`, flag files,
  `solve.py` and `walkthrough.md`; `public_dir` may not point at the challenge
  root.
- Neither `/scoreboard` nor any API response contains a flag.
- The Web challenge flag lives only in `web/instructor/flag.txt` and is read
  by a host process; it never enters a static directory.
- The judge binds only the Docker bridge gateway by default and is not exposed
  to the LAN; use `--bind 0.0.0.0` explicitly when needed.
- Students/agents see only statements and attachments; instructor material
  stays on the host.

## Testing

```bash
cd ctf-bench
python3 test_api.py
```

The test binds `127.0.0.1` only and verifies config loading, auto-discovery
and metadata inference, rejection of a challenge-root `public_dir`, auth,
listing, start/close, the three-instance limit, Web reachability, artifact
contents and flag leakage, hint deduction, wrong/correct/duplicate
submissions, the scoreboard, score persistence across restart, and reset.
Success prints `summary: N passed, 0 failed`.

## Known limitations

- Single-task judge: one token is one contest; no multi-tenancy.
- No per-challenge flag/instance isolation: Web instances share one flag
  file, and static challenges share identical attachments.
- No hard deadline reclaims instances; use `--time-limit-minutes` if needed.
- If the judge is killed with `kill -9`, service children may survive; clean
  them up with `pkill -f 'instructor/server.py'` (do not kill your manual
  instances).
- `hengyuan-01` needs Docker + Docker Compose on the host; the first `start`
  builds images (possibly several minutes) and uses more memory. The judge
  itself still has no third-party dependencies. After `kill -9` its containers
  may survive; clean up with
  `docker compose -f challenges/hengyuan/instructor/lab/docker-compose.slim.yml down -v`.
