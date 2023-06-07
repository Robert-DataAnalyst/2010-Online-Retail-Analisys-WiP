--I've created a database called Netflix Analysis, imported the table from an Excel file available in the folder, 
--and named it dbo.Online_Retail
--If you would like to execute the code, please do the same.

--Because my computer was using a polish locale system setting, I weren't able to import the data from CSV file
--without encountering any errors or having missing data. 
--In that situation, I decided to split the values in the CSV file and change it to an Excel file.

USE Online_Retail

SELECT *
FROM Online_Retail

--PLEASE NOTE--
--To check the functionality of the entire code, I recommend creating a new SQL file, importing the Excel file and then 
--running the code.


---------DATA CLEANING---------

--Checking the Datatype for all columns
SELECT *
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Online_Retail'

ALTER TABLE dbo.Online_Retail 
ALTER COLUMN InvoiceNo Int

ALTER TABLE dbo.Online_Retail 
ALTER COLUMN Quantity Int

ALTER TABLE dbo.Online_Retail 
ALTER COLUMN InvoiceDate Datetime 

ALTER TABLE dbo.Online_Retail
ALTER COLUMN UnitPrice DECIMAL(10,2)

ALTER TABLE dbo.Online_Retail
ALTER COLUMN CustomerID Int

--Deleting the rows with number of items below 1
DELETE FROM dbo.Online_Retail
WHERE Quantity < 1

--Finding the items with smaller than 0.01 price and finding the medians of all the items with the same description

SELECT Distinct Description
FROM Online_Retail
WHERE UnitPrice < 0.01

SELECT Distinct Description, 
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY UnitPrice ASC) OVER (PARTITION BY Description) as Medians
INTO #Temp_Medians
FROM Online_Retail
WHERE Description IN 
	(
	SELECT Description
	FROM Online_Retail
	WHERE UnitPrice < 0.01
	)
ORDER BY Description ASC

--Updating the values in the original table using the medians in the temporary table
UPDATE Online_Retail
SET Online_Retail.UnitPrice = #Temp_Medians.Medians
FROM #Temp_Medians
WHERE Online_Retail.Description = #Temp_Medians.Description AND UnitPrice < 0.01

--Deleting the rows that weren't affected by the previous code
DELETE FROM Online_Retail
WHERE UnitPrice < 0.01

--Since some of the orders contained transactions like errors, adjusments etc., I've decided to check 
--if there were any left and if yes, delete them. 
SELECT *
FROM Online_Retail
WHERE Description LIKE '%Error%'
	OR Description LIKE '%Incorrect%'
	OR Description LIKE '%Adjust%'
	OR Description LIKE '%Broken%'
	OR Description LIKE '%Fix%'
	OR Description LIKE '%Return%'

DELETE FROM Online_Retail
WHERE Description LIKE '%Adjust%'

--Now, I'm deleting the "Unspecified" country
SELECT Distinct Country 
FROM Online_Retail

DELETE FROM Online_Retail
WHERE Country = 'Unspecified'


--Updating the values in the description column, so that they are not in uppercase.
UPDATE Online_Retail
SET Description = UPPER(LEFT(Description, 1))+LOWER(SUBSTRING(Description,2,LEN(Description)))


--Creating an additional column with the Order Sum
ALTER TABLE Online_Retail
ADD OrderSum DECIMAL(10,2)

UPDATE Online_Retail
SET OrderSum = Quantity*UnitPrice


--Creating additional period columns
ALTER TABLE Online_Retail
ADD Day int

ALTER TABLE Online_Retail
ADD Month NVARCHAR(10)

ALTER TABLE Online_Retail
ADD Year int

UPDATE Online_Retail
SET Day = DAY(InvoiceDate)

UPDATE Online_Retail
SET Month = DATENAME(mm,InvoiceDate)

UPDATE Online_Retail
SET Year = YEAR(InvoiceDate)


--Updating the country names
UPDATE Online_Retail
SET Country = 'Ireland'
WHERE Country = 'EIRE'

UPDATE Online_Retail
SET Country = 'Republic of South Africa'
WHERE Country = 'RSA'


--ANALYSIS--
--Creating an additional table with the data grouped by invoice and medians for country, years and months
SELECT InvoiceNo, 
	MIN(InvoiceDate) as InvoiceDate,
	MIN(Day) as Day, 
	MIN(Month) as Month, 
	MIN(Year) as Year,
	SUM(Quantity) as TotalItems,  
	SUM(OrderSum) as OrderTotal,
	MIN(CustomerID) as CustomerID,
	MIN(Country) as Country
