module YMF278B (
	CLK,
	RST_N,
	EN,
	CE,
	A,
	DI,
	DO,
	RD_N,
	WR_N,
	CS_N,
	IC_N,
	IRQ_N,
	MA,
	MDI,
	MDO,
	MRD_N,
	MWR_N,
	MCS_N,
	MEM_SLOT,
	MIX_FM,
	OUT0_L,
	OUT0_R,
	OUT1_L,
	OUT1_R,
	OUT2_L,
	OUT2_R,
	SND_EN,
	CYCLE1_NEXT
);
	reg _sv2v_0 = 0;
	input CLK;
	input RST_N;
	input EN;
	input CE;
	input [2:0] A;
	input [7:0] DI;
	output wire [7:0] DO;
	input RD_N;
	input WR_N;
	input CS_N;
	input IC_N;
	output wire IRQ_N;
	output wire [20:0] MA;
	input [7:0] MDI;
	output wire [7:0] MDO;
	output wire MRD_N;
	output wire MWR_N;
	output wire [9:0] MCS_N;
	output wire [4:0] MEM_SLOT;
	output wire [5:0] MIX_FM;
	output wire [15:0] OUT0_L;
	output wire [15:0] OUT0_R;
	output wire [15:0] OUT1_L;
	output wire [15:0] OUT1_R;
	output wire [15:0] OUT2_L;
	output wire [15:0] OUT2_R;
	input [2:0] SND_EN;
	output wire CYCLE1_NEXT;
	reg NEW2 = 0;
	reg [7:0] TEST0 = 0;
	reg [7:0] TEST1 = 0;
	reg [4:0] MEMMODE = 0;
	reg [21:0] MEMADDR = 0;
	reg [7:0] MEMDAT = 0;
	reg [5:0] MIXFM = 0;
	reg [5:0] MIXPCM = 0;
	reg LD = 0;
	reg LD2 = 0;
	reg BUSY = 0;
	reg BUSY2 = 0;
	reg [44:0] OP2 = 0;
	reg [65:0] OP3 = 0;
	reg [13:0] OP4 = 0;
	reg [41:0] OP5 = 0;
	reg [33:0] OP6 = 0;
	reg [23:0] OP7 = 0;
	wire [21:0] WD_ADDR;
	reg WD_READ = 0;
	reg [21:0] MEM_A = 0;
	reg [7:0] MEM_D = 0;
	wire [7:0] MEM_Q;
	reg MEM_WR = 0;
	reg MEM_RD = 0;
	reg [7:0] REG_A = 0;
	reg [7:0] REG_D = 0;
	reg [7:0] REG_Q = 0;
	reg REG_WR = 0;
	reg REG_RD = 0;
	wire RES_N = IC_N;
	reg CLK_RES = 0;
	reg RST_N_OLD = 0;
	always @(posedge CLK) begin : sv2v_autoblock_1
		if (CE) begin
			RST_N_OLD <= RST_N;
			CLK_RES <= RST_N & ~RST_N_OLD;
		end
	end
	reg [1:0] CLK_DIV = 0;
	reg [2:0] CYCLE_NUM = 0;
	always @(posedge CLK)
		if (CLK_RES) begin
			CLK_DIV <= 1'sb0;
			CYCLE_NUM <= 1'sb0;
		end
		else if (CE) begin
			CLK_DIV <= CLK_DIV + 2'd1;
			if (CLK_DIV == 2'd3)
				CYCLE_NUM <= CYCLE_NUM + 3'd1;
		end
	wire SLOT0_EN = CYCLE_NUM[2:1] == 2'b01;
	wire SLOT1_EN = CYCLE_NUM[2:1] == 2'b11;
	wire CYCLE0_CE = (~CYCLE_NUM[0] & (CLK_DIV == 2'd3)) & CE;
	wire CYCLE1_CE = (CYCLE_NUM[0] & (CLK_DIV == 2'd3)) & CE;
	wire [1:0] MSX_DIV_NXT = (CE ? CLK_DIV + 2'd1 : CLK_DIV);
	wire [2:0] MSX_CYC_NXT = (CE && (CLK_DIV == 2'd3) ? CYCLE_NUM + 3'd1 : CYCLE_NUM);
	assign CYCLE1_NEXT = MSX_CYC_NXT[0] & (MSX_DIV_NXT == 2'd3);
	wire SLOT0_CE = SLOT0_EN & CYCLE1_CE;
	wire SLOT1_CE = SLOT1_EN & CYCLE1_CE;
	reg [4:0] EVOL_RA = 0;
	reg [4:0] AM_RA = 0;
	reg [4:0] SA_RA = 0;
	reg [4:0] FNUM_RA = 0;
	reg [4:0] LFO_RA = 0;
	reg [4:0] SLOT = 0;
	always @(*) begin
		if (_sv2v_0)
			;
		casex (CYCLE_NUM[2:1])
			2'b0x: begin
				SA_RA = OP2[44-:5];
				FNUM_RA = SLOT;
				AM_RA = SLOT;
				EVOL_RA = OP2[44-:5];
				LFO_RA = SLOT;
			end
			2'b1x: begin
				SA_RA = OP2[44-:5];
				FNUM_RA = OP4[13-:5];
				AM_RA = OP4[13-:5];
				EVOL_RA = OP4[13-:5];
				LFO_RA = OP4[13-:5];
			end
		endcase
	end
	reg [0:23] REG_KB = 0;
	reg [0:23] REG_LOAD = 0;
	reg RST = 0;
	reg [3:0] OP1_OCT = 0;
	reg OP1_PREVERB = 0;
	reg [9:0] OP1_FNUM = 0;
	reg [2:0] OP1_LFO = 0;
	reg [2:0] OP1_VIB = 0;
	reg OP1_LFORST = 0;
	reg [8:0] OP1_WTN = 0;
	reg [3:0] OP1_LOAD_POS = 0;
	reg [2:0] KEY_RAM_D = 0;
	wire [2:0] KEY_RAM_Q;
	reg [21:0] LFO_RAM_D = 0;
	wire [21:0] LFO_RAM_Q;
	wire [15:0] REG_FNUM_Q;
	wire [7:0] REG_LFO_Q;
	localparam RT_PN = 3'd6;
	reg [7:0] rt_q [0:6];
	wire [7:0] REG_PAN_Q = rt_q[RT_PN];
	wire REG_PAN_SEL = (REG_A >= 8'h68) && (REG_A <= 8'h7f);
	localparam RT_WT = 3'd4;
	wire [7:0] REG_WTN_Q = rt_q[RT_WT];
	wire REG_WTN_SEL = (REG_A >= 8'h08) && (REG_A <= 8'h1f);
	function [9:0] YMF278B_PKG_LFOFreqDiv;
		input reg [2:0] LFO;
		reg [10:0] RET;
		begin
			case (LFO)
				3'h0: RET = 10'd1013;
				3'h1: RET = 10'd85;
				3'h2: RET = 10'd54;
				3'h3: RET = 10'd41;
				3'h4: RET = 10'd33;
				3'h5: RET = 10'd29;
				3'h6: RET = 10'd28;
				3'h7: RET = 10'd25;
			endcase
			YMF278B_PKG_LFOFreqDiv = RET - 10'd1;
		end
	endfunction
	localparam [44:0] YMF278B_PKG_OP2_RESET = 45'h000000000000;
	function [22:0] YMF278B_PKG_PhaseCalc;
		input reg [9:0] FNUM;
		input reg [3:0] OCT;
		input reg signed [7:0] PLFO_WAVE;
		reg [26:0] P;
		reg [3:0] S;
		reg [10:0] F;
		reg [11:0] FM;
		begin
			S = OCT ^ 4'h8;
			F = 11'h400 + FNUM;
			FM = {{4 {PLFO_WAVE[7]}}, PLFO_WAVE};
			P = {15'b000000000000000, {1'b0, F} + FM} << (S - 1);
			YMF278B_PKG_PhaseCalc = P[26:4];
		end
	endfunction
	function [7:0] YMF278B_PKG_VIBCalc;
		input reg [7:0] DATA;
		input reg [2:0] VIB;
		reg [5:0] FM6;
		reg [3:0] A;
		reg [1:0] D6;
		reg [2:0] D3;
		reg [6:0] MAG;
		reg NEG;
		begin
			FM6 = DATA[7:2];
			if (FM6[4])
				FM6 = FM6 ^ 6'h1f;
			NEG = FM6[5];
			A = FM6[3:0];
			D6 = (A >= 4'd12 ? 2'd2 : (A >= 4'd6 ? 2'd1 : 2'd0));
			D3 = (A == 4'd15 ? 3'd5 : (A >= 4'd12 ? 3'd4 : (A >= 4'd9 ? 3'd3 : (A >= 4'd6 ? 3'd2 : (A >= 4'd3 ? 3'd1 : 3'd0)))));
			case (VIB)
				3'h0: MAG = 7'd0;
				3'h1: MAG = {5'b00000, D6};
				3'h2: MAG = {5'b00000, A[3:2]};
				3'h3: MAG = {4'b0000, D3};
				3'h4: MAG = {4'b0000, A[3:1]};
				3'h5: MAG = {3'b000, A};
				3'h6: MAG = {2'b00, A, 1'b0};
				3'h7: MAG = {1'b0, A, 2'b00};
			endcase
			YMF278B_PKG_VIBCalc = (NEG ? ~{1'b0, MAG} + 8'd1 : {1'b0, MAG});
		end
	endfunction
	reg [9:0] OP1_LFO_DIV = 0;
	reg [7:0] OP1_LFO_DATA = 0;
	reg [0:23] REG_KB_OLD = 0;
	reg [7:0] PLFO_WAVE = 0;
	reg [22:0] PHASE = 0;
	reg [7:0] NEW_LFO_DATA = 0;
	reg [9:0] NEW_LFO_DIV = 0;
	reg [3:0] NEW_LOAD_POS = 0;
	always @(posedge CLK or negedge RST_N) begin : sv2v_autoblock_2
		if (!RST_N) begin
			{OP1_OCT, OP1_FNUM} <= 1'sb0;
			{OP1_LFO, OP1_VIB} <= 1'sb0;
			OP1_LFORST <= 0;
			OP1_WTN <= 1'sb0;
			REG_KB <= {24 {1'b0}};
			REG_KB_OLD <= {24 {1'b0}};
			REG_LOAD <= {24 {1'b0}};
			SLOT <= 1'sb0;
			RST <= 1;
			OP2 <= YMF278B_PKG_OP2_RESET;
		end
		else if (!RES_N) begin
			{OP1_OCT, OP1_FNUM} <= 1'sb0;
			{OP1_LFO, OP1_VIB} <= 1'sb0;
			OP1_LFORST <= 0;
			OP1_WTN <= 1'sb0;
			REG_KB <= {24 {1'b0}};
			REG_KB_OLD <= {24 {1'b0}};
			REG_LOAD <= {24 {1'b0}};
			SLOT <= 1'sb0;
			RST <= 1;
			OP2 <= YMF278B_PKG_OP2_RESET;
		end
		else begin
			if (CYCLE0_CE)
				case (CYCLE_NUM[2:1])
					2'b00: begin
						{OP1_OCT, OP1_PREVERB, OP1_FNUM} <= REG_FNUM_Q[15:1];
						{OP1_LFO, OP1_VIB} <= REG_LFO_Q[5:0];
						OP1_LFORST <= REG_PAN_Q[5];
						OP1_WTN <= {REG_FNUM_Q[0], REG_WTN_Q};
						{OP1_LOAD_POS, OP1_LFO_DIV, OP1_LFO_DATA} <= LFO_RAM_Q;
					end
				endcase
			if (CYCLE1_CE) begin
				if (REG_PAN_SEL && REG_WR)
					REG_KB[REG_A[4:0] - 5'h08] <= REG_D[7];
				if (REG_WTN_SEL && REG_WR)
					REG_LOAD[REG_A[4:0] - 5'h08] <= 1;
			end
			if (SLOT1_CE) begin
				KEY_RAM_D[1:0] <= 1'sb0;
				if (REG_KB[SLOT] && !REG_KB_OLD[SLOT])
					KEY_RAM_D[0] <= 1;
				if (!REG_KB[SLOT] && REG_KB_OLD[SLOT])
					KEY_RAM_D[1] <= 1;
				REG_KB_OLD[SLOT] <= REG_KB[SLOT];
				if (REG_LOAD[SLOT])
					REG_LOAD[SLOT] <= 0;
			end
			PLFO_WAVE <= YMF278B_PKG_VIBCalc(OP1_LFO_DATA, OP1_VIB);
			PHASE = YMF278B_PKG_PhaseCalc(OP1_FNUM, OP1_OCT, PLFO_WAVE);
			if (SLOT1_CE) begin
				OP2[44-:5] <= SLOT;
				OP2[39] <= RST;
				OP2[38] <= KEY_RAM_Q[0];
				OP2[37] <= KEY_RAM_Q[1];
				OP2[36] <= KEY_RAM_Q[2];
				OP2[35-:23] <= PHASE;
				OP2[12-:9] <= OP1_WTN;
				OP2[3-:4] <= OP1_LOAD_POS;
				SLOT <= SLOT + 5'd1;
				if (SLOT == 5'd23) begin
					SLOT <= 1'sb0;
					RST <= 0;
				end
			end
			if (SLOT1_CE) begin
				if (!OP1_LFO_DIV) begin
					NEW_LFO_DIV = YMF278B_PKG_LFOFreqDiv(OP1_LFO);
					NEW_LFO_DATA = OP1_LFO_DATA + 8'd1;
				end
				else begin
					NEW_LFO_DIV = OP1_LFO_DIV - 10'd1;
					NEW_LFO_DATA = OP1_LFO_DATA;
				end
				if (OP1_LFORST) begin
					NEW_LFO_DIV = 1'sb0;
					NEW_LFO_DATA = 1'sb0;
				end
				if (KEY_RAM_Q[2])
					NEW_LOAD_POS = OP1_LOAD_POS + 4'd1;
				else
					NEW_LOAD_POS = 1'sb0;
				KEY_RAM_D[2] <= KEY_RAM_Q[2];
				if (NEW_LOAD_POS == 4'd12)
					KEY_RAM_D[2] <= 0;
				else if (REG_LOAD[SLOT])
					KEY_RAM_D[2] <= 1;
				LFO_RAM_D <= {NEW_LOAD_POS, NEW_LFO_DIV, NEW_LFO_DATA};
			end
		end
	end
	OPL4_KEY_RAM KEY_RAM(
		.CLK(CLK),
		.WRADDR(OP2[44-:5]),
		.DATA(KEY_RAM_D),
		.WREN(SLOT1_CE),
		.RDADDR(SLOT),
		.Q(KEY_RAM_Q)
	);
	OPL4_LFO_RAM LFO_RAM(
		.CLK(CLK),
		.WRADDR(OP2[44-:5]),
		.DATA(LFO_RAM_D),
		.WREN(SLOT1_CE),
		.RDADDR(LFO_RA),
		.Q(LFO_RAM_Q)
	);
	reg [1:0] OP2_DATA_BIT = 0;
	reg [21:0] OP2_SA = 0;
	reg [15:0] OP2_LA = 0;
	reg [15:0] OP2_EA = 0;
	wire [11:0] EVOL_RAM_Q;
	reg [13:0] PHASE_FRAC_RAM_D = 0;
	wire [13:0] PHASE_FRAC_RAM_Q;
	wire [15:0] REG_EA_Q;
	wire [15:0] REG_LA_Q;
	wire [23:0] REG_SA_Q;
	reg [15:0] SO_RAM_D = 0;
	wire [15:0] SO_RAM_Q;
	reg [1:0] WD_DATA_LEN = 0;
	reg [21:0] WD_SA = 0;
	localparam [65:0] YMF278B_PKG_OP3_RESET = 66'h00000000000000000;
	reg [1:0] OP2_EST = 0;
	reg [9:0] OP2_EVOL = 0;
	reg [8:0] PHASE_INT = 0;
	reg [13:0] PHASE_FRAC = 0;
	reg [13:0] CUR_PHASE_FRAC = 0;
	reg [15:0] CUR_SO = 0;
	reg [15:0] NEXT_SO = 0;
	reg [15:0] NEW_SAO = 0;
	reg COMP = 0;
	reg ALLOW = 0;
	always @(posedge CLK or negedge RST_N) begin : sv2v_autoblock_3
		if (!RST_N) begin
			OP3 <= YMF278B_PKG_OP3_RESET;
			OP2_DATA_BIT <= 1'sb0;
			OP2_SA <= 1'sb0;
			OP2_LA <= 1'sb0;
			OP2_EA <= 1'sb0;
			WD_READ <= 0;
		end
		else if (!RES_N) begin
			OP3 <= YMF278B_PKG_OP3_RESET;
			OP2_DATA_BIT <= 1'sb0;
			OP2_SA <= 1'sb0;
			OP2_LA <= 1'sb0;
			OP2_EA <= 1'sb0;
			WD_READ <= 0;
		end
		else begin
			if (CYCLE0_CE) begin
				{OP2_DATA_BIT, OP2_SA} <= (OP2[36] ? {2'b00, ((OP2[12:11] == 2'b11) && (MEMMODE[4:2] != 3'd0) ? ({MEMMODE[4:2], 19'd0} + {12'b000000000000, OP2[10:4], 3'b000}) + {13'b0000000000000, OP2[10:4], 2'b00} : {10'b0000000000, OP2[12-:9], 3'b000} + {11'b00000000000, OP2[12-:9], 2'b00})} + OP2[3-:4] : REG_SA_Q);
				OP2_LA <= REG_LA_Q;
				OP2_EA <= ~REG_EA_Q + 16'd1;
				case (CYCLE_NUM[2:1])
					2'b00: {OP2_EST, OP2_EVOL} <= EVOL_RAM_Q;
				endcase
			end
			CUR_SO = (OP2[38] ? {16 {1'sb0}} : SO_RAM_Q);
			if (OP2[39] || OP2[36])
				{PHASE_INT, PHASE_FRAC} = 1'sb0;
			else
				{PHASE_INT, PHASE_FRAC} = {9'b000000000, CUR_PHASE_FRAC} + OP2[35-:23];
			NEXT_SO = CUR_SO + {7'b0000000, PHASE_INT};
			CUR_PHASE_FRAC = (OP2[38] ? {14 {1'sb0}} : PHASE_FRAC_RAM_Q);
			ALLOW = 1;
			if (SLOT1_CE) begin
				if (OP2[39] || OP2[36]) begin
					NEW_SAO = 1'sb0;
					ALLOW = 0;
				end
				else if ((OP2_EVOL >= 10'h3c0) && !OP2[38]) begin
					NEW_SAO = 1'sb0;
					ALLOW = 0;
				end
				else begin
					NEW_SAO = NEXT_SO;
					if (NEXT_SO >= OP2_EA)
						NEW_SAO = NEXT_SO + (OP2_LA - OP2_EA);
				end
				SO_RAM_D <= NEW_SAO;
				OP3[65-:5] <= OP2[44-:5];
				OP3[60] <= OP2[39];
				OP3[59] <= OP2[38];
				OP3[58] <= OP2[37];
				OP3[57] <= OP2[36];
				OP3[56-:4] <= OP2[3-:4];
				OP3[52] <= ALLOW;
				OP3[37-:16] <= (OP2[36] ? 16'h0000 : CUR_SO);
				OP3[51-:14] <= (OP2[36] ? 14'h0000 : CUR_PHASE_FRAC);
				WD_SA <= OP2_SA;
				WD_DATA_LEN <= OP2_DATA_BIT;
				WD_READ <= ALLOW | OP2[36];
				PHASE_FRAC_RAM_D <= (ALLOW ? PHASE_FRAC : {14 {1'sb0}});
			end
		end
	end
	OPL4_SO_RAM SO_RAM(
		.CLK(CLK),
		.WRADDR(OP3[65-:5]),
		.DATA(SO_RAM_D),
		.WREN(SLOT1_CE),
		.RDADDR(OP2[44-:5]),
		.Q(SO_RAM_Q)
	);
	OPL4_PHASE_RAM PHASE_FRAC_RAM(
		.CLK(CLK),
		.WRADDR(OP3[65-:5]),
		.DATA(PHASE_FRAC_RAM_D),
		.WREN(SLOT1_CE),
		.RDADDR(OP2[44-:5]),
		.Q(PHASE_FRAC_RAM_Q)
	);
	wire [21:0] MOD_PHASE_CURR = {16'h0000, OP3[51:46]};
	wire [15:0] MOD_PHASE_INTEGER = MOD_PHASE_CURR[21:6];
	wire [16:0] SO_MOD = {1'b0, OP3[37-:16] + (!CYCLE_NUM[2] ? 16'd0 : 16'd1)};
	wire [21:0] SO_MOD_BY_1 = {{5 {SO_MOD[16]}}, SO_MOD};
	wire [21:0] SO_MOD_BY_1_5 = {{5 {SO_MOD[16]}}, SO_MOD} + {{6 {SO_MOD[16]}}, SO_MOD[16:1]};
	wire [21:0] SO_MOD_BY_2 = {{4 {SO_MOD[16]}}, SO_MOD, 1'b0};
	wire [21:0] WD_OFFS = (WD_DATA_LEN == 2'h0 ? SO_MOD_BY_1 : (WD_DATA_LEN == 2'h1 ? SO_MOD_BY_1_5 : SO_MOD_BY_2));
	assign WD_ADDR = (WD_SA + WD_OFFS) + (!CYCLE_NUM[1] ? 16'd0 : 16'd1);
	assign MEM_SLOT = OP3[65-:5];
	assign MIX_FM = MIXFM;
	reg [1:0] OP4_DATA_LEN = 0;
	reg OP4_SO0_CURR = 0;
	reg OP4_SO0_NEXT = 0;
	reg [15:0] OP4_WD = 0;
	localparam [13:0] YMF278B_PKG_OP4_RESET = 14'h0000;
	reg [15:0] WD = 0;
	reg SO0_CURR = 0;
	reg SO0_NEXT = 0;
	always @(posedge CLK or negedge RST_N) begin : sv2v_autoblock_4
		if (!RST_N) begin
			OP4 <= YMF278B_PKG_OP4_RESET;
			OP4_WD <= 1'sb0;
		end
		else if (!RES_N) begin
			OP4 <= YMF278B_PKG_OP4_RESET;
			OP4_WD <= 1'sb0;
		end
		else begin
			if (CYCLE1_CE)
				case (CYCLE_NUM[2:1])
					2'h1: begin
						WD[15:8] <= MEM_D;
						SO0_CURR <= SO_MOD[0];
					end
					2'h2: WD[7:0] <= MEM_D;
				endcase
			if (SLOT1_CE) begin
				OP4[13-:5] <= OP3[65-:5];
				OP4[8] <= OP3[60];
				OP4[7] <= OP3[59];
				OP4[6] <= OP3[58];
				OP4[5-:6] <= MOD_PHASE_CURR[5:0];
				OP4_WD <= WD;
				OP4_DATA_LEN <= WD_DATA_LEN;
				OP4_SO0_CURR <= SO0_CURR;
				OP4_SO0_NEXT <= SO0_NEXT;
			end
		end
	end
	reg [3:0] OP4_AR = 0;
	reg [3:0] OP4_D1R = 0;
	reg [3:0] OP4_D2R = 0;
	reg [3:0] OP4_RR = 0;
	reg [3:0] OP4_RC = 0;
	reg [3:0] OP4_DL = 0;
	reg [3:0] OP4_OCT = 0;
	reg OP4_FNUM9 = 0;
	reg [9:0] OP4_EVOL = 0;
	reg [1:0] OP4_EST = 0;
	reg [18:0] SCNT = 0;
	always @(posedge CLK or negedge RST_N)
		if (!RST_N)
			SCNT <= 1'sb0;
		else if (!RES_N)
			SCNT <= 1'sb0;
		else if (SLOT1_CE) begin
			if (OP4[13-:5] == 5'd23)
				SCNT <= SCNT + 1'd1;
		end
	reg [5:0] EFF_RATE = 0;
	reg EFF_RATE_OVR = 0;
	reg ENV_STEP = 0;
	reg [3:0] ENV_INC = 0;
	localparam [1:0] YMF278B_PKG_EST_ATTACK = 2'b00;
	localparam [1:0] YMF278B_PKG_EST_DECAY1 = 2'b01;
	localparam [1:0] YMF278B_PKG_EST_DECAY2 = 2'b10;
	localparam [1:0] YMF278B_PKG_EST_RELEASE = 2'b11;
	function [6:0] YMF278B_PKG_EffRateCalc;
		input reg [3:0] RATE;
		input reg [3:0] RC;
		input reg [3:0] OCT;
		input reg FNUM9;
		reg [5:0] RES;
		reg [5:0] TEMP;
		reg [6:0] KEY_EG_SCALE;
		reg [6:0] TEMP2;
		begin
			TEMP = {2'b00, RC} + {OCT[3], OCT[3], OCT};
			if (RC == 4'hf)
				KEY_EG_SCALE = 1'sb0;
			else
				KEY_EG_SCALE = {TEMP, FNUM9};
			if (RATE == 4'h0)
				TEMP2 = 7'h00;
			else if (RATE == 4'hf)
				TEMP2 = 7'h3f;
			else
				TEMP2 = {1'b0, RATE, 2'b00} + KEY_EG_SCALE;
			RES = (TEMP2[6] ? 6'h3f : TEMP2[5:0]);
			YMF278B_PKG_EffRateCalc = {TEMP2[6], RES};
		end
	endfunction
	localparam [2047:0] YMF278B_PKG_EncIncTbl = 2048'h101010101010101010101010101010101110111011101110101010101011101011101110111111101010101010111010111011101111111010101010101110101110111011111110101010101011101011101110111111101010101010111010111011101111111010101010101110101110111011111110101010101011101011101110111111101010101010111010111011101111111010101010101110101110111011111110101010101011101011101110111111111111111111211121212121212221222222222222224222424242424244424444444444444484448484848484888488888888888888888888888888888888888;
	function [3:0] YMF278B_PKG_EnvInc;
		input reg [17:0] CNT;
		input reg [5:0] ERATE;
		reg [2:0] IDX;
		begin
			case (ERATE[5:2])
				4'hc: IDX = CNT[14:12];
				4'hd: IDX = CNT[15:13];
				4'he: IDX = CNT[16:14];
				4'hf: IDX = CNT[17:15];
				default: IDX = CNT[13:11];
			endcase
			YMF278B_PKG_EnvInc = YMF278B_PKG_EncIncTbl[(511 - {ERATE, IDX}) * 4+:4];
		end
	endfunction
	function YMF278B_PKG_EnvStep;
		input reg [17:0] CNT;
		input reg [5:0] ERATE;
		reg RET;
		begin
			case (ERATE[5:2])
				4'h0: RET = ~|CNT[10:0];
				4'h1: RET = ~|CNT[9:0];
				4'h2: RET = ~|CNT[8:0];
				4'h3: RET = ~|CNT[7:0];
				4'h4: RET = ~|CNT[6:0];
				4'h5: RET = ~|CNT[5:0];
				4'h6: RET = ~|CNT[4:0];
				4'h7: RET = ~|CNT[3:0];
				4'h8: RET = ~|CNT[2:0];
				4'h9: RET = ~|CNT[1:0];
				4'ha: RET = ~|CNT[0:0];
				default: RET = 1;
			endcase
			YMF278B_PKG_EnvStep = RET;
		end
	endfunction
	reg [3:0] RATE = 0;
	always @(*) begin : sv2v_autoblock_5
		if (_sv2v_0)
			;
		case (OP4_EST)
			YMF278B_PKG_EST_ATTACK: RATE = OP4_AR;
			YMF278B_PKG_EST_DECAY1: RATE = OP4_D1R;
			YMF278B_PKG_EST_DECAY2: RATE = OP4_D2R;
			YMF278B_PKG_EST_RELEASE: RATE = OP4_RR;
		endcase
		if ((OP4_EST == YMF278B_PKG_EST_RELEASE) && OP4[7])
			RATE = OP4_AR;
		else if ((OP4_EST != YMF278B_PKG_EST_RELEASE) && OP4[6])
			RATE = OP4_RR;
		{EFF_RATE_OVR, EFF_RATE} = YMF278B_PKG_EffRateCalc(RATE, OP4_RC, OP4_OCT, OP4_FNUM9);
		ENV_STEP <= YMF278B_PKG_EnvStep(SCNT[18:1], EFF_RATE);
		ENV_INC <= YMF278B_PKG_EnvInc(SCNT[18:1], EFF_RATE);
	end
	reg [7:0] OP4_LFO_DATA = 0;
	reg [2:0] OP4_AM = 0;
	reg [11:0] EVOL_RAM_D = 0;
	localparam RT_AM = 3'd3;
	wire [7:0] REG_AM_Q = rt_q[RT_AM];
	localparam RT_R0 = 3'd0;
	wire [7:0] REG_RATE0_Q = rt_q[RT_R0];
	localparam RT_R1 = 3'd1;
	wire [7:0] REG_RATE1_Q = rt_q[RT_R1];
	localparam RT_R2 = 3'd2;
	wire [7:0] REG_RATE2_Q = rt_q[RT_R2];
	function [7:0] YMF278B_PKG_AMCalc;
		input reg [7:0] DATA;
		input reg [2:0] AM;
		reg [6:0] TRI;
		reg [9:0] S5;
		reg [8:0] S3;
		begin
			TRI = (DATA[7] ? ~DATA[6:0] : DATA[6:0]);
			S5 = {3'b000, TRI} + {1'b0, TRI, 2'b00};
			S3 = {2'b00, TRI} + {1'b0, TRI, 1'b0};
			case (AM)
				3'h0: YMF278B_PKG_AMCalc = 8'd0;
				3'h1: YMF278B_PKG_AMCalc = {3'b000, S5[9:5]};
				3'h2: YMF278B_PKG_AMCalc = {3'b000, TRI[6:2]};
				3'h3: YMF278B_PKG_AMCalc = {2'b00, S5[9:4]};
				3'h4: YMF278B_PKG_AMCalc = {2'b00, S3[8:3]};
				3'h5: YMF278B_PKG_AMCalc = {2'b00, TRI[6:1]};
				3'h6: YMF278B_PKG_AMCalc = {1'b0, S5[9:3]};
				3'h7: YMF278B_PKG_AMCalc = {1'b0, TRI};
			endcase
		end
	endfunction
	localparam [41:0] YMF278B_PKG_OP5_RESET = 42'h00000000000;
	reg [10:0] ATTACK_VOL_CALC = 0;
	reg [10:0] DECAY_VOL_CALC = 0;
	reg [9:0] NEW_EVOL = 0;
	reg [1:0] NEW_EST = 0;
	always @(posedge CLK or negedge RST_N) begin : sv2v_autoblock_6
		if (!RST_N) begin
			OP5 <= YMF278B_PKG_OP5_RESET;
			{OP4_AR, OP4_D1R, OP4_D2R, OP4_RR, OP4_RC, OP4_DL} <= 1'sb0;
			{OP4_OCT, OP4_FNUM9} <= 1'sb0;
			{OP4_EST, OP4_EVOL} <= 1'sb0;
		end
		else if (!RES_N) begin
			OP5 <= YMF278B_PKG_OP5_RESET;
			{OP4_AR, OP4_D1R, OP4_D2R, OP4_RR, OP4_RC, OP4_DL} <= 1'sb0;
			{OP4_OCT, OP4_FNUM9} <= 1'sb0;
			{OP4_EST, OP4_EVOL} <= 1'sb0;
		end
		else begin
			if (CYCLE0_CE) begin
				{OP4_AR, OP4_D1R} <= REG_RATE0_Q;
				{OP4_DL, OP4_D2R} <= REG_RATE1_Q;
				{OP4_RC, OP4_RR} <= REG_RATE2_Q;
				OP4_AM <= REG_AM_Q[2:0];
				case (CYCLE_NUM[2:1])
					2'b10: begin
						OP4_OCT <= REG_FNUM_Q[15:12];
						OP4_FNUM9 <= REG_FNUM_Q[10];
						{OP4_EST, OP4_EVOL} <= EVOL_RAM_Q;
						OP4_LFO_DATA <= LFO_RAM_Q[7:0];
					end
				endcase
			end
			if (SLOT1_CE) begin
				NEW_EVOL = OP4_EVOL;
				NEW_EST = OP4_EST;
				ATTACK_VOL_CALC = {1'b0, OP4_EVOL} + (ENV_STEP ? $signed($signed(~{1'b0, OP4_EVOL}) * $unsigned(ENV_INC)) : 11'd0);
				DECAY_VOL_CALC = {1'b0, OP4_EVOL} + (ENV_STEP ? {7'b0000000, ENV_INC} : 11'd0);
				if (OP4[8]) begin
					NEW_EVOL = 10'h3ff;
					NEW_EST = YMF278B_PKG_EST_RELEASE;
				end
				else if ((OP4_EST == YMF278B_PKG_EST_RELEASE) && OP4[7]) begin
					NEW_EVOL = (EFF_RATE_OVR ? 10'h000 : 10'h280);
					NEW_EST = YMF278B_PKG_EST_ATTACK;
				end
				else if ((OP4_EST != YMF278B_PKG_EST_RELEASE) && OP4[6])
					NEW_EST = YMF278B_PKG_EST_RELEASE;
				else
					case (OP4_EST)
						YMF278B_PKG_EST_ATTACK: begin
							if (!ATTACK_VOL_CALC[10])
								NEW_EVOL = ATTACK_VOL_CALC[9:0];
							else
								NEW_EVOL = 10'h000;
							if (!OP4_EVOL)
								NEW_EST = YMF278B_PKG_EST_DECAY1;
						end
						YMF278B_PKG_EST_DECAY1: begin
							if (!DECAY_VOL_CALC[10])
								NEW_EVOL = DECAY_VOL_CALC[9:0];
							else
								NEW_EVOL = 10'h3ff;
							if (OP4_EVOL[9:6] == OP4_DL)
								NEW_EST = YMF278B_PKG_EST_DECAY2;
						end
						YMF278B_PKG_EST_DECAY2:
							if (!DECAY_VOL_CALC[10])
								NEW_EVOL = DECAY_VOL_CALC[9:0];
							else
								NEW_EVOL = 10'h3ff;
						YMF278B_PKG_EST_RELEASE:
							if (!DECAY_VOL_CALC[10])
								NEW_EVOL = DECAY_VOL_CALC[9:0];
							else
								NEW_EVOL = 10'h3ff;
					endcase
				EVOL_RAM_D <= {NEW_EST, NEW_EVOL};
				OP5[41-:5] <= OP4[13-:5];
				OP5[36] <= OP4[8];
				OP5[35] <= OP4[7];
				OP5[34] <= OP4[6];
				OP5[17-:10] <= NEW_EVOL;
				OP5[33-:16] <= (OP4_DATA_LEN == 2'b00 ? {OP4_WD[15:8], 8'h00} : (OP4_DATA_LEN == 2'b01 ? (!OP4_SO0_CURR ? {OP4_WD[15:8], OP4_WD[7:4], 4'h0} : {OP4_WD[7:0], OP4_WD[11:8], 4'h0}) : OP4_WD));
				OP5[7-:8] <= YMF278B_PKG_AMCalc(OP4_LFO_DATA, OP4_AM);
			end
		end
	end
	OPL4_EVOL_RAM EVOL_RAM(
		.CLK(CLK),
		.WRADDR(OP5[41-:5]),
		.DATA(EVOL_RAM_D),
		.WREN(SLOT1_CE),
		.RDADDR(EVOL_RA),
		.Q(EVOL_RAM_Q)
	);
	reg [6:0] OP5_TL = 0;
	reg OP5_LDIR = 0;
	localparam RT_LV = 3'd5;
	wire [7:0] REG_LEVEL_Q = rt_q[RT_LV];
	reg [16:0] TL_RAM_D = 0;
	wire [16:0] TL_RAM_Q;
	function [9:0] YMF278B_PKG_LevelAddTLALFO;
		input reg [9:0] LEVEL;
		input reg [9:0] TL;
		input reg [7:0] ALFO;
		reg [10:0] SUM;
		begin
			SUM = ({1'b0, LEVEL} + {1'b0, TL}) + {3'b000, ALFO};
			YMF278B_PKG_LevelAddTLALFO = (!SUM[10] ? SUM[9:0] : 10'h3ff);
		end
	endfunction
	localparam [33:0] YMF278B_PKG_OP6_RESET = 34'h000000000;
	reg [6:0] TL_INT = 0;
	reg [9:0] TL_FRAC = 0;
	always @(posedge CLK or negedge RST_N) begin : sv2v_autoblock_7
		if (!RST_N) begin
			OP6 <= YMF278B_PKG_OP6_RESET;
			{OP5_TL, OP5_LDIR} <= 1'sb0;
		end
		else if (!RES_N) begin
			OP6 <= YMF278B_PKG_OP6_RESET;
			{OP5_TL, OP5_LDIR} <= 1'sb0;
		end
		else begin
			if (CYCLE0_CE)
				{OP5_TL, OP5_LDIR} <= REG_LEVEL_Q;
			{TL_INT, TL_FRAC} = TL_RAM_Q;
			if (SLOT1_CE) begin
				if (OP5_LDIR)
					TL_RAM_D <= {OP5_TL, 10'h000};
				else if (TL_INT > OP5_TL)
					TL_RAM_D <= {TL_INT, TL_FRAC} + 17'd19;
				else if (TL_INT < OP5_TL)
					TL_RAM_D <= {TL_INT, TL_FRAC} - 17'd38;
				else
					TL_RAM_D <= {TL_INT, TL_FRAC};
				OP6[33-:5] <= OP5[41-:5];
				OP6[28] <= OP5[36];
				OP6[27] <= OP5[35];
				OP6[26] <= OP5[34];
				OP6[9-:10] <= YMF278B_PKG_LevelAddTLALFO(OP5[17-:10], {TL_INT, TL_FRAC[9:8]}, OP5[7-:8]);
				OP6[25-:16] <= OP5[33-:16];
			end
		end
	end
	OPL4_TL_RAM TL_RAM(
		.CLK(CLK),
		.WRADDR(OP6[33-:5]),
		.DATA(TL_RAM_D),
		.WREN(SLOT1_CE),
		.RDADDR(OP5[41-:5]),
		.Q(TL_RAM_Q)
	);
	localparam [23:0] YMF278B_PKG_OP7_RESET = 24'h000000;
	function signed [15:0] YMF278B_PKG_VolCalc;
		input reg signed [15:0] WAVE;
		input reg [9:0] LEVEL;
		reg signed [24:0] MULT;
		reg signed [15:0] RES;
		begin
			MULT = WAVE * $signed({3'b001, ~LEVEL[5:0]});
			RES = $signed(MULT[22:7]) >>> LEVEL[9:6];
			YMF278B_PKG_VolCalc = RES;
		end
	endfunction
	always @(posedge CLK or negedge RST_N)
		if (!RST_N)
			OP7 <= YMF278B_PKG_OP7_RESET;
		else if (!RES_N)
			OP7 <= YMF278B_PKG_OP7_RESET;
		else if (SLOT1_CE) begin
			OP7[23-:5] <= OP6[33-:5];
			OP7[18] <= OP6[28];
			OP7[17] <= OP6[27];
			OP7[16] <= OP6[26];
			OP7[15-:16] <= YMF278B_PKG_VolCalc(OP6[25-:16], OP6[9-:10]);
		end
	reg [3:0] OP7_PAN = 0;
	reg OP7_CH = 0;
	reg [17:0] ACC_L = 0;
	reg [17:0] ACC_R = 0;
	function signed [15:0] YMF278B_PKG_PanLCalc;
		input reg signed [15:0] WAVE;
		input reg [3:0] PAN;
		reg [3:0] S;
		reg [15:0] TEMP;
		begin
			S = 4'd0 + PAN;
			TEMP = $signed($signed(WAVE) >>> {S[2:0], 1'b0});
			YMF278B_PKG_PanLCalc = (PAN == 4'h0 ? WAVE : (PAN == 4'h8 ? 16'h0000 : (PAN[3] ? WAVE : $signed(TEMP))));
		end
	endfunction
	function signed [15:0] YMF278B_PKG_PanRCalc;
		input reg signed [15:0] WAVE;
		input reg [3:0] PAN;
		reg [3:0] S;
		reg [15:0] TEMP;
		begin
			S = 4'd0 - PAN;
			TEMP = $signed($signed(WAVE) >>> {S[2:0], 1'b0});
			YMF278B_PKG_PanRCalc = (PAN == 4'h0 ? WAVE : (PAN == 4'h8 ? 16'h0000 : (!PAN[3] ? WAVE : $signed(TEMP))));
		end
	endfunction
	reg [4:0] S = 0;
	reg signed [15:0] TEMP = 0;
	reg signed [15:0] PAN_L = 0;
	reg signed [15:0] PAN_R = 0;
	always @(posedge CLK or negedge RST_N) begin : sv2v_autoblock_8
		if (!RST_N) begin
			OP7_PAN <= 1'sb0;
			ACC_L <= 0;
			ACC_R <= 0;
		end
		else if (!RES_N) begin
			OP7_PAN <= 1'sb0;
			ACC_L <= 0;
			ACC_R <= 0;
		end
		else begin
			if (CYCLE0_CE)
				{OP7_CH, OP7_PAN} <= REG_PAN_Q[4:0];
			S = OP7[23-:5];
			TEMP = (!OP7_CH ? OP7[15-:16] : {16 {1'sb0}});
			PAN_L = YMF278B_PKG_PanLCalc(TEMP, OP7_PAN);
			PAN_R = YMF278B_PKG_PanRCalc(TEMP, OP7_PAN);
			if (SLOT1_CE) begin
				if (S == 5'd0) begin
					ACC_L <= {{2 {PAN_L[15]}}, PAN_L[15:0]};
					ACC_R <= {{2 {PAN_R[15]}}, PAN_R[15:0]};
				end
				else begin
					ACC_L <= ACC_L + {{2 {PAN_L[15]}}, PAN_L[15:0]};
					ACC_R <= ACC_R + {{2 {PAN_R[15]}}, PAN_R[15:0]};
				end
			end
		end
	end
	reg [15:0] PCM_L = 0;
	reg [15:0] PCM_R = 0;
	function signed [15:0] YMF278B_PKG_TrimWave;
		input reg signed [17:0] WAVE;
		YMF278B_PKG_TrimWave = (WAVE[17] && (WAVE[16:15] != 2'b11) ? 16'h8000 : (!WAVE[17] && (WAVE[16:15] != 2'b00) ? 16'h7fff : WAVE[15:0]));
	endfunction
	always @(posedge CLK or negedge RST_N)
		if (!RST_N) begin
			PCM_L <= 1'sb0;
			PCM_R <= 1'sb0;
		end
		else if (!RES_N)
			;
		else if (((OP7[23-:5] == 5'd0) && (CYCLE_NUM[2:1] == 2'b00)) && CYCLE1_CE) begin
			PCM_L <= (!SND_EN[2] ? 16'h0000 : YMF278B_PKG_TrimWave(ACC_L));
			PCM_R <= (!SND_EN[2] ? 16'h0000 : YMF278B_PKG_TrimWave(ACC_R));
		end
	reg MEM_WREQ = 0;
	reg MEM_RREQ = 0;
	wire REG_AM_SEL = (REG_A >= 8'he0) && (REG_A <= 8'hf7);
	wire REG_FNUM0_SEL = (REG_A >= 8'h38) && (REG_A <= 8'h4f);
	wire REG_FNUM1_SEL = (REG_A >= 8'h20) && (REG_A <= 8'h37);
	wire REG_LEVEL_SEL = (REG_A >= 8'h50) && (REG_A <= 8'h67);
	wire REG_LFO_SEL = (REG_A >= 8'h80) && (REG_A <= 8'h97);
	wire REG_RATE0_SEL = (REG_A >= 8'h98) && (REG_A <= 8'haf);
	wire REG_RATE1_SEL = (REG_A >= 8'hb0) && (REG_A <= 8'hc7);
	wire REG_RATE2_SEL = (REG_A >= 8'hc8) && (REG_A <= 8'hdf);
	reg [7:0] rt_cpu_q = 0;
	wire rt_sel = (((((REG_RATE0_SEL | REG_RATE1_SEL) | REG_RATE2_SEL) | REG_AM_SEL) | REG_WTN_SEL) | REG_LEVEL_SEL) | REG_PAN_SEL;
	reg WR_N_OLD = 0;
	reg RD_N_OLD = 0;
	reg CS_N_OLD = 0;
	reg [1:0] REG_RD_DELAY = 0;
	reg REG_NEW_SEL = 0;
	reg [3:0] LD_WAIT = 0;
	reg MEM_START = 0;
	always @(posedge CLK or negedge RST_N) begin : sv2v_autoblock_9
		if (!RST_N) begin
			NEW2 <= 0;
			TEST0 <= 1'sb0;
			TEST1 <= 1'sb0;
			MEMMODE <= 1'sb0;
			MEMADDR <= 1'sb0;
			MEMDAT <= 1'sb0;
			MIXFM <= 1'sb0;
			MIXPCM <= 1'sb0;
			REG_Q <= 1'sb0;
			{BUSY, BUSY2} <= 0;
			LD <= 0;
			LD2 <= 0;
		end
		else if (!RES_N) begin
			NEW2 <= 0;
			TEST0 <= 1'sb0;
			TEST1 <= 1'sb0;
			MEMMODE <= 1'sb0;
			MEMADDR <= 1'sb0;
			MEMDAT <= 1'sb0;
			MIXFM <= 6'h1b;
			MIXPCM <= 6'h00;
			LD2 <= 0;
			MEM_A <= 1'sb0;
			MEM_WR <= 0;
			MEM_RD <= 0;
		end
		else if (CE) begin
			if (CYCLE1_CE) begin
				REG_RD <= 0;
				REG_WR <= 0;
				BUSY <= 0;
			end
			WR_N_OLD <= WR_N;
			RD_N_OLD <= RD_N;
			CS_N_OLD <= CS_N;
			if (((RD_N && !RD_N_OLD) && !CS_N_OLD) && (A == 3'h0)) begin
				if (LD2)
					LD2 <= 0;
			end
			if ((((!RD_N && RD_N_OLD) && !CS_N) && (A == 3'h5)) && NEW2) begin
				REG_RD <= 1;
				BUSY <= 1;
			end
			if ((!WR_N && WR_N_OLD) && !CS_N) begin
				REG_NEW_SEL <= 0;
				case (A)
					3'h2: REG_NEW_SEL <= DI == 8'h05;
					3'h3:
						if (REG_NEW_SEL && DI[1]) begin
							NEW2 <= 1;
							LD2 <= 1;
						end
					3'h4:
						if (NEW2)
							REG_A <= DI;
					3'h5:
						if (NEW2) begin
							REG_D <= DI;
							REG_WR <= 1;
							BUSY <= 1;
						end
				endcase
			end
			if ((OP7[23-:5] == 5'd23) && SLOT1_CE) begin
				if (LD_WAIT)
					LD_WAIT <= LD_WAIT - 4'd1;
				else
					LD <= 0;
			end
			REG_RD_DELAY[0] <= REG_RD;
			REG_RD_DELAY[1] <= REG_RD_DELAY[0];
			if (REG_WR && CYCLE1_CE) begin
				case (REG_A)
					8'h00: TEST0 <= REG_D;
					8'h01: TEST1 <= REG_D;
					8'h02: MEMMODE[4:0] <= REG_D[4:0];
					8'h03: MEMADDR[21:16] <= REG_D[5:0];
					8'h04: MEMADDR[15:8] <= REG_D;
					8'h05: MEMADDR[7:0] <= REG_D;
					8'h06: MEMDAT <= REG_D;
					8'hf8: MIXFM <= REG_D[5:0];
					8'hf9: MIXPCM <= REG_D[5:0];
					default:
						;
				endcase
				if (REG_WTN_SEL) begin
					LD <= 1;
					LD_WAIT <= 4'd12;
				end
				if (REG_A == 8'h06) begin
					MEM_WREQ <= 1;
					BUSY2 <= 1;
				end
				if (REG_A == 8'h05) begin
					MEM_RREQ <= 1;
					BUSY2 <= 1;
				end
			end
			if (REG_RD_DELAY == 2'b01) begin
				if (REG_WTN_SEL)
					REG_Q <= rt_cpu_q;
				else if (REG_FNUM0_SEL)
					REG_Q <= REG_FNUM_Q[15:8];
				else if (REG_FNUM1_SEL)
					REG_Q <= REG_FNUM_Q[7:0];
				else if (REG_LEVEL_SEL)
					REG_Q <= rt_cpu_q;
				else if (REG_PAN_SEL)
					REG_Q <= rt_cpu_q;
				else if (REG_LFO_SEL)
					REG_Q <= REG_LFO_Q;
				else if (REG_RATE0_SEL)
					REG_Q <= rt_cpu_q;
				else if (REG_RATE1_SEL)
					REG_Q <= rt_cpu_q;
				else if (REG_RATE2_SEL)
					REG_Q <= rt_cpu_q;
				else if (REG_AM_SEL)
					REG_Q <= rt_cpu_q;
				else begin
					case (REG_A)
						8'h00: REG_Q <= TEST0;
						8'h01: REG_Q <= TEST1;
						8'h02: REG_Q <= {3'b001, MEMMODE};
						8'h03: REG_Q <= {2'b00, MEMADDR[21:16]};
						8'h04: REG_Q <= MEMADDR[15:8];
						8'h05: REG_Q <= MEMADDR[7:0];
						8'h06: REG_Q <= MEMDAT;
						8'hf8: REG_Q <= {2'b00, MIXFM};
						8'hf9: REG_Q <= {2'b00, MIXPCM};
						default: REG_Q <= 1'sb0;
					endcase
					if (REG_A == 8'h06) begin
						MEM_RREQ <= 1;
						BUSY2 <= 1;
						MEMADDR <= MEMADDR + 22'd1;
					end
				end
			end
			if ((REG_RD_DELAY == 2'b10) && rt_sel)
				REG_Q <= rt_cpu_q;
			if (CYCLE1_CE) begin
				if (MEM_RD && !MEMMODE[0])
					MEM_D <= MDI;
				if (MEM_RD && MEMMODE[0])
					MEMDAT <= MDI;
				if (MEM_WR && MEMMODE[0])
					MEMADDR <= MEMADDR + 22'd1;
				MEM_WR <= 0;
				MEM_RD <= 0;
				BUSY2 <= 0;
			end
			MEM_START <= CYCLE1_CE;
			if ((MEM_START && WD_READ) && !MEMMODE[0]) begin
				MEM_A <= WD_ADDR;
				MEM_WR <= 0;
				MEM_RD <= 1;
			end
			else if ((MEM_START && (MEM_WREQ || MEM_RREQ)) && MEMMODE[0]) begin
				MEM_A <= MEMADDR;
				MEM_WR <= MEM_WREQ;
				MEM_RD <= MEM_RREQ;
				BUSY2 <= 1;
				MEM_WREQ <= 0;
				MEM_RREQ <= 0;
			end
		end
	end
	assign MA = MEM_A[20:0];
	assign MDO = MEMDAT;
	assign MWR_N = ~MEM_WR;
	assign MRD_N = ~MEM_RD;
	assign MCS_N[0] = ~((MEM_A[21:19] | 3'b011) == 3'b011);
	assign MCS_N[1] = ~((MEM_A[21:19] | 3'b011) == 3'b111);
	assign MCS_N[2] = ~((MEM_A[21:19] | 3'b001) == 3'b001);
	assign MCS_N[3] = ~((MEM_A[21:19] | 3'b001) == 3'b011);
	assign MCS_N[4] = ~((MEM_A[21:19] | 3'b001) == 3'b101);
	assign MCS_N[5] = ~((MEM_A[21:19] | 3'b001) == 3'b111);
	assign MCS_N[6] = ~(MEM_A[21:19] == 3'b100);
	assign MCS_N[7] = ~(MEM_A[21:19] == 3'b101);
	assign MCS_N[8] = ~(MEM_A[21:19] == 3'b110);
	assign MCS_N[9] = ~(MEM_A[21:19] == 3'b111);
	(* syn_ramstyle = "block_ram" *) reg [7:0] sa_mem [0:255];
	initial begin : sv2v_autoblock_10
		reg signed [31:0] si = 0;
		for (si = 0; si < 256; si = si + 1)
			sa_mem[si] = 1'sb0;
	end
	reg [7:0] sa_q [0:6];
	reg [7:0] sa_st [0:6];
	initial begin : sv2v_autoblock_11
		reg signed [31:0] qi = 0;
		for (qi = 0; qi < 7; qi = qi + 1)
			begin
				sa_q[qi] = 1'sb0;
				sa_st[qi] = 1'sb0;
			end
	end
	reg [2:0] sa_swp = 0;
	reg [2:0] sa_cap = 0;
	reg [2:0] sa_rstf = 0;
	reg sa_swp_on = 0;
	reg sa_cap_on = 0;
	reg [7:0] sa_rq = 0;
	wire sa_we_load = (OP3[57] & SLOT0_CE) & (OP3[56-:4] < 4'd7);
	wire sa_we = OP2[39] | sa_we_load;
	wire [7:0] sa_waddr = (OP2[39] ? {sa_rstf, OP2[44-:5]} : {OP3[55:53], OP3[65-:5]});
	always @(posedge CLK) begin
		if (sa_we)
			sa_mem[sa_waddr] <= (OP2[39] ? 8'd0 : MEM_D);
		sa_rstf <= (sa_rstf == 3'd6 ? 3'd0 : sa_rstf + 3'd1);
		sa_rq <= sa_mem[{sa_swp, SLOT}];
		sa_cap <= sa_swp;
		sa_cap_on <= sa_swp_on;
		if (sa_cap_on)
			sa_st[sa_cap] <= sa_rq;
		if (OP2[39]) begin
			sa_q[0] <= 1'sb0;
			sa_q[1] <= 1'sb0;
			sa_q[2] <= 1'sb0;
			sa_q[3] <= 1'sb0;
			sa_q[4] <= 1'sb0;
			sa_q[5] <= 1'sb0;
			sa_q[6] <= 1'sb0;
		end
		else if (SLOT1_CE) begin
			sa_q[0] <= sa_st[0];
			sa_q[1] <= sa_st[1];
			sa_q[2] <= sa_st[2];
			sa_q[3] <= sa_st[3];
			sa_q[4] <= sa_st[4];
			sa_q[5] <= sa_st[5];
			sa_q[6] <= sa_st[6];
		end
		if (CYCLE1_CE && (CYCLE_NUM == 3'd3)) begin
			sa_swp_on <= 1'b1;
			sa_swp <= 3'd0;
		end
		else if (sa_swp_on) begin
			if (sa_swp == 3'd6)
				sa_swp_on <= 1'b0;
			else
				sa_swp <= sa_swp + 3'd1;
		end
	end
	assign REG_SA_Q = {sa_q[0], sa_q[1], sa_q[2]};
	assign REG_LA_Q = {sa_q[3], sa_q[4]};
	assign REG_EA_Q = {sa_q[5], sa_q[6]};
	localparam sv2v_uu_REG_FNUM0_dw = 8;
	localparam [7:0] sv2v_uu_REG_FNUM0_ext_DATA_0 = 1'sb0;
	OPL4_REG_RAM #(
		.aw(5),
		.dw(8)
	) REG_FNUM0(
		.CLK(CLK),
		.WRADDR((RST ? SLOT : REG_A[4:0] - 5'h18)),
		.DATA((RST ? sv2v_uu_REG_FNUM0_ext_DATA_0 : REG_D)),
		.WREN((RST ? 1'b1 : (REG_WR & REG_FNUM0_SEL) & CYCLE1_CE)),
		.RDADDR((REG_RD ? REG_A[4:0] - 5'h18 : FNUM_RA)),
		.Q(REG_FNUM_Q[15:8])
	);
	localparam sv2v_uu_REG_FNUM1_dw = 8;
	localparam [7:0] sv2v_uu_REG_FNUM1_ext_DATA_0 = 1'sb0;
	OPL4_REG_RAM #(
		.aw(5),
		.dw(8)
	) REG_FNUM1(
		.CLK(CLK),
		.WRADDR((RST ? SLOT : REG_A[4:0] - 5'h00)),
		.DATA((RST ? sv2v_uu_REG_FNUM1_ext_DATA_0 : REG_D)),
		.WREN((RST ? 1'b1 : (REG_WR & REG_FNUM1_SEL) & CYCLE1_CE)),
		.RDADDR((REG_RD ? REG_A[4:0] - 5'h00 : FNUM_RA)),
		.Q(REG_FNUM_Q[7:0])
	);
	wire REG_LFO_LOAD = OP3[56-:4] == 4'h7;
	localparam sv2v_uu_REG_LFO_dw = 8;
	localparam [7:0] sv2v_uu_REG_LFO_ext_DATA_0 = 1'sb0;
	OPL4_REG_RAM #(
		.aw(5),
		.dw(8)
	) REG_LFO(
		.CLK(CLK),
		.WRADDR((RST ? SLOT : (OP3[57] ? OP3[65-:5] : REG_A[4:0] - 5'h00))),
		.DATA((RST ? sv2v_uu_REG_LFO_ext_DATA_0 : (OP3[57] ? MEM_D : REG_D))),
		.WREN((RST ? 1'b1 : (OP3[57] ? REG_LFO_LOAD & SLOT0_CE : (REG_WR & REG_LFO_SEL) & CYCLE1_CE))),
		.RDADDR((REG_RD ? REG_A[4:0] - 5'h00 : LFO_RA)),
		.Q(REG_LFO_Q)
	);
	wire [2:0] rt_fld = (REG_RATE0_SEL ? RT_R0 : (REG_RATE1_SEL ? RT_R1 : (REG_RATE2_SEL ? RT_R2 : (REG_AM_SEL ? RT_AM : (REG_WTN_SEL ? RT_WT : (REG_LEVEL_SEL ? RT_LV : RT_PN))))));
	wire [4:0] rt_idx = (REG_RATE0_SEL ? REG_A[4:0] - 5'h18 : (REG_RATE1_SEL ? REG_A[4:0] - 5'h10 : (REG_RATE2_SEL ? REG_A[4:0] - 5'h08 : (REG_AM_SEL ? REG_A[4:0] - 5'h00 : (REG_WTN_SEL ? REG_A[4:0] - 5'h08 : (REG_LEVEL_SEL ? REG_A[4:0] - 5'h10 : REG_A[4:0] - 5'h08))))));
	reg [2:0] rt_rstf = 0;
	wire rt_rst_we = (rt_rstf == RT_WT ? OP4[8] : RST);
	wire [7:0] rt_rst_ad = (rt_rstf == RT_WT ? {RT_WT, OP4[13-:5]} : {rt_rstf, SLOT});
	wire rt_we_load = ((OP3[57] & SLOT0_CE) & (OP3[56-:4] >= 4'd8)) & (OP3[56-:4] <= 4'd11);
	wire rt_we_cpu = (REG_WR & CYCLE1_CE) & rt_sel;
	reg rt_cpuw_p = 0;
	wire rt_cpuw_go = (rt_cpuw_p & ~rt_rst_we) & ~rt_we_load;
	wire rt_we = (rt_rst_we | rt_we_load) | rt_cpuw_go;
	reg [7:0] rt_cpuw_ad = 0;
	wire [7:0] rt_waddr = (rt_rst_we ? rt_rst_ad : (rt_we_load ? {1'b0, OP3[54:53], OP3[65-:5]} : rt_cpuw_ad));
	reg [7:0] rt_cpuw_dt = 0;
	wire [7:0] rt_wdata = (rt_rst_we ? 8'd0 : (rt_we_load ? MEM_D : rt_cpuw_dt));
	wire rt_cpurd = REG_RD & rt_sel;
	wire [4:0] rt_slot_nx = (SLOT == 5'd23 ? 5'd0 : SLOT + 5'd1);
	reg [2:0] rt_swp = 0;
	wire [4:0] rt_swp_ad = (rt_swp == RT_WT ? rt_slot_nx : (rt_swp == RT_LV ? OP4[13-:5] : (rt_swp == RT_PN ? OP6[33-:5] : OP3[65-:5])));
	(* syn_ramstyle = "block_ram" *) reg [7:0] rt_mem [0:255];
	initial begin : sv2v_autoblock_12
		reg signed [31:0] ri = 0;
		for (ri = 0; ri < 256; ri = ri + 1)
			rt_mem[ri] = 1'sb0;
	end
	reg [7:0] rt_st [0:6];
	initial begin : sv2v_autoblock_13
		reg signed [31:0] ri = 0;
		for (ri = 0; ri < 7; ri = ri + 1)
			begin
				rt_q[ri] = 1'sb0;
				rt_st[ri] = 1'sb0;
			end
	end
	initial rt_cpu_q = 1'sb0;
	reg [2:0] rt_cap = 0;
	reg rt_swp_on = 0;
	reg rt_cap_on = 0;
	reg rt_cpu_on = 0;
	reg [7:0] rt_rq = 0;
	initial begin
		rt_cpuw_p = 1'b0;
		rt_cpuw_ad = 1'sb0;
		rt_cpuw_dt = 1'sb0;
	end
	always @(posedge CLK) begin
		if (rt_we)
			rt_mem[rt_waddr] <= rt_wdata;
		rt_rstf <= (rt_rstf == RT_PN ? 3'd0 : rt_rstf + 3'd1);
		if (rt_we_cpu) begin
			rt_cpuw_p <= 1'b1;
			rt_cpuw_ad <= {rt_fld, rt_idx};
			rt_cpuw_dt <= REG_D;
		end
		else if (rt_cpuw_go)
			rt_cpuw_p <= 1'b0;
		rt_rq <= rt_mem[(rt_cpurd ? {rt_fld, rt_idx} : {rt_swp, rt_swp_ad})];
		rt_cap <= rt_swp;
		rt_cap_on <= rt_swp_on & ~rt_cpurd;
		rt_cpu_on <= rt_cpurd;
		if (rt_cpu_on)
			rt_cpu_q <= rt_rq;
		else if (rt_cap_on)
			rt_st[rt_cap] <= rt_rq;
		if (RST) begin
			rt_q[RT_R0] <= 1'sb0;
			rt_q[RT_R1] <= 1'sb0;
			rt_q[RT_R2] <= 1'sb0;
			rt_q[RT_AM] <= 1'sb0;
			rt_q[RT_LV] <= 1'sb0;
			rt_q[RT_PN] <= 1'sb0;
		end
		else if (SLOT1_CE) begin
			rt_q[RT_R0] <= rt_st[RT_R0];
			rt_q[RT_R1] <= rt_st[RT_R1];
			rt_q[RT_R2] <= rt_st[RT_R2];
			rt_q[RT_AM] <= rt_st[RT_AM];
			rt_q[RT_LV] <= rt_st[RT_LV];
			rt_q[RT_PN] <= rt_st[RT_PN];
		end
		if (OP4[8])
			rt_q[RT_WT] <= 1'sb0;
		else if (SLOT1_CE)
			rt_q[RT_WT] <= rt_st[RT_WT];
		if (CYCLE1_CE && (CYCLE_NUM == 3'd3)) begin
			rt_swp_on <= 1'b1;
			rt_swp <= 3'd0;
		end
		else if (rt_swp_on && !rt_cpurd) begin
			if (rt_swp == RT_PN)
				rt_swp_on <= 1'b0;
			else
				rt_swp <= rt_swp + 3'd1;
		end
	end
	wire [7:0] OPL3_DO;
	wire [15:0] OPL3_OUT_A;
	wire [15:0] OPL3_OUT_B;
	wire [15:0] OPL3_OUT_C;
	wire [15:0] OPL3_OUT_D;
	assign OPL3_DO = 1'sb0;
	assign {OPL3_OUT_A, OPL3_OUT_B, OPL3_OUT_C, OPL3_OUT_D} = 1'sb0;
	assign IRQ_N = 1;
	assign DO = (A == 3'h5 ? REG_Q : OPL3_DO | {6'b000000, LD | LD2, BUSY | BUSY2});
	assign OUT0_L = OPL3_OUT_C;
	assign OUT0_R = OPL3_OUT_D;
	assign OUT1_L = PCM_L;
	assign OUT1_R = PCM_R;
	function signed [15:0] YMF278B_PKG_MixCalc;
		input reg signed [15:0] WAVE;
		input reg [2:0] MIX;
		reg signed [15:0] BASE;
		begin
			BASE = (MIX[0] ? ($signed(WAVE) >>> 1) + ($signed(WAVE) >>> 2) : $signed(WAVE));
			YMF278B_PKG_MixCalc = (MIX == 3'd7 ? 16'sd0 : $signed(BASE >>> MIX[2:1]));
		end
	endfunction
	assign OUT2_L = YMF278B_PKG_MixCalc(PCM_L, MIXPCM[2:0]) + YMF278B_PKG_MixCalc(OPL3_OUT_A, MIXFM[2:0]);
	assign OUT2_R = YMF278B_PKG_MixCalc(PCM_R, MIXPCM[5:3]) + YMF278B_PKG_MixCalc(OPL3_OUT_B, MIXFM[5:3]);
	initial _sv2v_0 = 0;
endmodule
module OPL4_KEY_RAM (
	CLK,
	WRADDR,
	DATA,
	WREN,
	RDADDR,
	Q
);
	input CLK;
	input [4:0] WRADDR;
	input [2:0] DATA;
	input WREN;
	input [4:0] RDADDR;
	output wire [2:0] Q;
	reg [2:0] mem [0:31];
	integer ii;
	initial for (ii = 0; ii < 32; ii = ii + 1)
		mem[ii] = 0;
	always @(posedge CLK)
		if (WREN)
			mem[WRADDR] <= DATA;
	assign Q = mem[RDADDR];
endmodule
module OPL4_PHASE_RAM (
	CLK,
	WRADDR,
	DATA,
	WREN,
	RDADDR,
	Q
);
	input CLK;
	input [4:0] WRADDR;
	input [13:0] DATA;
	input WREN;
	input [4:0] RDADDR;
	output wire [13:0] Q;
	(* syn_ramstyle = "block_ram" *) reg [13:0] mem [0:31];
	integer ii;
	initial for (ii = 0; ii < 32; ii = ii + 1)
		mem[ii] = 0;
	reg [13:0] rd_q = 0;
	always @(posedge CLK) begin
		if (WREN)
			mem[WRADDR] <= DATA;
		rd_q <= mem[RDADDR];
	end
	assign Q = rd_q;
endmodule
module OPL4_LFO_RAM (
	CLK,
	WRADDR,
	DATA,
	WREN,
	RDADDR,
	Q
);
	input CLK;
	input [4:0] WRADDR;
	input [21:0] DATA;
	input WREN;
	input [4:0] RDADDR;
	output wire [21:0] Q;
	(* syn_ramstyle = "block_ram" *) reg [17:0] mem [0:31];
	reg [21:18] mem_hi [0:31];
	integer ii;
	initial for (ii = 0; ii < 32; ii = ii + 1)
		begin
			mem[ii] = 0;
			mem_hi[ii] = 0;
		end
	reg [17:0] rd_lo = 0;
	reg [21:18] rd_hi = 0;
	always @(posedge CLK) begin
		if (WREN) begin
			mem[WRADDR] <= DATA[17:0];
			mem_hi[WRADDR] <= DATA[21:18];
		end
		rd_lo <= mem[RDADDR];
		rd_hi <= mem_hi[RDADDR];
	end
	assign Q = {rd_hi, rd_lo};
endmodule
module OPL4_SO_RAM (
	CLK,
	WRADDR,
	DATA,
	WREN,
	RDADDR,
	Q
);
	input CLK;
	input [4:0] WRADDR;
	input [15:0] DATA;
	input WREN;
	input [4:0] RDADDR;
	output wire [15:0] Q;
	(* syn_ramstyle = "block_ram" *) reg [15:0] mem [0:31];
	integer ii;
	initial for (ii = 0; ii < 32; ii = ii + 1)
		mem[ii] = 0;
	reg [15:0] rd_q = 0;
	always @(posedge CLK) begin
		if (WREN)
			mem[WRADDR] <= DATA;
		rd_q <= mem[RDADDR];
	end
	assign Q = rd_q;
endmodule
module OPL4_EVOL_RAM (
	CLK,
	WRADDR,
	DATA,
	WREN,
	RDADDR,
	Q
);
	input CLK;
	input [4:0] WRADDR;
	input [11:0] DATA;
	input WREN;
	input [4:0] RDADDR;
	output wire [11:0] Q;
	(* syn_ramstyle = "block_ram" *) reg [11:0] mem [0:31];
	integer ii;
	initial for (ii = 0; ii < 32; ii = ii + 1)
		mem[ii] = 0;
	reg [11:0] rd_q = 0;
	always @(posedge CLK) begin
		if (WREN)
			mem[WRADDR] <= DATA;
		rd_q <= mem[RDADDR];
	end
	assign Q = rd_q;
endmodule
module OPL4_TL_RAM (
	CLK,
	WRADDR,
	DATA,
	WREN,
	RDADDR,
	Q
);
	input CLK;
	input [4:0] WRADDR;
	input [16:0] DATA;
	input WREN;
	input [4:0] RDADDR;
	output wire [16:0] Q;
	(* syn_ramstyle = "block_ram" *) reg [16:0] mem [0:31];
	integer ii;
	initial for (ii = 0; ii < 32; ii = ii + 1)
		mem[ii] = 0;
	reg [16:0] rd_q = 0;
	always @(posedge CLK) begin
		if (WREN)
			mem[WRADDR] <= DATA;
		rd_q <= mem[RDADDR];
	end
	assign Q = rd_q;
endmodule
module OPL4_REG_RAM (
	CLK,
	WRADDR,
	DATA,
	WREN,
	RDADDR,
	Q
);
	parameter aw = 5;
	parameter dw = 8;
	input CLK;
	input [aw - 1:0] WRADDR;
	input [dw - 1:0] DATA;
	input WREN;
	input [aw - 1:0] RDADDR;
	output wire [dw - 1:0] Q;
	(* syn_ramstyle = "registers" *) reg [dw - 1:0] mem [0:(2 ** aw) - 1];
	integer ii;
	initial for (ii = 0; ii < (2 ** aw); ii = ii + 1)
		mem[ii] = 0;
	reg [dw - 1:0] rd_q = 0;
	always @(posedge CLK) begin
		if (WREN)
			mem[WRADDR] <= DATA;
		rd_q <= mem[RDADDR];
	end
	assign Q = rd_q;
endmodule
