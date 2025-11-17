<Process>
<h3> After checking that it passes, you can change the code from the original as follows: </h3>

- ปรับ SP : [commercial].[SP_DM_PREPARE_SUGGEST] -> SQL(SP_DM_PREPARE_SUGGEST)
- Execute [commercial].[SP_DM_PREPARE_SUGGEST]
- Execute [commercial].[SP_DM_PROCESS_SUGGEST]
	- ลอง Query : [commercial].[VW_DIGITAL_MAP_SUGGEST]
- BI : กลับมาเปลี่ยน Path ใช้ [commercial].[VW_DIGITAL_MAP_SUGGEST]
- BI : เปลี่ยน Path สุดท้ายที่ VW_DIGITAL_MAP_TOP10_PRD (ข้อมูลของ Suggest)