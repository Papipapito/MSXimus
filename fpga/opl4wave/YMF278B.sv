// ============================================================================
// YMF278B.sv — motor PCM/wavetable del OPL4 (MoonSound) para MSXimus (_89)
//
// Origen: srg320/Arcade-PsikyoSH2_MiSTer rtl/PSH2/YMF278B.sv (jun-2026),
// usado con permiso explicito del autor ("You can use the code in any form",
// correo 2026-07-13). Derivado del ymf278b.cpp de MAME (BSD-3-Clause,
// R. Belmont / Olivier Galibert / hap) — se conserva la licencia BSD-3 con
// esos titulares, como se acordo con srg320.
//
// Solo esta implementada la parte PCM (24 slots); el FM del YMF278B es un
// stub (OPL3_DO=0) — en MSXimus el FM lo lleva opl4fm.v (gtaylormb/opl3).
//
// Cambios MSXimus respecto al original:
//  - Los 7 modulos RAM Altera (altsyncram/altdpram) reescritos como
//    inferencia Verilog pura conservando la latencia exacta:
//      altsyncram (addr_reg_b=CLOCK0, outdata=UNREGISTERED) ->
//        direccion de lectura registrada cada CLK, Q combinacional.
//      altdpram MLAB (todo UNREGISTERED) -> lectura combinacional.
//  - Nada mas: la logica del motor esta INTACTA.
//
// Este .sv es la FUENTE mantenida; el build usa ymf278b_gowin.v generado
// con sv2v (ver regen en fpga/opl4wave/convert.sh). NO editar el .v a mano.
// ============================================================================

// synopsys translate_off
`define SIM
// synopsys translate_on

module YMF278B
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              CE,
	
	input      [ 2: 0] A,
	input      [ 7: 0] DI,
	output     [ 7: 0] DO,
	input              RD_N,
	input              WR_N,
	input              CS_N,
	input              IC_N,
	
	output             IRQ_N,
	
	output     [20: 0] MA,
	input      [ 7: 0] MDI,
	output     [ 7: 0] MDO,
	output             MRD_N,
	output             MWR_N,
	output     [ 9: 0] MCS_N,
	output     [ 4: 0] MEM_SLOT,   // _107: slot dueno del fetch en curso (OP3)
	output     [ 5: 0] MIX_FM,     // _110: atenuacion F8 (el FM real vive fuera)
	
	output     [15: 0] OUT0_L,
	output     [15: 0] OUT0_R,
	output     [15: 0] OUT1_L,
	output     [15: 0] OUT1_R,
	output     [15: 0] OUT2_L,
	output     [15: 0] OUT2_R,
	
	input      [ 2: 0] SND_EN,

	// MSXimus: la proxima CE sera CYCLE1_CE (la ventana donde el motor
	// muestrea MDI y consume MEM_RD/MEM_WR). El pegamento congela SOLO esa
	// CE si el fetch DDR3 aun esta en vuelo — alineacion exacta, sin contar
	// CEs desde fuera (el divisor avanza con los mismos CE que lee el gate).
	output             CYCLE1_NEXT
	
`ifdef DEBUG
                      ,
	output             ATTACK_DBG,
	output             DECAY1_DBG,
	output             DECAY2_DBG,
	output             RELEASE_DBG,
	output signed [15:0] LVL_DBG,
	output signed [15:0] PAN_L_DBG,
	output signed [15:0] PAN_R_DBG
