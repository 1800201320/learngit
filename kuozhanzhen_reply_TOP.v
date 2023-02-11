`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/11/12 21:29:42
// Design Name: 
// Module Name: kuozhanzhen_reply_TOP
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module kuozhanzhen_reply_TOP(
    input                               sys_clk         ,
    input                               sys_res_n       ,
    
	input								udp_rec_data_key,//普通按键，非触摸按键
    //input                             touch_key       ,//这个触摸按键有失效的，一直按着只能拉高一段时间，之后就会拉低失效，就要重新松手再按
    
    //AD芯片接口
	output								ad_sample_clk   , //ad采样时钟
    input               [7:0]           ad_data_in      , //AD输入数据
    //模拟输入电压超出量程标志(作为指示灯)
    input                               ad_otr          , //0:在量程范围内 1:超出量程
    
    
    //DA芯片接口
    output                              da_re_clk       , //DA(AD9708)驱动时钟,最大支持125Mhz时钟
    output              [7:0]           da_data_in      , //输出给DA的数据
    
    
    //以太网RGMII接口   
    input                               eth_rxc         , //RGMII接收数据时钟
    input                               eth_rx_ctl      , //RGMII输入数据有效信号
    input               [3:0]           eth_rxd         , //RGMII输入数据
    
    output                              eth_txc         , //RGMII发送数据时钟     
    output                              eth_tx_ctl      , //RGMII输出数据有效信号
    output              [3:0]           eth_txd         , //RGMII输出数据          
    output                              eth_res_n       , //以太网芯片复位信号，低电平有效    
    
	
	//指示灯输出
	output				[2:0]			led
	);


//parameter define
//开发板MAC地址 00-11-22-33-44-55
parameter								BOARD_MAC = 48'h00_11_22_33_44_55;
//开发板IP地址 192.168.1.10
parameter								BOARD_IP  = {8'd192,8'd168,8'd1,8'd10};
//目的MAC地址 ff_ff_ff_ff_ff_ff
parameter								DES_MAC   = 48'hff_ff_ff_ff_ff_ff;
//目的IP地址 192.168.1.102
parameter								DES_IP    = {8'd192,8'd168,8'd1,8'd102};
//输入数据IO延时(如果为n,表示延时n*78ps)
parameter								IDELAY_VALUE = 0;



//wire define 
wire	signed			[7:0]			ad_data_out;            //ad输出的数据
wire									ad_data_en;

wire									adsample_clk_5M;		//用于AD采集的时钟
wire									clk_20M;	            //用来产生ad采集的时钟
wire									clk_200M;               //用于IO延时的时钟


wire									udp_rec_en;             //UDP接收的数据使能信号
wire					[31:0]			udp_rec_data;           //UDP接收的数据


wire									trigger_signal;
wire									pulse_effect;
wire	signed			[7:0]			sampl_data;
wire					[12:0]			filter_adudp_rd_data_count;
wire									ad_pulse_fifo_full;
wire									ad_pulse_fifo_empty;

wire					[15:0]			water_deep;
wire									system_work_en;
wire									udptx_key_flag;



//DA数据发送
da_send
#(
    .Freq_control (13'd5000)//DA输出信号频率调节，这个要和AD的采样频率实现有效衔接，采样倍数要满足关系
)
u_da_send
(
    .clk				(sys_clk),//(ad_sample_clk),
    .res_n				(sys_res_n),

    .da_tx_en			(trigger_signal),


    .da_data_in			(da_data_in),
    .da_re_clk			(da_re_clk)
    );




//AD数据接收
ad_res  u_ad_res
//AD采样频率控制，采样频率不能太高，比如500倍采样这种，会出现很多毛刺，因为DA里面的数据是一个周期五十个点
//DA是50倍，AD是500倍，会导致一个点采了十次，就会出现在这个点的十次采样中，每一次的值都会围绕这个值附近出现微小的波动，所以这十个值是不一样的，就出现了干扰噪声，这在频谱上能表现出来，所以不要太高采样，一般要保持在DA的采样倍数之内最好

//罗辉注释：这段注释是建姚师兄做ad-da环回实验时做的注释，和本次实验无关
(
    .clk				(sys_clk),
    .res_n				(sys_res_n),

	.system_work_en		(system_work_en),
    .ad_data_in			(ad_data_in),

    .ad_data_out    	(ad_data_out),
	.ad_sampleclk10K	(ad_sample_clk),
	.ad_data_en			(ad_data_en)
    );



//UDP时钟
clk_pll_udp200M u_clk_pll_udp200M
(
 // Clock out ports
 .clk_out1(clk_200M),     // output clk_out1
 // Status and control signals
 .resetn(sys_res_n), // input resetn
// Clock in ports
 .clk_in1(sys_clk)      // input clk_in1
);


system_work_ctrl	u_system_work_ctrl
(
	.clk				(sys_clk),
	.res_n				(sys_res_n),
	
	.ad_otr_max			(ad_otr),
	.trigger_signal		(trigger_signal),
	.udp_rec_data		(udp_rec_data),
	.udp_rec_en			(udp_rec_en),
	.udp_rec_data_key	(udp_rec_data_key),   //罗辉注释：2023年1月28日21点28分 按下按键系统开始工作
	
	.led				(led),
	.udptx_key_flag		(udptx_key_flag),     //罗辉注释：2023年1月28日21点39分 udp发送标志位（估计),21点51分，看完后觉得是ad信号写使能
	.system_work_en		(system_work_en),
	.water_deep			(water_deep)          //罗辉注释：2023年1月28日21点26分系统控制模块将udp发送的数据传给da_send模块
    );



eth_udp_top 
#(
	//parameter define
	//开发板MAC地址 00-11-22-33-44-55
	.BOARD_MAC			(BOARD_MAC),
	//开发板IP地址 192.168.1.10
	.BOARD_IP			(BOARD_IP),
	//目的MAC地址 ff_ff_ff_ff_ff_ff
	.DES_MAC			(DES_MAC),
	//目的IP地址 192.168.1.102
	.DES_IP				(DES_IP),
	//输入数据IO延时(如果为n,表示延时n*78ps)
	.IDELAY_VALUE		(IDELAY_VALUE)
)
u_eth_udp_top
(
    .clk				(sys_clk),
    .res_n				(sys_res_n),


    //.touch_key       	(touch_key),
    .ad_data_wr_en		(udptx_key_flag),//罗辉注释：2023年2月1日16点37分输入ad信号写使能
	
    .ad_data_in      	(ad_data_in),    //AD输入数据
    .ad_sample_clk_10K	(ad_sample_clk), //AD(AD9280)驱动时钟,最大支持32Mhz时钟
    .clk_200M			(clk_200M),

    .eth_rxc			(eth_rxc),       //RGMII接收数据时钟
    .eth_rx_ctl			(eth_rx_ctl),    //RGMII输入数据有效信号
    .eth_rxd			(eth_rxd),       //RGMII输入数据

    .eth_txc			(eth_txc),       //RGMII发送数据时钟
    .eth_tx_ctl			(eth_tx_ctl),    //RGMII输出数据有效信号
    .eth_txd			(eth_txd),       //RGMII输出数据
    .eth_res_n			(eth_res_n),     //以太网芯片复位信号，低电平有效

	.rec_data			(udp_rec_data),  //罗辉注释：2023年1月28日21点24分udp接受到的数据传给系统控制模块
	.rec_en				(udp_rec_en)     //罗辉注释：2023年1月28日21点24分udp接受到的数据传给系统控制模块有效信号
	);



//脉冲检测模块
pulse_detection_top	u_pulse_detection_top
(
	.clk				(sys_clk),
	.res_n				(sys_res_n),
	
	.sample_data		(ad_data_out),
	.sample_data_en		(ad_data_en),
	
	.pulse_effect		(trigger_signal)
    );
//结束了
//日期
//fast





endmodule
