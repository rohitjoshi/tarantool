env = require('test_run')
test_run = env.new()
engine = test_run:get_cfg('engine')

box.schema.user.grant('guest', 'read,write,execute', 'universe')

s = box.schema.space.create('test', {engine = engine});
index = s:create_index('primary', {type = 'tree'})

errinj = box.error.injection
fio = require('fio')

box.schema.user.grant('guest', 'replication')
test_run:cmd("create server replica with rpl_master=default, script='replication/replica.lua'")
test_run:cmd("start server replica")

test_run:cmd("switch replica")
repl = box.cfg.replication
box.cfg{replication = ""}
test_run:cmd("switch default")

for i = 1, 5 do s:insert{i} box.snapshot() end
s:select()
fio.glob(fio.pathjoin(fio.abspath("."), 'master/*.xlog'))
errinj.set("ERRINJ_NO_DISK_SPACE", true)
function insert(a) s:insert(a) end
_, err = pcall(insert, {6})
err:match("ailed to write")
fio.glob(fio.pathjoin(fio.abspath("."), 'master/*.xlog'))

-- cleanup
test_run:cmd("switch replica")
test_run:cmd("restart server default with cleanup=1")
test_run:cmd("switch default")
test_run:cmd("stop server replica")
test_run:cmd("cleanup server replica")
