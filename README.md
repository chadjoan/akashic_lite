Akashic Lite
====

Akashic Lite is a database in which all operations are reversible and
previous states can be easily visited (time-travel into history).

This is done by storing all data as a sequence of changes leading to a final
state. This sequence can be "rewound" to visit previous states at any point
in time. (Though unlike with tape rewinding, we can use indexed database rows
to jump directly to the most recent entries at the target date-time, thus
skipping the intervening history.)

Even deletion is reversable. Deletion is just an event on a timeline.
Whenever we "delete" a row from the database, it will internally create a new
record that says the preceding records cannot be gazed upon by mortal eyes.
But they'll still *be there*. And as long as you have `root`, you can take
a peek whenever you want.

If we allow our changesets (commits) to record which changesets (commits)
preceded them (instead of just assuming it's the one with the latest preceding
timestamp), then we can perform branching operations and have a system somewhat
like `git`, but for database schemas *and data*.

The downside, of course, is that if we never erase data, then the amount of
memory occupied by the database will always increase. This is undesirable
for any system that deals with many very temporary data updates, and you won't
be seeing this thing used at large scales any time soon. But that's not what
it's for. This system is for storing data such as community-edited text
content, or for computer games with minimal state (e.g. simplistic or no
"physics" involved in gameplay).

For community content management, this provides a nuclear "undo vandalism"
option. For gaming, this would trivialize save/load mechanisms, but more
importantly it could provide admins with god-like forensics capabilities
to use against cheaters/hackers (e.g. you could see the game exactly as
it appeared from any player's perspective during time intervals when
questionable events were taking place).

Current Status
==

This project is currently an SQLite schema. It's syntactically valid, executes
without error when passed to sqlite3, and generates what's expected.
At least for my (more simplistic) use-cases, the Akashic Lite database would
just be a different way to store data in an SQLite3 database (it's all in the
name), albeit with a lot of code to help organize that process.
It's not complete at all though, and the majority of the work is going to
involve writing code that performs various operations on the Akashic Lite database.

Desired future features include the following:

* A library that provides CRUD primitives for an Akashic Lite database.
    I'm envisioning a D API that allows the caller to create query plans
    and then execute them. An SQL grammar can be built ontop of that later,
    if need be, but for the "small" stuff I intend to use this on, it doesn't
    really make sense to go through all that trouble (and I mean, not just
    writing a grammar/parser, because that's the easy part, but writing
    an SQL query planner, which is a PITA).

* Ability to take an Akashic Lite schema and generate its corresponding
    snapshot schema that is not-hyper-normalized and easy to read by humans.
    It should, of course, also be able to populate the snapshot schema with
    data from a point in time (or, ideally, maintain a HEAD snapshot during
    realtime operation).

* Ability to take an arbitrary SQLite database, generate an Akashic Lite
    schema for it, and then use the database's contents as an initial commit.


And with that all written down, I'm going to get back to programming other
things. Because as I write this on 2020-10-06, I should really be doing writing
those other things. And I probably don't *really* need this right now.
But the code was blasting into my head, and it's important to write these
things down, otherwise the knowledge will pass into a region of time which
cannot be gazed upon by mortal eyes ;)

-- Chad
