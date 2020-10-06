import std.stdio;

int main(string[] args)
{
	writeln(`
This program is currently unimplemented.
Desired future features include the following:
- A library that provides CRUD primitives for an Akashic Lite database.
    I'm envisioning a D API that allows the caller to create query plans
    and then execute them. An SQL grammar can be built ontop of that later,
    if need be, but for the "small" stuff I intend to use this on, it doesn't
    really make sense to go through all that trouble (and I mean, not just
    writing a grammar/parser, because that's the easy part, but writing
    an SQL query planner, which is a PITA).
- Ability to take an Akashic Lite schema and generate its corresponding
    snapshot schema that is not-hyper-normalized and easy to read by humans.
    It should, of course, also be able to populate the snapshot schema with
    data from a point in time (or, ideally, maintain a HEAD snapshot during
    realtime operation).
- Ability to take an arbitrary SQLite database, generate an Akashic Lite
    schema for it, and then use the database's contents as an initial commit.

Dreaming:
- The Akashic Lite schema would have an even more efficient in-memory
    representation. This could lead to very efficient write-caching, if anyone
    ever cares at all. (Really, this thing is probably already shaping up to be
    way better optimized than I ever plan on needing it to be. It's not even
    *supposed* to be fast. It's supposed to make data *permanent*.)
`);
	return 0;
}
