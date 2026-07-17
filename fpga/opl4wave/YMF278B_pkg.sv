// YMF278B_pkg.sv — package del motor PCM OPL4 (srg320, con permiso;
// derivado de MAME ymf278b.cpp, BSD-3-Clause). Sin cambios MSXimus.

package YMF278B_PKG;


	typedef bit [1:0] EGState_t;
	parameter EGState_t EST_ATTACK  = 2'b00;
	parameter EGState_t EST_DECAY1  = 2'b01;
	parameter EGState_t EST_DECAY2  = 2'b10;
	parameter EGState_t EST_RELEASE = 2'b11;
	
	typedef struct packed
	{
		bit [ 4: 0] SLOT;	//
		bit         RST;	//
		bit         KON;	//
		bit         KOFF;	//
		bit         LOAD;
		bit [22: 0] PHASE;
		bit [ 8: 0] WTN;
		bit [ 3: 0] LOAD_POS;
	} OP2_t;
	parameter OP2_t OP2_RESET = '{5'h00,1'b0,1'b0,1'b0,1'b0,23'h000000,9'h000,4'h0};
	
	typedef struct packed
	{
		bit [ 4: 0] SLOT;	//
		bit         RST;	//
		bit         KON;	//
		bit         KOFF;	//
		bit         LOAD;
		bit [ 3: 0] LOAD_POS;
		bit         ALLOW;
		bit [13: 0] PHASE_FRAC;//Phase fractional
		bit [15: 0] SO;	//Sample offset
		bit [21: 0] MOD;	//Modulation
	} OP3_t;
	parameter OP3_t OP3_RESET = '{5'h00,1'b0,1'b0,1'b0,1'b0,4'h0,1'b0,14'h0000,16'h0000,22'h000000};
	
	typedef struct packed
	{
		bit [ 4: 0] SLOT;	//
		bit         RST;	//
		bit         KON;	//
		bit         KOFF;	//
		bit [ 5: 0] MODF;	//Modulation fractional
	} OP4_t;
	parameter OP4_t OP4_RESET = '{5'h00,1'b0,1'b0,1'b0,6'h00};
	
	typedef struct packed
	{
		bit [ 4: 0] SLOT;	//
		bit         RST;	//
		bit         KON;	//
		bit         KOFF;	//
		bit [15: 0] WD;	//Wave form data
		bit [ 9: 0] EVOL;	//Envelope volume
		bit [ 7: 0] ALFO; //ALFO wave
	} OP5_t;
	parameter OP5_t OP5_RESET = '{5'h00,1'b0,1'b0,1'b0,16'h0000,10'h000,8'h00};
	
	typedef struct packed
	{
		bit [ 4: 0] SLOT;	//
		bit         RST;	//
		bit         KON;	//
		bit         KOFF;	//
		bit [15: 0] WD;	//Wave form data
		bit [ 9: 0] LEVEL;//Level
	} OP6_t;
	parameter OP6_t OP6_RESET = '{5'h00,1'b0,1'b0,1'b0,16'h0000,10'h000};
	
	typedef struct packed
	{
		bit [ 4: 0] SLOT;	//
		bit         RST;	//
		bit         KON;	//
		bit         KOFF;	//
		bit [15: 0] SD;	//Slot out data
	} OP7_t;
	parameter OP7_t OP7_RESET = '{5'h00,1'b0,1'b0,1'b0,16'h0000};

	function bit [22:0] PhaseCalc(bit [9:0] FNUM, bit [3:0] OCT, bit signed [7:0] PLFO_WAVE);
		bit [26:0] P;
		bit [3:0] S;
		bit [10:0] F;
		bit [11:0] FM;

		S = OCT^4'h8;
		F = 11'h400 + FNUM;
		// _113 canon (datasheet/openMSX): el vibrato se SUMA directo a F
		// (VIB=7 -> ±48*15/12=±60 sobre 0x400 = ±79.3 cents, la cifra del
		// datasheet). El original escalaba por F/1024 (hasta ±204 cents).
		FM = {{4{PLFO_WAVE[7]}},PLFO_WAVE};
		P = {15'b000000000000000,{1'b0,F}+FM}<<(S-1);

		return P[26:4];
	endfunction
	
	function bit [9:0] LFOFreqDiv(bit [2:0] LFO);
		bit [10:0] RET;
		
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
		
		return RET - 10'd1;
	endfunction
	
	// _113: LFO canon (datasheet YMF278B / openMSX). El original usaba el
	// contador LFO en CRUDO como onda de modulacion: una SIERRA con un
	// acantilado de fase/volumen una vez por ciclo (0.17-6.9Hz) y el doble
	// (AM) o 2.6x (PM) de profundidad maxima — el "vibrato"/"bombeo" audible
	// en los instrumentos GM sostenidos (sonyc/MoonBlaster/VGMPlay). El chip
	// real modula con TRIANGULO plegado y tablas de profundidad fijas.
	function bit [7:0] AMCalc(bit [7:0] DATA, bit [2:0] AM);
		bit [6:0] TRI;
		bit [9:0] S5;
		bit [8:0] S3;

		TRI = DATA[7] ? ~DATA[6:0] : DATA[6:0];  // triangulo 0..7F..0 (256 pasos)
		// (TRI*DEPTH)>>7 con DEPTH={0,14h,20h,28h,30h,40h,50h,80h} (max 11.91dB)
		// descompuesto en 2 sumadores + mux de shifts (EXACTO, verificado
		// exhaustivo) — un mult 8x8 real aqui hundio el timing de la _113.
		S5 = {3'b000,TRI} + {1'b0,TRI,2'b00};    // TRI*5
		S3 = {2'b00,TRI} + {1'b0,TRI,1'b0};      // TRI*3
		case (AM)
			3'h0: AMCalc = 8'd0;
			3'h1: AMCalc = {3'b000,S5[9:5]};     // *20>>7 = *5>>5
			3'h2: AMCalc = {3'b000,TRI[6:2]};    // *32>>7
			3'h3: AMCalc = {2'b00,S5[9:4]};      // *40>>7 = *5>>4
			3'h4: AMCalc = {2'b00,S3[8:3]};      // *48>>7 = *3>>3
			3'h5: AMCalc = {2'b00,TRI[6:1]};     // *64>>7
			3'h6: AMCalc = {1'b0,S5[9:3]};       // *80>>7 = *5>>3
			3'h7: AMCalc = {1'b0,TRI};           // *128>>7
		endcase
	endfunction

	function bit [7:0] VIBCalc(bit [7:0] DATA, bit [2:0] VIB);
		bit [5:0] FM6;
		bit [3:0] A;
		bit [1:0] D6;
		bit [2:0] D3;
		bit [6:0] MAG;
		bit       NEG;

		FM6 = DATA[7:2];                          // 64 pasos por ciclo
		if (FM6[4]) FM6 = FM6 ^ 6'h1F;            // pliegue: 0..15..0
		NEG = FM6[5];                             // mitad negativa
		A   = FM6[3:0];                           // |triangulo| 0..15
		// canon = trunc(TRI*DEPTH/12) con DEPTH={0,2,3,4,6,12,24,48}
		// (cents max: 3.4/5.1/6.8/10.1/20.2/40.1/79.3) => DEPTH/12 =
		// {0,1/6,1/4,1/3,1/2,1,2,4}: LUTs de 16 entradas para /6 y /3 +
		// shifts (EXACTO, verificado exhaustivo; sin mult ni divisor).
		D6 = (A >= 4'd12) ? 2'd2 : (A >= 4'd6) ? 2'd1 : 2'd0;          // A/6
		D3 = (A == 4'd15) ? 3'd5 : (A >= 4'd12) ? 3'd4 : (A >= 4'd9) ? 3'd3 :
		     (A >= 4'd6)  ? 3'd2 : (A >= 4'd3)  ? 3'd1 : 3'd0;         // A/3
		case (VIB)
			3'h0: MAG = 7'd0;
			3'h1: MAG = {5'b00000,D6};            // A/6  (±2)
			3'h2: MAG = {5'b00000,A[3:2]};        // A/4  (±3)
			3'h3: MAG = {4'b0000,D3};             // A/3  (±5)
			3'h4: MAG = {4'b0000,A[3:1]};         // A/2  (±7)
			3'h5: MAG = {3'b000,A};               // A    (±15)
			3'h6: MAG = {2'b00,A,1'b0};           // A*2  (±30)
			3'h7: MAG = {1'b0,A,2'b00};           // A*4  (±60)
		endcase
		VIBCalc = NEG ? (~{1'b0,MAG} + 8'd1) : {1'b0,MAG};  // signo (compl. a 2)
	endfunction
	
	function bit [15:0] Interpolate(input bit [15:0] WAVE0, input bit [15:0] WAVE1, bit [5:0] PHASE);
		bit [ 6:0] PHASE_NEG;
		bit [21:0] TEMP0,TEMP1;
		bit [21:0] SUM;
		
		PHASE_NEG = 7'h40 - PHASE;
		TEMP0 = $signed(WAVE0) * PHASE_NEG;
		TEMP1 = $signed(WAVE1) * PHASE;
		SUM = $signed(TEMP0) + $signed(TEMP1);
	
		return SUM[21:6];
	endfunction
		
	function bit [6:0] EffRateCalc(bit [3:0] RATE, bit [3:0] RC, bit [3:0] OCT, bit FNUM9);
		bit [5:0] RES;
		bit [5:0] TEMP;
		bit [6:0] KEY_EG_SCALE;
		bit [6:0] TEMP2;
		
		TEMP = {2'b00,RC} + {OCT[3],OCT[3],OCT};
		if (RC == 4'hF) 
			KEY_EG_SCALE = '0;
		else
			KEY_EG_SCALE = {TEMP,FNUM9};
		
		if (RATE == 4'h0)
			TEMP2 = 7'h00;
		else if (RATE == 4'hF)
			TEMP2 = 7'h3F;
		else
			TEMP2 = {1'b0,RATE,2'b00} + KEY_EG_SCALE;
			
		RES = TEMP2[6] ? 6'h3F : TEMP2[5:0];
			
		return {TEMP2[6],RES};
	endfunction
	
	function bit EnvStep(bit [17:0] CNT, bit [5:0] ERATE);
		bit RET;

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
			4'hA: RET = ~|CNT[0:0];
			default: RET = 1;
		endcase
			
		return RET;
	endfunction
	
	parameter bit [3:0] EncIncTbl[64*8] = 
	'{ 4'h0,4'h0,4'h0,4'h0,4'h0,4'h0,4'h0,4'h0,
      4'h0,4'h0,4'h0,4'h0,4'h0,4'h0,4'h0,4'h0,
      4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,
      4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,
      4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,//04
      4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,//08
      4'h0,4'h1,4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,//0C
      4'h0,4'h1,4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,//10
      4'h0,4'h1,4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,//14
      4'h0,4'h1,4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,//18
      4'h0,4'h1,4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,//1C
      4'h0,4'h1,4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,//20
      4'h0,4'h1,4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,//24
      4'h0,4'h1,4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,//28
      4'h0,4'h1,4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,4'h0,4'h1,//2C
      4'h0,4'h1,4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h0,4'h1,4'h1,4'h1,
      4'h0,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,
      4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,4'h1,//30
      4'h1,4'h1,4'h1,4'h2,4'h1,4'h1,4'h1,4'h2,
      4'h1,4'h2,4'h1,4'h2,4'h1,4'h2,4'h1,4'h2,
      4'h1,4'h2,4'h2,4'h2,4'h1,4'h2,4'h2,4'h2,
      4'h2,4'h2,4'h2,4'h2,4'h2,4'h2,4'h2,4'h2,//34
      4'h2,4'h2,4'h2,4'h4,4'h2,4'h2,4'h2,4'h4,
      4'h2,4'h4,4'h2,4'h4,4'h2,4'h4,4'h2,4'h4,
      4'h2,4'h4,4'h4,4'h4,4'h2,4'h4,4'h4,4'h4,
      4'h4,4'h4,4'h4,4'h4,4'h4,4'h4,4'h4,4'h4,//38
      4'h4,4'h4,4'h4,4'h8,4'h4,4'h4,4'h4,4'h8,
      4'h4,4'h8,4'h4,4'h8,4'h4,4'h8,4'h4,4'h8,
      4'h4,4'h8,4'h8,4'h8,4'h4,4'h8,4'h8,4'h8,
      4'h8,4'h8,4'h8,4'h8,4'h8,4'h8,4'h8,4'h8,//3C
      4'h8,4'h8,4'h8,4'h8,4'h8,4'h8,4'h8,4'h8,
      4'h8,4'h8,4'h8,4'h8,4'h8,4'h8,4'h8,4'h8,
      4'h8,4'h8,4'h8,4'h8,4'h8,4'h8,4'h8,4'h8
	};
	
	function bit [3:0] EnvInc(bit [17:0] CNT, bit [5:0] ERATE);
		bit [2:0] IDX;

		case (ERATE[5:2])
			4'hC: IDX = CNT[14:12];
			4'hD: IDX = CNT[15:13];
			4'hE: IDX = CNT[16:14];
			4'hF: IDX = CNT[17:15];
			default: IDX = CNT[13:11];
		endcase
			
		return EncIncTbl[{ERATE,IDX}];
	endfunction
	
	function bit [9:0] LevelAddTLALFO(bit [9:0] LEVEL, bit [9:0] TL, bit [7:0] ALFO);
		bit [10:0] SUM;
		
		SUM = {1'b0,LEVEL} + {1'b0,TL} + {3'b000,ALFO};
		
		return !SUM[10] ? SUM[9:0] : 10'h3FF;
	endfunction

	function bit signed [15:0] VolCalc(bit signed [15:0] WAVE, bit [9:0] LEVEL);
		bit signed [24:0] MULT;
		bit signed [15:0] RES;
		
		// MSXimus: el original hacia `$signed(WAVE) * ({2'b01,~LEVEL[5:0]})` —
		// multiplicacion MIXTA signed x unsigned => UNSIGNED segun el LRM y las
		// muestras NEGATIVAS salian rectificadas a positivo (0x8100 -> +32766,
		// verificado en sim). Nivel como signed positivo de 9 bits => producto signed.
		MULT = WAVE * $signed({3'b001,~LEVEL[5:0]});
		RES = $signed(MULT[22:7]) >>> LEVEL[9:6];
		
		return RES;
	endfunction
	
	function bit signed [15:0] PanLCalc(bit signed [15:0] WAVE, bit [3:0] PAN);
		bit [3:0] S;
		bit [15:0] TEMP;
		
		S = 4'd0 + PAN;
		TEMP = $signed($signed(WAVE)>>>{S[2:0],1'b0});
		// _116: fix de pan del upstream (srg320 5379b34): el sentido de PAN[3]
		// estaba INVERTIDO (atenuaba el canal equivocado; un pan suave -1
		// casi muteaba la izquierda). Canon: PAN>0 atenua IZQUIERDA (suena
		// derecha), PAN<0 (bit3) deja la izquierda ENTERA; 0=centro, 8=mute.
		return PAN == 4'h0 ? WAVE : PAN == 4'h8 ? 16'h0000 : PAN[3] ? WAVE : $signed(TEMP);
	endfunction
	
	function bit signed [15:0] PanRCalc(bit signed [15:0] WAVE, bit [3:0] PAN);
		bit [3:0] S;
		bit [15:0] TEMP;
		
		S = 4'd0 - PAN;
		TEMP = $signed($signed(WAVE)>>>{S[2:0],1'b0});
		// _116: espejo del fix de PanLCalc (srg320 5379b34): PAN<0 atenua
		// DERECHA; PAN>0 la deja entera.
		return PAN == 4'h0 ? WAVE : PAN == 4'h8 ? 16'h0000 : !PAN[3] ? WAVE : $signed(TEMP);
	endfunction
	
	function bit signed [15:0] MixCalc(bit signed [15:0] WAVE, bit [2:0] MIX);
		bit signed [15:0] BASE;

		// _114 canon (openMSX/datasheet): pasos de -3dB aproximados como
		// {1, 0.75, 0.5, 0.375, 0.25, 0.1875, 0.125, MUTE} = (impar? 0.75 : 1)
		// >> (MIX/2); 0.75x = (x>>1)+(x>>2), un solo sumador. El atajo
		// original ">>>{MIX,1'b0}" era -12dB/paso: el reset canon del F8
		// (0x1B = 3/3, -8.5dB de FM) se convertia en /64 = FM inaudible en
		// software que nunca escribe F8 (VGMPlay con VGMs YMF262/OPL3).
		BASE = MIX[0] ? ($signed(WAVE)>>>1) + ($signed(WAVE)>>>2)
		              : $signed(WAVE);

		return (MIX == 3'd7) ? 16'sd0 : $signed(BASE >>> MIX[2:1]);
	endfunction
	
	function bit signed [15:0] TrimWave(bit signed [17:0] WAVE);
		return WAVE[17] && WAVE[16:15] != 2'b11 ? 16'h8000 : !WAVE[17] && WAVE[16:15] != 2'b00 ? 16'h7FFF : WAVE[15:0];
	endfunction
	
endpackage
