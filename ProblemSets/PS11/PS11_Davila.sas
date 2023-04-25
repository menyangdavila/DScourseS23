/*==============================================================================================*/
* Copustat data;
/*==============================================================================================*/
data funda1; set comp.funda;
    where indfmt="INDL" and datafmt='STD' and consol='C' and curcd="USD";
    if (2000 le fyear le 2022) and (at gt 0);
    CUSIP8=substr(CUSIP,1,8);
    
    if (au = 4) or (au = 5) or (au = 6) or (au = 7) or (au = 11) or (au = 17) then large_auditor = 1;
    else large_auditor = 0;
    
    if abs(fca) gt 0 then foreign_currency = 1;
    else foreign_currency = 0;
    
    mkt_cap = prcc_f*csho;
    size = log(at);
    btm = ceq/mkt_cap;
    
    if dltt = . then dltt = 0;
    if dlc = . then dlc = 0;
    leverage = (dltt+dlc)/at;
    
    if exchg = 1 then exchange = 1;
    else exchange = 0;
    
    if (ni ne .)  and (ni lt 0) then loss = 1;
    else loss = 0;
    
    keep gvkey sich cik fyear datadate exchange at ceq mkt_cap sic roa ib oancf large_auditor foreign_currency size btm leverage loss CUSIP8 cusip;
run;

* lag total assets;
proc sql;
	create table funda2 as 
		select a.*, b.at as at_m1
		from funda1 as a left join funda1 as b 
		on a.gvkey = b.gvkey and a.fyear = b.fyear + 1
		order by gvkey, fyear;
quit;


/*==============================================================================================*/
* Segment data;
/*==============================================================================================*/
* segment data;
data segment_bus1; set compsegd.wrds_segmerged; 
	where stype="BUSSEG" and year(datadate) ge 2013;
	keep gvkey datadate srcdate stype sid;
run;

proc sql;
	create table segment_bus2 as
		select *
		from segment_bus1
		group by gvkey, datadate, sid
		having srcdate = min(srcdate); *121,654 obs;
	
	create table segment_bus as 
		select gvkey, datadate, count(sid) as segment_bus
		from segment_bus2
		group by gvkey, datadate; *58,466 obs;
	
	create table funda3 as 
		select a.*, b.segment_bus 
		from funda2 as a left join segment_bus as b 
		on a.gvkey = b.gvkey and a.datadate = b.datadate;
quit;



/*==============================================================================================*/
* Age;
/*==============================================================================================*/
* age;
data age1 ; set comp.funda;
	where indfmt="INDL" and datafmt='STD' and consol='C' and curcd="USD";
	keep gvkey fyear;
run;

proc sort data = age1 out=age1 nodupkey; by _ALL_ ; run;

proc sql;
    create table age2 as
	select *, min(fyear) as start
	from age1
	group by gvkey;
quit;	

data age; set age2;
	age = log(fyear - start + 1);
	drop start;
run;

proc sql;
	create table funda4 as 
		select a.*, b.age 
		from funda3 as a left join age as b 
		on a.gvkey = b.gvkey and a.fyear = b.fyear;
quit;

data funda5; set funda4;
	where at_m1 ne .;
	avg_at = (at + at_m1)/2;
	roa = ib/avg_at;
	cfo_a = oancf/avg_at;
	if segment_bus = . then segment_bus = 1;
	
	date = day(datadate);
	month = month(datadate);
	if month = 1 and date le 15 then fiscal_year_comp = year(datadate) - 1;
	else fiscal_year_comp = year(datadate); 
	
	drop ib oancf;
run; 


/*==============================================================================================*/
* ICMW - 404a;
/*==============================================================================================*/
* Management IC dataset has 92,076 non-duplicate observations (2000 - 2021);
proc import file="/home/ou/mengyangdavila/sasuser.v94/Summar2022/mgr_ic_new.xlsx"
    out=mgr_IC_raw
    dbms=xlsx
    replace; 
run; * 102,887 obs;

proc sort data = mgr_IC_raw out= mgr_IC_raw nodupkey; by _all_; run;

data mgr_ic1; set mgr_IC_raw;
	where cik_code ne .;
	if source ne "10-K" and source ne "10-K/A" and source ne "10-KT/A" and source ne "10-KT" then delete;
	
	cik=put(cik_code, z10.);
	
	if effective_internal_controls = "No" then mgr_404_t = 1;
	else mgr_404_t = 0;

	if restated_internal_control_report = "No" then restated = 0;
	else restated = 1;
	
	keep cik fiscal_year auditor_key mgr_404_t source_date source Signature_Date restated;
run; 

proc sql;
	create table mgr_ic2 as 
		select distinct *
		from mgr_ic1
		group by cik, fiscal_year
		having mgr_404_t = max(mgr_404_t); 
	
	create table mgr_ic3 as 
		select distinct *
		from mgr_ic2
		group by cik, fiscal_year
		having restated = min(restated); 
	create table mgr_ic as 
		select distinct *
		from mgr_ic3
		group by cik, fiscal_year
		having source_date = max(source_date); 
	
	create table merge as
		select a.*, b.mgr_404_t
		from funda5 as a left join mgr_ic as b 
		on a.cik = b.cik and a.fiscal_year_comp = b.fiscal_year
		order by gvkey, fyear; 
		
	create table sample1 as
		select a.*, b.mgr_404_t as mgr_404_tm1
		from merge as a left join mgr_ic as b 
		on a.cik = b.cik and a.fiscal_year_comp = b.fiscal_year + 1
		order by gvkey, fyear; 
quit;


/*==============================================================================================*/
* Fill missing sic code and assign FF12	code;
/*==============================================================================================*/
data sic; set comp.company;
	where sic ne " ";
	keep gvkey sic;
run;

* Fill sich missing with sic;
proc sql;
	create table sample2 as
		select a.*, b.sic
		from sample1 as a left join sic as b 
		on a.gvkey = b.gvkey;
quit;

data sample3; set sample2;
	if sich = . then sich = sic;
	if ( sich ge 0100 and sich le 0999) or ( sich ge 2000 and sich le 2399) or ( sich ge 2700 and sich le 2749) or ( sich ge 2770 and sich le 2799) or ( sich ge 3100 and sich le 3199) or ( sich ge 3940 and sich le 3989)then ff12= 1;
	if ( sich ge 2500 and sich le 2519) or ( sich ge 2590 and sich le 2599) or ( sich ge 3630 and sich le 3659) or ( sich ge 3710 and sich le 3711) or ( sich ge 3714 and sich le 3714) or ( sich ge 3716 and sich le 3716) or ( sich ge 3750 and sich le 3751) or ( sich ge 3792 and sich le 3792) or ( sich ge 3900 and sich le 3939) or ( sich ge 3990 and sich le 3999) then ff12= 2;
	if ( sich ge 2520 and sich le 2589) or ( sich ge 2600 and sich le 2699) or ( sich ge 2750 and sich le 2769) or ( sich ge 3000 and sich le 3099) or ( sich ge 3200 and sich le 3569) or ( sich ge 3580 and sich le 3629) or ( sich ge 3700 and sich le 3709) or ( sich ge 3712 and sich le 3713) or ( sich ge 3715 and sich le 3715) or ( sich ge 3717 and sich le 3749) or ( sich ge 3752 and sich le 3791) or ( sich ge 3793 and sich le 3799) or ( sich ge 3830 and sich le 3839) or ( sich ge 3860 and sich le 3899) then ff12= 3;
	if ( sich ge 1200 and sich le 1399) or ( sich ge 2900 and sich le 2999) then ff12= 4;
	if ( sich ge 2800 and sich le 2829) or ( sich ge 2840 and sich le 2899) then ff12= 5;
	if ( sich ge 3570 and sich le 3579) or ( sich ge 3660 and sich le 3692) or ( sich ge 3694 and sich le 3699) or ( sich ge 3810 and sich le 3829) or ( sich ge 7370 and sich le 7379) then ff12= 6;
	if ( sich ge 4800 and sich le 4899) then ff12= 7;
	if ( sich ge 4900 and sich le 4949) then ff12= 8;
	if ( sich ge 5000 and sich le 5999) or ( sich ge 7200 and sich le 7299) or ( sich ge 7600 and sich le 7699) then ff12= 9;
	if ( sich ge 2830 and sich le 2839) or ( sich ge 3693 and sich le 3693) or ( sich ge 3840 and sich le 3859) or ( sich ge 8000 and sich le 8099) then ff12=10;
	if ( sich ge 6000 and sich le 6999) then ff12=11;
	if ff12 = . then ff12 = 12;
