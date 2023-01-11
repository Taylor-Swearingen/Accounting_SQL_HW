/* seeing date needed by year*/
/*
SELECT je.journal_entry_id, je.journal_type_id, jt.journal_type, jeli.description, jeli.debit, jeli.credit, date_format(je.entry_date, '%Y-%m') as date_Y_M, je.entry_date, je.last_modified
FROM accounting.journal_entry je
LEFT JOIN accounting.journal_entry_line_item jeli
ON je.journal_entry_id = jeli.journal_entry_id
LEFT JOIN accounting.journal_type jt
ON je.journal_type_id = jt.journal_type_id
WHERE je.entry_date BETWEEN '2020-01-01' AND '2020-12-31';
*/

/* trying to select data by year*/
/*
SELECT entry_date, date_format(entry_date, '%Y-%m') as date_Y_M
FROM accounting.journal_entry
WHERE date_format(entry_date, '%Y-%m') > '2014-12' AND date_format(entry_date, '%Y-%m') < '2016-01'
ORDER BY date_Y_M ASC;
*/
/*Not going in the right direction*/


/* BALANCE SHEET SINGULAR YEAR - change year (INT (4)) for each year's balance sheet */
SELECT  date_format(je.entry_date, '%Y') AS year,
        ss.statement_section,
		ROUND(SUM(IFNULL(jeli.debit,0)),2) as debit, 
        ROUND(SUM(IFNULL(jeli.credit,0))*-1,2) as credit,
        ROUND(SUM(IFNULL(jeli.debit,0))+SUM(IFNULL(jeli.credit,0))*-1,2) as difference 
FROM accounting.journal_entry_line_item jeli
LEFT JOIN accounting.account a ON a.account_id = jeli.account_id
LEFT JOIN accounting.statement_section ss ON ss.statement_section_id = a.balance_sheet_section_id
LEFT JOIN accounting.journal_entry je ON je.journal_entry_id = jeli.journal_entry_id
WHERE date_format(je.entry_date, '%Y') = 2015 AND je.cancelled=0 AND ss.is_balance_sheet_section = 1 AND a.company_id = 1
GROUP BY ss.statement_section with ROLLUP /* ROLLUP provides the zero balance in the difference columns for balance check  NOT NEEDED*/
ORDER BY ss.statement_section; 

/* 2020 IS NOT BALANCED YET */

/* BALANCE SHEET ALL YEARS COMPARED*/
SELECT  date_format(je.entry_date, '%Y') AS year,
        ss.statement_section,
		ROUND(SUM(IFNULL(jeli.debit,0)),2) as debit, 
        ROUND(SUM(IFNULL(jeli.credit,0))*-1,2) as credit,
        
        ROUND(SUM(IFNULL(jeli.debit,0))+SUM(IFNULL(jeli.credit,0))*-1,2) as debit_credit_difference,
        
        /*comparison - percent change*/        
        ROUND(((ROUND(SUM(IFNULL(jeli.debit,0))-SUM(IFNULL(jeli.credit,0)),2)) - 
        (LAG(ROUND(SUM(IFNULL(jeli.debit,0))-SUM(IFNULL(jeli.credit,0)),2), 1, 0) OVER (PARTITION BY ss.statement_section ORDER BY date_format(je.entry_date, '%Y'))))/
        LAG(ROUND(SUM(IFNULL(jeli.debit,0))-SUM(IFNULL(jeli.credit,0)),2), 1, 0) OVER (PARTITION BY ss.statement_section ORDER BY date_format(je.entry_date, '%Y')),2) AS diff_perc_change
        
FROM accounting.journal_entry_line_item jeli
LEFT JOIN accounting.account a ON a.account_id = jeli.account_id
LEFT JOIN accounting.statement_section ss ON ss.statement_section_id = a.balance_sheet_section_id
LEFT JOIN accounting.journal_entry je ON je.journal_entry_id = jeli.journal_entry_id
WHERE je.cancelled=0 AND ss.is_balance_sheet_section = 1 AND a.company_id = 1
GROUP BY ss.statement_section, date_format(je.entry_date, '%Y')
ORDER BY ss.statement_section, date_format(je.entry_date, '%Y'); 

