function [filename,time_offset,drop_num_start,drop_num_end] = get_filename(Data_id)
% time_offset = 0;
% drop_num_start = 0;
% drop_num_end = 0;
switch Data_id
    % Low SpO2 data
    case 196
        time_offset = -3000;
        drop_num_start = 0;
        drop_num_end = 3000; 
    case 197
        time_offset = -2000;
        drop_num_start = 0;
        drop_num_end = 2000;
    case 208
        time_offset = -2000;
        drop_num_start = 0;
        drop_num_end = 5000; 
    case 215
        time_offset = -3000;
        drop_num_start = 0;
        drop_num_end = 3000; 
    case 216
        time_offset = -3000;
        drop_num_start = 0;
        drop_num_end = 3000; 
    case 221
        time_offset = -1200;
        drop_num_start = 0;
        drop_num_end = 1200; 
    case 225
        time_offset = -1500;
        drop_num_start = 5000;
        drop_num_end = 1500; 
    case 227
        time_offset = -1500;
        drop_num_start = 3000;
        drop_num_end = 1500; 
    case 228
        time_offset = -1750;
        drop_num_start = 2500;
        drop_num_end = 1750; 
    case 229
        time_offset = -1750;
        drop_num_start = 2750;
        drop_num_end = 1500; 
    case 1001
        time_offset = 0;
        drop_num_start = 4000;
        drop_num_end = 2000;
    case 1004
        time_offset = 0;
        drop_num_start = 1500;
        drop_num_end = 500;
    case 1013
        time_offset = 0;
        drop_num_start = 1500;
        drop_num_end = 10000;
    case 1017
        time_offset = 0;
        drop_num_start = 0;
        drop_num_end = 1500;
    case 1018
        time_offset = 0;
        drop_num_start = 1500;
        drop_num_end = 190000;
    case 1019
        time_offset = 0;
        drop_num_start = 5500;
        drop_num_end = 1500;
    case 1020
        time_offset = 0;
        drop_num_start = 5500;
        drop_num_end = 100000;


    case 2001
        time_offset = 0;
        drop_num_start = 500;
        drop_num_end = 1000;
    case 2002
        time_offset = 0;
        drop_num_start = 1250;
        drop_num_end = 1000;
    otherwise
        time_offset = -1500;
        drop_num_start = 0;
        drop_num_end = 1500;
end