INTO Online_Retail_By_Invoice
FROM Online_Retail
GROUP BY InvoiceNo

ALTER TABLE Online_Retail_By_Invoice
ADD CountryItemsMedian DECIMAL(10,1)

ALTER TABLE Online_Retail_By_Invoice
ADD CountryMthYrItemsMedian DECIMAL(10,1)

ALTER TABLE Online_Retail_By_Invoice
ADD CountryAmountMedian DECIMAL(10,2)

ALTER TABLE Online_Retail_By_Invoice
ADD CountryMthYrAmountMedian DECIMAL(10,2)

SELECT InvoiceNo, Country,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY TotalItems ASC) OVER (PARTITION BY Country) as CountryItemsMedian,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY TotalItems ASC) OVER (PARTITION BY Country, Year, Month) as CountryMthYrItemsMedian,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY OrderTotal ASC) OVER (PARTITION BY Country) as CountryAmountMedian,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY OrderTotal ASC) OVER (PARTITION BY Country, Year, Month) as CountryMthYrAmountMedian
INTO #Temp_Group_Median
FROM Online_Retail_By_Invoice

UPDATE Online_Retail_By_Invoice
SET Online_Retail_By_Invoice.CountryItemsMedian = #Temp_Group_Median.CountryItemsMedian
FROM #Temp_Group_Median
WHERE Online_Retail_By_Invoice.InvoiceNo = #Temp_Group_Median.InvoiceNo 
	AND Online_Retail_By_Invoice.Country = #Temp_Group_Median.Country

UPDATE Online_Retail_By_Invoice
SET Online_Retail_By_Invoice.CountryMthYrItemsMedian = #Temp_Group_Median.CountryMthYrItemsMedian
FROM #Temp_Group_Median
WHERE Online_Retail_By_Invoice.InvoiceNo = #Temp_Group_Median.InvoiceNo 
	AND Online_Retail_By_Invoice.Country = #Temp_Group_Median.Country

UPDATE Online_Retail_By_Invoice
SET Online_Retail_By_Invoice.CountryAmountMedian = #Temp_Group_Median.CountryAmountMedian
FROM #Temp_Group_Median
WHERE Online_Retail_By_Invoice.InvoiceNo = #Temp_Group_Median.InvoiceNo 
	AND Online_Retail_By_Invoice.Country = #Temp_Group_Median.Country

UPDATE Online_Retail_By_Invoice
SET Online_Retail_By_Invoice.CountryMthYrAmountMedian = #Temp_Group_Median.CountryMthYrAmountMedian
FROM #Temp_Group_Median
WHERE Online_Retail_By_Invoice.InvoiceNo = #Temp_Group_Median.InvoiceNo 
	AND Online_Retail_By_Invoice.Country = #Temp_Group_Median.Country



--Creating two tables with items and values parameters 

--Items parameters
WITH 
	Percentiles_IQR (Country,p25,p50,p75,IQR,IQRMulti)
	AS
		(
			SELECT
			Country,
			AVG(p25),
			AVG(p50),
			AVG(p75),
			AVG(p75-p25),
			AVG((p75-p25)*1.5)
			FROM 		
			(
				SELECT 
				Country,
				PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY TotalItems) OVER (PARTITION BY Country) as p25,
				PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY TotalItems) OVER (PARTITION BY Country) as p50,
				PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY TotalItems) OVER (PARTITION BY Country) as p75
				FROM Online_Retail_By_Invoice
			) as Percentiles
			GROUP BY Country
		)
		,
	Summary (Country, Invoices, TotalItems, AvgItems, MinItems, p25, p50, p75, MaxItems, IQR, IQRMulti, LowerBracket,
	UpperBracket, StdP)
	AS
		(
			SELECT Helper1.Country, Invoices, TotalItems, AvgItems, MinItems, p25, p50, p75, MaxItems, IQR, IQRMulti,
			CASE WHEN p25 - IQRMulti < MinItems THEN MinItems ELSE p25 - IQRMulti END,
			CASE WHEN p75 + IQRMulti > MaxItems THEN MaxItems ELSE p75 + IQRMulti END,
			StdP
			FROM
			(
				SELECT Country,
					COUNT(*) as Invoices,
					SUM(TotalItems) as TotalItems,
					ROUND(AVG(CAST(TotalItems as float)), 2) as AvgItems,
					MIN(TotalItems) as MinItems,
					MAX(TotalItems) MaxItems,
					ROUND(STDEVP(TotalItems), 3) as StdP
				FROM Online_Retail_By_Invoice
				GROUP BY Country
			) as Helper1
			LEFT JOIN Percentiles_IQR as Helper2
			ON Helper1.Country = Helper2.Country
		)
		,
	Addition (Country, OutliersNo)
	AS
		(
			Select Main.Country, 
			COUNT(
				CASE 
					WHEN Main.TotalItems < LowerBracket THEN Main.InvoiceNo
					WHEN Main.TotalItems > UpperBracket THEN Main.InvoiceNo 
				END
				)
			FROM Online_Retail_By_Invoice as Main
			LEFT JOIN 
			Summary
			ON Main.Country = Summary.Country
			GROUP BY Main.Country
		)