run;

/*==============================================================================================*/
* Thomson Reuters for institutional ownership;
/*==============================================================================================*/
data ins_own_raw; set tfn.s34;
	where (rdate between "01JAN2000"d and "31DEC2022"d) and stkcdesc = "COM";
	if cusip ne " " and shrout2 gt 0 and shares gt 0;
	keep mgrname mgrno stkcd stkcdesc cusip rdate shares shrout1 shrout2;
run;

proc sort data = ins_own_raw out = ins_own nodupkey; by mgrno cusip rdate; run;

proc sql; 
	* In the Ge et al. prediction model, they use shares/(shrout1*1000), 
	  which should not be correct, since shrout1 is by millions and shrout2 is by thousands;
	create table p_ins as
		select distinct cusip, rdate, sum(shares/(shrout2*1000)) as ins_own_t
		from ins_own
		group by cusip, rdate;
	
	create table sample4 as 
		select a.*, b.ins_own_t
		from sample3 as a left join p_ins as b 
		on a.CUSIP8 = b.cusip and 0 le (a.datadate - b.rdate) lt 180
		group by a.CUSIP8, a.datadate
		having b.rdate = max(b.rdate);
quit;


/*==============================================================================================*/
* Market value from CRSP and market_adjusted return;
/*==============================================================================================*/
libname cdl "/home/ou/mengyangdavila/sasuser.v94/Summar2022";
* Add permno;
data mycstlink; set cdl.mycstlink;
	where LINKTYPE in ("LU","LC","LD","LN","LS","LX");
run;

proc sql;
    create table sample5 as
	select a.*, b.lpermno as permno
	from sample4 a left join mycstlink b
	on a.gvkey = b.gvkey and b.linkdt <= a.datadate <= b.extlinkenddt;
quit;

data sample5; set sample5;
	begdate=intnx('month', datadate, -11, 'begin');
	format begdate YYMMDDN8.;
run; 
	
proc sql; 
	create table mret as 
		select a.*, b.ret, b.date as ret_date 
		from sample5 as a left join crsp.msf as b 
		on a.permno = b.permno and a.begdate le b.date le a.datadate
		order by gvkey, datadate;
	
	create table midex as 
		select a.*, b.vwretd
		from mret as a left join crsp.msi as b 
		on a.ret_date = b.date
		order by gvkey, datadate;
	
	create table adj_ret as 
		select *, exp(sum(log(ret-vwretd+1)))-1 as mkt_adj_ret
		from midex
		group by gvkey, datadate;
quit;					

data mv_ret; set adj_ret;
	drop begdate ret_date ret vwretd;
run;

proc sort data = mv_ret out = sample6 nodupkey; by _ALL_; run;


/*==============================================================================================*/
* Obtain board id for future variable merge;
/*==============================================================================================*/
data A_0_Set_00; set Boardex.NA_WRDS_COMPANY_NAMES boardex.NA_WRDS_COMPANY_PROFILE;
	where not missing(BoardID) and (not missing(ISIN) or not missing(Ticker) or not missing(CIKCode));
	COMP_Cusip = substr(isin,3,9);
	CRSP_Cusip = substr(isin,3,8);
	SDC_Cusip = substr(isin,3,6);

	label SDC_Cusip = "SDC CUSIP";
	if not missing(SDC_Cusip) then Match_31 = 1;

	keep BoardID BoardName ISIN Ticker CIKCode COMP_Cusip CRSP_Cusip SDC_Cusip Match_31;
run;

data BX_SDC_00; set A_0_Set_00;
	where not missing(SDC_Cusip);
	LinkType = 'LC';
	keep BoardID SDC_Cusip LinkType;
	rename SDC_Cusip = BXcusip;
run;

proc sort data=BX_SDC_00 out=BX_SDC_Link nodupkey; by BoardID BXcusip; run;


/*  -------------------------------------------------------------------------  */
/*       Matching Round 1 - Compustat matching on the CUSIP identifier         */
/*  -------------------------------------------------------------------------  */
proc sort data=A_0_Set_00 out=A_1_Set_00; by BoardID descending COMP_Cusip; run;
proc sort data=A_1_Set_00 out=A_1_Set_01 nodupkey; by BoardID COMP_Cusip; run;

/*  Matching step                                                              */
proc sql;
	create table A_1_Set_02 as
 		select a.*, b.*
		from A_1_Set_01 (where=(not missing(COMP_Cusip))) a left join comp.names b
		on a.COMP_Cusip = b.cusip
		order by BoardName;
quit;

* Delete dupliates;
proc sort data=A_1_Set_02 out=A_1_Set_03 nodupkey; by BoardID gvkey; quit;

data AB_App_11; retain BoardID gvkey BoardName Match_11; set A_1_Set_03;
	where not missing(gvkey);
	Match_11 = 1;
	keep BoardID gvkey BoardName Match_11;
run;

/*  -------------------------------------------------------------------------  */
/*           Matching Round 2 - Compustat matching on the CIK Code             */
/*  -------------------------------------------------------------------------  */
* FIRST: backfill non ten-digit CIK codes in the BoardEx names file;
data A_2_Set_00; format NewCIK $10.; format FullCIK $10.; set A_0_Set_00;
	where not missing(CIKCode);
	
	if length(CIKCode) lt 10 then newCIK = cats(repeat('0',10-1-length(CIKCode)),CIKCode);
	FullCIK = coalescec(NewCIK,CIKCode);
	
	drop NewCIK;
run;

* Remove duplicate entries;
proc sort data=A_2_Set_00 out=A_2_Set_01; by BoardID descending FullCIK; run;

proc sort data=A_2_Set_01 out=A_2_Set_02 nodupkey; by BoardID FullCIK; run;

proc sql;
	create table A_2_Set_03 as
 		select	a.*, b.*
		from A_2_Set_02 a left join comp.names b
		on a.FullCIK = b.cik
		order by BoardID;
quit;

* Delete dupliate;
proc sort data=A_2_Set_03 out=A_2_Set_04 nodupkey; by BoardID gvkey; quit;

data AB_App_12; retain BoardID gvkey BoardName Match_12; set A_2_Set_04;
	where not missing(gvkey);
	Match_12 = 1;
	keep BoardID gvkey BoardName Match_12;
run;

/*  -------------------------------------------------------------------------  */
/*           Matching Round 3 - Manual Compustat matching                      */
/*  -------------------------------------------------------------------------  */
* NR - No link available, confirmed by research;
data A_13_set_00; set Boardex.Na_dir_profile_emp;
	rename CompanyID = BoardID;
	rename CompanyName = BoardName;
	keep CompanyID CompanyName ;
run;

proc sort data=A_13_set_00 nodupkey; by BoardID BoardName; run;

data AB_App_13; set A_13_set_00;

/*	set boardex.Na_company_profile_details;*/
	if BoardID in(15917) then gvkey = '116609';	/*  INFINITY BROADCASTING CORP */
	if BoardID in(678) then gvkey = '031520';		/*	ACRODYNE COMMUNICATIONS INC  */
	if BoardID in(3342) then gvkey = '065196';	/*	AZUREL	*/
	if BoardID in(5816) then gvkey = '062912';	/*	CARDIOGENESIS CORP (Eclipse Surgical Technologies prior to 05/2001) (De-listed 04/2003)	 */
