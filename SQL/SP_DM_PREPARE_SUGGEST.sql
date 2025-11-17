-- แก้ตรงที่ ROW_NO<=10 เท่านั้น


/****** Object:  StoredProcedure [commercial].[SP_DM_PREPARE_SUGGEST]    Script Date: 5/9/2567 14:00:12 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [commercial].[SP_DM_PREPARE_SUGGEST] AS

BEGIN

DECLARE @FAC_FROM DATE, @FAC_TO DATE, @REV_FROM DATE, @REV_TO DATE
  , @YYYYQQ INT 
  , @TYPE INT
SET @TYPE=2    /* 

แบบที่ 1 REV เป็น Dec Jan , Facing เป็น Current Quarter
แบบที่ 2 REV เป็น Dec Jan , Facing เป็น Dec Jan
*/

--select getdate() az, DATEADD(HH, -7, GETDATE()) [az-7], DATEADD(HH, 7, GETDATE()) [az+7=thailand]
--select getdate()-1 az, DATEADD(HH, -7, GETDATE()-1) [az-7], DATEADD(HH, 7, GETDATE()-1) [az+7=thailand]

--select DATEADD(HH, -7, GETDATE()-1)

--SELECT DATEADD(MONTH, DATEDIFF(MONTH, 0, DATEADD(QUARTER, DATEDIFF(QUARTER, 0, DATEADD(HH, -7, GETDATE()-1)), -1)), 0) )

SET @REV_FROM=(SELECT DATEADD(MONTH, DATEDIFF(MONTH, 0, DATEADD(QUARTER, DATEDIFF(QUARTER, 0, DATEADD(HH, -7, GETDATE()-1)), -1)), 0) )
SET @REV_TO=(SELECT DATEADD(QUARTER, DATEDIFF(QUARTER, 0, DATEADD(HH, -7, GETDATE()-1)) + 1, -1))
SET @FAC_FROM=
    (SELECT CASE WHEN @TYPE=1 THEN DATEADD(QUARTER, DATEDIFF(QUARTER, 0, DATEADD(HH, -7, GETDATE()-1)), 0) 
	 ELSE DATEADD(MONTH, DATEDIFF(MONTH, 0, DATEADD(QUARTER, DATEDIFF(QUARTER, 0, DATEADD(HH, -7, GETDATE()-1)), -1)), 0)  END)
SET @FAC_TO=(SELECT DATEADD(QUARTER, DATEDIFF(QUARTER, 0, DATEADD(HH, -7, GETDATE()-1)) + 1, -1))

SET @YYYYQQ=(SELECT DATEPART(YY, @REV_TO)*100+DATEPART(QQ, @REV_TO) )

PRINT @REV_FROM
PRINT @REV_TO
PRINT @FAC_FROM
PRINT @FAC_TO
PRINT @YYYYQQ;


TRUNCATE TABLE [commercial].[STG_DIGITAL_MAP_SUGGEST];

WITH

PP AS (
SELECT *
, ROW_NUMBER() OVER(PARTITION BY [CustomerGroupCode], [CustomerSubtradeChannelCode], [IndirectCustServiceChannelCode], [ProductId]
ORDER BY [CustomerGroupCode],[CustomerSubtradeChannelCode], [IndirectCustServiceChannelCode], [ProductId], [ValidToDate] DESC) AS ROW_NO
FROM [dbo].[DIM_ProductPremiseMapping]
----WHERE [CustomerGroupCode]='51' AND [CustomerSubtradeChannelCode]='234' 
---- AND [IndirectCustServiceChannelCode]='1'
),

STK as (
----select customerId, STARTBUSINESSDATE, DATEPART(YY, STARTBUSINESSDATE)*100+DATEPART(QQ, STARTBUSINESSDATE) AS YYYYQQ_START
select customerId, [CreateDate], DATEPART(YY, [CreateDate])*100+DATEPART(QQ, [CreateDate]) AS YYYYQQ_START
from dim_customermaster  
where (DsdStockist = 'Stockist' AND [SuppressCode]<>'S') OR (customercategory='LCC' AND [SuppressCode]<>'S')

--and customerid in ('0501800547')
--and customerId='0505102819'
--AND CUSTOMERID='0501800158'
)
------select * from stk   where customerid  IN ('0509274183' )   --'0509062075', '0501343948', '0509125511', '0501217165', '0505445428') 
,   
/* เงื่อนไขนี้มีใน product suggestion >> AND [SuppressCode]<>'S' OR (customercategory='LCC' AND [SuppressCode]<>'S') */
DarkSpace AS (
----select customerId, StockistCustomerCode, STARTBUSINESSDATE, DATEPART(YY, STARTBUSINESSDATE)*100+DATEPART(QQ, STARTBUSINESSDATE) AS YYYYQQ_START
select customerId, StockistCustomerCode, [CreateDate], DATEPART(YY, [CreateDate])*100+DATEPART(QQ, [CreateDate]) AS YYYYQQ_START
,[SuppressCode],customercategory
from dim_customermaster
where (IndirectCustomerGroup1Code = '1' AND [SuppressCode]<>'S' OR (customercategory='LCC' AND [SuppressCode]<>'S'))
--and StockistCustomerCode = '0501800158'  
)
------select * from DarkSpace   where StockistCustomerCode  IN ('0509274183', '0509182936') --'0509062075', '0501343948', '0509125511', '0501217165', '0505445428') 
------ORDER BY 1
,

