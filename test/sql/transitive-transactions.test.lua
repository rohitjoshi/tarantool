test_run = require('test_run').new()
test_run:cmd("setopt delimiter ';'")

-- These tests are aimed at checking transitive transactions
-- between SQL and Lua. In particular, make sure that deferred foreign keys
-- violations are passed correctly.
--

box.begin() box.sql.execute('COMMIT');
box.begin() box.sql.execute('ROLLBACK');
box.sql.execute('BEGIN;') box.commit();
box.sql.execute('BEGIN;') box.rollback();

box.sql.execute('pragma foreign_keys = 1;');
box.sql.execute('CREATE TABLE parent(id INT PRIMARY KEY, y INT UNIQUE);');
box.sql.execute('CREATE TABLE child(id INT PRIMARY KEY, x INT REFERENCES parent(y) DEFERRABLE INITIALLY DEFERRED);');

fk_violation_1 = function()
    box.begin()
    box.sql.execute('INSERT INTO child VALUES (1, 1);')
    box.sql.execute('COMMIT;')
end;
fk_violation_1();
box.space.CHILD:select();

fk_violation_2 = function()
    box.sql.execute('BEGIN;')
    box.sql.execute('INSERT INTO child VALUES (1, 1);')
    box.commit()
end;
fk_violation_2();
box.space.CHILD:select();

fk_violation_3 = function()
    box.begin()
    box.sql.execute('INSERT INTO child VALUES (1, 1);')
    box.sql.execute('INSERT INTO parent VALUES (1, 1);')
    box.commit()
end;
fk_violation_3();
box.space.CHILD:select();
box.space.PARENT:select();

-- Make sure that 'PRAGMA defer_foreign_keys' works.
--
box.sql.execute('DROP TABLE child;')
box.sql.execute('CREATE TABLE child(id INT PRIMARY KEY, x INT REFERENCES parent(y))')

fk_defer = function()
    box.begin()
    box.sql.execute('INSERT INTO child VALUES (1, 2);')
    box.sql.execute('INSERT INTO parent VALUES (2, 2);')
    box.commit()
end;
fk_defer();
box.space.CHILD:select();
box.space.PARENT:select();
box.sql.execute('PRAGMA defer_foreign_keys = 1;')
fk_defer();
box.space.CHILD:select();
box.space.PARENT:select();

-- Cleanup
box.sql.execute('DROP TABLE child;');
box.sql.execute('DROP TABLE parent;');