/*	if BoardID in(10302) then gvkey = '004252';*/	/*	ELDER-BEERMAN STORES CORP (De-listed 10/2003)	*/
	if BoardID in(10302) then gvkey = '066465';	/*	ELDER-BEERMAN STORES CORP (De-listed 10/2003)	*/
	if BoardID in(10447) then gvkey = '130400';	/*	ELOQUENT INC */
	if BoardID in(10633) then gvkey = '062200';	/*	ENDOCARE INC (De-listed 07/2009)	*/
	if BoardID in(15272) then gvkey = '065825';	/*	HYBRID NETWORKS INC (De-listed 04/2002)	*/
	if BoardID in(15625) then gvkey = '126495';	/*	IMANAGE INC */

/*	10*/
	if BoardID in(15835) then gvkey = '005921';	/*	INDIANAPOLIS POWER & LIGHT CO */
	if BoardID in(19318) then gvkey = '163087';	/*	SOLEXA INC (Lynx Therapeutics prior to 2/2005) (De-listed 01/2007) */
	if BoardID in(27921) then gvkey = '009691';	/*	SIERRA PACIFIC POWER CO */
	if BoardID in(29259) then gvkey = '009900';	/*	SOUTHWESTERN BELL TELEPHONE CO */
	if BoardID in(29310) then gvkey = '010093';	/*	STONE CONTAINER CP */
	if BoardID in(32064) then gvkey = '022915';	/*	US-WORLDLINK INC */
	if BoardID in(634006) then gvkey = '108107';	/*	BUCHANS MINERALS CORP (Royal Roads Corp prior to 07/2010) (De-listed 07/2013) */
	if BoardID in(634381) then gvkey = '026355';	/*	PETAQUILLA MINERALS LTD (Adrian Resources Ltd prior to 12/2004) (De-listed 03/2015) */
	if BoardID in(741484) then gvkey = '107860';	/*	CANICKEL MINING LTD (Crowflight Minerals Inc prior to 06/2011) */
	if BoardID in(784170) then gvkey = '107758';	/*	VANGOLD RESOURCES LTD */

/*	20*/
	if BoardID in(815929) then gvkey = '148810';	/*	ALBA MINERALS LTD (Acrex Ventures Ltd prior to 07/2014) CANADIAN */
	if BoardID in(917913) then gvkey = '108292';	/*	DAMARA GOLD CORP (Solomon Resources Ltd prior to 10/2014) */
	if BoardID in(933187) then gvkey = '107962';	/*	ALDERSHOT RESOURCES LTD (Quattro Resources Ltd prior to 10/2001) */
	if BoardID in(1003662) then gvkey = '106064';	/*	EL NINO VENTURES INC */
	if BoardID in(1055313) then gvkey = '107854';	/*	PETROMIN RESOURCES LTD */
	if BoardID in(1095421) then gvkey = '106968';	/*	KENAI RESOURCES LTD (De-listed 07/2013) */
	if BoardID in(1147989) then gvkey = '105826';	/*	CASSIDY GOLD CORP (PMA Resources Inc prior to 09/1996) (De-listed 06/2017) */
	if BoardID in(1210869) then gvkey = '183274';	/*	BAYMOUNT INC (Academy Capital Corp prior to 01/2006) */
	if BoardID in(1221966) then gvkey = '142933';	/*	MOUNTAINVIEW ENERGY LTD */
	if BoardID in(1222852) then gvkey = '142501';	/*	MAXTECH VENTURES INC */

/*	30*/
	if BoardID in(1226178) then gvkey = '106008';	/*	XEMPLAR ENERGY CORP (Consolidated Petroquin Resources Ltd prior to 07/07/2005) */
	if BoardID in(1227073) then gvkey = '065809';	/*	FUTURE FARM TECHNOLOGIES INC (Arcturus Growthstar Technologies Inc prior to 02/2017) */
	if BoardID in(1245334) then gvkey = '177472';	/*	NOBILIS HEALTH CORP (Northstar Healthcare Inc prior to 12/2014) */
	if BoardID in(1262284) then gvkey = '155462';	/*	SEAIR INC */
	if BoardID in(1281699) then gvkey = '106988';	/*	BELLHAVEN COPPER & GOLD INC (Bellhaven Ventures Inc prior to 10/2006) (De-listed 05/2017) */
	if BoardID in(1347626) then gvkey = '178326';	/*	ELGIN MINING INC (Phoenix Coal Inc prior to 05/2010) */
	if BoardID in(1623978) then gvkey = '137840';	/*	IROC ENERGY SERVICES CORP (IROC Systems Corp prior to 05/2007) (De-listed 04/2013) */
	if BoardID in(1684863) then gvkey = '140202';	/*	HORNBY BAY MINERAL EXPLORATION LTD (HBME) (UNOR Inc prior to 04/2010) */
	if BoardID in(1713074) then gvkey = '187583';	/*	BRAVURA VENTURES CORP */
	if BoardID in(1248) then gvkey = '001225';		/*	ALABAMA POWER CO	*/

/*	40*/
	if BoardID in(1738) then gvkey = '023253';	/*	RADIENT PHARMACEUTICALS CORP	*/
	if BoardID in(2371) then gvkey = '031193';	/*	DIGITAL ANGEL CORP-OLD2 matched on ticker May be 023964 */
	if BoardID in(8775) then gvkey = '060923';	/*	DAVE & BUSTER'S ENTMT INC	*/
	if BoardID in(13005) then gvkey = '005073';	/*	GENERAL MOTORS CO	*/
	if BoardID in(14142) then gvkey = '028018';	/*	GYMBOREE CORP	*/
	if BoardID in(15541) then gvkey = '005888';	/*	IGI Labs now TELIGENT INC	 */
	if BoardID in(17217) then gvkey = '011538';	/*	J. ALEXANDER'S HOLDINGS INC	*/
	if BoardID in(007163) then gvkey = '028018';	/*	MCGRAW-HILL FINANCIAL now S&P GLOBAL INC	*/
	if BoardID in(20064) then gvkey = '030950';	/*	MEDIA GENERAL INC	MATCHED ON cik */
	if BoardID in(20349) then gvkey = '007267';	/*	MERRILL LYNCH & CO INC	*/

/*	50*/
	if BoardID in(24460) then gvkey = '012785';	/*	PILGRIM'S PRIDE CORP	*/
	if BoardID in(27257) then gvkey = '111491';	/*	SCHOOL SPECIALTY INC	*/
	if BoardID in(33763) then gvkey = '011555';	/*	INTEGRYS HOLDING INC matched on CIK	*/
	if BoardID in(482963) then gvkey = '007450';	/*	MISSISSIPPI POWER CO	*/
	if BoardID in(16982) then gvkey = '001656';	/*	IQUNIVERSE INC 	*/
	if BoardID in(4919) then gvkey = '002410';	/*	BP PLC 	*/
	if BoardID in(46864) then gvkey = '009236';	/*	RHONE-POULENC RORER 	*/
	if BoardID in(1505) then gvkey = '015505';	/*	ALLIED IRISH BANKS 	*/
	if BoardID in(9074) then gvkey = '015576';	/*	DEUTSCHE BANK AG 	*/
	if BoardID in(27066) then gvkey = '103487';	/*	SAP SE 	*/

/*	60*/
	if BoardID in(23862) then gvkey = '125378';	/*	PARTNER COMMUNICATIONS CO 	*/
	if BoardID in(605022) then gvkey = '206059';	/*	NASPERS LTD 	*/
	if BoardID in(1043876) then gvkey = '242587';	/*	INDIANA RESOURCES LTD (IMX Resources Ltd prior to 06/2016)  	*/