/* can we make this a user function? Answer: No... so commenting the attempt out*/
/*CREATE VIEW Balance_Sheet_TS as
		SELECT  date_format(je.entry_date, '%Y') AS year,
				ss.statement_section as main, 
				ROUND(IFNULL(jeli.debit,0),2) as debit, 
				ROUND(IFNULL(jeli.credit,0),2) as credit, 
				ROUND((SUM(IFNULL(jeli.debit,0))-SUM(IFNULL(jeli.credit,0))),2) as row_totals        
		FROM accounting.journal_entry_line_item jeli
		LEFT JOIN accounting.account a ON a.account_id = jeli.account_id
		LEFT JOIN accounting.statement_section ss ON ss.statement_section_id = a.balance_sheet_section_id
		LEFT JOIN accounting.journal_entry je ON je.journal_entry_id = jeli.journal_entry_id
		WHERE date_format(je.entry_date, '%Y') = 2020 AND je.cancelled=0 AND ss.is_balance_sheet_section = 1 AND a.company_id = 1
		GROUP BY ss.statement_section with ROLLUP; /* added rollup clause to get bottom right total of zero to ensure the sheet is balanced. Other bottom values are irrelevant*/
    
/*cannot create stored procedure because I forgot I don't have access in this database, but if I could would introduce the code below.*/
/*CREATE PROCEDURE Balance_Sheet_Creator(IN year int(4))
	SELECT *
	FROM accounting.Balance_Sheet_TS
	WHERE date_format(je.entry_date, '%Y') = year;
*/


/* CASH FLOWS SHEET SINGULAR YEAR - for different years just change year (2015-2020)*/
/* THIS SHOWS THE CASH AS EMPTY */

SELECT date_format(je.entry_date, '%Y') AS Year,
		ss.statement_section_id,
        ss.statement_section,
        
        /*making the values correct sign (positive or negative)*/
        CASE
			WHEN ss.debit_is_positive = 0 
            THEN ROUND(SUM(jeli.debit),2)
            ELSE ROUND((-1*SUM(jeli.debit)),2)
		END AS debit
        
FROM accounting.account a
LEFT JOIN accounting.journal_entry_line_item jeli ON a.account_id = jeli.account_id
LEFT JOIN accounting.statement_section ss ON ss.statement_section_id = a.profit_loss_section_id
LEFT JOIN accounting.journal_entry je ON je.journal_entry_id = jeli.journal_entry_id
WHERE a.company_id = 1 AND date_format(je.entry_date, '%Y') = 2019 AND je.cancelled = 0 /* explain the 0 & blank for the CASH value */
GROUP BY a.profit_loss_section_id with ROLLUP /*shows the total of the profit loss table in the top right NOT NEEDED*/
ORDER BY a.profit_loss_section_id;


/* CASH FLOWS SHEET EVERY YEAR for comparison*/
SELECT date_format(je.entry_date, '%Y') AS Year,
		ss.statement_section_id,
        ss.statement_section,
        
        /*making the values correct sign (positive or negative)*/
        CASE
			WHEN ss.debit_is_positive = 0 
            THEN ROUND(SUM(jeli.debit),2)
            ELSE ROUND((-1*SUM(jeli.debit)),2)
		END AS debit,
        
        /*comparison*/
       ROUND(((CASE
			WHEN ss.debit_is_positive = 0 
            THEN ROUND(SUM(jeli.debit),2)
            ELSE ROUND((-1*SUM(jeli.debit)),2)
		END) /* This gives us the current year debit*/ - LAG (CASE
			WHEN ss.debit_is_positive = 0 
            THEN ROUND(SUM(jeli.debit),2)
            ELSE ROUND((-1*SUM(jeli.debit)),2)
		END, 1, 0) OVER (PARTITION BY profit_loss_section_id ORDER BY date_format(je.entry_date, '%Y'))) /*This gives us previous years debit*/ / (LAG (CASE
			WHEN ss.debit_is_positive = 0 
            THEN ROUND(SUM(jeli.debit),2)
            ELSE ROUND((-1*SUM(jeli.debit)),2)
		END, 1, 0) OVER (PARTITION BY profit_loss_section_id ORDER BY date_format(je.entry_date, '%Y')))/*This divides the difference of new & previous values by the previous value*/
        ,2) AS perc_change 
        