DS_CUST AS (
select STK.customerId AS CUSTOMER_PARENT, ds.customerId AS CUSTOMER_CHILD, DS.YYYYQQ_START
from DarkSpace ds
left join stk on ds.StockistCustomerCode=stk.customerid
WHERE StockistCustomerCode IS NOT NULL     --(229142 row(s) affected)
)
--SELECT * FROM DS_CUST WHERE CUSTOMER_PARENT IS NOT NULL
------SELECT * FROM DS_CUST WHERE CUSTOMER_PARENT IN ('0509274183', '0509182936') OR CUSTOMER_CHILD  IN ('0509274183', '0509182936')
,
/* new */
DS_COUNT AS (
select STK.customerId AS CUSTOMER_PARENT, COUNT(DISTINCT ds.customerId) DS_COUNT
from DarkSpace ds
left join stk on ds.StockistCustomerCode=stk.customerid
WHERE StockistCustomerCode IS NOT NULL 
AND  STK.customerId IS NOT NULL
GROUP BY STK.customerId
)
--SELECT * FROM DS_COUNT where CUSTOMER_PARENT='0501800158'
,

SKUCloboticMaster AS (
---Find TNTL SKU and Clobotic Sku
Select a.*, b.Productid, productShortName
from DIM_TNTLCloboticMaster a
inner join DIM_ProductMaster b
on a.tntlbrandCode = b.Brand 
and a.TNTLFlavourCode = b.Flavour
and a.TNTLPackSizeCode = b.Packsize
and a.TNTLPackTypeCode = b.Packtype
where b.deletionFlag = ' ' and PromotionIndicator = 'R'
),

LatestResultDarckSpace AS (
SELECT b.PhotoRegInfId, b.periodCode, b.Customerid, b.CloboticSKUid, b.facing, A.CUSTOMER_PARENT, a.CUSTOMER_CHILD
, ROW_NUMBER() OVER(PARTITION BY Customerid ORDER BY PhotoRegInfId desc) as rowIndex
FROM DS_CUST a
left join fact_facingcapture b on a.CUSTOMER_CHILD=b.Customerid
WHERE --b.periodCode in ('202110','202111','202112') 
b.periodCode>=CONVERT(VARCHAR(6), @FAC_FROM, 112) AND b.periodCode<=CONVERT(VARCHAR(6), @FAC_TO, 112)
----b.periodCode>=CONVERT(VARCHAR(6), 202112, 112) AND b.periodCode<=CONVERT(VARCHAR(6), 202203, 112)
)
--select * from LatestResultDarckSpace
----WHERE CUSTOMER_PARENT='0505102819'
----order by periodCode desc, PhotoRegInfId, Customerid 
,

----------NO_OF_CUST AS (
----------SELECT 
------------ds1.*
----------DATEADD(QUARTER, DATEDIFF(QUARTER, 0, @REV_TO), 0) AS [FIRST_DAY_OF_QUARTER]
----------, DS1.CUSTOMER_PARENT, DS1.[SKUName], DS1.CloboticSKUId  /*, DS2.CloboticSKUid, C.Manufact--, SUM(CONVERT(INT, DS2.facing)) AS FACING*/
----------, COUNT(DISTINCT DS1.Customerid) AS NO_OF_CUST
----------from LatestResultDarckSpace DS1 
------------where 
--------------DS1.rowIndex='1'
--------------AND C.Manufact='Thainamthip' and 
------------DS1.Customerid='0501802730'
----------GROUP BY DS1.CUSTOMER_PARENT, DS1.[SKUName], DS1.CloboticSKUId 
----------)
----------SELECT * FROM NO_OF_CUST --WHERE CUSTOMER_PARENT='0501802730'
----------,