`endif
);

	import YMF278B_PKG::*;
	
	bit          NEW2;
	bit  [ 7: 0] TEST0;
	bit  [ 7: 0] TEST1;
	bit  [ 4: 0] MEMMODE;
	bit  [21: 0] MEMADDR;
	bit  [ 7: 0] MEMDAT;
	bit  [ 5: 0] MIXFM;
	bit  [ 5: 0] MIXPCM;
	bit          LD,LD2,BUSY,BUSY2;

	OP2_t        OP2;
	OP3_t        OP3;
	OP4_t        OP4;
	OP5_t        OP5;
	OP6_t        OP6;
	OP7_t        OP7;
		
	bit  [21: 0] WD_ADDR;
	bit          WD_READ;
	
	bit  [21: 0] MEM_A;
	bit  [ 7: 0] MEM_D;
	bit  [ 7: 0] MEM_Q;
	bit          MEM_WR;
	bit          MEM_RD;
	
	bit  [ 7: 0] REG_A;
	bit  [ 7: 0] REG_D;
	bit  [ 7: 0] REG_Q;
	bit          REG_WR;
	bit          REG_RD;
	
	wire         RES_N = IC_N;
	
	bit          CLK_RES;
	always @(posedge CLK) begin
		bit          RST_N_OLD;
	
		if (CE) begin
			RST_N_OLD <= RST_N;
			CLK_RES <= RST_N & ~RST_N_OLD;
		end
	end
	
	bit  [ 1: 0] CLK_DIV;
	bit  [ 2: 0] CYCLE_NUM;
	always @(posedge CLK) begin
		if (CLK_RES) begin
			CLK_DIV <= '0;
			CYCLE_NUM <= '0;
		end
		else if (CE) begin
			CLK_DIV <= CLK_DIV + 2'd1;
			if (CLK_DIV == 2'd3) 
				CYCLE_NUM <= CYCLE_NUM + 3'd1;
		end 
	end
	
	wire SLOT0_EN = (CYCLE_NUM[2:1] == 2'b01);
	wire SLOT1_EN = (CYCLE_NUM[2:1] == 2'b11);
	
	wire CYCLE0_CE = ~CYCLE_NUM[0] & CLK_DIV == 2'd3 & CE;
	wire CYCLE1_CE =  CYCLE_NUM[0] & CLK_DIV == 2'd3 & CE;
	// MSXimus: estado del divisor DESPUES del CE de este ciclo (look-ahead):
	// el que decide el proximo CE fuera del chip lee este mismo flanco.
	wire [1:0] MSX_DIV_NXT = (CE)                    ? CLK_DIV + 2'd1   : CLK_DIV;
	wire [2:0] MSX_CYC_NXT = (CE && CLK_DIV == 2'd3) ? CYCLE_NUM + 3'd1 : CYCLE_NUM;
	assign CYCLE1_NEXT = MSX_CYC_NXT[0] & (MSX_DIV_NXT == 2'd3);
	wire SLOT0_CE = SLOT0_EN & CYCLE1_CE;
	wire SLOT1_CE = SLOT1_EN & CYCLE1_CE;
		
	bit  [ 4: 0] EVOL_RA,AM_RA,SA_RA,FNUM_RA,LFO_RA;
	always_comb begin
		casex (CYCLE_NUM[2:1])
			2'b0x: begin
				SA_RA = OP2.SLOT;//OP2
				FNUM_RA = SLOT;//OP1
				AM_RA = SLOT;//OP1
				EVOL_RA = OP2.SLOT;//OP2
				LFO_RA = SLOT;//OP1
			end
			2'b1x: begin
				SA_RA = OP2.SLOT;//OP2
				FNUM_RA = OP4.SLOT;//OP4
				AM_RA = OP4.SLOT;//OP4
				EVOL_RA = OP4.SLOT;//OP4
				LFO_RA = OP4.SLOT;//OP4
			end
		endcase
	end
	
	//Operation 1: PLFO, PG, KEY ON/OFF
	bit          REG_KB[24],REG_LOAD[24];
	bit  [ 4: 0] SLOT;
	bit          RST;
	bit  [ 3: 0] OP1_OCT;
	bit          OP1_PREVERB;
	bit  [ 9: 0] OP1_FNUM;
	bit  [ 2: 0] OP1_LFO,OP1_VIB;
	bit          OP1_LFORST;
	bit  [ 8: 0] OP1_WTN;
	bit  [ 3: 0] OP1_LOAD_POS;
	always @(posedge CLK or negedge RST_N) begin
		bit  [ 9: 0] OP1_LFO_DIV;
		bit  [ 7: 0] OP1_LFO_DATA;
		bit          REG_KB_OLD[24];
		bit  [ 7: 0] PLFO_WAVE;
		bit  [22: 0] PHASE;
		bit  [ 7: 0] NEW_LFO_DATA;
		bit  [ 9: 0] NEW_LFO_DIV;
		bit  [ 3: 0] NEW_LOAD_POS;
		
		if (!RST_N) begin
			{OP1_OCT,OP1_FNUM} <= '0;
			{OP1_LFO,OP1_VIB} <= '0;
			OP1_LFORST <= 0;
			OP1_WTN <= '0;
			REG_KB <= '{24{1'b0}};
			REG_KB_OLD <= '{24{1'b0}};
			REG_LOAD <= '{24{1'b0}};
			SLOT <= '0;
			RST <= 1;
			OP2 <= OP2_RESET;
		end else if (!RES_N) begin
			{OP1_OCT,OP1_FNUM} <= '0;
			{OP1_LFO,OP1_VIB} <= '0;
			OP1_LFORST <= 0;
			OP1_WTN <= '0;
			REG_KB <= '{24{1'b0}};
			REG_KB_OLD <= '{24{1'b0}};
			REG_LOAD <= '{24{1'b0}};
			SLOT <= '0;
			RST <= 1;
			OP2 <= OP2_RESET;
		end else begin
			if (CYCLE0_CE) begin
				case (CYCLE_NUM[2:1])
					2'b00: begin
						{OP1_OCT,OP1_PREVERB,OP1_FNUM} <= REG_FNUM_Q[15:1];
						{OP1_LFO,OP1_VIB} <= REG_LFO_Q[5:0];
						OP1_LFORST <= REG_PAN_Q[5];
						OP1_WTN <= {REG_FNUM_Q[0],REG_WTN_Q};
						{OP1_LOAD_POS,OP1_LFO_DIV,OP1_LFO_DATA} <= LFO_RAM_Q;
					end
				endcase
			end
			
			//Key on/off, header load
			if (CYCLE1_CE) begin
				if (REG_PAN_SEL && REG_WR) begin
					REG_KB[REG_A[4:0] - 5'h8] <= REG_D[7];
				end
				if (REG_WTN_SEL && REG_WR) begin
					REG_LOAD[REG_A[4:0] - 5'h8] <= 1;
				end
			end
			if (SLOT1_CE) begin
				KEY_RAM_D[1:0] <= '0;
				if (REG_KB[SLOT] && !REG_KB_OLD[SLOT]) begin
					KEY_RAM_D[0] <= 1;
				end
				if (!REG_KB[SLOT] && REG_KB_OLD[SLOT]) begin
					KEY_RAM_D[1] <= 1;
				end
				REG_KB_OLD[SLOT] <= REG_KB[SLOT];
				
				if (REG_LOAD[SLOT]) REG_LOAD[SLOT] <= 0;
			end
			
			PLFO_WAVE <= VIBCalc(OP1_LFO_DATA, OP1_VIB);
			PHASE = PhaseCalc(OP1_FNUM, OP1_OCT, PLFO_WAVE);
			
			if (SLOT1_CE) begin
				OP2.SLOT <= SLOT;
				OP2.RST <= RST;
				OP2.KON <= KEY_RAM_Q[0];
				OP2.KOFF <= KEY_RAM_Q[1];
				OP2.LOAD <= KEY_RAM_Q[2];
				OP2.PHASE <= PHASE;
				OP2.WTN <= OP1_WTN;
				OP2.LOAD_POS <= OP1_LOAD_POS;

				SLOT <= SLOT + 5'd1;
				if (SLOT == 5'd23) begin
					SLOT <= '0;
					RST <= 0;
				end
			end
			
			//LFO
			if (SLOT1_CE) begin				
				if (!OP1_LFO_DIV) begin
					NEW_LFO_DIV = LFOFreqDiv(OP1_LFO);
					NEW_LFO_DATA = OP1_LFO_DATA + 8'd1;
				end else begin
					NEW_LFO_DIV = OP1_LFO_DIV - 10'd1;
					NEW_LFO_DATA = OP1_LFO_DATA;
				end
				if (OP1_LFORST) begin
					NEW_LFO_DIV = '0;
					NEW_LFO_DATA = '0;
				end
				
				if (KEY_RAM_Q[2])
					NEW_LOAD_POS = OP1_LOAD_POS + 4'd1;
				else
					NEW_LOAD_POS = '0;
				
				KEY_RAM_D[2] <= KEY_RAM_Q[2];
				if (NEW_LOAD_POS == 4'd12) KEY_RAM_D[2] <= 0;
				else if (REG_LOAD[SLOT]) KEY_RAM_D[2] <= 1;
				
				LFO_RAM_D <= {NEW_LOAD_POS,NEW_LFO_DIV,NEW_LFO_DATA};
			end
		end
	end
	
	bit  [ 2:0] KEY_RAM_D;
	bit  [ 2:0] KEY_RAM_Q;
		OPL4_KEY_RAM KEY_RAM(CLK, OP2.SLOT, KEY_RAM_D, SLOT1_CE, SLOT, KEY_RAM_Q);
	
	bit  [21:0] LFO_RAM_D;
	bit  [21:0] LFO_RAM_Q;
	OPL4_LFO_RAM LFO_RAM(CLK, OP2.SLOT, LFO_RAM_D, SLOT1_CE, LFO_RA, LFO_RAM_Q);

	
	//Operation 2: MD read, ADP
	bit  [ 1: 0] OP2_DATA_BIT;
	bit  [21: 0] OP2_SA;
	bit  [15: 0] OP2_LA;
	bit  [15: 0] OP2_EA;	
	always @(posedge CLK or negedge RST_N) begin
		EGState_t    OP2_EST;	//Current envelope state
		bit  [ 9: 0] OP2_EVOL;	//Current envelope volume
		bit  [ 8: 0] PHASE_INT;	//New phase integer
		bit  [13: 0] PHASE_FRAC;	//New phase fractional
		bit  [13: 0] CUR_PHASE_FRAC;//Current phase fractional
		bit  [15: 0] CUR_SO;		//Sample offset integer
		bit  [15: 0] NEXT_SO;
		bit  [15: 0] NEW_SAO;
		bit          COMP;
		bit          ALLOW;
		
		if (!RST_N) begin
			OP3 <= OP3_RESET;
			OP2_DATA_BIT <= '0;
			OP2_SA <= '0;
			OP2_LA <= '0;
			OP2_EA <= '0;
			WD_READ <= 0;
		end else if (!RES_N) begin
			OP3 <= OP3_RESET;
			OP2_DATA_BIT <= '0;
			OP2_SA <= '0;
			OP2_LA <= '0;
			OP2_EA <= '0;
			WD_READ <= 0;
		end else begin
			if (CYCLE0_CE) begin
				// _106: relocacion wavetblhdr (canon openMSX/MAME): las ondas
				// >=384 (RAM) llevan su tabla de cabeceras en wavetblhdr*0x80000
				// (reg 02 bits 4:2 = MEMMODE[4:2]); sin esto MBWave/Bombaman y
				// cualquier musica con instrumentos propios leian cabeceras de
				// la YRW801 (wave*12 siempre). WTN>=384 <=> WTN[8:7]==11 y
				// (WTN-384) == WTN[6:0].
				{OP2_DATA_BIT,OP2_SA} <= OP2.LOAD ? {2'b00 ,
					((OP2.WTN[8:7] == 2'b11 && MEMMODE[4:2] != 3'd0)
					 ? {MEMMODE[4:2],19'd0} + {12'b000000000000,OP2.WTN[6:0],3'b000} + {13'b0000000000000,OP2.WTN[6:0],2'b00}
					 : {10'b0000000000,OP2.WTN,3'b000} + {11'b00000000000,OP2.WTN,2'b00})} + OP2.LOAD_POS : REG_SA_Q;
				OP2_LA <= REG_LA_Q;
				OP2_EA <= ~(REG_EA_Q) + 16'd1;
				case (CYCLE_NUM[2:1])
					2'b00: begin
						{OP2_EST,OP2_EVOL} <= EVOL_RAM_Q;
					end
				endcase
			end
		
			CUR_SO = OP2.KON ? '0 : SO_RAM_Q;
			
			//Phase accum
			if (OP2.RST || OP2.LOAD)
				{PHASE_INT,PHASE_FRAC} = '0;
			else
				{PHASE_INT,PHASE_FRAC} = {9'b000000000,CUR_PHASE_FRAC} + OP2.PHASE;
			NEXT_SO = CUR_SO + {7'b0000000,PHASE_INT};
			
			CUR_PHASE_FRAC = OP2.KON ? '0 : PHASE_FRAC_RAM_Q;
						
			ALLOW = 1;
			if (SLOT1_CE) begin
				//Sample offset
				if (OP2.RST || OP2.LOAD) begin
					NEW_SAO = '0;
					ALLOW = 0;
				end else if (OP2_EVOL >= 10'h3C0 && !OP2.KON) begin
					NEW_SAO = '0;
					ALLOW = 0;
				end else begin
					NEW_SAO = NEXT_SO;
					if (NEXT_SO >= OP2_EA) begin
						NEW_SAO = NEXT_SO + (OP2_LA - OP2_EA);
					end
				end
				SO_RAM_D <= NEW_SAO;
				
				OP3.SLOT <= OP2.SLOT;
				OP3.RST <= OP2.RST;
				OP3.KON <= OP2.KON;
				OP3.KOFF <= OP2.KOFF;
				OP3.LOAD <= OP2.LOAD;
				OP3.LOAD_POS <= OP2.LOAD_POS;
				OP3.ALLOW <= ALLOW;
				OP3.SO <= OP2.LOAD ? 16'h0000 : CUR_SO;
//				OP3.MOD <= MDCalc(SOUSX, SOUSY, OP2_SCR4.MDL);
				OP3.PHASE_FRAC <= OP2.LOAD ? 14'h0000 : CUR_PHASE_FRAC;
				
				WD_SA <= OP2_SA;
				WD_DATA_LEN <= OP2_DATA_BIT;
				WD_READ <= ALLOW | OP2.LOAD;
				
				PHASE_FRAC_RAM_D <= ALLOW ? PHASE_FRAC : '0;
			end
		end
	end
	bit [15:0] SO_RAM_D;
	bit [15:0] SO_RAM_Q;
		OPL4_SO_RAM SO_RAM(CLK, OP3.SLOT, SO_RAM_D, SLOT1_CE, OP2.SLOT, SO_RAM_Q);
	
	bit  [13:0] PHASE_FRAC_RAM_D;
	bit  [13:0] PHASE_FRAC_RAM_Q;
		OPL4_PHASE_RAM PHASE_FRAC_RAM(CLK, OP3.SLOT, PHASE_FRAC_RAM_D, SLOT1_CE, OP2.SLOT, PHASE_FRAC_RAM_Q);
	
	//Operation 3:  
	bit  [21: 0] WD_SA;
	bit  [ 1: 0] WD_DATA_LEN;
	
	wire [21: 0] MOD_PHASE_CURR = /*OP3.MOD +*/ {16'h0000,OP3.PHASE_FRAC[13:8]};
	wire [15: 0] MOD_PHASE_INTEGER = MOD_PHASE_CURR[21:6];
	wire [16: 0] SO_MOD = {1'b0,OP3.SO + (!CYCLE_NUM[2] ? 16'd0 : 16'd1)} /*+ {MOD_PHASE_INTEGER[15],MOD_PHASE_INTEGER}*/;
	wire [21: 0] SO_MOD_BY_1 = {{5{SO_MOD[16]}},SO_MOD};
	wire [21: 0] SO_MOD_BY_1_5 = {{5{SO_MOD[16]}},SO_MOD} + {{6{SO_MOD[16]}},SO_MOD[16:1]};
	wire [21: 0] SO_MOD_BY_2 = {{4{SO_MOD[16]}},SO_MOD,1'b0};
	wire [21: 0] WD_OFFS = WD_DATA_LEN == 2'h0 ? SO_MOD_BY_1 : WD_DATA_LEN == 2'h1 ? SO_MOD_BY_1_5 : SO_MOD_BY_2;
	assign WD_ADDR = WD_SA + WD_OFFS + (!CYCLE_NUM[1] ? 16'd0 : 16'd1);
	assign MEM_SLOT = OP3.SLOT;   // _107: coherente con WD_SA (latch conjunto)
	assign MIX_FM = MIXFM;        // _110: reg F8 hacia el mixer del top
	
	always @(posedge CLK or negedge RST_N) begin
		bit  [15: 0] WD;
		bit          SO0_CURR,SO0_NEXT;
		
		if (!RST_N) begin
			OP4 <= OP4_RESET;
			OP4_WD <= '0;
		end else if (!RES_N) begin
			OP4 <= OP4_RESET;
			OP4_WD <= '0;
		end else begin
			if (CYCLE1_CE) begin
				case (CYCLE_NUM[2:1])
					2'h1: begin WD[15:8] <= MEM_D; SO0_CURR <= SO_MOD[0]; end
					2'h2: WD[7:0] <= MEM_D;
				endcase
			end
			
			if (SLOT1_CE) begin
				OP4.SLOT <= OP3.SLOT;
				OP4.RST <= OP3.RST;
				OP4.KON <= OP3.KON;
				OP4.KOFF <= OP3.KOFF;
				OP4.MODF <= MOD_PHASE_CURR[5:0];
				OP4_WD <= WD;
				OP4_DATA_LEN <= WD_DATA_LEN;
				OP4_SO0_CURR <= SO0_CURR;
				OP4_SO0_NEXT <= SO0_NEXT;
			end
		end
	end
	
	//Operation 4: Interpolation, EG, ALFO
	bit  [15: 0] OP4_WD;
	bit  [ 1: 0] OP4_DATA_LEN;
	bit          OP4_SO0_CURR,OP4_SO0_NEXT;
	
	bit  [ 3: 0] OP4_AR,OP4_D1R,OP4_D2R,OP4_RR,OP4_RC,OP4_DL;
	bit  [ 3: 0] OP4_OCT;
	bit          OP4_FNUM9;
	bit  [ 9: 0] OP4_EVOL;	//Current envelope volume
	EGState_t    OP4_EST;	//Current envelope state
	bit  [18: 0] SCNT;		//Sample counter
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			SCNT <= '0;
		end else if (!RES_N) begin
			SCNT <= '0;
		end else begin
			if (SLOT1_CE) begin
				if (OP4.SLOT == 5'd23) begin
					SCNT <= SCNT + 1'd1;
				end
			end
		end
	end
	
	bit  [ 5: 0] EFF_RATE;	//Effective rate
	bit          EFF_RATE_OVR;	//Effective rate over
	bit          ENV_STEP;
	bit  [ 3: 0] ENV_INC;
	always_comb begin
		bit  [ 3: 0] RATE;
		
		case (OP4_EST)
			EST_ATTACK: RATE = OP4_AR;	
			EST_DECAY1: RATE = OP4_D1R;
			EST_DECAY2: RATE = OP4_D2R;
			EST_RELEASE: RATE = OP4_RR;
		endcase
		if (OP4_EST == EST_RELEASE && OP4.KON) begin
			RATE = OP4_AR;
		end else if (OP4_EST != EST_RELEASE && OP4.KOFF) begin
			RATE = OP4_RR;
		end
		{EFF_RATE_OVR,EFF_RATE} = EffRateCalc(RATE, OP4_RC, OP4_OCT, OP4_FNUM9);
		
		ENV_STEP <= EnvStep(SCNT[18:1], EFF_RATE);
		ENV_INC <= EnvInc(SCNT[18:1], EFF_RATE);
	end
	
	bit  [ 7: 0] OP4_LFO_DATA;
	bit  [ 2: 0] OP4_AM;
	always @(posedge CLK or negedge RST_N) begin
		bit  [10: 0] ATTACK_VOL_CALC,DECAY_VOL_CALC;
		bit  [ 9: 0] NEW_EVOL;
		bit  [ 1: 0] NEW_EST;
		
		if (!RST_N) begin
			OP5 <= OP5_RESET;
			{OP4_AR,OP4_D1R,OP4_D2R,OP4_RR,OP4_RC,OP4_DL} <= '0;
			{OP4_OCT,OP4_FNUM9} <= '0;
			{OP4_EST,OP4_EVOL} <= '0;
		end else if (!RES_N) begin
			OP5 <= OP5_RESET;
			{OP4_AR,OP4_D1R,OP4_D2R,OP4_RR,OP4_RC,OP4_DL} <= '0;
			{OP4_OCT,OP4_FNUM9} <= '0;
			{OP4_EST,OP4_EVOL} <= '0;
		end else begin
			if (CYCLE0_CE) begin
				{OP4_AR,OP4_D1R} <= REG_RATE0_Q;
				{OP4_DL,OP4_D2R} <= REG_RATE1_Q;
				{OP4_RC,OP4_RR} <= REG_RATE2_Q;
				OP4_AM <= REG_AM_Q[2:0];
				case (CYCLE_NUM[2:1])
					2'b10: begin
						OP4_OCT <= REG_FNUM_Q[15:12];
						OP4_FNUM9 <= REG_FNUM_Q[10];
						{OP4_EST,OP4_EVOL} <= EVOL_RAM_Q;
						OP4_LFO_DATA <= LFO_RAM_Q[7:0];
					end
				endcase
			end
			
`ifdef DEBUG
			if (CYCLE1_CE) begin
				DECAY1_DBG <= 0;
				DECAY2_DBG <= 0;
				ATTACK_DBG <= 0;
				RELEASE_DBG <= 0;
			end