/*	Confirmed missing link*/
	if BoardID in(26040) then Match_14 = 1;			/*	RENAISSANCE ENERGY (De-listed 08/2000) Canadian firm */
	if BoardID in(26098) then Match_14 = 1;			/*	RESOURCES FINANCE & INVESTMENT */
	if BoardID in(4860) then Match_14 = 1;			/*	BOSTON EDISON CO	*/
	if BoardID in(5541) then Match_14 = 1;			/*	CALIFORNIA COMMUNITY BANCSHARES INC	*/
	if BoardID in(3209) then Match_14 = 1;			/*	AVERY COMMUNICATIONS INC*/
	if BoardID in(1813507) then Match_14 = 1;		/*	STRATA MINERALS INC (JBZ Capital Inc prior to 11/2011) */
	if BoardID in(1322720) then Match_14 = 1;		/*	MAJESCOR RESOURCES INC */
	if BoardID in(1635910) then Match_14 = 1;		/*	VOLCANIC GOLD MINES INC (Volcanic Metals Corp prior to 01/2017) */
	if BoardID in(1054270) then Match_14 = 1;		/*	CARTIER IRON CORP (Northfield Metals Inc prior to 01/2013) */

/*	Sept 14*/
	if BoardID in(890046) then Match_14 = 1;	/*	CHINA LNG GROUP LIMITED (Artel Solutions Group Holdings Ltd prior to 06/2014)  	*/
	if BoardID in(1472330) then Match_14 = 1;	/*	CIPLA MEDPRO SOUTH AFRICA LTD (Enaleni Pharma Ltd prior to 11/2008) (De-listed 07/2013)  	*/
	if BoardID in(48921) then Match_14 = 1;	/*	HCL TECHNOLOGIES LTD  	*/
	if BoardID in(16023) then Match_14 = 1;	/*	ING BANK SLASKI SA  	*/
	if BoardID in(16966) then Match_14 = 1;	/*	IPSOS SA  	*/
	if BoardID in(1016765) then Match_14 = 1;	/*	JSC BANK OF GEORGIA  	*/
	if BoardID in(24523) then Match_14 = 1;	/*	PIRELLI & C SPA (De-listed 02/2016)  	*/
	if BoardID in(7590) then Match_14 = 1;	/*	SYGNITY SA (Computerland SA prior to 04/2007)  	*/
	if BoardID in(622) then Match_14 = 1;	/*	ACER INC	*/
	if BoardID in(2402) then Match_14 = 1;	/*	APRIL SA (April Group prior to 05/2011)	*/
	if BoardID in(2472) then gvkey = '066321';	/*	ROOMLINX INC (Arc Communication Inc prior to 08/2004)	*/
	if BoardID in(4223) then Match_14 = 1;	/*	SOCIETE BIC SA	*/
	if BoardID in(4511) then gvkey = '015530';	/*	BANK OF EAST ASIA LTD	*/
	if BoardID in(6376) then gvkey = '001953';	/*	CERPLEX GROUP INC	*/
	if BoardID in(7189) then gvkey = '029367';	/*	COASTCAST CORP (De-listed 09/2002)	*/
	if BoardID in(7873) then gvkey = '030442';	/*	CORAM HEALTHCARE CORP (De-listed 03/2000)	*/
	if BoardID in(8235) then gvkey = '030117';	/*	CRESCENT REAL ESTATES EQUITIES (De-listed 08/2007)	*/
	if BoardID in(9657) then gvkey = '162378';	/*	FAMILYMEDS GROUP INC (DrugMax Inc prior to 07/2006) (De-listed 01/2007)	*/
	if BoardID in(10001) then gvkey = '029803';	/*	EBT INTERNATIONAL INC	*/
	if BoardID in(10025) then gvkey = '004140';	/*	ECI TELECOM LTD (De-listed 10/2007)	*/
	if BoardID in(10125) then Match_14 = 1;	/*	EDIPRESSE SA	*/
	if BoardID in(10299) then gvkey = '013442';	/*	ELCOTEL	*/
	if BoardID in(10479) then Match_14 = 1;	/*	EMAP PLC (De-listed 03/2008)	*/
	if BoardID in(12310) then gvkey = '006226';	/*	FORT JAMES CORP (James River Corp of Virginia prior to 07/1997) (De-listed 11/2000)	*/
	if BoardID in(14321) then gvkey = '005038';	/*	HARCOURT GENERAL INC (De-listed 07/2001)	*/
	if BoardID in(15117) then gvkey = '015360';	/*	HOUSE2HOME INC	*/
	if BoardID in(15583) then gvkey = '124677';	/*	ILLUMINET HLDGS INC	*/
	if BoardID in(16928) then gvkey = '064420';	/*	IONA TECHNOLOGIES (De-listed 09/2008)	*/
	if BoardID in(17127) then Match_14 = 1;	/*	ITESOFT SA	*/
	if BoardID in(19434) then gvkey = '025367';	/*	MAGIC SOFTWARE ENTERPRISES LTD	*/
	if BoardID in(19737) then gvkey = '060993';	/*	MARTIN INDUSTRIES INC (De-listed 05/2001)	*/
	if BoardID in(20973) then Match_14 = 1;	/*	MOLICHEM MEDICINES	*/
	if BoardID in(21869) then gvkey = '123099';	/*	NETRADIO CORP (De-listed 10/2001)	*/
	if BoardID in(22016) then Match_14 = 1;	/*	NEW WAVE GROUP AB	*/
	if BoardID in(23894) then Match_14 = 1;	/*	PATHE	*/
	if BoardID in(25324) then gvkey = '027785';	/*	PROXIMA	*/
	if BoardID in(27526) then gvkey = '009589';	/*	SEITEL INC (De-listed 02/2007)	*/
	if BoardID in(28481) then gvkey = '106025';	/*	TELSON RESOURCES INC (Soho Resources Corp prior to 01/2013)	*/
	if BoardID in(29552) then gvkey = '028398';	/*	SUNGLASS HUT INTERNATIONAL INC (De-listed 04/2001)	*/
	if BoardID in(31312) then gvkey = '010724';	/*	TRIDEX CORP (De-listed 05/2000)	*/
	if BoardID in(31370) then gvkey = '137668';	/*	TRITON NETWORK SYSTEMS	*/
	if BoardID in(33429) then Match_14 = 1;	/*	WHATMAN PLC (De-listed 04/2008)	*/
	if BoardID in(34063) then gvkey = '007469';	/*	ZARLINK SEMICONDUCTOR INC (Mitel Corp prior to 05/2001) (De-listed 10/2011)	*/
	if BoardID in(536539) then gvkey = '065254';	/*	SIROCCO MINING INC (Atacama Minerals Corp prior to 01/2012) (De-listed 01/2014)	*/
	if BoardID in(550286) then Match_14 = 1;	/*	VELA TECHNOLOGIES PLC (Asia Digital Holdings PLC prior to 01/2013)	*/
	if BoardID in(605108) then gvkey = '165575';	/*	SYNENCO ENERGY INC (De-listed 08/2008)	*/
	if BoardID in(634145) then gvkey = '065744';	/*	LUNDIN GOLD INC (Fortress Minerals Corp prior to 12/2014)	*/
	if BoardID in(634385) then gvkey = '026767';	/*	LATTICE BIOLOGICS LTD (Blackstone Ventures Inc prior to 12/2015)	*/
	if BoardID in(745789) then gvkey = '064562';	/*	REDSTAR GOLD CORP (Redstar Resources Corp prior to 04/2002)	*/
	if BoardID in(747388) then gvkey = '031640';	/*	DIADEM RESOURCES LTD (De-listed 04/2015)	*/
	if BoardID in(805425) then gvkey = '031698';	/*	AGUILA AMERICAN GOLD LTD (Aguila American Resources Ltd prior to 05/2011)	*/
	if BoardID in(815463) then Match_14 = 1;	/*	CATHAY MERCHANT GROUP INC (De-listed 12/2007)	*/
	if BoardID in(872367) then Match_14 = 1;	/*	ALTITUDE GROUP PLC (Dowlis Corporate Solutions prior to 06/2008)	*/
	if BoardID in(917917) then gvkey = '108585';	/*	WEALTH MINERALS LTD	*/
	if BoardID in(924930) then gvkey = '162765';	/*	EESTOR CORP (ZENN Motor Co Inc prior to 04/2015)	*/
	if BoardID in(931849) then gvkey = '105562';	/*	BEAUFIELD RESOURCES INC	*/
	if BoardID in(950322) then gvkey = '065656';	/*	STEALTH VENTURES INC (Stealth Ventures Ltd prior to 08/2012) (De-listed 03/2016)	*/
	if BoardID in(956442) then gvkey = '141309';	/*	LICO ENERGY METALS INC (Wildcat Exploration Ltd prior to 10/2016)	*/
	if BoardID in(1026398) then Match_14 = 1;	/*	IDM INTERNATIONAL LTD (Industrial Minerals Corp Ltd prior to 12/2011) (De-listed 01/2016)	*/
	if BoardID in(1044968) then gvkey = '107616';	/*	NORONT RESOURCES LTD (White Wing Resources Inc prior to 07/1983)	*/
	if BoardID in(1060490) then gvkey = '186160';	/*	RYAN GOLD CORP (Valdez Gold Inc prior to 12/2010) (De-listed 08/2015)	*/
	if BoardID in(1067423) then gvkey = '151593';	/*	TRUE NORTH GEMS INC	*/
	if BoardID in(1073606) then Match_14 = 1;	/*	VALERO ENERGY CORP (De-listed 07/1997)	*/
	if BoardID in(1077982) then Match_14 = 1;	/*	TETRA BIO-PHARMA INC (Growpros Cannabis Ventures Inc prior to 09/2016)	*/
	if BoardID in(1192227) then gvkey = '119920';	/*	INTERNATIONAL SAMUEL EXPLORATION CORP (Consolidated TranDirect.com Technologies Inc prior to 06/2001)	*/
	if BoardID in(1208076) then gvkey = '178720';	/*	ARGENTUM SILVER CORP (Silex Ventures Ltd prior to 02/2011)	*/
	if BoardID in(1236259) then gvkey = '166218';	/*	NEW PACIFIC HOLDINGS CORP (New Pacific Metals Corp prior to 07/2016)	*/
	if BoardID in(1240770) then gvkey = '183268';	/*	POLAR STAR MINING CORP (De-listed 12/2014)	*/
	if BoardID in(1241128) then gvkey = '139242';	/*	XIANA MINING INC (Dorato Resources Inc prior to 10/2013)	*/
	if BoardID in(1241260) then gvkey = '106048';	/*	BRS RESOURCES LTD (Bonanza Resources Corp prior to 02/2011)	*/
	if BoardID in(1340318) then gvkey = '106356';	/*	OREX EXPLORATION INC (De-listed 05/2017)	*/
	if BoardID in(1478369) then gvkey = '177425';	/*	NORTH ARROW MINERALS INC	*/
	if BoardID in(1482020) then Match_14 = 1;	/*	UNIVERSAL BIOSENSORS INC	*/
	if BoardID in(1564127) then gvkey = '174377';	/*	AREHADA MINING LTD (Dragon Capital Corp prior to 07/2007) (De-listed 10/2014)	*/
	if BoardID in(1584916) then Match_14 = 1;	/*	CALTON INC (De-listed 04/2004)	*/
	if BoardID in(1638612) then gvkey = '025302';	/*	INTRUSION INC (Intrusion.com Inc prior to 03/2001) (De-listed 10/2006)	*/
	if BoardID in(1656896) then gvkey = '183882';	/*	HEATHERDALE RESOURCES LTD	*/
	if BoardID in(1694070) then gvkey = '186664';	/*	CASTLE PEAK MINING LTD (Formerly known as Critical Capital Corporation)	*/
	if BoardID in(1710274) then gvkey = '183226';	/*	EUROTIN INC	*/
	if BoardID in(1718240) then gvkey = '177798';	/*	NEVADO RESOURCES CORP	*/
	if BoardID in(1718504) then gvkey = '025399';	/*	HAMPSHIRE GROUP LTD (De-listed 01/2007)	*/
	if BoardID in(1750334) then Match_14 = 1;	/*	CERTIVE SOLUTIONS INC (VisualVault Corp prior to 10/2013)	*/
	if BoardID in(1820640) then Match_14 = 1;	/*	NEW DESTINY MINING CORP	*/
	if BoardID in(1823399) then gvkey = '187410';	/*	ANNIDIS CORP (Aumento Capital Corp prior to 06/2011)	*/
	if BoardID in(1826034) then gvkey = '187794';	/*	COMSTOCK METALS LTD (Tectonic Capital Corp prior to 04/2009)	*/
	if BoardID in(1873273) then gvkey = '027026';	/*	VAXIL BIO LTD (Emerge Resources Corp prior to 03/2016)	*/
	if BoardID in(1879825) then Match_14 = 1;	/*	VOLTAIC MINERALS CORP (Prima Diamond Corp prior to 04/2016)	*/
	if BoardID in(1917129) then gvkey = '184172';	/*	DECLAN RESOURCES INC (Kokanee Minerals Inc prior to 04/2012)	*/
	if BoardID in(1096090) then gvkey = '116591';	/*	ALTURAS MINERALS CORP  */
	if BoardID in(1056054) then Match_14 = 1;	/*	ARMOR DESIGNS INC (De-listed 01/2015)  */
	if BoardID in(33410) then gvkey = '011450';	/*	WESTWOOD ONE INC (De-listed 11/2008)  */