DS_SKU AS (
--SELECT DISTINCT /*DS1.periodCode,*/ DS1.CUSTOMER_PARENT, C.Productid, DS2.FACING /*--, SUM(CONVERT(INT, DS2.facing)) AS FACING*/
SELECT DS1.CUSTOMER_PARENT, C.Productid, MAX(CONVERT(INT, DS2.FACING)) AS FACING /*--, SUM(CONVERT(INT, DS2.facing)) AS FACING*/
--, DS2.CloboticSKUid
----SELECT DS1.*, C.Productid, DS2.FACING AS FC
from LatestResultDarckSpace DS1 
inner join LatestResultDarckSpace DS2 ON DS2.PhotoRegInfId = DS1.PhotoRegInfId
LEFT JOIN SKUCloboticMaster C ON C.CloboticSKUid = DS2.CloboticSKUid
where DS1.rowIndex='1' AND C.Manufact='Thainamthip'
GROUP BY DS1.CUSTOMER_PARENT, C.Productid ---, DS2.CloboticSKUid
)
--SELECT * FROM DS_SKU where CUSTOMER_PARENT='0501800158'
,

/* new suggest */
NO_DS_SKU AS (
--SELECT DISTINCT /*DS1.periodCode,*/ DS1.CUSTOMER_PARENT, C.Productid, DS2.FACING /*--, SUM(CONVERT(INT, DS2.facing)) AS FACING*/
SELECT DS1.CUSTOMER_PARENT, C.Productid, count(distinct ds1.customer_child) No_of_DS_Buy
--, DS2.CloboticSKUid
----SELECT DS1.*, C.Productid, DS2.FACING AS FC
from LatestResultDarckSpace DS1 
inner join LatestResultDarckSpace DS2 ON DS2.PhotoRegInfId = DS1.PhotoRegInfId
LEFT JOIN SKUCloboticMaster C ON C.CloboticSKUid = DS2.CloboticSKUid
where DS1.rowIndex='1' AND C.Manufact='Thainamthip'
GROUP BY DS1.CUSTOMER_PARENT, C.Productid --, DS2.CloboticSKUid
)
--SELECT * FROM NO_DS_SKU where CUSTOMER_PARENT='0501800158'

,

STK_SKU AS (
SELECT 
--CONVERT(VARCHAR(6), CONVERT(DATE, [PostingDate]), 112) AS YYYYMM
----CONVERT(VARCHAR(6), @REV_TO, 112) AS YYYYMM
A.Customerid, REV.[ProductId], A.Customerid AS CUSTOMER_PARENT, a.Customerid AS CUSTOMER_CHILD, SUM([RevenueSR]) AS [RevenueSR]
FROM STK a
LEFT JOIN [dbo].[FACT_BillingData] REV ON REV.[CustomerId]=A.customerId
WHERE --b.periodCode in ('202110','202111','202112') 
CONVERT(DATE, [PostingDate])>=@REV_FROM AND CONVERT(DATE, [PostingDate])<=@REV_TO
----CONVERT(DATE, [PostingDate])>='2021-12-01' AND CONVERT(DATE, [PostingDate])<='2022-03-31'
GROUP BY CONVERT(VARCHAR(6), CONVERT(DATE, [PostingDate]), 112)
, A.Customerid, REV.[ProductId], A.Customerid, a.Customerid
HAVING SUM([RevenueSR])<>0
)
--SELECT * FROM STK_SKU where CUSTOMER_PARENT='0501800158'
,

/* ต้องเพิ่มส่วน Product Mapping */

