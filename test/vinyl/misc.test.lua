fiber = require('fiber')

--
-- gh-2784: do not validate space formatted but not indexed fields
-- in surrogate statements.
--

-- At first, test simple surrogate delete generated from a key.
format = {{name = 'a', type = 'unsigned'}, {name = 'b', type = 'unsigned'}}
s = box.schema.space.create('test', {engine = 'vinyl', format = format})
_ = s:create_index('pk')
s:insert{1, 1}
-- Type of a second field in a surrogate tuple must be NULL but
-- with UNSIGNED type, specified in a tuple_format. It is
-- possible, because only indexed fields are used in surrogate
-- tuples.
s:delete(1)
s:drop()

-- Test select after snapshot. This select gets surrogate
-- tuples from a disk. Here NULL also can be stored in formatted,
-- but not indexed field.
format = {}
format[1] = {name = 'a', type = 'unsigned'}
format[2] = {name = 'b', type = 'unsigned'}
format[3] = {name = 'c', type = 'unsigned'}
s = box.schema.space.create('test', {engine = 'vinyl', format = format})
_ = s:create_index('pk')
_ = s:create_index('sk', {parts = {2, 'unsigned'}})
s:insert{1, 1, 1}
box.snapshot()
s:delete(1)
box.snapshot()
s:select()
s:drop()

--
-- gh-2983: ensure the transaction associated with a fiber
-- is automatically rolled back if the fiber stops.
--
s = box.schema.create_space('test', { engine = 'vinyl' })
_ = s:create_index('pk')
tx1 = box.stat.vinyl().tx
ch = fiber.channel(1)
_ = fiber.create(function() box.begin() s:insert{1} ch:put(true) end)
ch:get()
tx2 = box.stat.vinyl().tx
tx2.commit - tx1.commit -- 0
tx2.rollback - tx1.rollback -- 1
s:drop()

--
-- gh-3158: check of duplicates is skipped if the index
-- is contained by another unique index which is checked.
--
s = box.schema.create_space('test', {engine = 'vinyl'})
i1 = s:create_index('i1', {unique = true, parts = {1, 'unsigned', 2, 'unsigned'}})
i2 = s:create_index('i2', {unique = true, parts = {2, 'unsigned', 1, 'unsigned'}})
i3 = s:create_index('i3', {unique = true, parts = {3, 'unsigned', 4, 'unsigned', 5, 'unsigned'}})
i4 = s:create_index('i4', {unique = true, parts = {5, 'unsigned', 4, 'unsigned'}})
i5 = s:create_index('i5', {unique = true, parts = {4, 'unsigned', 5, 'unsigned', 1, 'unsigned'}})
i6 = s:create_index('i6', {unique = true, parts = {4, 'unsigned', 6, 'unsigned', 5, 'unsigned'}})
i7 = s:create_index('i7', {unique = true, parts = {6, 'unsigned'}})

s:insert{1, 1, 1, 1, 1, 1}

i1:info().lookup -- 1
i2:info().lookup -- 0
i3:info().lookup -- 0
i4:info().lookup -- 1
i5:info().lookup -- 0
i6:info().lookup -- 0
i7:info().lookup -- 1

s:drop()