SELECT Summary.Country, Invoices, TotalItems, AvgItems, MinItems, p25, p50 as Median, p75, MaxItems, IQR, IQRMulti, 
LowerBracket, UpperBracket, OutliersNo, ROUND((OutliersNo/CAST(Invoices as float))*100,2) as OutliersProportion, StdP
INTO Items_Parameters
FROM Summary 
LEFT JOIN 
Addition
ON Summary.Country = Addition.Country


--Values parameters
WITH
	Percentiles_IQR (Country,p25,p50,p75,IQR,IQRMulti)
	AS
		(
			SELECT
			Country,
			AVG(p25),
			AVG(p50),
			AVG(p75),
			AVG(p75-p25),
			AVG((p75-p25)*1.5)
			FROM 		
			(
				SELECT 
				Country,
				PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY OrderTotal) OVER (PARTITION BY Country) as p25,
				PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY OrderTotal) OVER (PARTITION BY Country) as p50,
				PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY OrderTotal) OVER (PARTITION BY Country) as p75
				FROM Online_Retail_By_Invoice
			) as Percentiles
			GROUP BY Country
		)
		,
	Summary (Country, Invoices, OrderTotal, AvgValue, MinValue, p25, p50, p75, MaxValue, IQR, IQRMulti, LowerBracket,
	UpperBracket, StdP)
	AS
		(
			SELECT Helper1.Country, Invoices, OrderTotal, AvgValue, MinValue, p25, p50, p75, MaxValue, IQR, IQRMulti,
			CASE WHEN p25 - IQRMulti < MinValue THEN MinValue ELSE p25 - IQRMulti END,
			CASE WHEN p75 + IQRMulti > MaxValue THEN MaxValue ELSE p75 + IQRMulti END,
			StdP
			FROM
			(
				SELECT Country,
					COUNT(*) as Invoices,
					SUM(OrderTotal) as OrderTotal,
					ROUND(AVG(CAST(OrderTotal as float)), 2) as AvgValue,
					MIN(OrderTotal) as MinValue,
					MAX(OrderTotal) MaxValue,
					ROUND(STDEVP(OrderTotal), 3) as StdP
				FROM Online_Retail_By_Invoice
				GROUP BY Country
			) as Helper1
			LEFT JOIN Percentiles_IQR as Helper2
			ON Helper1.Country = Helper2.Country
		)
		,
	Addition (Country, OutliersNo)
	AS
		(
			Select Main.Country, 
			COUNT(
				CASE 
					WHEN Main.OrderTotal < LowerBracket THEN Main.InvoiceNo
					WHEN Main.OrderTotal > UpperBracket THEN Main.InvoiceNo 
				END
				)
			FROM Online_Retail_By_Invoice as Main
			LEFT JOIN 
			Summary
			ON Main.Country = Summary.Country
			GROUP BY Main.Country
		)
SELECT Summary.Country, Invoices, OrderTotal, AvgValue, MinValue, ROUND(p25,2) as p25, ROUND(p50,2) as Median, 
ROUND(p75,2) as p75, MaxValue, ROUND(IQR,2) as IQR, ROUND(IQRMulti,2) as IQRMulti, LowerBracket, 
ROUND(UpperBracket,2) as UpperBracket, OutliersNo, 
ROUND((OutliersNo/CAST(Invoices as float))*100,2) as OutliersProportion, StdP
INTO Values_Parameters
FROM Summary 
LEFT JOIN 
Addition
ON Summary.Country = Addition.Country

SELECT *
FROM Items_Parameters

SELECT *
FROM Values_Parameters

