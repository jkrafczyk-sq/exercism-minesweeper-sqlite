CREATE TABLE input (
    rownum INTEGER NOT NULL,
    cells VARCHAR NOT NULL
);

CREATE TRIGGER insert_cell 
BEFORE INSERT ON input 
BEGIN
    --If we are inserting the first row of a field, delete all existing data in 'cells' and 'input' tables:
    DELETE FROM input WHERE NEW.rownum = 1;
    DELETE FROM cells WHERE NEW.rownum = 1;

    --Parse 'cells' string for current row and insert into cells table
    --Syntax in sqlite is a bit weird for this.
    --INSERT INTO table(...) SELECT (...) is equivalent to Oracles SELECT () INTO table()
    INSERT INTO cells(rownum, colnum, is_bomb)
        WITH RECURSIVE cell AS (
            --"initial select": Insert column 1, with first character of row, and everything but the first character as 'remainder'
            SELECT 
                NEW.rownum as rownum, 
                1 AS colnum, 
                CASE 0 
                    WHEN SUBSTR(NEW.cells, 1, 1) = '*' THEN 0
                    ELSE 1
                END AS is_bomb,
                SUBSTR(NEW.cells, 2) AS remainder
            UNION ALL 
            --"recursive select": As long as the remainder is not empty, insert more cells with the first char of remainder
            SELECT NEW.rownum, 
                prev.colnum+1 , 
                CASE 0 
                    WHEN SUBSTR(prev.remainder, 1, 1) = '*' THEN 0
                    ELSE 1
                END AS is_bomb,
                SUBSTR(prev.remainder, 2) FROM cell prev WHERE prev.remainder != ''
        ) 
        SELECT rownum, colnum, is_bomb FROM cell;
END;

CREATE TABLE cells (
    rownum INTEGER NOT NULL,
    colnum INTEGER NOT NULL,
    is_bomb INTEGER NOT NULL
);

CREATE VIEW output AS WITH RECURSIVE
    row_nums AS (
        SELECT DISTINCT rownum FROM cells ORDER BY rownum
    ),
    row_strs AS (
        SELECT 
            row_nums.rownum AS rownum, 
            0 AS colnum,
            '' AS display,
            0 AS is_last
        FROM row_nums
     UNION ALL 
        SELECT 
            cells.rownum, 
            cells.colnum, 
            prev.display || CASE 
                WHEN cells.is_bomb THEN '*'
                ELSE (SELECT CASE 
                         WHEN SUM(is_bomb) > 0 THEN SUM(is_bomb)
                         ELSE ' '
                         END
                 FROM cells c2 
                 WHERE c2.rownum >= cells.rownum-1 AND c2.rownum <= cells.rownum+1
                   AND c2.colnum >= cells.colnum-1 AND c2.colnum <= cells.colnum+1)
            END,
            cells.colnum = (SELECT MAX(colnum) FROM cells WHERE rownum = prev.rownum)
        FROM row_strs prev INNER JOIN cells
        ON cells.colnum = prev.colnum + 1 AND cells.rownum = prev.rownum
    ) 
SELECT 
    *
FROM
    row_strs
WHERE  
    is_last = 1
ORDER BY 
    rownum ASC;