/* March 21 2018 */
	if BoardID in(876814) then gvkey = '028862';	/*	CALIAN GROUP LTD (Calian Technologies Ltd prior to 04/2016)  */

/* March 22 2018 - Compustat identifies this firm as Pacwest Bancorp, which is incorrect */
	if BoardID in(23646) then gvkey = '125860';	/*	PAC-WEST TELECOMM INC (De-listed 12/2007)  */

/*	Confirmed missing link on 11/23/2017 - two new */
	if BoardID in(25024) then NR = 1;			/*	PRICER AB */
	if BoardID in(2017510) then NR = 1;			/*	TOSE CO LTD */

/* March 22 2018 - Compustat identifies US LEC as PAETEC, the company it merged into, which is incorrect */
	if BoardID in(31979) then gvkey = '109929';	/*	US LEC CORP (De-listed 02/2007)  */
	if not missing(gvkey) then Match_13 = 1;
	if ((Match_13 ne 1) and (Match_14 ne 1)) then delete;
	keep BoardID gvkey Match_13 Match_14;
run;


/*  -------------------------------------------------------------------------  */
/*                  Matching Round 4 - CRSP matching on CUSIP                  */
/*  -------------------------------------------------------------------------  */
proc sort data=A_0_Set_00 out=A_4_Set_00; by BoardID descending CRSP_Cusip; run;

proc sort data=A_4_Set_00 out=A_4_Set_01 nodupkey; by BoardID CRSP_Cusip; run;

proc sql;
	create table A_4_Set_02 as
 		select	a.BoardID, a.BoardName, a.CRSP_CUSIP, b.permno, b.namedt, b.nameendt, b.ncusip, b.comnam
		from A_4_Set_01 (where=(not missing(CRSP_Cusip))) a, crsp.dsenames b
		where a.CRSP_Cusip = b.ncusip
		order by BoardID, permno, namedt, nameendt;
quit;