`endif
			if (SLOT1_CE) begin
				NEW_EVOL = OP4_EVOL;
				NEW_EST = OP4_EST;
				
				ATTACK_VOL_CALC = {1'b0,OP4_EVOL} + (ENV_STEP ? $signed($signed(~{1'b0,OP4_EVOL}) * $unsigned(ENV_INC)) : 11'd0);
				DECAY_VOL_CALC = {1'b0,OP4_EVOL} + (ENV_STEP ? {7'b0000000,ENV_INC} : 11'd0);
				if (OP4.RST) begin
					NEW_EVOL = 10'h3FF;
					NEW_EST = EST_RELEASE;
				end else if (OP4_EST == EST_RELEASE && OP4.KON) begin
					NEW_EVOL = EFF_RATE_OVR ? 10'h000 : 10'h280;
					NEW_EST = EST_ATTACK;
`ifdef DEBUG
					ATTACK_DBG <= 1;
`endif
				end else if (OP4_EST != EST_RELEASE && OP4.KOFF) begin
					NEW_EST = EST_RELEASE;
`ifdef DEBUG
					RELEASE_DBG <= 1;
`endif
				end else begin
					case (OP4_EST)
						EST_ATTACK: begin
							if (!ATTACK_VOL_CALC[10]) begin
								NEW_EVOL = ATTACK_VOL_CALC[9:0];
							end else begin
								NEW_EVOL = 10'h000;
							end
							if (!OP4_EVOL) begin
								NEW_EST = EST_DECAY1;
`ifdef DEBUG
								DECAY1_DBG <= 1;
