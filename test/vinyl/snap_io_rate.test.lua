fiber = require('fiber')
digest = require('digest')
test_run = require('test_run').new()

MB = 1024 * 1024
TUPLE_SIZE = 1024
TUPLE_COUNT = 100

snap_io_rate_limit = box.cfg.snap_io_rate_limit
box.cfg{snap_io_rate_limit = 0.1}

s = box.schema.space.create('test', {engine = 'vinyl'})
_ = s:create_index('primary', {page_size = TUPLE_SIZE, run_count_per_level = 1, run_size_ratio = 10})

function fill() for i = 1, TUPLE_COUNT do s:replace{i, digest.urandom(TUPLE_SIZE)} end end

-- check that snap_io_rate_limit is applied to dump
fill()
t1 = fiber.time()
box.snapshot()
t2 = fiber.time()

rate = TUPLE_SIZE * TUPLE_COUNT / (t2 - t1) / MB
rate < box.cfg.snap_io_rate_limit or rate

-- check that snap_io_rate_limit is applied to compaction
fill()
t1 = fiber.time()
box.snapshot()
while s.index.primary:info().disk.compact.count == 0 do fiber.sleep(0.001) end
t2 = fiber.time()

-- dump + compaction => multiply by 2
rate = 2 * TUPLE_SIZE * TUPLE_COUNT / (t2 - t1) / MB
rate < box.cfg.snap_io_rate_limit or rate

s:drop()
box.cfg{snap_io_rate_limit = snap_io_rate_limit}