* Collapse link table;
data A_4_Set_03; set A_4_Set_02;
    by BoardID permno namedt nameendt;
    format prev_ldt prev_ledt yymmddn8.;
    retain prev_ldt prev_ledt;

    if first.permno then do;
        if last.permno then do;
/*  Keep this obs if it's the first and last matching permno pair              */
            output;           
        end;
        else do;

/*  If it's the first but not the last pair, retain the dates for future use   */
            prev_ldt = namedt;
            prev_ledt = nameendt;
            output;
            end;
        end;   
    else do;
        if namedt=prev_ledt+1 or namedt=prev_ledt then do;

* If the date range follows the previous one, assign the previous namedt value to the current - will remove the redundant in later steps;
* Also retain the link end date value;
            namedt = prev_ldt;
            prev_ledt = nameendt;
            output;
            end;
        else do;

* If it doesn't fall into any of the above conditions, just keep it and retain the link date range for future use; 
            output;
            prev_ldt = namedt;
            prev_ledt = nameendt;
            end;
        end;
    drop prev_ldt prev_ledt;
run;

data A_4_Set_04; retain BoardID permno comnam namedt nameendt; set A_4_Set_03;
	by BoardID permno namedt;
	if last.namedt;
  * remove redundant observations with identical namedt (result of the previous data step);
  * so that each consecutive pair of observations will have either different GVKEY-IID-PERMNO match, or non-consecutive link date range;

	label BoardID = "BoardEx Board ID";
	label permno = "CRSP Permno";
	label namedt = "CRSP Names Date";
	label nameendt = "CRSP Names Ending Date";
/*	drop comnam BoardName CRSP_CUSIP ncusip;*/
run;

* Delete dupliates;
proc sort data=A_4_Set_04 out=A_4_Set_05 nodupkey; by BoardID permno namedt nameendt; quit;

data AB_App_21; retain BoardID permno namedt nameendt Match_21 LinkType; set A_4_Set_05;
	where not missing(permno);
	Match_21 = 1;
	LinkType = 'LC';
	keep BoardID permno namedt nameendt Match_21 LinkType;
	rename permno=BXpermno namedt=BXnamedt nameendt=BXnameendt;
run;

data BX_CRSP_Link; set AB_App_21;
	keep BoardID BXpermno BXnamedt BXnameendt LinkType;
run;


/*  -------------------------------------------------------------------------  */
/*           Matching Round 5 - CUSIP-based Permno link to Compustat           */
/*  -------------------------------------------------------------------------  */
*Reverse from CRSP to GVKEY;
proc sql;
	create table A_5_set_00 as
 		select	a.*, b.*
		from A_4_set_05 a left join crsp.Ccmxpf_lnkhist b
		on a.permno = b.lpermno
		order by BoardID, permno, gvkey, linkprim, liid, linkdt;
quit;

* Because out goal is to find a GVKEY match to a BoardID, we can remove BoardID - GVKEY duplicates;
* It may leave us with observations BoardID-PERMNO duplicates - they will need to be checed when merging Compustat financial data;
proc sort data=A_5_set_00 out=A_5_set_01 nodupkey; by BoardID gvkey; run;

* Create a Match_15 indicator for observations matched in this round;
data AB_App_15; retain BoardID GVKEY Match_15; set A_5_set_01;
	where not missing(gvkey);
	Match_15 = 1;
	keep BoardID GVKEY Match_15;
run;


/*  -------------------------------------------------------------------------  */
/*        This code consolidates the result of multiple matching steps         */
/*  -------------------------------------------------------------------------  */
data A0_Matched_00; set A_13_set_00 Boardex.Na_wrds_company_names boardex.Na_wrds_company_profile;
	keep BoardID;
run;

proc sort data=A0_Matched_00 out=A0_Matched_00 nodupkey; by BoardID; run;

data BxComp_00; set AB_App_11 AB_App_12 AB_App_13 AB_App_15; run;

proc sort data=BxComp_00; by BoardID descending Match_11-Match_15; run;

proc sql;
	create table BxComp_01 as
		select	BoardID, GVKEY, max(Match_11) as Match_11, max(Match_12) as Match_12, max(Match_13) as Match_13, max(Match_14) as Match_14, max(Match_15) as Match_15
	from BxComp_00
	group by BoardID, GVKEY;
quit;

data BxComp_02; set BxComp_01;
	if Match_15=1 and Match_11 ne 1 then Match_N = 1;
	if Match_15=1 and Match_12 ne 1 then Match_C = 1;
	if Match_11=1 or Match_12=1 or Match_13=1 then Match_0 = 1;
	if Match_0 ne 1 and Match_N = 1 then Match_W = 1;
run;

proc sql;
	select count(Match_13) as Manual_match, count(Match_12) as CIK_match
	from BxComp_01;
quit;

data BxComp_02; retain BoardID gvkey Linktype Matchpattern Match_1: ; set BxComp_01;
	Matchpattern = cats(Match_11,Match_12,Match_13,Match_14,Match_15);
	if Matchpattern in('1....') or Matchpattern in('1...1') then Linktype = 'LC';
	if Matchpattern in('.1...') or Matchpattern in('.1..1') then Linktype = 'LK';
	if Matchpattern in('11...') or Matchpattern in('11..1') then Linktype = 'LX';
	if Matchpattern in('1.1..') or Matchpattern in('.11..') or Matchpattern in('111..')
		or Matchpattern in('1.1.1') or Matchpattern in('.11.1') or Matchpattern in('111.1')
		then Linktype = 'LY';		
	if Matchpattern in('.....') then Linktype = '';
	if Matchpattern in('..1..') then Linktype = 'LM';
	if Matchpattern in('...1.') then Linktype = 'LN';
	if Matchpattern in('....1') then Linktype = 'LR';
	if Matchpattern in('.....') then delete;
	label LinkType = "Link Type";
	label BoardID = "BoardEx BoardID";
	label GVKEY = "Compustat GVKEY";
	keep BoardID gvkey Linktype Matchpattern Match_1: ;
	rename GVKEY = BXgvkey;
run;

proc sort data=BxComp_02; by BoardID; run;

data Bx_Comp_Link; set BxComp_02;
	if LinkType = 'LX' then LinkPriority = 1;
	if LinkType = 'LC' then LinkPriority = 2;
	if LinkType = 'LK' then LinkPriority = 3;
	if LinkType = 'LM' then LinkPriority = 4;
	if LinkType = 'LY' then LinkPriority = 5;
	if LinkType = 'LR' then LinkPriority = 6;
	keep BoardID BXgvkey LinkType LinkPriority;
run;

proc sort data=Bx_Comp_Link (where=(not missing(BXgvkey))) out=Bx_Comp_Link_unq; by BXgvkey LinkPriority BoardID; run;

proc sort data=Bx_Comp_Link_unq nodupkey; by BXgvkey; run;

/*==============================================================================================*/
* Merge board ID to sample using gvkey;
/*==============================================================================================*/
proc sql;
	create table sample7 as 
		select a.*, b.BoardID
		from sample6 as a left join Bx_Comp_Link_unq as b 
		on a.gvkey = b.BXgvkey;	
quit;

/*==============================================================================================*/
* Boardex - board and audit committee size and percentage of independent members;
/*==============================================================================================*/
* clean up data; 
data board_raw; set boardex.na_board_dir_committees;
	if annualreportdate ne .;
	if ned = "Yes" then independent = 1;
	else independent = 0;
	keep annualreportdate boardid independent directorid;
run;

proc sql;	
	create table boardex as 
		select distinct * from board_raw
		group by annualreportdate, boardid, directorid
		having independent = min(independent);
quit;

* calculate board size and the percentage of independent members;
proc freq data=boardex noprint ;
     tables annualreportdate*boardid*independent
     / out=board_boardex(keep=annualreportdate boardid independent pct_row count where=(independent=1)) 
     outpct;
run; * The variable COUNT has the number of independent directors by firm by year;
	 * The variable PCT_ROW has the pct of independent directors over the total number of director per firm and year;

