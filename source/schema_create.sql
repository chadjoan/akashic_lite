/*
Akashic Lite; a database that stores the entire history (including schema
details) of another database. It is hyper-normalized and capable of winding
a "view" of the database forwards and backwards in time. Akashic Lite never
loses data. This is good-bad, because modern computers have finite storage,
so you probably don't want to use this for something that changes data
very frequently without necessarily creating new entries. On the other hand
it means you never learn data. Well, technically you can MAKE the Akashic
records forget something, but make sure you have sufficient Justification.

The Akashic records are owned by no one. But if someone changes something,
that change is recorded.
*/

CREATE TABLE akc0_sql_types
(
	id    INTEGER  PRIMARY KEY,
	name  TEXT
);

INSERT INTO akc0_sql_types
	(id, name)
	VALUES
	(0, 'NULL'),
	(1, 'INTEGER'),
	(2, 'REAL'),
	(3, 'TEXT'),
	(4, 'BLOB');

CREATE TABLE akc2_users
(
	id  INTEGER

	-- TODO: How to associate these with other systems, like cloud-based
	-- identity providers? (Or someday, maybe in-house user databases, but
	-- really not now? Or if someone wanted it, LDAP?)
);


CREATE TABLE akc0_entity_types
(
	-- A number representing some component of an SQL schema, like a table,
	-- field, key, etc.
	id    INTEGER  PRIMARY KEY,

	-- Ex: 'table', 'field', 'key', etc.
	name  TEXT  NOT NULL
);

INSERT INTO akc0_entity_types
	(id, name)
	VALUES
	(0x01, 'schema'),
	(0x02, 'table'),
	(0x03, 'key'),
	(0x04, 'constraint'),
	(0x05, 'field');

CREATE TABLE akc0_key_types
(
	id    INTEGER  PRIMARY KEY,
	name  TEXT  NOT NULL
);

INSERT INTO akc0_key_types
	(id, name)
	VALUES
	(0x0100, 'primary'),
	(0x0200, 'foreign'),
	(0x0300, 'unique');

