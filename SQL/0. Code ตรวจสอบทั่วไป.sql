
SELECT distinct ROW_NO 
		--, [Suggested SKUs],* 
FROM [commercial].[VW_DIGITAL_MAP_SUGGEST_TEST]			T1
FULL JOIN [commercial].[VW_DIGITAL_MAP_TOP10_PRD]	T2 ON T1.JOIN_KEY = T2.JOIN_KEY


SELECT top 10 *
FROM [commercial].[VW_DIGITAL_MAP_STOCKIST]


SELECT top 10 *
FROM [commercial].[VW_DIGITAL_MAP_SUGGEST_TEST]			T1


SELECT top 10 *
FROM [commercial].[VW_DIGITAL_MAP_TOP10_PRD]			T2

SELECT distinct TradeNameDesc
FROM dim_customermaster 
ORDER BY 1


-----------------------------------

SELECT top 200 *
FROM [commercial].[DIGITAL_MAP_SUGGEST_TEST]			T1



SELECT * --count(*)
FROM [commercial].[STG_DIGITAL_MAP_SUGGEST_TEST]			T1
WHERE ROW_NO <= 5
SELECT count(*)
FROM [commercial].[STG_DIGITAL_MAP_SUGGEST]			T1

SELECT count(*)
FROM [commercial].[DIGITAL_MAP_SUGGEST_TEST]			T1
WHERE ROW_NO <= 5
SELECT count(*)
FROM [commercial].[DIGITAL_MAP_SUGGEST]			T1
-- WHERE ROW_NO <= 5

SELECT count(*)
FROM [commercial].[VW_DIGITAL_MAP_SUGGEST_TEST]			T1
SELECT count(*)
FROM [commercial].[VW_DIGITAL_MAP_SUGGEST]			T1




SELECT top 100 *
FROM [commercial].[VW_DIGITAL_MAP_SUGGEST]			T1

SELECT top 100 *
FROM [commercial].[VW_DIGITAL_MAP_TOP10_PRD]			T1