SUGGEST_SKU AS (
SELECT 
DATEADD(QUARTER, DATEDIFF(QUARTER, 0, @REV_TO), 0) AS [FIRST_DAY_OF_QUARTER]
----DATEADD(QUARTER, DATEDIFF(QUARTER, 0, CONVERT(DATE, CONVERT(VARCHAR(6), 202201)+'01', 112)), 0) AS [FIRST_DAY_OF_QUARTER]
, DS.CUSTOMER_PARENT, DS.Productid, CM.[CustomerName], FACING
, CM.[CustomerGroupCode], CM.[CustomerSubtradeChannelCode], CM.[IndirectCustServiceChannelCode]
--, ROW_NUMBER() OVER(PARTITION BY DS.CUSTOMER_PARENT ORDER BY FACING DESC) AS ROW_NO  /* BY facing */
, ROW_NUMBER() OVER(PARTITION BY DS.CUSTOMER_PARENT ORDER BY Nsku.No_of_DS_Buy DESC) AS ROW_NO  /* BY No_of_DS_Buy */
--, DS.CloboticSKUid
, Nsku.No_of_DS_Buy, dsc.DS_COUNT
----, DATEADD(HH, 7, GETDATE()) AS UPDATE_DATE
FROM DS_SKU DS
LEFT JOIN STK_SKU STK ON STK.CUSTOMER_PARENT=DS.CUSTOMER_PARENT AND STK.Productid=DS.Productid
LEFT JOIN [dbo].[DIM_CustomerMaster] CM ON CM.[CustomerId]=DS.CUSTOMER_PARENT
LEFT JOIN PP ON 
CONVERT(VARCHAR(8), substring(PP.[ProductId], patindex('%[^0]%', PP.[ProductId]), 10))=CONVERT(VARCHAR(8), substring(DS.Productid, patindex('%[^0]%', DS.Productid), 10)) 
AND PP.[CustomerGroupCode]=CM.[CustomerGroupCode] 
AND PP.[CustomerSubtradeChannelCode]=CM.[CustomerSubtradeChannelCode] 
AND PP.[IndirectCustServiceChannelCode]=CM.[IndirectCustServiceChannelCode]
left join NO_DS_SKU Nsku on Nsku.CUSTOMER_PARENT=DS.CUSTOMER_PARENT and Nsku.Productid=DS.Productid
left join DS_COUNT dsc on dsc.CUSTOMER_PARENT=ds.CUSTOMER_PARENT
WHERE STK.[ProductId] IS NULL
AND PP.TYPE in ('C', 'S', 'N')
AND ValidToDate >= GETDATE()-1
AND PP.ROW_NO=1 

   --DS.CUSTOMER_PARENT='0509274183' AND 
--ORDER BY DS.CUSTOMER_PARENT
)
--SELECT * FROM SUGGEST_SKU where CUSTOMER_PARENT='0501800158'

/*
,

SG_PP AS (
SELECT SG.*, PP.TYPE, PP.ValidToDate, PP.ROW_NO AS PP_ROW_NO FROM SUGGEST_SKU SG
LEFT JOIN PP ON 
CONVERT(VARCHAR(8), substring(PP.[ProductId], patindex('%[^0]%', PP.[ProductId]), 10))=CONVERT(VARCHAR(8), substring(SG.Productid, patindex('%[^0]%', SG.Productid), 10)) AND 
PP.[CustomerGroupCode]=SG.[CustomerGroupCode] AND 
PP.[CustomerSubtradeChannelCode]=SG.[CustomerSubtradeChannelCode] AND 
PP.[IndirectCustServiceChannelCode]=SG.[IndirectCustServiceChannelCode]

WHERE PP.TYPE in ('C', 'S', 'N')
AND PP.ValidToDate >= GETDATE()-1
AND PP.ROW_NO=1 

)
*/

--------------SELECT * FROM SUGGEST_SKU
--------------WHERE CUSTOMER_PARENT='0505102819'

INSERT INTO [commercial].[STG_DIGITAL_MAP_SUGGEST]

/* นับจำนวนลูกค้าที่มีการซื้อผลิตภัณฑ์ที่ stk ไม่ได้ซื้อกับเราเพื่อหา % */

----------WHERE ROW_NO<=10

SELECT 
SS.[FIRST_DAY_OF_QUARTER]
, SS.[CUSTOMER_PARENT]
, SS.[Productid]
, SS.[CustomerName]
, SS.[FACING]
, SS.[ROW_NO]
, No_of_DS_Buy, DS_COUNT
, DATEADD(HH, 7, GETDATE()) AS UPDATE_DATE
FROM SUGGEST_SKU SS
WHERE ROW_NO<=10

--GROUP BY SS.[FIRST_DAY_OF_QUARTER]
--, SS.[CUSTOMER_PARENT]
--, SS.[Productid]
--, SS.[CustomerName]
--, SS.[FACING]
--, SS.[ROW_NO]


END 


/*

--DELETE
----SELECT COUNT(*) 
FROM [commercial].[DIGITAL_MAP_SUGGEST]
WHERE FIRST_DAY_OF_QUARTER IN (SELECT DISTINCT FIRST_DAY_OF_QUARTER FROM [commercial].[STG_DIGITAL_MAP_SUGGEST])


INSERT INTO [commercial].[DIGITAL_MAP_SUGGEST]

SELECT 
[FIRST_DAY_OF_QUARTER],
[CUSTOMER_PARENT],
[Productid],
[CustomerName],
[FACING],
[ROW_NO],
DATEADD(HH, 7, GETDATE()) AS UPDATE_DATE
--------INTO [commercial].[DIGITAL_MAP_SUGGEST]
FROM [commercial].[STG_DIGITAL_MAP_SUGGEST]


*/

GO