-- This is the table that principally defines an entity.
--
-- Entities are timeless things that, once envisioned, are always present
-- in the akashic record, even when they no longer "exist" at a point in time.
--
-- There are some attributes of an entity that will never, and should never,
-- change. Those fields go here. There really shouldn't be very many of those,
-- because this has implications.
--
-- For example, the `container_id` field being present in this table implies
-- that a field's container is intrinsic to its identity. This field simply
-- cannot exist in another container (though we can make copies). Ultimately,
-- anything can change, but what we're saying with the `container_id` field
-- is that if you were to, for instance, move a field from one table to
-- another, then it must necessarily involve deleting that field from the
-- first table and then create a new field that duplicates that previous
-- field's attributes (and perhaps other things as well).
--
-- Anything about an entity that can change over time should have its own
-- table. Examples include `akc_entity_existence`, `akc_entity_
CREATE TABLE akc2_entities
(
	-- The entity's ID.
	--
	-- This number is used as the upper 24 bits of the 64-bit value commonly
	-- used to look up various data in Akashic Lite.
	--
	-- Do not use the lower 40 bits of this integer. In other words, when
	-- generating a commit ID, create a positive 64-bit integer that does not
	-- exceed (2^24-1), then reverse this integer's bits.
	--
	-- This little bit of tedium allows this field to be simply ORed with
	-- other IDs (ex: `akc_commits.id40lo`) to create an ID that can be
	-- used to look up records in other tables. The 64-bit composite is used
	-- instead of composite primary keys so that the large number of tables
	-- using (`commit_id+entity_id`) primary keys can still treat their
	-- primary key as an alias to ROWID (an INTEGER PRIMARY KEY in SQLite
	-- is treated as an alias to the implicit, and fast, ROWID index that
	-- tables have by default, but only if the primary key only contains
	-- one INTEGER field).
	--
	-- Note that, during ID generation, the strategy of reversing the bits of
	-- this hi-id will be superior to simply shifting left by 40 bits.
	-- It creates a situation where if our bit allocations are off (we
	-- needed more than 24 bits and less than 40, or less than 24 and more
	-- than 40), then the overflow won't necessarily cause problems as long
	-- as the number of commits is low enough to leave empty bits in its
	-- portion of the 64-bit integer. At that point, the bit-counting
	-- (24 vs 40) doesn't matter for database integrity, just that the number
	-- of possible commit+entity combinations does not exceed 2^64.
	-- The 24hi and 40lo nomenclature is still used because these allocations
	-- might be helpful when attempting to extract the individual IDs from
	-- a composite ID (ideally we never do this, but you never know).
	--
	-- As a consequence of all of the above, Akashic Lite should be able to
	-- to store *at least* 16 million different definitions for tables,
	-- fields, keys, and so on, throughout the life of the database. If the
	-- number of commits is less than about 500 billion, then it should
	-- be possible to store even more entities (memory permitting!).
	--
	id24hi        INTEGER  PRIMARY KEY,

	-- Number that determines what entity this relates to, ex: table, field, key, etc.'),
	entity_type   INTEGER  NOT NULL,

	-- The ID of the entity that contains this entity, if applicable.
	--
	-- When not applicable, this shall be set equal to the same row's
	-- value for `id24hi`.
	--
	-- This only applies for permanent/intrinsic relationships, which,
	-- as of this writing (2020-10-06), is pretty much just table->field and
	-- table->key relationships.
	--
	-- For things like key->field and schema->table relationships, where
	-- it logically makes sense for it to be possible to break and create
	-- such relationships (as it wouldn't fundamentally change the entity's
	-- identity), it is more appropriate to store those in a separate table
	-- that has timestamps and commit (changeset) membership.
	--
	container_id  INTEGER  NOT NULL,

	-- --------------
	-- Keys and such:
	--
	FOREIGN KEY (entity_type)
		REFERENCES akc_entity_types (id)
			ON DELETE RESTRICT
			ON UPDATE RESTRICT,

	FOREIGN KEY (container_id)
		REFERENCES akc_entities (id24hi)
			ON DELETE RESTRICT
			ON UPDATE RESTRICT
);

-- This table records whether entities exist or not at a given time.
--
-- Every entity must associate with at least one record from this table.
CREATE TABLE akc4_entity_existence
(
	-- The entity id ORed with the commit id.
	--
	-- To calculate this id, use this expression:
	-- `id64 = (akc_entities.id24hi | akc_commits.id40lo)`
	--
	id64          INTEGER  PRIMARY KEY,

	-- This field determines whether the entity was created or deleted at
	-- the time of the related commit. 1 == created, 0 == deleted.
	existence     INTEGER  NOT NULL
);

-- This table records an entity's name.
--
-- Every entity must associate with at least one record from this table.
CREATE TABLE akc4_entity_names
(
	-- The entity id ORed with the commit id.
	--
	-- To calculate this id, use this expression:
	-- `id64 = (akc_entities.id24hi | akc_commits.id40lo)`
	--
	id64          INTEGER  PRIMARY KEY,

	-- The entity's name at the time of the related commit.
	name          TEXT     NOT NULL
);

-- This table records an entity's description or comment.
--
-- Entity descriptions are optional. Other computer systems shall treat an
-- absent entity description as implying that the entity's description is
-- the empty string.
CREATE TABLE akc4_entity_descriptions
(
	-- The entity id ORed with the commit id.
	--
	-- To calculate this id, use this expression:
	-- `id64 = (akc_entities.id24hi | akc_commits.id40lo)`
	--
	id64          INTEGER  PRIMARY KEY,

	-- The entity's description at the given `time_id`.
	-- This can be used as a comment to describe the entity's function.
	-- If Akashic Lite is importing another database's schema (with or without
	-- data), then this should be populated with any comments present on
	-- the statements that created the entity.
	description   TEXT  NOT NULL
);

CREATE TABLE akc4_field_types
(
	-- The field's entity id ORed with the commit id.
	-- (While entities may or may not be fields, fields are certainly entities.)
	--
	-- To calculate this id, use this expression:
	-- `id64 = (akc_entities.id24hi | akc_commits.id40lo)`
	--
	id64          INTEGER  PRIMARY KEY,

	-- The field's SQLite type.
	-- This references the `akc_sql_types.id` field.
	sql_type_id   INTEGER  NOT NULL,

	-- --------------
	-- Keys and such:
	--
	FOREIGN KEY (sql_type_id)
		REFERENCES akc_sql_types (id)
			ON UPDATE RESTRICT
			ON DELETE RESTRICT
);

CREATE TABLE akc2_keys
(
	-- The key's entity ID. This is one-to-one with `akc_entities.id24hi`
	-- for all entities (and only entities) that are keys.
	--
	id24hi        INTEGER PRIMARY KEY,

	-- The key's type (ex: primary, foreign, unique).
	--
	-- References the `akc_key_types.id` field.
	--
	key_type_id   INTEGER NOT NULL,

	-- --------------
	-- Keys and such:
	--
	FOREIGN KEY (key_type_id)
		REFERENCES akc_key_types (id)
			ON UPDATE RESTRICT
			ON DELETE RESTRICT
);

CREATE TABLE akc4_key_member_fields
(
	-- The key's entity id ORed with the commit id.
	-- (While entities may or may not be keys, keys are certainly entities.)
	--
	-- To calculate this id, use this expression:
	-- `id64 = (akc_entities.id24hi | akc_commits.id40lo)`
	--
	id64          INTEGER  PRIMARY KEY,

	-- The member field's entity ID.
	-- (While entities may or may not be fields, fields are certainly entities.)
	--
	field_id24hi  INTEGER  NOT NULL,

	-- --------------
	-- Keys and such:
	--
	FOREIGN KEY (field_id24hi)
		REFERENCES akc_entities (id24hi)
			ON UPDATE RESTRICT
			ON DELETE RESTRICT
);

-- Table used to represent the list of fields referenced by a foreign key.
CREATE TABLE akc4_fkey_ref_fields
(
	-- The key's entity id ORed with the commit id.
	-- (While entities may or may not be keys, keys are certainly entities.)
	--
	-- To calculate this id, use this expression:
	-- `id64 = (akc_entities.id24hi | akc_commits.id40lo)`
	--
	-- For a key to have rows in this table, the `akc_keys` entry with the
	-- corresponding `id24hi` value must have a `key_type_id` that encodes
	-- the 'foreign' (foreign key) type.
	--
	-- It is also noteworthy that we don't have a table for foreign key
	-- table references. There is no need: this field reference table
	-- can be used to look up that information by using the
	-- `akc_entities.container_id` field belonging to one of the referenced
	-- fields. Relatedly, this schema cannot be represented in SQLite if
	-- any of the fields in this list belongs to a different table than the
	-- others, so don't do that ;)
	--
	id64          INTEGER  PRIMARY KEY,

	-- The referenced field's entity ID.
	-- (While entities may or may not be fields, fields are certainly entities.)
	--
	field_id24hi  INTEGER  NOT NULL,

	-- --------------
	-- Keys and such:
	--
	FOREIGN KEY (field_id24hi)
		REFERENCES akc_entities (id24hi)
			ON UPDATE RESTRICT
			ON DELETE RESTRICT
);

CREATE TABLE akc2_commits
(
	-- An arbitrary number representing this commit.
	--
	-- This number is used as the lower 40 bits of the 64-bit value commonly
	-- used to look up various data in Akashic Lite.
	--
	-- Avoid inserting any IDs that exceed (2^40-1). Ideally, start at 0 and
	-- count up from there. 
	--
	-- This slightly odd constraint allows this field to be simply ORed with
	-- other IDs (ex: `akc_entities.id24hi`) to create an ID that can be
	-- used to look up records in other tables. The 64-bit composite is used
	-- instead of composite primary keys so that the large number of tables
	-- using (`commit_id+entity_id`) primary keys can still treat their
	-- primary key as an alias to ROWID (an INTEGER PRIMARY KEY in SQLite
	-- is treated as an alias to the implicit, and fast, ROWID index that
	-- tables have by default, but only if the primary key only contains
	-- one INTEGER field).
	--
	-- If this number is generated incrementally and the id24hi numbers are
	-- generated incrementally and then bit-reversed in a 64-bit integer,
	-- then it is possible to exceed 2^40 commits if there are far fewer than
	-- 2^24 entities, or to exceed 2^24 entities if there are far fewer than
	-- 2^40 commits. This notion is covered in greater detail in the
	-- documentation of `akc2_entities.id24hi`.
	--
	id40lo        INTEGER  PRIMARY KEY,

	-- The time when this commit was made, as the number of hecto-nanoseconds
	-- (hnsecs) since midnight, January 1st, 1 A.D.
	commit_time   INTEGER  UNIQUE  NOT NULL,

	-- The ID of the commit that defined the database's state prior to this
	-- commit. This field is what allows forking to happen.
	--
	-- Normally set to equal to the `id40lo` value from another row in this
	-- table.
	--
	-- If this commit has no parent, it should be set equal to the same row's
	-- value for `id40lo`.
	--
	parent_id     INTEGER  NOT NULL,

	-- The ID of the user that made this modification.
	user_id       INTEGER  NOT NULL,

	-- --------------
	-- Keys and such:
	--
	FOREIGN KEY (parent_id)
		REFERENCES akc_commits (id40lo)
			ON UPDATE RESTRICT
			ON DELETE RESTRICT,

	FOREIGN KEY (user_id)
		REFERENCES akc_users (id)
			ON UPDATE RESTRICT
			ON DELETE RESTRICT
);

/*
-- Below, we have older notes from before I realized a better way to do it all.


-- This table is an extension of the `akc_entities` table, but with metadata
-- specifically related to field-type entities (fields! columns.).
--
-- Like with the `akc_entities` table, any columns in this table indicate
-- permanent, immutable, intrinsic attributes of fields.
CREATE TABLE akc_fields AS
(
	-- The entity ID.
	id  INTEGER,

);

-- This table stores metadata about metadata about metadata about entities.
--
-- So yeah, if the `akc_schema_entity_xx_metafields` tables weren't *meta*
-- enough for you, we have this one.
--
-- This table describes what kinds of metafields an entity can have.
--
-- What's a metafield? Check out the documentation for a table like
-- `akc_entity_int_metafields` to learn that, then come back here.
-- This table is an implementation detail that supports those higher-level
-- concepts.
--
CREATE TABLE akc_entity_metafield_types
(
	id           INTEGER,
	sql_type_id  INTEGER,
	name         TEXT,
	comment      TEXT
);

INSERT INTO akc_entity_metafield_types
	VALUES(1, 1, 'entity_type', 'Number that determines what entity this relates to, ex: table, field, key, etc.'),
	VALUES(2, 3, 'entity_name', 'The name of the entity (ex: a table name, field name, etc).'),
	VALUES(3, 1, 'container',   'The ID of the entity that contains this entity, if applicable.');

-- This is one of the tables that stores metadata about metadata about entities.
--
-- Okay okay, let's unpack that:
-- Whenever we have an entity (a table, a field, a key, whatever), there will
-- be things we need to track about that entity: what type of entity it is,
-- what its name is, what entity contains it (if applicable), and so on.
-- In other words, a "table" has fields (your data: things like account
-- balances in a financial system, or number of lives in a game) and it has
-- *metafields* (metadata: things like "this entity is a table",
-- the table's name, and a reference to the table's schema).
--
-- This table stores the definitions of those metafields. The "definition"
-- information is information that is intrinsic to those metafields and never
-- changes.
-- 
CREATE TABLE akc_entity_metafield_defs
(
	-- The entity ID.
	entity_id  INTEGER,

	-- The metafield's ID.
	--
	-- This can be used to look up values in tables such as
	-- `akc_entity_int_metafields` and `akc_entity_text_metafields` by
	-- pulling their `id` field. This is a foreign key to those tables'
	-- `id` fields.
	metafield_id  INTEGER,

	-- This is a foreign key related to the `id` field of the
	-- `akc_entity_metafield_types` table.
	--
	-- The value here selects what metafield we are reading or manipulating.
	metafield_type_id  INTEGER
);

-- This is one of the tables that stores metadata about metadata about entities.
--
-- Okay okay, let's unpack that:
-- Whenever we have an entity (a table, a field, a key, whatever), there will
-- be things we need to track about that entity: what type of entity it is,
-- what its name is, what entity contains it (if applicable), and so on.
-- In other words, a "table" has fields (your data: things like account
-- balances in a financial system, or number of lives in a game) and it has
-- *metafields* (metadata: things like "this entity is a table",
-- the table's name, and a reference to the table's schema).
--
-- This table stores those metafields, as long as they are INTEGER-typed.
-- 
CREATE TABLE akc_entity_int_metafields
(
	-- The metafield ID.
	--
	-- Note that this field is not unique on its own, at least within this
	-- table (it IS unique to the entity). That's because every entity can
	-- have multiple revisions. Only the (`id+time_id`) combination is
	-- guaranteed to be unique within this table.
	--
	metafield_id  INTEGER,

	-- The time when this modification was made to this entity, as long as
	-- the modification is a creation or assignment. (Deletion is handled
	-- by the `akc_entity_deletions` table.)
	--
	-- This is a foreign key to the cct_commits table. This timestamp also identifies which changeset this modification
	-- is a member of. Regardless of whether anything else changed,
	-- the value can be followed into the `cct_commits` table to retrieve
	-- user information.
	--
	-- All timestamps in this schema are represented as the number of
	-- hecto-nanoseconds (hnsecs) since midnight, January 1st, 1 A.D.
	--
	time_id  INTEGER,

	-- The value this metafield has at the time given by `time_id`.
	value  INTEGER
);

CREATE TABLE akc_entity_text_metafields
(
	-- The metafield ID.
	--
	-- Note that this field is not unique on its own, at least within this
	-- table (it IS unique to the entity). That's because every entity can
	-- have multiple revisions. Only the (`id+time_id`) combination is
	-- guaranteed to be unique within this table.
	--
	metafield_id  INTEGER,

	-- The time when this modification was made to this entity, as long as
	-- the modification is a creation or assignment. (Deletion is handled
	-- by the `akc_entity_deletions` table.)
	--
	-- This is a foreign key to the cct_commits table. This timestamp also identifies which changeset this modification
	-- is a member of. Regardless of whether anything else changed,
	-- the value can be followed into the `cct_commits` table to retrieve
	-- user information.
	--
	-- All timestamps in this schema are represented as the number of
	-- hecto-nanoseconds (hnsecs) since midnight, January 1st, 1 A.D.
	--
	time_id  INTEGER,

	-- The value this metafield has at the time given by `time_id`.
	value  TEXT
);

CREATE TABLE akc_entity_deletions
(
	-- The entity ID.
	--
	-- Note that this field is not unique on its own, at least within this
	-- table (it IS unique to the entity). That's because every entity can
	-- have multiple revisions. Only the (`id+time_id`) combination is
	-- guaranteed to be unique within this table.
	--
	id  INTEGER,

	-- The time when this entity was deleted. (Creation and updates are handled
	-- in the `akc_entity_xx_metafields` tables.)
	--
	-- This is a foreign key to the cct_commits table. This timestamp also identifies which changeset this modification
	-- is a member of. Regardless of whether anything else changed,
	-- the value can be followed into the `cct_commits` table to retrieve
	-- user information.
	--
	-- All timestamps in this schema are represented as the number of
	-- hecto-nanoseconds (hnsecs) since midnight, January 1st, 1 A.D.
	--
	time_id  INTEGER
);
*/

