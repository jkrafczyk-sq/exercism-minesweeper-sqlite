CREATE VIEW input (line) AS SELECT ('');

CREATE TABLE board_info(
    rows INTEGER NOT NULL,
    columns INTEGER NOT NULL,
    error VARCHAR DEFAULT NULL
);

CREATE TABLE cells (
    rownum INTEGER NOT NULL,
    colnum INTEGER NOT NULL,
    is_bomb INTEGER NOT NULL
);

CREATE TRIGGER insert_cell 
INSTEAD OF INSERT ON input 
BEGIN
    --If input is "RESET", clear the entire field (board_info and cells) and don't process this line as input:
    DELETE FROM cells WHERE NEW.line = 'RESET';
    DELETE FROM board_info WHERE NEW.line = 'RESET';
    SELECT RAISE(IGNORE) WHERE NEW.line = 'RESET';

    INSERT INTO board_info (rows, columns)
    SELECT
        0,
         LENGTH(NEW.line)
    WHERE NOT EXISTS(SELECT * FROM board_info);

    UPDATE board_info SET rows = rows + 1;

    UPDATE 
        board_info 
    SET error = 'New row has ' || LENGTH(NEW.line) || ' columns, but expected ' || columns 
    WHERE LENGTH(NEW.line) != columns;

    SELECT RAISE(FAIL, 
        'New row has incorrect number of columns'
    ) WHERE LENGTH(NEW.line) != (SELECT columns FROM board_info);

    --Parse 'cells' string for current row and insert into cells table
    --Syntax in sqlite is a bit weird for this.
    --INSERT INTO table(...) SELECT (...) is equivalent to Oracles SELECT () INTO table()
    INSERT INTO cells(rownum, colnum, is_bomb)
        WITH RECURSIVE cell AS (
            --"initial select": Insert column 1, with first character of the new row, and everything but the first character as 'remainder'
            SELECT 
                (SELECT rows FROM board_info) as rownum, 
                1 AS colnum, 
                CASE 0 
                    WHEN SUBSTR(NEW.line, 1, 1) = '*' THEN 0
                    ELSE 1
                END AS is_bomb,
                SUBSTR(NEW.line, 2) AS remainder
            UNION ALL 
            --"recursive select": As long as the remainder is not empty, insert more cells with the first char of remainder
            SELECT 
                (SELECT rows FROM board_info), 
                prev.colnum+1 , 
                CASE 0 
                    WHEN SUBSTR(prev.remainder, 1, 1) = '*' THEN 0
                    ELSE 1
                END AS is_bomb,
                SUBSTR(prev.remainder, 2) FROM cell prev WHERE prev.remainder != ''
        ) 
        SELECT rownum, colnum, is_bomb FROM cell;
END;

CREATE VIEW output AS WITH RECURSIVE
    row_nums AS (
        SELECT DISTINCT rownum FROM cells ORDER BY rownum
    ),
    row_strs AS (
        -- initial select: column '0', empty string
        SELECT 
            row_nums.rownum AS rownum, 
            0 AS colnum,
            '' AS display,
            0 AS is_last
        FROM row_nums
     UNION ALL 
        -- recursive select: stringify the next column and append that to the current columns 'display'
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