proc freq data=boardex noprint ;
     tables annualreportdate*boardid 
     / out=board_size_boardex(keep=annualreportdate boardid count) 
     outpct;
run; * The variable COUNT has the number of directors by firm by year;

proc sql;
	* get cik for boardid to merge;
	create table boardex_cik as 
		select distinct boardid, annualreportdate, cikcode from boardex.na_wrds_org_summary
		having year(annualreportdate) ge 2000;
quit;

data link_cik; set boardex_cik;
	if not missing(CIKCode);
	cik = input(CIKCode, 10.);
	board_cik = put(cik, z10.);
	drop CIKCode cik;
run;

proc sql;
	create table board_temp1 as	
		select distinct a.*, b.pct_row as ind_pct_bd_boardex1
		from link_cik as a left join board_boardex as b 
		on a.boardid = b.boardid and a.annualreportdate = b.annualreportdate;
	
	create table board_temp2 as	
		select distinct a.*, b.count as bd_size_boardex1
		from  board_temp1 as a left join board_size_boardex as b 
		on a.boardid = b.boardid and a.annualreportdate = b.annualreportdate;
		
	create table sample8 as 
		select a.*, b.ind_pct_bd_boardex1, b.bd_size_boardex1, b.boardid, b.annualreportdate
		from sample7 as a left join board_temp2 as b 
		on a.cik = b.board_cik and (a.datadate - 365) le b.annualreportdate le a.datadate;
quit; 

proc sort data = sample8 out = sample8 nodupkey; by gvkey fyear; run;

proc sql;
	create table sample9 as	
		select a.*, b.pct_row as ind_pct_bd_boardex2
		from sample8 as a left join board_boardex as b 
		on a.BoardID = b.BoardID and a.annualreportdate = b.annualreportdate;
	
	create table sample10 as	
		select a.*, b.count as bd_size_boardex2
		from  sample9 as a left join board_size_boardex as b 
		on a.boardid = b.boardid and a.annualreportdate = b.annualreportdate;
quit;

* audit committee data;
data audit_raw; set boardex.na_board_dir_committees;
	if committeename = "Audit" and annualreportdate ne .;
	if ned = "Yes" then independent = 1;
	else independent = 0;
	
	year = year(annualreportdate);
	keep annualreportdate boardid independent directorid year;
run;

proc sort data = audit_raw out = audit_raw nodupkey; by _all_; run;

proc sql;
	create table turnover_bx1 as 
		select a.*, b.year as year_p1 
		from audit_raw as a left join audit_raw as b 
		on a.year = b.year - 1 and a.boardid = b.boardid and a.directorid = b.directorid
		order by a.boardid, a.year, a.directorid;
quit;

data turnover_bx2; set turnover_bx1;
	if year_p1 = . then turnover = 1;
	else turnover = 0;
run;

proc sql;
	create table turnover as 
		select distinct boardid, annualreportdate, max(turnover) as turnover
		from turnover_bx2
		group by boardid;
	
	create table sample11 as 
		select a.*, b.turnover 
		from sample10 as a left join turnover as b 
		on a.boardid = b.boardid and a.annualreportdate = b.annualreportdate;
quit;


/*==============================================================================================*/
* ISS - board and audit committee size and percentage of independent members;
/*==============================================================================================*/
proc import 
    out=iss_raw
    datafile = "/home/ou/mengyangdavila/sasuser.v94/DJY/data/iss_director.xlsx" 
    dbms=xlsx 
    replace;
run;

data iss; set iss_raw;
	if board_affiliation='I' or board_affiliation='I-NED' then independence = 1;
	else independence = 0;
	
	if ceo = "Yes" and chairman = "Yes" then ceo_chairman_iss = 1;
	else ceo_chairman_iss = 0;
run;

* calculate board size and the percentage of independent members;
proc freq data=iss noprint ;
     tables data_year*cusip*independence
     / out=board_iss(keep=data_year cusip independence pct_row count where=(independence=1)) 
     outpct;
run; * The variable COUNT has the number of independent directors by firm by year;
	 * The variable PCT_ROW has the pct of independent directors over the total number of director per firm and year;

proc freq data=iss noprint ;
     tables data_year*cusip 
     / out=board_size_iss(keep=data_year cusip count) 
     outpct;
run; * The variable COUNT has the number of directors by firm by year;

* merge with compustat;
proc sql;	
	create table sample12 as
		select a.*, b.pct_row as ind_pct_bd_iss
		from sample11 as a left join board_iss as b 
		on a.cusip = b.cusip and a.fyear = b.data_year;
	
	create table sample13 as
		select a.*, b.count as bd_size_iss
		from sample12  as a left join board_size_iss as b 
		on a.cusip = b.cusip and a.fyear = b.data_year;
quit; 

/*==============================================================================================*/
* Accounting expertise  (this part takes a long time and needs to be ran separately);
/*==============================================================================================*/

libname djy "/home/ou/mengyangdavila/sasuser.v94//DJY";
 
proc sql;
	create table sample14 as	
		select distinct a.*, b.expert_acc
		from sample13 as a left join djy.acc_expert as b 
		on a.boardid = b.companyid and a.fyear = b.expert_year;
quit;

data expert; set boardex.Na_dir_profile_emp;
	Rolename_clean = compress(Rolename,",,.,/,*,',-,","");
	Detail_clean = compress(FulltextDescription,",,.,/,*,',-,",""); 
	year_start=year(DateStartRole);
	year_end=year(DateEndRole);
	
	* if missing either start or end year just assume start and end in the same year;	
	if year_start ne . and year_end = . then year_end = 2023;
	if year_start = . and  year_end ne . then year_start = year_end;
	if year_end = . and year_start ne . then year_end = year_start;
	if year_start = . and year_end = . then delete;
	
	keep CompanyID RoleName_clean year_start year_end DateStartRole DateEndRole;
run;

proc sort data=expert out=expert nodupkeys; by CompanyID rolename_clean year_start year_end; run;

* Identify the expertise areas per Badolato et al 2014;
* accounting 1;
data acc_expert1;
	set expert;
	if prxmatch("m/\s*Chief\s*Financial\s*Officer\s*|CFO|\s*Accounting\s*Officer\s*|\s*Chief\s*Accountant\s*|\s*Senior\s*Accountant\s*|\s*Controller|\s*Manager\s*Audit\s*|\s*Manager\s*Auditor\s*|\s*Accounting\s*Manager\s*/oi",rolename_clean) > 0 
	then acc1=1;
	else acc1t=0;
run;

* accounting 2;
data acc_expert2;
	set acc_expert1;
	if prxmatch("m/\s*Certified\s*Public\s*Accountant\s*|\s*Chartered\s*Accountant\s*|\s*Financial\s*Officer\s*|\s*Head\s*of\s*Accounting\s*|\s*Vice\s*President\s*of\s*Accounting\s*|\s*Principal\s*Accounting\s*Officer\s*/oi",rolename_clean) > 0 
	then acc2=1;
	else acc2=0;
run;

* accounting 3;
data acc_expert3;
	set acc_expert2;
	if prxmatch("m/\s*Comptroller\s*|s*Audit\s*Partner\s*|\s*Director\s*Accounting|\s*Account\s*|\s*Internal\s*Auditor\s*|\s*Head\s*of\s*Financial\s*Reporting\s*/oi",rolename_clean) > 0 
	then acc3=1;
	else acc3=0;
run;

* accounting 4;
data acc_expert4; 
	set acc_expert3;
	if prxmatch("m/\s*Head\s*of\s*FinanceAccounting\s*|\s*Head\s*of\s*audit\s*|\s*Head\s*of\s*Assurance\s*|\s*VP\s*Accounting\s*|\s*VP\s*Internal\s*Audit|\s*VP\s*Internal\s*Auditing\s*/oi",rolename_clean) > 0 
	then acc4=1;
	else acc4=0;