FROM accounting.account a
LEFT JOIN accounting.journal_entry_line_item jeli ON a.account_id = jeli.account_id
LEFT JOIN accounting.statement_section ss ON ss.statement_section_id = a.profit_loss_section_id
LEFT JOIN accounting.journal_entry je ON je.journal_entry_id = jeli.journal_entry_id
WHERE a.company_id = 1 AND je.cancelled = 0 /* explain the 0 & blank for the cash value */
GROUP BY a.profit_loss_section_id, date_format(je.entry_date, '%Y')
ORDER BY a.profit_loss_section_id, date_format(je.entry_date, '%Y');



/*Profit and Loss statment SINGULAR YEAR - for different years just change year (2015-2020)*/
/* THIS SHOWS THE CASH AS EMPTY */

SELECT date_format(je.entry_date, '%Y') AS Year,
		a.profit_loss_section_id,
        ss.statement_section,
        
        /*making the values correct sign (positive or negative)*/
        CASE
			WHEN ss.debit_is_positive = 0 
            THEN ROUND(SUM(jeli.debit),2)
            ELSE ROUND((-1*SUM(jeli.debit)),2)
		END AS debit
        
FROM accounting.account a
LEFT JOIN accounting.journal_entry_line_item jeli ON a.account_id = jeli.account_id
LEFT JOIN accounting.statement_section ss ON ss.statement_section_id = a.profit_loss_section_id
LEFT JOIN accounting.journal_entry je ON je.journal_entry_id = jeli.journal_entry_id
WHERE a.company_id = 1 AND date_format(je.entry_date, '%Y') = 2019 AND je.cancelled = 0 /* explain the 0 & blank for the cash value */
GROUP BY a.profit_loss_section_id with ROLLUP /*shows the total of the profit loss table in the top right NOT NEEDED*/
ORDER BY a.profit_loss_section_id;

/*Profit and Loss statment ALL YEARS for comparison*/

SELECT date_format(je.entry_date, '%Y') AS Year,
		a.profit_loss_section_id,
        ss.statement_section,
        
        /*making the values correct sign (positive or negative)*/
        CASE
			WHEN ss.debit_is_positive = 0 
            THEN ROUND(SUM(jeli.debit),2)
            ELSE ROUND((-1*SUM(jeli.debit)),2)
		END AS debit,
        
        /*comparison*/
       ROUND(((CASE
			WHEN ss.debit_is_positive = 0 
            THEN ROUND(SUM(jeli.debit),2)
            ELSE ROUND((-1*SUM(jeli.debit)),2)
		END) /* This gives us the current year debit*/ - LAG (CASE
			WHEN ss.debit_is_positive = 0 
            THEN ROUND(SUM(jeli.debit),2)
            ELSE ROUND((-1*SUM(jeli.debit)),2)
		END, 1, 0) OVER (PARTITION BY profit_loss_section_id ORDER BY date_format(je.entry_date, '%Y'))) /*This gives us previous years debit*/ / (LAG (CASE
			WHEN ss.debit_is_positive = 0 
            THEN ROUND(SUM(jeli.debit),2)
            ELSE ROUND((-1*SUM(jeli.debit)),2)
		END, 1, 0) OVER (PARTITION BY profit_loss_section_id ORDER BY date_format(je.entry_date, '%Y')))/*This divides the difference of new & previous values by the previous value*/
        ,2) AS perc_change 
        
FROM accounting.account a
LEFT JOIN accounting.journal_entry_line_item jeli ON a.account_id = jeli.account_id
LEFT JOIN accounting.statement_section ss ON ss.statement_section_id = a.profit_loss_section_id
LEFT JOIN accounting.journal_entry je ON je.journal_entry_id = jeli.journal_entry_id
WHERE a.company_id = 1 AND je.cancelled = 0 /* explain the 0 & blank for the cash value */
GROUP BY a.profit_loss_section_id, date_format(je.entry_date, '%Y')
ORDER BY  a.profit_loss_section_id, date_format(je.entry_date, '%Y');