`endif
							end
						end
						
						EST_DECAY1: begin
							if (!DECAY_VOL_CALC[10]) begin
								NEW_EVOL = DECAY_VOL_CALC[9:0];
							end else begin
								NEW_EVOL = 10'h3FF;
							end
							if (OP4_EVOL[9:6] == OP4_DL) begin
								NEW_EST = EST_DECAY2;
`ifdef DEBUG
								DECAY2_DBG <= 1;
`endif
							end
						end
						
						EST_DECAY2: begin
							if (!DECAY_VOL_CALC[10]) begin
								NEW_EVOL = DECAY_VOL_CALC[9:0];
							end else begin
								NEW_EVOL = 10'h3FF;
							end
						end
						
						EST_RELEASE: begin
							if (!DECAY_VOL_CALC[10]) begin
								NEW_EVOL = DECAY_VOL_CALC[9:0];
							end else begin
								NEW_EVOL = 10'h3FF;
							end
						end
					endcase
				end
				EVOL_RAM_D <= {NEW_EST,NEW_EVOL};
				
				OP5.SLOT <= OP4.SLOT;
				OP5.RST <= OP4.RST;
				OP5.KON <= OP4.KON;
				OP5.KOFF <= OP4.KOFF;
				OP5.EVOL <= NEW_EVOL;
				
				OP5.WD <= OP4_DATA_LEN == 2'b00 ? {OP4_WD[15:8],8'h00} : 
				          OP4_DATA_LEN == 2'b01 ? (!OP4_SO0_CURR ? {OP4_WD[15:8],OP4_WD[7:4],4'h0} : {OP4_WD[7:0],OP4_WD[11:8],4'h0}) : 
							                         OP4_WD;
				
				OP5.ALFO <= AMCalc(OP4_LFO_DATA, OP4_AM);
			end
		end
	end
	bit [11:0] EVOL_RAM_D;
	bit [11:0] EVOL_RAM_Q;
		OPL4_EVOL_RAM EVOL_RAM(CLK, OP5.SLOT, EVOL_RAM_D, SLOT1_CE, EVOL_RA, EVOL_RAM_Q);

	//Operation 5: Level calculation
	bit  [ 6: 0] OP5_TL;
	bit          OP5_LDIR;
	always @(posedge CLK or negedge RST_N) begin	
		bit  [ 6: 0] TL_INT;
		bit  [ 9: 0] TL_FRAC;
	
		if (!RST_N) begin
			OP6 <= OP6_RESET;
			{OP5_TL,OP5_LDIR} <= '0;
		end else if (!RES_N) begin
			OP6 <= OP6_RESET;
			{OP5_TL,OP5_LDIR} <= '0;
		end else begin
			if (CYCLE0_CE) begin
				{OP5_TL,OP5_LDIR} <= REG_LEVEL_Q;
			end
			
			{TL_INT,TL_FRAC} = TL_RAM_Q;
			if (SLOT1_CE) begin
				if (OP5_LDIR) TL_RAM_D <= {OP5_TL,10'h000};
				else begin
					if (TL_INT > OP5_TL) begin
						TL_RAM_D <= {TL_INT,TL_FRAC} + 17'd19;
					end
					else if (TL_INT < OP5_TL) begin
						TL_RAM_D <= {TL_INT,TL_FRAC} - 17'd38;
					end
					else begin
						TL_RAM_D <= {TL_INT,TL_FRAC};
					end
				end
				
				OP6.SLOT <= OP5.SLOT;
				OP6.RST <= OP5.RST;
				OP6.KON <= OP5.KON;
				OP6.KOFF <= OP5.KOFF;
				OP6.LEVEL <= LevelAddTLALFO(OP5.EVOL, {TL_INT, TL_FRAC[9:8]}, OP5.ALFO);
				OP6.WD <= OP5.WD;
			end
		end
	end
	bit [16:0] TL_RAM_D;
	bit [16:0] TL_RAM_Q;
		OPL4_TL_RAM TL_RAM(CLK, OP6.SLOT, TL_RAM_D, SLOT1_CE, OP5.SLOT, TL_RAM_Q);

	//Operation 6: Level calculation
	always @(posedge CLK or negedge RST_N) begin		
		if (!RST_N) begin
			OP7 <= OP7_RESET;
		end else if (!RES_N) begin
			OP7 <= OP7_RESET;
		end else begin
			
			if (SLOT1_CE) begin
				OP7.SLOT <= OP6.SLOT;
				OP7.RST <= OP6.RST;
				OP7.KON <= OP6.KON;
				OP7.KOFF <= OP6.KOFF;
				OP7.SD <= VolCalc(OP6.WD, OP6.LEVEL);
			end
		end
	end
	
	//Operation 7: 
	bit  [ 3: 0] OP7_PAN;
	bit          OP7_CH;
	bit  [17: 0] ACC_L,ACC_R;
	always @(posedge CLK or negedge RST_N) begin
		bit [ 4:0] S;
		bit signed [15:0] TEMP;
		bit signed [15:0] PAN_L,PAN_R;
		
		if (!RST_N) begin
			OP7_PAN <= '0;
			ACC_L <= 0;
			ACC_R <= 0;
		end else if (!RES_N) begin
			OP7_PAN <= '0;
			ACC_L <= 0;
			ACC_R <= 0;
		end else begin
			if (CYCLE0_CE) begin
				{OP7_CH,OP7_PAN} <= REG_PAN_Q[4:0];
			end
			
			S = OP7.SLOT;
			TEMP = !OP7_CH ? OP7.SD : '0;
			PAN_L = PanLCalc(TEMP,OP7_PAN);
			PAN_R = PanRCalc(TEMP,OP7_PAN);
			
			if (SLOT1_CE) begin
				if (S == 5'd0) begin
					ACC_L <= {{2{PAN_L[15]}},PAN_L[15:0]};
					ACC_R <= {{2{PAN_R[15]}},PAN_R[15:0]};
				end else begin
					ACC_L <= ACC_L + {{2{PAN_L[15]}},PAN_L[15:0]};
					ACC_R <= ACC_R + {{2{PAN_R[15]}},PAN_R[15:0]};
				end
			end
			
`ifdef DEBUG
			LVL_DBG <= TEMP;
			PAN_L_DBG <= PAN_L;
			PAN_R_DBG <= PAN_R;
