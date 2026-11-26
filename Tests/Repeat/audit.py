"""Read the old schema independently of the app. Only use this on the disposable fixture."""
import argparse
import collections
import datetime
import json
import pathlib
import sqlite3
import struct


def snapshot(path):
    db = sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True)
    try:
        db.execute("BEGIN")
        def raw(value):
            if isinstance(value, bytes):
                return value.hex()
            if isinstance(value, float):
                return struct.pack(">d", value).hex()
            return value
        def rows(sql):
            return [[raw(v) for v in row] for row in db.execute(sql)]
        return {
            "workouts": rows("SELECT Z_PK,ZID,ZSTARTDATE,ZDAYKEY,ZTITLE,ZTOTALMETERS,ZNOTES FROM ZERGWORKOUT ORDER BY Z_PK"),
            "pieces": rows("SELECT Z_PK,ZID,ZORDERINDEX,ZREPS,ZMETERSPERREP,ZRESTSECONDS,ZAVGSPLITSECPER500,Z2PIECES FROM ZERGPIECE ORDER BY Z_PK"),
            "transactions": rows("SELECT * FROM ATRANSACTION ORDER BY Z_PK"),
            "changes": rows("SELECT * FROM ACHANGE ORDER BY Z_PK"),
        }
    finally:
        db.close()


def check_inserts(before, after, timed_only=False):
    new = {}
    for table in ("workouts", "pieces"):
        old = {r[0] for r in before[table]}
        assert [r for r in after[table] if r[0] in old] == before[table], f"STOP: historical {table} changed"
        new[table] = [r for r in after[table] if r[0] not in old]
    for table in ("transactions", "changes"):
        assert after[table][:len(before[table])] == before[table], f"STOP: historical {table} changed"
    old_ids = {r[1] for table in ("workouts", "pieces") for r in before[table]}
    ids = [r[1] for table in ("workouts", "pieces") for r in new[table]]
    assert len(ids) == len(set(ids)) and old_ids.isdisjoint(ids)
    expected = collections.Counter([
        (4000, "", ((0, 4, 1000, 150, None),)),
        (4000, "", ((0, 4, 1000, 150, None),)),
        (6000, "New steady note", ((0, 1, 6000, None, None),)),
        (2500, "", ((0, 10, 250, 45, struct.pack(">d", 100.2).hex()),)),
        (3250, "", ((0, 1, 1000, None, None), (1, 2, 750, 0, None), (2, 3, 250, 45, None))),
        (6347, "", ()),
        (2601, "", ((0, 1, 2000, None, None),)),
    ])
    if timed_only:
        expected = collections.Counter({(4000, "", ((0, 4, 1000, 150, None),)): 2})
    actual = collections.Counter()
    owners = {w[0] for w in new["workouts"]}
    assert all(p[-1] in owners for p in new["pieces"])
    changes = after["changes"][len(before["changes"]):]
    transactions = after["transactions"][len(before["transactions"]):]
    assert len(transactions) == len(new["workouts"]) and all(c[3] == 0 for c in changes)
    for pk, _, start, day, title, total, notes in new["workouts"]:
        assert start == day and title == ""
        # SQLite can return an integer for a midnight timestamp with no fraction.
        seconds = start if isinstance(start, int) else struct.unpack(">d", bytes.fromhex(start))[0]
        instant = seconds + 978307200
        local = datetime.datetime.fromtimestamp(instant)
        assert local.date() == datetime.date.today() and local.time() == datetime.time()
        pieces = [p for p in new["pieces"] if p[-1] == pk]
        actual[total, notes, tuple(sorted(tuple(p[2:7]) for p in pieces))] += 1
        (entry,) = [c for c in changes if (c[4], c[5]) == (2, pk)]
        batch = [c for c in changes if c[6] == entry[6]]
        assert len(batch) == 1 + len(pieces)
        assert {(c[4], c[5]) for c in batch} == {(2, pk)} | {(1, p[0]) for p in pieces}
    assert actual == expected, actual
    assert len(changes) == len(new["workouts"]) + len(new["pieces"])
    return f"{len(new['workouts'])} new workouts, {len(new['pieces'])} new pieces, {len(transactions)} insert-only transactions"


def check_delete(before, after):
    (workout,) = [w for w in before["workouts"] if w[4] == "" and w[5] == 3250]
    pk = workout[0]
    owned = [p for p in before["pieces"] if p[-1] == pk]
    assert len(owned) == 3
    assert after["workouts"] == [w for w in before["workouts"] if w[0] != pk]
    assert after["pieces"] == [p for p in before["pieces"] if p[-1] != pk]
    assert after["transactions"][:-1] == before["transactions"]
    old = before["changes"]
    assert after["changes"][:len(old)] == old
    diff = after["changes"][len(old):]
    assert len(diff) == 4 and all(c[3] == 2 and c[6] == after["transactions"][-1][0] for c in diff)
    assert {(c[4], c[5]) for c in diff} == {(2, pk)} | {(1, p[0]) for p in owned}
    return "only the repeated mixed workout and its three pieces deleted"


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("mode", choices=("record", "unchanged", "timed", "saved", "deleted"))
    p.add_argument("store", type=pathlib.Path)
    p.add_argument("reference", type=pathlib.Path)
    args = p.parse_args()
    current = snapshot(args.store)
    if args.mode == "record":
        with args.reference.open("x") as f:
            json.dump(current, f, ensure_ascii=False)
        print("Recorded", *(len(current[k]) for k in ("workouts", "pieces", "transactions", "changes")))
    else:
        before = json.loads(args.reference.read_text())
        if args.mode == "unchanged":
            assert current == before, "STOP: database changed unexpectedly"
            print("PASS unchanged")
        elif args.mode == "deleted":
            print("PASS", check_delete(before, current))
        else:
            print("PASS", check_inserts(before, current, timed_only=args.mode == "timed"))