--Creating a table with parameters for years, quarters and months
SELECT 
Month as Period, 
COUNT(*) as Total_No_of_Invoices, 
SUM(TotalItems) as Sum_of_Items_Ordered, 
ROUND(AVG(CAST(TotalItems as float)), 2) as Avg_No_of_Items_Ordered,
ROUND(AVG(Median_Items), 2) as Median_No_of_Items_Ordered,
SUM(OrderTotal) as Sum_of_Invoices_Values, 
ROUND(AVG(CAST(OrderTotal as float)), 2) as Avg_Invoice_Value,
ROUND(AVG(Median_Values), 2) as Median_Invoice_Value
INTO Period_Summary
FROM 
(
SELECT 
*,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY TotalItems ASC) OVER (PARTITION BY Year, Month) as Median_Items,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY OrderTotal ASC) OVER (PARTITION BY Year, Month) as Median_Values
FROM Online_Retail_By_Invoice
) as Extended
GROUP BY ROLLUP (Year, DATEPART(quarter, InvoiceDate), Month)


--Because medians for quaters and years are incorrect, I have to manually fix them by creating temporary tables with
--the correct medians
SELECT 
DISTINCT Year,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY TotalItems ASC) OVER (PARTITION BY Year) as Items,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY OrderTotal ASC) OVER (PARTITION BY Year) as 'Values'
INTO #Year_Median_Fixer
FROM Online_Retail_By_Invoice

SELECT 
DISTINCT Year,
DATEPART(quarter, InvoiceDate) as Quarter,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY TotalItems ASC) OVER (PARTITION BY Year, DATEPART(quarter, InvoiceDate)) as Items,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY OrderTotal ASC) OVER (PARTITION BY Year, DATEPART(quarter, InvoiceDate)) as 'Values'
INTO #Quarter_Median_Fixer
FROM Online_Retail_By_Invoice

SELECT 
Distinct PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY TotalItems ASC) OVER () as Items,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY OrderTotal ASC) OVER () as 'Values'
INTO #Overall_median_Fixer
FROM Online_Retail_By_Invoice

--Checking the temporary tables
SELECT *
FROM #Year_Median_Fixer

SELECT *
FROM #Quarter_Median_Fixer

SELECT *
FROM #Overall_Median_Fixer

--Adding an id column, to simplify the process of fixing the table
ALTER TABLE Period_Summary
ADD id INT IDENTITY NOT NULL

--Fixing the values associated with quarters
UPDATE Period_Summary
SET Period = 'Q4'
WHERE id = 2

UPDATE Period_Summary
SET Period = 'Q1', Median_No_of_Items_Ordered = #Quarter_Median_Fixer.Items, Median_Invoice_Value = #Quarter_Median_Fixer.[Values]
FROM #Quarter_Median_Fixer
WHERE id = 7 AND #Quarter_Median_Fixer.Year = 2011 AND #Quarter_Median_Fixer.Quarter = 1

UPDATE Period_Summary
SET Period = 'Q2', Median_No_of_Items_Ordered = #Quarter_Median_Fixer.Items, Median_Invoice_Value = #Quarter_Median_Fixer.[Values]
FROM #Quarter_Median_Fixer
WHERE id = 11 AND #Quarter_Median_Fixer.Year = 2011 AND #Quarter_Median_Fixer.Quarter = 2

UPDATE Period_Summary
SET Period = 'Q3', Median_No_of_Items_Ordered = #Quarter_Median_Fixer.Items, Median_Invoice_Value = #Quarter_Median_Fixer.[Values]
FROM #Quarter_Median_Fixer
WHERE id = 15 AND #Quarter_Median_Fixer.Year = 2011 AND #Quarter_Median_Fixer.Quarter = 3

UPDATE Period_Summary
SET Period = 'Q4', Median_No_of_Items_Ordered = #Quarter_Median_Fixer.Items, Median_Invoice_Value = #Quarter_Median_Fixer.[Values]
FROM #Quarter_Median_Fixer
WHERE id = 19 AND #Quarter_Median_Fixer.Year = 2011 AND #Quarter_Median_Fixer.Quarter = 4

--Fixing the values associated with years
UPDATE Period_Summary
SET Period = '2010'
WHERE id = 3

UPDATE Period_Summary
SET Period = '2011', Median_No_of_Items_Ordered = #Year_Median_Fixer.Items, Median_Invoice_Value = #Year_Median_Fixer.[Values]
FROM #Year_Median_Fixer
WHERE id = 20 AND #Year_Median_Fixer.Year = 2011

--Fixing the overall values
UPDATE Period_Summary
SET Period = 'Overall', Median_No_of_Items_Ordered = #Overall_Median_Fixer.Items, Median_Invoice_Value = #Overall_Median_Fixer.[Values]
FROM #Overall_Median_Fixer
WHERE id = 21

--Dropping the id column
ALTER TABLE Period_summary
DROP COLUMN id

--Checking the final table
SELECT *
from Period_Summary