`endif
		end
	end
	
	//Out
	bit  [15: 0] PCM_L,PCM_R;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			PCM_L <= '0;
			PCM_R <= '0;
		end else if (!RES_N) begin
			
		end else begin
			if (OP7.SLOT == 5'd0 && CYCLE_NUM[2:1] == 2'b00 && CYCLE1_CE) begin
				PCM_L <= (!SND_EN[2] ? 16'h0000 : TrimWave(ACC_L));
				PCM_R <= (!SND_EN[2] ? 16'h0000 : TrimWave(ACC_R));
			end
		end
	end
	
	//Memory/Registers
	bit          MEM_WREQ,MEM_RREQ;
	always @(posedge CLK or negedge RST_N) begin
		bit         WR_N_OLD,RD_N_OLD,CS_N_OLD;
		bit [ 1: 0] REG_RD_DELAY;
		bit         REG_NEW_SEL;
		bit [ 3: 0] LD_WAIT;
		bit         MEM_START;
		
		if (!RST_N) begin
			NEW2 <= 0;
			TEST0 <= '0;
			TEST1 <= '0;
			MEMMODE <= '0;
			MEMADDR <= '0;
			MEMDAT <= '0;
			MIXFM <= '0;
			MIXPCM <= '0;
			REG_Q <= '0;
			{BUSY,BUSY2} <= 0;
			LD <= 0;
			LD2 <= 0;
		end else begin
			if (!RES_N) begin
				NEW2 <= 0;
				TEST0 <= '0;
				TEST1 <= '0;
				MEMMODE <= '0;
				MEMADDR <= '0;
				MEMDAT <= '0;
				MIXFM <= {3'h3,3'h3};
				MIXPCM <= {3'h0,3'h0};
				LD2 <= 0;
				MEM_A <= '0;
				MEM_WR <= 0;
				MEM_RD <= 0;
			end else if (CE) begin
				//Register access
				if (CYCLE1_CE) begin
					REG_RD <= 0;
					REG_WR <= 0;
					BUSY <= 0;
				end
				
				WR_N_OLD <= WR_N;
				RD_N_OLD <= RD_N;
				CS_N_OLD <= CS_N;
				if (RD_N && !RD_N_OLD && !CS_N_OLD && A == 3'h0) begin
					if (LD2) LD2 <= 0;
				end
				if (!RD_N && RD_N_OLD && !CS_N && A == 3'h5 && NEW2) begin
					REG_RD <= 1;
					BUSY <= 1;
				end
				if (!WR_N && WR_N_OLD && !CS_N) begin
					REG_NEW_SEL <= 0;
					case (A)
						3'h2: REG_NEW_SEL <= (DI == 8'h05);
						3'h3: if (REG_NEW_SEL && DI[1]) begin NEW2 <= 1; LD2 <= 1; end
						3'h4: if (NEW2) REG_A <= DI;
						3'h5: if (NEW2) begin
							REG_D <= DI;
							REG_WR <= 1;
							BUSY <= 1;
						end
					endcase
				end
				
				if (OP7.SLOT == 5'd23 && SLOT1_CE) begin
					if (LD_WAIT) LD_WAIT <= LD_WAIT - 4'd1;
					else LD <= 0;
				end
				
				REG_RD_DELAY[0] <= REG_RD;
				REG_RD_DELAY[1] <= REG_RD_DELAY[0];
				if (REG_WR && CYCLE1_CE) begin
					case (REG_A)
						8'h00: TEST0 <= REG_D;
						8'h01: TEST1 <= REG_D;
						8'h02: MEMMODE[4:0] <= REG_D[4:0];
						8'h03: MEMADDR[21:16] <= REG_D[5:0]; // MSXimus: 6 bits (el [4:0] original perdia el bit21 = la RAM de muestras en 0x200000+)
						8'h04: MEMADDR[15:8] <= REG_D;
						8'h05: MEMADDR[7:0] <= REG_D;
						8'h06: MEMDAT <= REG_D; 
						8'hF8: MIXFM <= REG_D[5:0];
						8'hF9: MIXPCM <= REG_D[5:0];
						default:;
					endcase
					if (REG_WTN_SEL) begin
						LD <= 1;
						LD_WAIT <= 4'd12;
					end
					if (REG_A == 8'h06) begin MEM_WREQ <= 1; BUSY2 <= 1; end
					if (REG_A == 8'h05) begin MEM_RREQ <= 1; BUSY2 <= 1; end
				end
				if (REG_RD_DELAY == 2'b01) begin
					// era v3: WTN/LEVEL/PAN salen de la BSRAM unica igual
					// que RATE/AM — el valor bueno se remuestrea en
					// DELAY==10 (ver mas abajo)
					if (REG_WTN_SEL) REG_Q <= rt_cpu_q;
					else if (REG_FNUM0_SEL) REG_Q <= REG_FNUM_Q[15:8];
					else if (REG_FNUM1_SEL) REG_Q <= REG_FNUM_Q[7:0];
					else if (REG_LEVEL_SEL) REG_Q <= rt_cpu_q;
					else if (REG_PAN_SEL) REG_Q <= rt_cpu_q;
					else if (REG_LFO_SEL) REG_Q <= REG_LFO_Q;
					// era v3: los cuatro salen de la BSRAM unica; el dato
					// bueno se remuestrea un CE mas tarde (ver abajo)
					else if (REG_RATE0_SEL) REG_Q <= rt_cpu_q;
					else if (REG_RATE1_SEL) REG_Q <= rt_cpu_q;
					else if (REG_RATE2_SEL) REG_Q <= rt_cpu_q;
					else if (REG_AM_SEL) REG_Q <= rt_cpu_q;
					else begin
						case (REG_A)
							8'h00: REG_Q <= TEST0;
							8'h01: REG_Q <= TEST1;
							8'h02: REG_Q <= {3'b001,MEMMODE};
							8'h03: REG_Q <= {2'b00,MEMADDR[21:16]};
							8'h04: REG_Q <= MEMADDR[15:8];
							8'h05: REG_Q <= MEMADDR[7:0];
							8'h06: REG_Q <= MEMDAT;
							8'hF8: REG_Q <= {2'b00,MIXFM};
							8'hF9: REG_Q <= {2'b00,MIXPCM};
							default: REG_Q <= '0;
						endcase
						// MSXimus: el incremento de lectura va AQUI (al consumir
						// reg6), no al completarse el fetch — el prefetch del
						// write de reg5 dejaba MEMADDR corrido +1 y las
						// ESCRITURAS de reg6 aterrizaban un byte desplazadas
						// (semantica del chip real segun MAME/openMSX)
						if (REG_A == 8'h06) begin MEM_RREQ <= 1; BUSY2 <= 1; MEMADDR <= MEMADDR + 22'd1; end
					end
				end
				// ERA v3: el grupo RATE/AM ya no es un array de lectura
				// asincrona, sino BSRAM: su dato tarda DOS clk (peticion +
				// captura) desde REG_RD, y la ventana DELAY==01 solo da uno
				// garantizado. Se remuestrea en DELAY==10, un CE despues —
				// sobra margen (el consumidor es el Z80 leyendo el puerto).
				// Sin esto, el readback devuelve el valor de la lectura
				// ANTERIOR (cazado por tb_regrd: 144/144 mal).
				if (REG_RD_DELAY == 2'b10 && rt_sel) REG_Q <= rt_cpu_q;

				//Memory access
				if (CYCLE1_CE) begin
					if (MEM_RD && !MEMMODE[0]) begin
						MEM_D <= MDI;
					end
					if (MEM_RD && MEMMODE[0]) begin
						MEMDAT <= MDI;      // MSXimus: sin incremento (ver arriba)
					end
					if (MEM_WR && MEMMODE[0]) begin
						MEMADDR <= MEMADDR + 22'd1;
					end
					MEM_WR <= 0;
					MEM_RD <= 0;
					BUSY2 <= 0;
				end
				
				MEM_START <= CYCLE1_CE;
				if (MEM_START && WD_READ && !MEMMODE[0]) begin
					MEM_A <= WD_ADDR;
					MEM_WR <= 0;
					MEM_RD <= 1;
				end
				else if (MEM_START && (MEM_WREQ || MEM_RREQ) && MEMMODE[0]) begin
					MEM_A <= MEMADDR;
					MEM_WR <= MEM_WREQ;
					MEM_RD <= MEM_RREQ;
					BUSY2 <= 1;
					MEM_WREQ <= 0;
					MEM_RREQ <= 0;
				end
			end
		end
	end
	assign MA = MEM_A[20:0];
	assign MDO = MEMDAT;
	assign MWR_N = ~MEM_WR;
	assign MRD_N = ~MEM_RD;
	assign MCS_N[0] = ~(MEM_A[21:19] ==? 3'b0??);
	assign MCS_N[1] = ~(MEM_A[21:19] ==? 3'b1??);
	assign MCS_N[2] = ~(MEM_A[21:19] ==? 3'b00?);
	assign MCS_N[3] = ~(MEM_A[21:19] ==? 3'b01?);
	assign MCS_N[4] = ~(MEM_A[21:19] ==? 3'b10?);
	assign MCS_N[5] = ~(MEM_A[21:19] ==? 3'b11?);
	assign MCS_N[6] = ~(MEM_A[21:19] == 3'b100);
	assign MCS_N[7] = ~(MEM_A[21:19] == 3'b101);
	assign MCS_N[8] = ~(MEM_A[21:19] == 3'b110);
	assign MCS_N[9] = ~(MEM_A[21:19] == 3'b111);

	
	// =====================================================================
	// ERA v3 (sin SSRAM): el grupo SA/LA/EA — 7 campos de 32x8 con la MISMA
	// direccion de lectura (SA_RA) y de escritura, y SIN acceso de CPU —
	// deja de ser 7 arrays (1.8K FF + 7 muxes 32:1) y pasa a UNA BSRAM
	// 256x8 con direccion {campo[2:0], slot[4:0]} y DOS barridos por slot.
	//
	// La clave que lo hace seguro es el pipeline: en el slot en que
	// SLOT==s, las etapas llevan OP2=s-1, OP3=s-2, OP4=s-3. Las escrituras
	// van SIEMPRE a OP3.SLOT (LOAD, un campo por SLOT0_CE via LOAD_POS
	// 0..6) o a OP2.SLOT (limpieza en OP2.RST) — NUNCA a las direcciones
	// que los barridos leen (SLOT y OP4.SLOT): imposible leer rancio.
	//
	// MEDIDO EN SIM (sonda probe_sa, 04/08): la direccion consumida es
	// SLOT-1 durante TODO el slot y EN LAS DOS FASES (OP2.SLOT y OP4.SLOT
	// valen lo mismo en cada CYCLE0_CE: el mux de fase es vestigial), y
	// las escrituras LOAD van a OP3.SLOT = SLOT-2 en el SLOT0_CE. Por
	// tanto: UN SOLO barrido por slot, disparado al final del CYCLE 3,
	// leyendo {campo, SLOT} — la direccion que se consumira el slot
	// siguiente. Sin colision por construccion (escrituras a SLOT-2) y
	// con ~17 clk de margen hasta la frontera (el barrido tarda ~9).
	// Durante el clear de reset (OP2.RST) los latches se fuerzan a 0: el
	// original leia en vivo el slot recien borrado (ceros); el barrido
	// adelantado le habria ensenado el dato pre-borrado una vuelta.
	// =====================================================================
	(* syn_ramstyle = "block_ram" *) bit [7:0] sa_mem [0:255];
	initial for (int si = 0; si < 256; si++) sa_mem[si] = '0;
	bit [7:0] sa_q  [0:6];     // banco ACTIVO (lo que consumen los Q)
	bit [7:0] sa_st [0:6];     // staging del barrido; commit en SLOT1_CE
	// init explicito: sv2v convierte bit->reg (4 estados) y el postproc no
	// cubre arrays desempaquetados — sin esto arrancan en X y lo propagan
	initial for (int qi = 0; qi < 7; qi++) begin sa_q[qi] = '0; sa_st[qi] = '0; end
	bit [2:0] sa_swp, sa_cap, sa_rstf;
	bit       sa_swp_on, sa_cap_on;
	bit [7:0] sa_rq;

	// escritura: limpieza de reset (7 campos de OP2.SLOT, uno por clk,
	// ciclando — el slot dura ~35 clk asi que barre todos de sobra; el
	// original escribia los 7 arrays a la vez, mismo estado final y los
	// consumidores estan en reset) > LOAD (un campo por SLOT0_CE)
	wire       sa_we_load = OP3.LOAD & SLOT0_CE & (OP3.LOAD_POS < 4'd7);
	wire       sa_we      = OP2.RST | sa_we_load;
	wire [7:0] sa_waddr   = OP2.RST ? {sa_rstf, OP2.SLOT}
	                                : {OP3.LOAD_POS[2:0], OP3.SLOT};

	always_ff @(posedge CLK) begin
		if (sa_we) sa_mem[sa_waddr] <= OP2.RST ? 8'd0 : MEM_D;
		sa_rstf <= (sa_rstf == 3'd6) ? 3'd0 : sa_rstf + 3'd1;

		// puerto de lectura: el barrido unico ({campo, SLOT}) a STAGING;
		// el commit staging->activo va en la frontera (SLOT1_CE) para que
		// los 4 consumos del slot vean el MISMO juego (la primera version
		// refrescaba en vivo a mitad de slot y c4/c6 veian el siguiente)
		sa_rq     <= sa_mem[{sa_swp, SLOT}];
		sa_cap    <= sa_swp;
		sa_cap_on <= sa_swp_on;
		if (sa_cap_on)
			sa_st[sa_cap] <= sa_rq;
		if (OP2.RST) begin
			sa_q[0] <= '0; sa_q[1] <= '0; sa_q[2] <= '0; sa_q[3] <= '0;
			sa_q[4] <= '0; sa_q[5] <= '0; sa_q[6] <= '0;
		end
		else if (SLOT1_CE) begin
			sa_q[0] <= sa_st[0]; sa_q[1] <= sa_st[1]; sa_q[2] <= sa_st[2];
			sa_q[3] <= sa_st[3]; sa_q[4] <= sa_st[4]; sa_q[5] <= sa_st[5];
			sa_q[6] <= sa_st[6];
		end

		if (CYCLE1_CE && CYCLE_NUM == 3'd3) begin
			sa_swp_on <= 1'b1;  sa_swp <= 3'd0;
		end
		else if (sa_swp_on) begin
			if (sa_swp == 3'd6) sa_swp_on <= 1'b0;
			else                sa_swp <= sa_swp + 3'd1;
		end
	end

	bit [23:0] REG_SA_Q;
	bit [15:0] REG_LA_Q;
	bit [15:0] REG_EA_Q;
	assign REG_SA_Q = {sa_q[0],sa_q[1],sa_q[2]};
	assign REG_LA_Q = {sa_q[3],sa_q[4]};
	assign REG_EA_Q = {sa_q[5],sa_q[6]};
	
	wire       REG_WTN_SEL = (REG_A >= 8'h08 && REG_A <= 8'h1F);
	// era v3: WTN vive en la BSRAM unica rt_mem (campo RT_WT)
	//OPL4_REG_RAM #(5,8) REG_WTN  (CLK, OP4.RST ? OP4.SLOT :                       REG_A[4:0]-5'h08, OP4.RST ? '0 :                    REG_D, OP4.RST ? 1'b1 : (REG_WR & REG_WTN_SEL & CYCLE1_CE), (REG_RD ? REG_A[4:0]-5'h08 : SLOT), REG_WTN_Q);
	
	wire       REG_FNUM0_SEL = (REG_A >= 8'h38 && REG_A <= 8'h4F);
	wire       REG_FNUM1_SEL = (REG_A >= 8'h20 && REG_A <= 8'h37);
	bit [15:0] REG_FNUM_Q;
	OPL4_REG_RAM #(5,8) REG_FNUM0(CLK,     RST ?     SLOT :                       REG_A[4:0]-5'h18,     RST ? '0 :                    REG_D,     RST ? 1'b1 : (REG_WR & REG_FNUM0_SEL & CYCLE1_CE), (REG_RD ? REG_A[4:0]-5'h18 : FNUM_RA ), REG_FNUM_Q[15:8]);
	OPL4_REG_RAM #(5,8) REG_FNUM1(CLK,     RST ?     SLOT :                       REG_A[4:0]-5'h00,     RST ? '0 :                    REG_D,     RST ? 1'b1 : (REG_WR & REG_FNUM1_SEL & CYCLE1_CE), (REG_RD ? REG_A[4:0]-5'h00 : FNUM_RA ), REG_FNUM_Q[7:0]);
	
	wire       REG_LEVEL_SEL = (REG_A >= 8'h50 && REG_A <= 8'h67);
	// era v3: LEVEL vive en la BSRAM unica rt_mem (campo RT_LV)
	//OPL4_REG_RAM #(5,8) REG_LEVEL(CLK,     RST ?     SLOT :                       REG_A[4:0]-5'h10,     RST ? '0 :                    REG_D,     RST ? 1'b1 : (REG_WR & REG_LEVEL_SEL & CYCLE1_CE), (REG_RD ? REG_A[4:0]-5'h10 : OP5.SLOT ), REG_LEVEL_Q);
	
	wire       REG_PAN_SEL = (REG_A >= 8'h68 && REG_A <= 8'h7F);
	// era v3: PAN vive en la BSRAM unica rt_mem (campo RT_PN)
	//OPL4_REG_RAM #(5,8) REG_PAN  (CLK,     RST ?     SLOT :                       REG_A[4:0]-5'h08,     RST ? '0 :                    REG_D,     RST ? 1'b1 : (REG_WR & REG_PAN_SEL & CYCLE1_CE), (REG_RD ? REG_A[4:0]-5'h08 : OP7.SLOT ), REG_PAN_Q);
	
	wire       REG_LFO_SEL = (REG_A >= 8'h80 && REG_A <= 8'h97);
	wire       REG_LFO_LOAD  = (OP3.LOAD_POS == 4'h7);
	bit [ 7:0] REG_LFO_Q;
	OPL4_REG_RAM #(5,8) REG_LFO  (CLK,     RST ?     SLOT : OP3.LOAD ? OP3.SLOT : REG_A[4:0]-5'h00,     RST ? '0 : OP3.LOAD ? MEM_D : REG_D,     RST ? 1'b1 : OP3.LOAD ? (REG_LFO_LOAD & SLOT0_CE) : (REG_WR & REG_LFO_SEL & CYCLE1_CE), (REG_RD ? REG_A[4:0]-5'h00 : LFO_RA ), REG_LFO_Q);
	
	wire       REG_RATE0_SEL = (REG_A >= 8'h98 && REG_A <= 8'hAF);
	wire       REG_RATE1_SEL = (REG_A >= 8'hB0 && REG_A <= 8'hC7);
	wire       REG_RATE2_SEL = (REG_A >= 8'hC8 && REG_A <= 8'hDF);
	wire       REG_AM_SEL    = (REG_A >= 8'hE0 && REG_A <= 8'hF7);

	// =====================================================================
	// ERA v3: grupo RATE0/1/2 + AM (4 arrays de 32x8 = 1.024 FF + 4 muxes
	// 32:1) fusionado en UNA BSRAM 128x8 con direccion {campo[1:0],slot} y
	// UN barrido por slot con doble bufer — el patron del grupo SA/LA/EA.
	//
	// MEDIDO con probe_rate.v (0 de 3.744 tramos de slot): OP4.SLOT NO
	// cambia nunca dentro de un slot y vale SLOT-3, luego el OP4.SLOT del
	// slot SIGUIENTE es el OP3.SLOT de ahora => el barrido lee
	// {campo, OP3.SLOT} y el commit va en la frontera (SLOT1_CE). Los 4
	// consumos por slot (uno por CYCLE0_CE) leian el MISMO valor: el
	// barrido unico no pierde nada.
	//
	// A DIFERENCIA del grupo SA, este tiene escrituras de CPU y readback:
	//  - escrituras: RST (limpieza, un campo por clk ciclando) > LOAD de
	//    cabecera (un campo por SLOT0_CE, LOAD_POS 8..11) > CPU. Nunca dos
	//    a la vez (los SEL son rangos disjuntos).
	//  - readback: REG_RD roba UN ciclo del puerto de lectura (el barrido
	//    se para ese ciclo; tiene ~17 clk de margen para 4 campos) y el
	//    dato aterriza en rt_cpu_q, que alimenta el mux de REG_Q. El
	//    muestreo del readback va con REG_RD_DELAY, varios CE despues.
	// =====================================================================
	// SIETE campos en UNA BSRAM 256x8 {campo[2:0], slot[4:0]}: RATE0/1/2,
	// AM, WTN, LEVEL y PAN. Los tres ultimos entran GRATIS en BSRAM (256x8
	// = 2 Kbit sigue siendo UN primitivo) — critico, porque el presupuesto
	// esta en 117/118 y no habia sitio para otro bloque.
	//
	// MEDIDO con probe_wlp.v (3743/3743 transiciones): SLOT, OP5.SLOT y
	// OP7.SLOT son estables dentro del slot, y la direccion del slot
	// SIGUIENTE es (SLOT+1) mod 24, OP4.SLOT y OP6.SLOT respectivamente —
	// que es justo lo que lee el barrido pre-frontera de cada campo.
	localparam RT_R0=3'd0, RT_R1=3'd1, RT_R2=3'd2, RT_AM=3'd3,
	           RT_WT=3'd4, RT_LV=3'd5, RT_PN=3'd6;

	wire [2:0] rt_fld = REG_RATE0_SEL ? RT_R0 : REG_RATE1_SEL ? RT_R1
	                  : REG_RATE2_SEL ? RT_R2 : REG_AM_SEL    ? RT_AM
	                  : REG_WTN_SEL   ? RT_WT : REG_LEVEL_SEL ? RT_LV : RT_PN;
	wire [4:0] rt_idx = REG_RATE0_SEL ? REG_A[4:0]-5'h18
	                  : REG_RATE1_SEL ? REG_A[4:0]-5'h10
	                  : REG_RATE2_SEL ? REG_A[4:0]-5'h08
	                  : REG_AM_SEL    ? REG_A[4:0]-5'h00
	                  : REG_WTN_SEL   ? REG_A[4:0]-5'h08
	                  : REG_LEVEL_SEL ? REG_A[4:0]-5'h10 : REG_A[4:0]-5'h08;
	wire       rt_sel = REG_RATE0_SEL | REG_RATE1_SEL | REG_RATE2_SEL
	                  | REG_AM_SEL | REG_WTN_SEL | REG_LEVEL_SEL | REG_PAN_SEL;

	// limpieza de reset serializada: cada campo con SU condicion y SU
	// direccion — WTN se borra con OP4.RST en OP4.SLOT (no con RST en
	// SLOT como los otros seis); respetarlo importa.
	wire       rt_rst_we = (rt_rstf == RT_WT) ? OP4.RST : RST;
	wire [7:0] rt_rst_ad = (rt_rstf == RT_WT) ? {RT_WT, OP4.SLOT}
	                                          : {rt_rstf, SLOT};
	wire       rt_we_load = OP3.LOAD & SLOT0_CE & (OP3.LOAD_POS >= 4'd8)
	                                            & (OP3.LOAD_POS <= 4'd11);
	wire       rt_we_cpu  = REG_WR & CYCLE1_CE & rt_sel;
	// Con SIETE campos en un solo puerto de escritura hay que arbitrar lo
	// que antes tenia siete puertos: una escritura de CPU puede coincidir
	// con un paso de la carga de cabecera (ambos piden CYCLE1_CE) y se
	// perdia. tb_regrd lo cazo (4 de 288, esporadico). La CPU va a un
	// buffer de UNA plaza y entra en cuanto el puerto queda libre — no
	// tiene prisa (el siguiente acceso del Z80 esta a microsegundos) y
	// asi la carga de cabecera nunca cede su turno.
	wire       rt_cpuw_go = rt_cpuw_p & ~rt_rst_we & ~rt_we_load;
	wire       rt_we      = rt_rst_we | rt_we_load | rt_cpuw_go;
	wire [7:0] rt_waddr   = rt_rst_we  ? rt_rst_ad
	                      : rt_we_load ? {1'b0, OP3.LOAD_POS[1:0], OP3.SLOT}
	                                   : rt_cpuw_ad;
	wire [7:0] rt_wdata   = rt_rst_we ? 8'd0 : rt_we_load ? MEM_D : rt_cpuw_dt;
	wire       rt_cpurd   = REG_RD & rt_sel;

	// direccion del barrido: la que consumira el slot SIGUIENTE
	wire [4:0] rt_slot_nx = (SLOT == 5'd23) ? 5'd0 : SLOT + 5'd1;
	wire [4:0] rt_swp_ad  = (rt_swp == RT_WT) ? rt_slot_nx
	                      : (rt_swp == RT_LV) ? OP4.SLOT
	                      : (rt_swp == RT_PN) ? OP6.SLOT : OP3.SLOT;

	(* syn_ramstyle = "block_ram" *) bit [7:0] rt_mem [0:255];
	initial for (int ri = 0; ri < 256; ri++) rt_mem[ri] = '0;
	bit [7:0] rt_q  [0:6];      // banco ACTIVO (lo que consume el motor)
	bit [7:0] rt_st [0:6];      // staging del barrido
	bit [7:0] rt_cpu_q;         // dato del readback de CPU
	initial for (int ri = 0; ri < 7; ri++) begin rt_q[ri] = '0; rt_st[ri] = '0; end
	initial rt_cpu_q = '0;
	bit [2:0] rt_swp, rt_cap, rt_rstf;
	bit       rt_swp_on, rt_cap_on, rt_cpu_on;
	bit [7:0] rt_rq;
	bit       rt_cpuw_p;                 // escritura de CPU en espera
	bit [7:0] rt_cpuw_ad, rt_cpuw_dt;
	initial begin rt_cpuw_p = 1'b0; rt_cpuw_ad = '0; rt_cpuw_dt = '0; end

	always_ff @(posedge CLK) begin
		if (rt_we) rt_mem[rt_waddr] <= rt_wdata;
		rt_rstf <= (rt_rstf == RT_PN) ? 3'd0 : rt_rstf + 3'd1;

		// buffer de la escritura de CPU (ver nota del arbitraje)
		if (rt_we_cpu) begin
			rt_cpuw_p  <= 1'b1;
			rt_cpuw_ad <= {rt_fld, rt_idx};
			rt_cpuw_dt <= REG_D;
		end
		else if (rt_cpuw_go) rt_cpuw_p <= 1'b0;

		// puerto de lectura: la CPU tiene prioridad y roba el ciclo
		rt_rq     <= rt_mem[rt_cpurd ? {rt_fld, rt_idx} : {rt_swp, rt_swp_ad}];
		rt_cap    <= rt_swp;
		rt_cap_on <= rt_swp_on & ~rt_cpurd;
		rt_cpu_on <= rt_cpurd;
		if (rt_cpu_on)      rt_cpu_q       <= rt_rq;
		else if (rt_cap_on) rt_st[rt_cap]  <= rt_rq;

		if (RST) begin
			rt_q[RT_R0] <= '0; rt_q[RT_R1] <= '0; rt_q[RT_R2] <= '0;
			rt_q[RT_AM] <= '0; rt_q[RT_LV] <= '0; rt_q[RT_PN] <= '0;
		end
		else if (SLOT1_CE) begin
			rt_q[RT_R0] <= rt_st[RT_R0]; rt_q[RT_R1] <= rt_st[RT_R1];
			rt_q[RT_R2] <= rt_st[RT_R2]; rt_q[RT_AM] <= rt_st[RT_AM];
			rt_q[RT_LV] <= rt_st[RT_LV]; rt_q[RT_PN] <= rt_st[RT_PN];
		end
		// WTN sigue a OP4.RST, no a RST (como el array original)
		if (OP4.RST)          rt_q[RT_WT] <= '0;
		else if (SLOT1_CE)    rt_q[RT_WT] <= rt_st[RT_WT];

		if (CYCLE1_CE && CYCLE_NUM == 3'd3) begin
			rt_swp_on <= 1'b1;  rt_swp <= 3'd0;
		end
		else if (rt_swp_on && !rt_cpurd) begin
			if (rt_swp == RT_PN) rt_swp_on <= 1'b0;
			else                 rt_swp <= rt_swp + 3'd1;
		end
	end

	wire [7:0] REG_RATE0_Q = rt_q[RT_R0];
	wire [7:0] REG_RATE1_Q = rt_q[RT_R1];
	wire [7:0] REG_RATE2_Q = rt_q[RT_R2];
	wire [7:0] REG_AM_Q    = rt_q[RT_AM];
	wire [7:0] REG_WTN_Q   = rt_q[RT_WT];
	wire [7:0] REG_LEVEL_Q = rt_q[RT_LV];
	wire [7:0] REG_PAN_Q   = rt_q[RT_PN];
	
	
	//OPL3
	bit  [ 7: 0] OPL3_DO;
	bit  [15: 0] OPL3_OUT_A;
	bit  [15: 0] OPL3_OUT_B;
	bit  [15: 0] OPL3_OUT_C;
	bit  [15: 0] OPL3_OUT_D;
	
	assign OPL3_DO = '0;
	assign {OPL3_OUT_A,OPL3_OUT_B,OPL3_OUT_C,OPL3_OUT_D} = '0;
	assign IRQ_N = 1;
	
	assign DO = A == 3'h5 ? REG_Q : OPL3_DO | {6'b000000,LD|LD2,BUSY|BUSY2};
	
	assign OUT0_L = OPL3_OUT_C;
	assign OUT0_R = OPL3_OUT_D;
	
	assign OUT1_L = PCM_L;
	assign OUT1_R = PCM_R;
	
	assign OUT2_L = MixCalc(PCM_L, MIXPCM[2:0]) + MixCalc(OPL3_OUT_A, MIXFM[2:0]);
	assign OUT2_R = MixCalc(PCM_R, MIXPCM[5:3]) + MixCalc(OPL3_OUT_B, MIXFM[5:3]);
	
endmodule

module OPL4_KEY_RAM
(
	input          CLK,

	input  [ 4: 0] WRADDR,
	input  [ 2: 0] DATA,
	input          WREN,
	input  [ 4: 0] RDADDR,
	output [ 2: 0] Q
);

	// altdpram MLAB: escritura registrada, LECTURA COMBINACIONAL (async)
	reg [2:0] mem [0:31];
	// power-up a 0 (como la MLAB real; en sim evita X)
	integer ii;
	initial for (ii = 0; ii < 32; ii = ii + 1) mem[ii] = 0;
	always @(posedge CLK) if (WREN) mem[WRADDR] <= DATA;
	assign Q = mem[RDADDR];

endmodule

module OPL4_PHASE_RAM (
	input          CLK,
	input  [ 4: 0] WRADDR,
	input  [13: 0] DATA,
	input          WREN,
	input  [ 4: 0] RDADDR,
	output [13: 0] Q);

	// ERA v3: lectura SINCRONA (dato registrado) => BSRAM SDPB. Antes era
	// direccion registrada + lectura asincrona (SSRAM), pero Gowin retiro el
	// SSRAM del GW5AT-60B por un problema de silicio (soporte, 03/08/2026).
	// Equivalencia: RDADDR es estable >=1 clk antes de cada CE consumidor
	// (cambia solo en flancos con CE y se consume >=4 clk despues), y
	// escritura y lectura nunca coinciden en el mismo slot => mismo dato.
	// De regalo, read-old en colision = la semantica del altsyncram original.
	(* syn_ramstyle = "block_ram" *) reg [13:0] mem [0:31];
	// power-up a 0 (como la BSRAM real; en sim evita X)
	integer ii;
	initial for (ii = 0; ii < 32; ii = ii + 1) mem[ii] = 0;
	reg [13:0] rd_q;
	always @(posedge CLK) begin
		if (WREN) mem[WRADDR] <= DATA;
		rd_q <= mem[RDADDR];
	end
	assign Q = rd_q;

endmodule

module OPL4_LFO_RAM (
	input          CLK,
	input  [ 4: 0] WRADDR,
	input  [21: 0] DATA,
	input          WREN,
	input  [ 4: 0] RDADDR,
	output [21: 0] Q);

	// ERA v3: lectura SINCRONA => BSRAM SDPB (ver nota en OPL4_PHASE_RAM).
	// 22 bits > 18 => partido en 18b de BSRAM + 4b en FF (mismas
	// direcciones): un SDP >18b consume DOS primitivos; asi, UNO + 128 FF.
	(* syn_ramstyle = "block_ram" *) reg [17:0] mem [0:31];
	reg [21:18] mem_hi [0:31];
	// power-up a 0 (como la BSRAM real; en sim evita X)
	integer ii;
	initial for (ii = 0; ii < 32; ii = ii + 1) begin mem[ii] = 0; mem_hi[ii] = 0; end
	reg [17:0] rd_lo;
	reg [21:18] rd_hi;
	always @(posedge CLK) begin
		if (WREN) begin
			mem[WRADDR]    <= DATA[17:0];
			mem_hi[WRADDR] <= DATA[21:18];
		end
		rd_lo <= mem[RDADDR];
		rd_hi <= mem_hi[RDADDR];
	end
	assign Q = {rd_hi, rd_lo};

endmodule

module OPL4_SO_RAM (
	input          CLK,
	input  [ 4: 0] WRADDR,
	input  [15: 0] DATA,
	input          WREN,
	input  [ 4: 0] RDADDR,
	output [15: 0] Q);

	// ERA v3: lectura SINCRONA => BSRAM SDPB (ver nota en OPL4_PHASE_RAM)
	(* syn_ramstyle = "block_ram" *) reg [15:0] mem [0:31];
	// power-up a 0 (como la BSRAM real; en sim evita X)
	integer ii;
	initial for (ii = 0; ii < 32; ii = ii + 1) mem[ii] = 0;
	reg [15:0] rd_q;
	always @(posedge CLK) begin
		if (WREN) mem[WRADDR] <= DATA;
		rd_q <= mem[RDADDR];
	end
	assign Q = rd_q;

endmodule

module OPL4_EVOL_RAM (
	input          CLK,
	input  [ 4: 0] WRADDR,
	input  [11: 0] DATA,
	input          WREN,
	input  [ 4: 0] RDADDR,
	output [11: 0] Q);

	// ERA v3: lectura SINCRONA => BSRAM SDPB (ver nota en OPL4_PHASE_RAM)
	(* syn_ramstyle = "block_ram" *) reg [11:0] mem [0:31];
	// power-up a 0 (como la BSRAM real; en sim evita X)
	integer ii;
	initial for (ii = 0; ii < 32; ii = ii + 1) mem[ii] = 0;
	reg [11:0] rd_q;
	always @(posedge CLK) begin
		if (WREN) mem[WRADDR] <= DATA;
		rd_q <= mem[RDADDR];
	end
	assign Q = rd_q;

endmodule

module OPL4_TL_RAM (
	input          CLK,
	input  [ 4: 0] WRADDR,
	input  [16: 0] DATA,
	input          WREN,
	input  [ 4: 0] RDADDR,
	output [16: 0] Q);

	// ERA v3: lectura SINCRONA => BSRAM SDPB (ver nota en OPL4_PHASE_RAM)
	(* syn_ramstyle = "block_ram" *) reg [16:0] mem [0:31];
	// power-up a 0 (como la BSRAM real; en sim evita X)
	integer ii;
	initial for (ii = 0; ii < 32; ii = ii + 1) mem[ii] = 0;
	reg [16:0] rd_q;
	always @(posedge CLK) begin
		if (WREN) mem[WRADDR] <= DATA;
		rd_q <= mem[RDADDR];
	end
	assign Q = rd_q;

endmodule

module OPL4_REG_RAM
#(
	parameter aw = 5, dw = 8
)
(
	input            CLK,
	input  [aw-1: 0] WRADDR,
	input  [dw-1: 0] DATA,
	input            WREN,
	input  [aw-1: 0] RDADDR,
	output [dw-1: 0] Q
);

	// ERA v3: lectura SINCRONA, pero en REGISTROS (no BSRAM): hay 17
	// instancias de 32x8 con direcciones de lectura DISTINTAS y
	// concurrentes (SA_RA/FNUM_RA/AM_RA/LFO_RA/readback) — infusionables
	// en una sola BSRAM, y 17 BSRAMs por 4,3Kbit reventaban el chip
	// (PA2017: 127/118 con el doblado SDP32/36 de la advisory 202409001).
	// Como FF son ~4,3K registros: el plan-B asumido de la migracion.
	(* syn_ramstyle = "registers" *) reg [dw-1:0] mem [0:(2**aw)-1];
	// power-up a 0 (como la BSRAM real; en sim evita X)
	integer ii;
	initial for (ii = 0; ii < (2**aw); ii = ii + 1) mem[ii] = 0;
	reg [dw-1:0] rd_q;
	always @(posedge CLK) begin
		if (WREN) mem[WRADDR] <= DATA;
		rd_q <= mem[RDADDR];
	end
	assign Q = rd_q;

endmodule