switch Data_id
    case 1
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240423_idS2_2352_merged.txt'; % Data 01
    case 2
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240424_idS1_0149_merged.txt'; % Data 02
    case 3
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240424_idS2_2251_merged.txt'; % Data 02
    case 4
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240425_idS1_0055_merged.txt'; % Data 02
    case 5
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240425_idS2_2332_merged.txt'; % Data 02
    case 6
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240426_idS1_0131_merged.txt'; % Data 02
    case 7
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240427_idS1_0211_merged.txt'; % Data 02
    case 8
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240429_idS1_0116_merged.txt'; % Data 02
    case 9
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240429_idS2_0003_merged.txt'; % Data 02
    case 10
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240429_idS2_2308_merged.txt'; % Data 02
    case 11
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240430_idS1_0109_merged.txt'; % Data 02
    case 12
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240506_idS1_0152_merged.txt'; % Data 02
    case 13
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240506_idS2_2239_merged.txt'; % Data 02
    case 14
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240507_idS1_0131_merged.txt'; % Data 02
    case 15
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240507_idS2_2233_merged.txt'; % Data 02
    case 16
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240508_idS1_0133_merged.txt'; % Data 02
    case 17
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240509_idS1_0106_merged.txt'; % Data 02
    case 18
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240509_idS2_0013_merged.txt'; % Data 02
    case 19
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240510_idS1_0058_merged.txt'; % Data 02
    case 20
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240510_idS2_0024_merged.txt'; % Data 02
    case 21
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240511_idS1_0132_merged.txt'; % Data 02
    case 22
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240511_idS2_0050_merged.txt'; % Data 02
    case 23
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240513_idS2_2358_merged.txt'; % Data 02
    case 24
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240514_idS1_0115_merged.txt'; % Data 02
    case 25
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240515_idS1_0024_merged.txt'; % Data 02
    case 26
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240515_idS2_0039_merged.txt'; % Data 02
    case 27
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240716_idS2_2334_merged.txt'; % Data 02
    case 28
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240718_idS2_0027_merged.txt'; % Data 02
    case 29
        filename = '../../Data/Go2Sleep/txt/Data_ppg_20240719_idS1_0046_merged.txt'; % Data 02

    case 182 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No182_20250306_tangjing_id17_low_spo2_merged.txt';
	case 183 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No183_20250306_tangjing_id17_low_spo2_merged.txt';
	case 184 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No184_20250306_tangjing_id17_low_spo2_merged.txt';
	case 187
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No187_20250310_tangjing_id17_low_spo2_merged.txt';
	case 188 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No188_20250310_tangjing_id17_low_spo2_merged.txt';
	case 193
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No193_20250317_shaobo_id6_low_spo2_merged.txt';
	case 194 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No194_20250319_david_id20_low_spo2_merged.txt';
	case 195 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No195_20250319_shaobo_id6_low_spo2_merged.txt';
	case 196 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No196_20250319_shaobo_id6_low_spo2_merged.txt';
	case 197 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No197_20250319_shaobo_id6_low_spo2_merged.txt';
	case 198 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No198_20250319_tangjing_id17_low_spo2_merged.txt';
	case 199 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No199_20250319_tangjing_id17_low_spo2_merged.txt';
	case 200 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No200_20250321_wangbiao_id3_low_spo2_merged.txt';
	case 201 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No201_20250321_cassie_id123_low_spo2_merged.txt';
	case 202 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No202_20250321_tangjing_id17_low_spo2_merged.txt';
	case 203 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No203_20250321_tangjing_id17_low_spo2_merged.txt';
	case 204 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No204_20250321_shaobo_id6_low_spo2_merged.txt';
	case 206 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No206_20250326_claudius_id？_low_spo2_merged.txt';
	case 207 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No207_20250326_xiaozhu_id18_low_spo2_merged.txt';
	case 208 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No208_20250331_shaobo_id6_low_spo2_merged.txt';
	case 209 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No209_20250331_shaobo_id6_low_spo2_merged.txt';
	case 210 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No210_20250331_tangjing_id17_low_spo2_merged.txt';
	case 211 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No211_20250331_tangjing_id17_low_spo2_merged.txt';
	case 212 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No212_20250331_tangjing_id17_low_spo2_merged.txt';
	case 213 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No213_20250401_tangjing_id17_low_spo2_merged.txt';
	case 214 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No214_20250401_tangjing_id17_low_spo2_merged.txt';
	case 215 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No215_20250401_cassie_id123_low_spo2_merged.txt';
	case 216 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No216_20250401_cassie_id123_low_spo2_merged.txt';
	case 217 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No217_20250321_shaobo_id6_low_spo2_merged.txt';
	case 218 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No218_20250321_shaobo_id6_low_spo2_merged.txt';
	case 219 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No219_20250326_tangjing_id17_low_spo2_merged.txt';
	case 220 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No220_20250326_tangjing_id17_low_spo2_merged.txt';
	case 221 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No221_20250326_cassie_id123_low_spo2_merged.txt';
	case 222 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No222_20250326_cassie_id123_low_spo2_merged.txt';
	case 223 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No223_20250326_shaobo_id6_low_spo2_merged.txt';
	case 224 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No224_20250410_shaobo_id6_low_spo2_merged.txt';
	case 225 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No225_20250410_shaobo_id6_low_spo2_merged.txt';
	case 226 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No226_20250410_xiaozhu_id18_low_spo2_merged.txt';
	case 227 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No227_20250410_xiaozhu_id18_low_spo2_merged.txt';
	case 228 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No228_20250411_shaobo_id6_low_spo2_merged.txt';
	case 229 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No229_20250411_shaobo_id6_low_spo2_merged.txt';
	case 230 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No230_20250411_tangjing_id17_low_spo2_merged.txt';
	case 231 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No231_20250411_tangjing_id17_low_spo2_merged.txt';
	case 232 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No232_20250411_xiaozhu_id18_low_spo2_merged.txt';
	case 233 
		filename = '../../Data/Go2Sleep/txt/Data_ppg_No233_20250411_xiaozhu_id18_low_spo2_merged.txt';



    case 177
        filename = '/Volumes/79 ALL Group/光电信号采集/指尖绑带采集记录/No177-0206-小猪-指尖绑带-睡眠-0230（6.3.14）/output/Data_ppg_No177_20250206_xiaozhu_id18_sleep_merged.txt';
    case 178
        filename = '/Volumes/79 ALL Group/光电信号采集/指尖绑带采集记录/No178-0208-王彪-指尖绑带-睡眠-0230（6.3.14）/output/Data_ppg_No178_20250208_wangbiao_id3_sleep_merged.txt';
    case 179
        filename = '/Volumes/79 ALL Group/光电信号采集/指尖绑带采集记录/No179-0218-小猪-指尖绑带-睡眠-0230（6.3.14）/output/Data_ppg_No179_20250218_xiaozhu_id18_sleep_merged.txt';
    case 180
        filename = '/Volumes/79 ALL Group/光电信号采集/指尖绑带采集记录/No179-0218-小猪-指尖绑带-睡眠-0230（6.3.14）/output/Data_ppg_No179_20250218_xiaozhu_id18_sleep_merged.txt';


    case 1001
        filename = '../../Data/PPG_Collection/on_fingers/No1-0318-周鹏-指尖绑带-睡眠/output/Data_ppg_No1_20260318_zp_732_sleep_merged.txt';
    case 1002
        filename = '../../Data/PPG_Collection/on_fingers/No2-0317-孙哲俊-指尖绑带-睡眠/output/Data_ppg_No2_20260317_szj_820_sleep_merged.txt';
    case 1003
        filename = '../../Data/PPG_Collection/on_fingers/No3-0318-孙哲俊-指尖绑带-睡眠/output/Data_ppg_No3_20260318_szj_820_sleep_merged.txt';
    case 1004
        filename = '../../Data/PPG_Collection/on_fingers/No4-0319-周鹏-指尖绑带-睡眠/output/Data_ppg_No4_20260319_zp_732_sleep_merged.txt';
    case 1005
        filename = '../../Data/PPG_Collection/on_fingers/No5-0319-孙哲俊-指尖绑带-睡眠/output/Data_ppg_No5_20260319_szj_820_sleep_merged.txt';
    case 1006
        filename = '../../Data/PPG_Collection/on_fingers/No6-0323-杨少波-指尖绑带-睡眠/output/Data_ppg_No6_20260323_ysb_820_sleep_merged.txt';
    case 1007
        filename = '../../Data/PPG_Collection/on_fingers/No7-0323-周鹏-指尖绑带-睡眠/output/Data_ppg_No7_20260323_zp_732_sleep_merged.txt';
    case 1008
        filename = '../../Data/PPG_Collection/on_fingers/No8-0324-杨少波-指尖绑带-睡眠/output/Data_ppg_No8_20260324_ysb_732_sleep_merged.txt';
    case 1009
        filename = '../../Data/PPG_Collection/on_fingers/No9-0325-唐静-指尖绑带-睡眠/output/Data_ppg_No9_20260325_tj_17_sleep_merged.txt';
    case 1010
        filename = '../../Data/PPG_Collection/on_fingers/No10-0325-王彪-指尖绑带-睡眠/output/Data_ppg_No10_20260325_wb_3_sleep_merged.txt';
    case 1011
        filename = '../../Data/PPG_Collection/on_fingers/No11-0326-薛洁-指尖绑带-睡眠/output/Data_ppg_No11_20260326_xj_820_sleep_merged.txt';
    case 1012
        filename = '../../Data/PPG_Collection/on_fingers/No12-0326-王彪-指尖绑带-睡眠/output/Data_ppg_No12_20260326_wb_3_sleep_merged.txt';
    case 1013
        filename = '../../Data/PPG_Collection/on_fingers/No13-0330-王彪-指尖绑带-睡眠/output/Data_ppg_No13_20260330_wb_3_sleep_merged.txt';
    case 1014
        filename = '../../Data/PPG_Collection/on_fingers/No14-0330-薛洁-指尖绑带-睡眠/output/Data_ppg_No14_20260330_xj_820_sleep_merged.txt';
    case 1015
        filename = '../../Data/PPG_Collection/on_fingers/No13-0330-王彪-指尖绑带-睡眠/output/Data_ppg_No13_20260330_wb_3_sleep_merged.txt';
    case 1016
        filename = '../../Data/PPG_Collection/on_fingers/No16-0331-唐静-指尖绑带-睡眠/output/Data_ppg_No16_20260331_tj_17_sleep_merged.txt';
    case 1017
        filename = '../../Data/PPG_Collection/on_fingers/No17-0401-孙哲俊-指尖绑带-睡眠/output/Data_ppg_No17_20260401_szj_821_sleep_merged.txt';
    case 1018
        filename = '../../Data/PPG_Collection/on_fingers/No18-0401-孙哲俊-指尖绑带-睡眠/output/Data_ppg_No18_20260401_szj_820_sleep_merged.txt';
    case 1019
        filename = '../../Data/PPG_Collection/on_fingers/No19-0401-周鹏-指尖绑带-睡眠/output/Data_ppg_No19_20260401_zp_732_sleep_merged.txt';
    case 1020
        filename = '../../Data/PPG_Collection/on_fingers/No20-0403-王彪-指尖绑带-睡眠/output/Data_ppg_No20_20260402_wb_3_LowO2_merged.txt';
    case 1021
        filename = '../../Data/PPG_Collection/on_fingers/No21-0402-杨少波-指尖绑带-睡眠/output/Data_ppg_No21_20260402_ysb_820_LowO2_merged.txt';





   case 2001
        filename = '../../Data/PPG_Collection/Low_SpO2/No1-0324-周鹏-低氧/output2/Data_ppg_No1_20260324_zp_732_LowO2_merged.txt';
   case 2002
        filename = '../../Data/PPG_Collection/Low_SpO2/No2-0325-孙哲俊-低氧/output/Data_ppg_No2_20260325_szj_820_LowO2_merged.txt';
   case 2003
        filename = '../../Data/PPG_Collection/Low_SpO2/No3-0325-周鹏-低氧/output2/Data_ppg_No3_20260325_zp_732_LowO2_merged.txt';
   case 2004
        filename = '../../Data/PPG_Collection/Low_SpO2/No4-0330-孙哲俊-低氧/output2/Data_ppg_No4_20260330_szj_820_LowO2_merged.txt';
   case 2005
        filename = '../../Data/PPG_Collection/Low_SpO2/No5-0330-周鹏-低氧/output2/Data_ppg_No5_20260330_zp_732_LowO2_merged.txt';
   case 2006
        filename = '../../Data/PPG_Collection/Low_SpO2/No6-0331-孙哲俊-低氧/output2/Data_ppg_No6_20260331_szj_820_LowO2_merged.txt';
   case 2007
        filename = '../../Data/PPG_Collection/Low_SpO2/No7-0331-周鹏-低氧/output2/Data_ppg_No7_20260331_zp_732_LowO2_merged.txt';
   case 2008
        filename = '../../Data/PPG_Collection/Low_SpO2/No8-0402-常总-低氧-指尖绑带/output/Data_ppg_No8_20260402_chang_820_LowO2_merged.txt';
   case 2009
        filename = '../../Data/PPG_Collection/Low_SpO2/No4-0330-孙哲俊-低氧/output/Data_ppg_No9_20260402_chang_820_LowO2_merged.txt';
   case 2010
        filename = '../../Data/PPG_Collection/Low_SpO2/No10-0402-常总-低氧-创可贴2/output/Data_ppg_No10_20260402_chang_820_LowO2_merged.txt';
   case 2011
        filename = '../../Data/PPG_Collection/Low_SpO2/No11-0402-常总-低氧-指尖绑带2/output/Data_ppg_No11_20260402_chang_820_LowO2_merged.txt';
   case 2012
        filename = '../../Data/PPG_Collection/Low_SpO2/No12-0402-常总-低氧-指尖套/output/Data_ppg_No12_20260402_chang_820_LowO2_merged.txt';
   case 2013
        filename = '../../Data/PPG_Collection/Low_SpO2/No13-0403-常总-低氧1/output/Data_ppg_No13_20260403_chang_820_LowO2_merged.txt';
   case 2014
        filename = '../../Data/PPG_Collection/Low_SpO2/No14-0403-常总-低氧2/output/Data_ppg_No14_20260403_chang_732_LowO2_merged.txt';



end
end