run;

* accounting 5;
data acc_expert5; 
	set acc_expert4;
	if prxmatch("m/\s*account*/oi",rolename_clean) > 0 
	then acc5=1;
	else acc5=0;
run;

* get the years that companies having accounting expert;
data acc_expert; set acc_expert5;
	acc = acc1 + acc2 + acc3 + acc4 + acc5;
	if acc > 0 then expert_acc=1;
	else expert_acc=0;
	

	if expert_acc = 0 then delete;
	if year_start = . and year_end = . then delete;
	keep companyid expert_acc year_start year_end;
run;

data years;
   years = 1900;
   do i = 1 to 124; output;
      years = years + 1;
   end;
   drop i;
run;

proc sql;
	create table expert_year as	
		select distinct a.companyid, a.expert_acc, b.years as expert_year
		from acc_expert as a left join years as b 
		on a.year_start le b.years le a.year_end;
	
	create table sample14 as	
		select distinct a.*, b.expert_acc
		from sample13 as a left join expert_year as b 
		on a.boardid = b.companyid and a.fyear = b.expert_year;
quit; 


/*==============================================================================================*/
* CEO duality from both boardex and iss;
/*==============================================================================================*/
* from boardex;
data ceo_dual; set boardex.Na_board_dir_committees;
	where annualreportdate ne .;
	Rolen_clean = compress(BoardRole,",,.,/,*,',-,",""); 
	keep boardid annualreportdate Rolen_clean BoardRole;
run;

proc sort data = ceo_dual out=ceo_dual nodupkey; by _all_; run;

data dual1; set ceo_dual;
	if prxmatch("m/\s*Chairman\s*CEO\s*|\s*chair\s*ceo\s*/oi",Rolen_clean) > 0 
	then all_chairceo=1;
	else all_chairceo=0;
run;

data dual2; set dual1;
	if prxmatch("m/\s*vice\s*chair\s*/oi",Rolen_clean) > 0 
	then vice_chair=1;
	else vice_chair=0;
run;

data ceo_dual_boardex; set dual2;
	if all_chairceo = 1 and vice_chair = 0 then ceo_chair_boardex = 1;
	else ceo_chair_boardex = 0;
	keep boardid annualreportdate ceo_chair_boardex;
run;

proc sort data = ceo_dual_boardex out = ceo_dual_boardex nodupkey; by _all_; run;

* from iss;
proc sql;	
	create table ceo_dual_iss as
		select distinct data_year, cusip, ceo_chairman_iss as ceo_chair_iss from iss
		group by data_year, cusip
		having ceo_chairman_iss = max(ceo_chairman_iss);
quit;

* merge both to compustat;
proc sql;
	create table ceo_dual_boardex as
		select distinct boardid, annualreportdate, ceo_chair_boardex from ceo_dual_boardex
		group by boardid, annualreportdate
		having ceo_chair_boardex = max(ceo_chair_boardex);
		
	create table sample15 as
		select a.*, b.ceo_chair_boardex 
		from sample14 as a left join ceo_dual_boardex as b 
		on a.boardid = b.boardid and a.annualreportdate = b.annualreportdate;
	
	create table sample16 as
		select a.*, b.ceo_chair_iss 
		from sample15 as a left join ceo_dual_iss as b 
		on a.cusip = b.cusip and a.fyear = b.data_year;
quit;


/*==============================================================================================*/
* Merge with IBES;
/*==============================================================================================*/	
* first merge rdq from fundq, then merge permno and permco from crsp;
data fundq; set comp.fundq;
    where indfmt="INDL" and datafmt='STD' and consol='C' and curcdq="USD";
    if 2000 le fyearq le 2023 and fqtr = 4;
    keep gvkey fyearq rdq;
run;
   
proc sql;
	create table merge1 as 
		select a.*, b.rdq 
		from sample16 as a left join fundq as b 
		on a.gvkey = b.gvkey and a.fyear = b.fyearq;

	create table merge2 as
		select a.*, b.lpermno as permno, b.lpermco as permco
		from merge1 as a left join crsp.Ccmxpf_Linktable as b
		on a.gvkey=b.gvkey and (b.linkdt<=a.rdq<=b.linkenddt 
			or (b.linkdt<=a.rdq and missing(b.linkenddt)))
			and b.usedflag=1 and b.linkprim in ('P','C')
		group by a.gvkey, datadate, permno
		having a.fyear=min(a.fyear);
		
	create table merge3 as 
		select a.*, b.ibtic
		from merge2 as a left join (select distinct gvkey, ibtic from comp.security
  			where not missing(ibtic) and iid='01') as b
  		on a.gvkey=b.gvkey
 		order by a.gvkey, a.datadate;
quit;     

* CRSP-IBES link table;
%iclink;

* link in additional IBES ticker-PERMNO  matches;
proc sort data=Iclink (where=(score in (0,1))) out=Ibeslink; by permno ticker score; run;
data Ibeslink; set Ibeslink; by permno ticker; if first.permno; run;

* firms have permnos, but have no matching IBES ticker;
data noticker; set merge3;
	where not missing(permno) and missing(ibtic);
	drop ibtic;
run;

proc sql; 
	create table noticker1 as
		select a.*, b.ticker as ibtic
		from noticker a left join Ibeslink b
		on a.permno=b.permno
		order by gvkey, datadate;
quit;

* append the additional GVKEY-IBES Ticker links;
data merge4; set merge3
	(where=(missing(permno) or not missing(ibtic))) noticker1;
	label ibtic='IBES Ticker';
run;

* Analyst coverage;
data ibes; set ibes.STATSUMU_EPSUS;
	*keep ticker STATPERS FPEDATS numest;
	if measure="EPS" and fpi = "1";
	if 2000 < year(FPEDATS) < 2024;
run;

proc sql;
create table final1 as
	select a.*, b.STATPERS, b.numest as num_analysts
		from merge4 as a left join ibes as b
		on a.ibtic = b.ticker and a.datadate-30 < b.STATPERS < a.datadate and a.datadate-5 <= b.FPEDATS <= a.datadate+5;
quit;


/*==============================================================================================*/
* Final clean up;
/*==============================================================================================*/	
data final2; set final1;
	where 2004 le fyear le 2019;
	
	if missing(num_analysts) then num_analysts=0;
	analyst_coverage=log(1+num_analysts);
	
	if ceo_chair_boardex ne . then duality = ceo_chair_boardex;
	if ceo_chair_boardex eq . then duality = ceo_chair_iss;
	
	if ind_pct_bd_boardex1 ne . then ind_pct_bd = ind_pct_bd_boardex1;
	if ind_pct_bd_boardex1 eq . then ind_pct_bd = ind_pct_bd_boardex2;
	if ind_pct_bd_boardex2 eq . then ind_pct_bd = ind_pct_bd_iss;
	
	if bd_size_boardex1 ne . then bd_size = bd_size_boardex1;
	if bd_size_boardex1 eq . then bd_size = bd_size_boardex2;
	if bd_size_boardex2 eq . then bd_size = bd_size_iss;
	
	if turnover = . then turnover = 0;
	
	if ins_own_t gt 1 then ins_own_t = 1;
	if ins_own_t = . then ins_own_t = 0;
	
	drop ceo_chair_boardex ceo_chair_iss ibtic statpers num_analysts rdq ind_pct_bd_boardex1 ind_pct_bd_boardex2 ind_pct_bd_iss
		 bd_size_boardex1 bd_size_boardex2 bd_size_iss annualreportdate sic month date;
run;

proc sort data = final2 out = final3 nodupkey; by _all_; run;
proc means data = final3; run;

proc export data = final3 
	outfile= "/home/ou/mengyangdavila/sasuser.v94/ECON/PS11_Davila.csv"
	dbms=csv
	replace;
run;








