//
//	vdp_command_cache.v
//
//	Copyright (C) 2025 Takayuki Hara
//
//	本ソフトウェアおよび本ソフトウェアに基づいて作成された派生物は、以下の条件を
//	満たす場合に限り、再頒布および使用が許可されます。
//
//	1.ソースコード形式で再頒布する場合、上記の著作権表示、本条件一覧、および下記
//	  免責条項をそのままの形で保持すること。
//	2.バイナリ形式で再頒布する場合、頒布物に付属のドキュメント等の資料に、上記の
//	  著作権表示、本条件一覧、および下記免責条項を含めること。
//	3.書面による事前の許可なしに、本ソフトウェアを販売、および商業的な製品や活動
//	  に使用しないこと。
//
//	本ソフトウェアは、著作権者によって「現状のまま」提供されています。著作権者は、
//	特定目的への適合性の保証、商品性の保証、またそれに限定されない、いかなる明示
//	的もしくは暗黙な保証責任も負いません。著作権者は、事由のいかんを問わず、損害
//	発生の原因いかんを問わず、かつ責任の根拠が契約であるか厳格責任であるか（過失
//	その他の）不法行為であるかを問わず、仮にそのような損害が発生する可能性を知ら
//	されていたとしても、本ソフトウェアの使用によって発生した（代替品または代用サ
//	ービスの調達、使用の喪失、データの喪失、利益の喪失、業務の中断も含め、またそ
//	れに限定されない）直接損害、間接損害、偶発的な損害、特別損害、懲罰的損害、ま
//	たは結果損害について、一切責任を負わないものとします。
//
//	Note that above Japanese version license is the formal document.
//	The following translation is only for reference.
//
//	Redistribution and use of this software or any derivative works,
//	are permitted provided that the following conditions are met:
//
//	1. Redistributions of source code must retain the above copyright
//	   notice, this list of conditions and the following disclaimer.
//	2. Redistributions in binary form must reproduce the above
//	   copyright notice, this list of conditions and the following
//	   disclaimer in the documentation and/or other materials
//	   provided with the distribution.
//	3. Redistributions may not be sold, nor may they be used in a
//	   commercial product or activity without specific prior written
//	   permission.
//
//	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//	"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//	LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//	FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//	COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//	INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//	CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//	LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
//	ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//	POSSIBILITY OF SUCH DAMAGE.
//
//-----------------------------------------------------------------------------

module vdp_command_cache (
	input				reset_n,
	input				clk,
	input				start,						//	1 clock pulse
	//	VDP command interface
	input		[17:0]	cache_vram_address,
	input				cache_vram_valid,
	output				cache_vram_ready,
	input				cache_vram_write,
	input		[7:0]	cache_vram_wdata,
	output		[7:0]	cache_vram_rdata,
	output				cache_vram_rdata_en,
	input				cache_flush_start,
	output				cache_flush_end,
	//	VRAM interface
	output		[17:0]	command_vram_address,
	output				command_vram_valid,
	input				command_vram_ready,
	output				command_vram_write,
	output		[31:0]	command_vram_wdata,
	output		[3:0]	command_vram_wdata_mask,
	input		[31:0]	command_vram_rdata,
	input				command_vram_rdata_en
);
	reg		[17:2]	ff_cache0_address;
	reg		[31:0]	ff_cache0_data;
	reg				ff_cache0_data_en;
	reg		[3:0]	ff_cache0_data_mask;
	reg				ff_cache0_already_read;
	wire			w_cache0_hit;
	reg		[17:2]	ff_cache1_address;
	reg		[31:0]	ff_cache1_data;
	reg				ff_cache1_data_en;
	reg		[3:0]	ff_cache1_data_mask;
	reg				ff_cache1_already_read;
	wire			w_cache1_hit;
	reg		[17:2]	ff_cache2_address;
	reg		[31:0]	ff_cache2_data;
	reg				ff_cache2_data_en;
	reg		[3:0]	ff_cache2_data_mask;
	reg				ff_cache2_already_read;
	wire			w_cache2_hit;
	reg		[17:2]	ff_cache3_address;
	reg		[31:0]	ff_cache3_data;
	reg				ff_cache3_data_en;
	reg		[3:0]	ff_cache3_data_mask;
	reg				ff_cache3_already_read;
	wire			w_cache3_hit;
	reg		[1:0]	ff_update_target;
	reg		[7:0]	ff_cache_vram_rdata;
	reg				ff_cache_vram_rdata_en;
	reg				ff_vram_valid;
	reg		[17:2]	ff_vram_address;
	reg				ff_vram_write;				//	0: read, 1: write
	reg		[31:0]	ff_vram_wdata;
	reg		[3:0]	ff_vram_data_mask;
	wire			w_vram_ready;
	reg				ff_prewrite_read;
	reg				ff_busy;
	reg				ff_after_read;
	reg		[2:0]	ff_flush_state;
	//	MSXimus (BUG#16): lecturas ACEPTADAS por el interface cuya respuesta
	//	aun no ha llegado (ff_read_pending) y cuantas de ellas hay que TIRAR a
	//	la basura por haberse abortado su comando (ff_read_discard).
	reg		[1:0]	ff_read_pending;
	reg		[1:0]	ff_read_discard;
	wire			w_read_accept;
	wire	[1:0]	w_read_pending_next;

	assign w_cache0_hit		= ff_cache0_data_en && (ff_cache0_address == cache_vram_address[17:2]);
	assign w_cache1_hit		= ff_cache1_data_en && (ff_cache1_address == cache_vram_address[17:2]);
	assign w_cache2_hit		= ff_cache2_data_en && (ff_cache2_address == cache_vram_address[17:2]);
	assign w_cache3_hit		= ff_cache3_data_en && (ff_cache3_address == cache_vram_address[17:2]);
	assign cache_flush_end	= (ff_flush_state == 3'd1) ? ~ff_vram_valid: 1'b0;

	//	FIX ABORTO: hay palabras de ESCRITURA aun no emitidas a VRAM
	wire w_dirty_any =
		(ff_cache0_data_en && ff_cache0_data_mask != 4'b1111) ||
		(ff_cache1_data_en && ff_cache1_data_mask != 4'b1111) ||
		(ff_cache2_data_en && ff_cache2_data_mask != 4'b1111) ||
		(ff_cache3_data_en && ff_cache3_data_mask != 4'b1111);

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_cache0_address		<= 16'd0;
			ff_cache0_data			<= 32'd0;
			ff_cache0_data_en		<= 1'b0;
			ff_cache0_data_mask		<= 4'b1111;
			ff_cache0_already_read	<= 1'b0;
			ff_cache1_address		<= 16'd0;
			ff_cache1_data			<= 32'd0;
			ff_cache1_data_en		<= 1'b0;
			ff_cache1_data_mask		<= 4'b1111;
			ff_cache1_already_read	<= 1'b0;
			ff_cache2_address		<= 16'd0;
			ff_cache2_data			<= 32'd0;
			ff_cache2_data_en		<= 1'b0;
			ff_cache2_data_mask		<= 4'b1111;
			ff_cache2_already_read	<= 1'b0;
			ff_cache3_address		<= 16'd0;
			ff_cache3_data			<= 32'd0;
			ff_cache3_data_en		<= 1'b0;
			ff_cache3_data_mask		<= 4'b1111;
			ff_cache3_already_read	<= 1'b0;
			ff_update_target		<= 2'd0;
			ff_vram_address			<= 16'd0;
			ff_vram_valid			<= 1'b0;
			ff_vram_write			<= 1'b0;
			ff_vram_wdata			<= 32'd0;
			ff_vram_data_mask		<= 4'b1111;
			ff_cache_vram_rdata		<= 8'd0;
			ff_cache_vram_rdata_en	<= 1'b0;
			ff_busy					<= 1'b1;
			ff_flush_state			<= 3'd0;
		end
		else if( start ) begin
			//	FIX ABORTO: un comando nuevo (o STOP) con palabras SUCIAS en
			//	la cache las FLUSHEA en vez de descartarlas. Antes: clear sin
			//	flush => bytes ya consumidos por el motor no llegaban NUNCA a
			//	la VRAM (bloque rancio persistente). El comando nuevo espera:
			//	w_vram_ready=0 mientras ff_flush_state != 0 (ver abajo).
			ff_update_target		<= 2'd0;
			ff_prewrite_read		<= 1'b0;
			ff_after_read			<= 1'b0;
			//	FIX STROBE (bug #17): el strobe de respuesta pertenece al comando
			//	que se ABORTA, asi que se descarta AQUI (vale para las dos ramas
			//	de abajo). Sin esto, si el R#46 cae en el unico ciclo en que
			//	ff_cache_vram_rdata_en esta alto y ademas hay flush sucio, las
			//	ramas de mayor prioridad (ff_vram_valid / ff_flush_state) tapan a
			//	la rama :313 durante TODO el flush y el strobe se queda alto. Al
			//	acabar el flush, w_vram_ready sube en el mismo ciclo en que la
			//	:313 por fin se ejecuta, y esa rama GANA a la aceptacion de la
			//	peticion (:318): el motor ve ready=1, baja su valid dandola por
			//	aceptada y se queda esperando para siempre un rdata_en que ya
			//	nadie va a generar => comando colgado con CE=1 hasta el siguiente
			//	R#46. Se restaura el invariante "rdata_en dura 1 ciclo".
			ff_cache_vram_rdata_en	<= 1'b0;
			if( w_dirty_any || ff_flush_state != 3'd0 ) begin
				//	la ESCRITURA en vuelo se conserva; la lectura se cancela
				ff_vram_valid		<= ff_vram_valid && ff_vram_write;
				ff_busy				<= 1'b1;
				if( ff_flush_state == 3'd0 )
					ff_flush_state	<= 3'd5;
			end
			else begin
				//	sin suciedad: el clear de siempre
				ff_cache0_data_en	<= 1'b0;
				ff_cache1_data_en	<= 1'b0;
				ff_cache2_data_en	<= 1'b0;
				ff_cache3_data_en	<= 1'b0;
				ff_vram_valid		<= 1'b0;
				ff_busy				<= 1'b0;
				ff_flush_state		<= 3'd0;
			end
		end
		else if( cache_flush_start ) begin
			//	キャッシュフラッシュの開始
			ff_flush_state			<= 3'd5;
			ff_busy					<= 1'b1;
		end
		else if( ff_vram_valid ) begin
			//	SDRAMコントローラーへアクセス要求を出している場合
			if( command_vram_ready ) begin
				//	SDRAMコントローラーからアクセスを受理されたので要求を下ろす
				ff_vram_valid			<= 1'b0;
				if( ff_busy && !ff_after_read ) begin
					ff_busy				<= 1'b0;
				end
			end
			else begin
				//	hold
			end
		end
		else if( ff_after_read && ff_busy && ff_vram_write ) begin
			//	cache#n 更新前に、cache#n の中の書きかけのデータを書き終えた後にここに来る。
			ff_after_read <= 1'b0;
			case( ff_update_target )
			2'd0: begin
				//	cache#0 更新用のリード要求
				ff_vram_valid			<= 1'b1;
				ff_vram_write			<= 1'b0;
				ff_vram_address			<= ff_cache0_address;
				ff_vram_wdata			<= ff_cache0_data;
				ff_vram_data_mask		<= ff_cache0_data_mask;
			end
			2'd1: begin
				//	cache#1 更新用のリード要求
				ff_vram_valid			<= 1'b1;
				ff_vram_write			<= 1'b0;
				ff_vram_address			<= ff_cache1_address;
				ff_vram_wdata			<= ff_cache1_data;
				ff_vram_data_mask		<= ff_cache1_data_mask;
			end
			2'd2: begin
				//	cache#2 更新用のリード要求
				ff_vram_valid			<= 1'b1;
				ff_vram_write			<= 1'b0;
				ff_vram_address			<= ff_cache2_address;
				ff_vram_wdata			<= ff_cache2_data;
				ff_vram_data_mask		<= ff_cache2_data_mask;
			end
			2'd3: begin
				//	cache#3 更新用のリード要求
				ff_vram_valid			<= 1'b1;
				ff_vram_write			<= 1'b0;
				ff_vram_address			<= ff_cache3_address;
				ff_vram_wdata			<= ff_cache3_data;
				ff_vram_data_mask		<= ff_cache3_data_mask;
			end
			endcase
		end
		else if( ff_flush_state != 3'd0 ) begin
			//	キャッシュの内容をフラッシュするステートの場合
			case( ff_flush_state )
			3'd5: begin
				if( ff_cache0_data_en && ff_cache0_data_mask != 4'b1111 ) begin
					//	もし cache#0 の中に書き込み結果が残っていたら書き出す
					ff_vram_valid			<= 1'b1;
					ff_vram_write			<= 1'b1;
					ff_vram_address			<= ff_cache0_address;
					ff_vram_wdata			<= ff_cache0_data;
					ff_vram_data_mask		<= ff_cache0_data_mask;
				end
				ff_cache0_data_mask		<= 4'b1111;
				ff_cache0_data_en		<= 1'b0;
				ff_flush_state			<= 3'd4;
			end
			3'd4: begin
				if( ff_cache1_data_en && ff_cache1_data_mask != 4'b1111 ) begin
					//	もし cache#1 の中に書き込み結果が残っていたら書き出す
					ff_vram_valid			<= 1'b1;
					ff_vram_write			<= 1'b1;
					ff_vram_address			<= ff_cache1_address;
					ff_vram_wdata			<= ff_cache1_data;
					ff_vram_data_mask		<= ff_cache1_data_mask;
				end
				ff_cache1_data_mask		<= 4'b1111;
				ff_cache1_data_en		<= 1'b0;
				ff_flush_state			<= 3'd3;
			end
			3'd3: begin
				if( ff_cache2_data_en && ff_cache2_data_mask != 4'b1111 ) begin
					//	もし cache#2 の中に書き込み結果が残っていたら書き出す
					ff_vram_valid			<= 1'b1;
					ff_vram_write			<= 1'b1;
					ff_vram_address			<= ff_cache2_address;
					ff_vram_wdata			<= ff_cache2_data;
					ff_vram_data_mask		<= ff_cache2_data_mask;
				end
				ff_cache2_data_mask		<= 4'b1111;
				ff_cache2_data_en		<= 1'b0;
				ff_flush_state			<= 3'd2;
			end
			3'd2: begin
				if( ff_cache3_data_en && ff_cache3_data_mask != 4'b1111 ) begin
					//	もし cache#3 の中に書き込み結果が残っていたら書き出す
					ff_vram_valid			<= 1'b1;
					ff_vram_write			<= 1'b1;
					ff_vram_address			<= ff_cache3_address;
					ff_vram_wdata			<= ff_cache3_data;
					ff_vram_data_mask		<= ff_cache3_data_mask;
				end
				ff_cache3_data_mask		<= 4'b1111;
				ff_cache3_data_en		<= 1'b0;
				ff_flush_state			<= 3'd1;
			end
			3'd1: begin
				//	書き出し終わり
				ff_vram_write			<= 1'b0;
				ff_flush_state			<= 3'd0;
				//	FIX ABORTO 2: TODO cierre de flush libera ff_busy.
				//	Un start (escritura de R#46, legal sin esperar a CE=0) que
				//	caiga con un flush en marcha entra por la rama de arriba y
				//	pone ff_busy=1. Si ese flush ya estaba DRENADO -- lo tipico
				//	tras un comando de SOLO LECTURA (POINT/SRCH/LMCM), que no
				//	ensucia la cache -- no queda ninguna aceptacion de VRAM que
				//	lo vuelva a bajar (esa es la unica via, linea ~203) y
				//	cache_vram_ready se queda a 0 PARA SIEMPRE: el comando nuevo
				//	no se ejecuta jamas, CE cae igual y el software ve un
				//	rectangulo fantasma hasta el siguiente R#46.
				//	Este estado es el UNICO punto por el que pasan TODOS los
				//	flushes (5->4->3->2->1->0), venga el flush del motor
				//	(cache_flush_start) o de la rama de aborto: liberar aqui
				//	cubre todas las entradas con una sola linea.
				//	No adelanta nada ni cambia el timing de lo que hoy funciona:
				//	w_vram_ready ya vale 0 mientras ff_flush_state != 0, y en los
				//	flushes con escrituras ff_busy ya estaba a 0 al llegar aqui.
				//	Sin guard `if( !ff_vram_valid )`: a este estado solo se llega
				//	con ff_vram_valid == 0, porque la rama de la linea ~197 tiene
				//	prioridad sobre toda la maquina de flush.
				ff_busy					<= 1'b0;
			end
			default: begin
				//	hold
			end
			endcase
		end
		else if( ff_cache_vram_rdata_en ) begin
			//	ff_cache_vram_rdata_en は必ず受け取って貰えるので、即下ろす
			ff_cache_vram_rdata_en	<= 1'b0;
			ff_busy					<= 1'b0;
		end
		else if( cache_vram_valid && w_vram_ready ) begin
			//	受け取れるタイミングでアクセス要求が来た場合
			if( !cache_vram_write ) begin
				//	リードアクセス要求の場合
				if(      w_cache0_hit ) begin
					//	Hit cache#0
					if( ff_cache0_already_read || ff_cache0_data_mask[ cache_vram_address[1:0] ] == 1'b0 ) begin
						//	cache#0 の中に必要なデータが存在する場合
						case( cache_vram_address[1:0] )
						2'd0:	ff_cache_vram_rdata <= ff_cache0_data[ 7: 0];
						2'd1:	ff_cache_vram_rdata <= ff_cache0_data[15: 8];
						2'd2:	ff_cache_vram_rdata <= ff_cache0_data[23:16];
						2'd3:	ff_cache_vram_rdata <= ff_cache0_data[31:24];
						endcase
						ff_cache_vram_rdata_en		<= 1'b1;
					end
					else begin
						//	cache#0 の中に必要なデータが存在しない場合（歯抜けで書き込んだだけで、その抜けてる部分のリードだった場合）
						//	対象のデータをリードする
						ff_vram_address		<= cache_vram_address[17:2];
						ff_vram_valid		<= 1'b1;
						ff_vram_data_mask	<= 4'b1111;
						ff_update_target	<= 2'd0;
					end
					ff_vram_write		<= 1'b0;
					ff_busy				<= 1'b1;
				end
				else if( w_cache1_hit ) begin
					//	Hit cache#1
					if( ff_cache1_already_read || ff_cache1_data_mask[ cache_vram_address[1:0] ] == 1'b0 ) begin
						//	cache#1 の中に必要なデータが存在する場合
						case( cache_vram_address[1:0] )
						2'd0:	ff_cache_vram_rdata <= ff_cache1_data[ 7: 0];
						2'd1:	ff_cache_vram_rdata <= ff_cache1_data[15: 8];
						2'd2:	ff_cache_vram_rdata <= ff_cache1_data[23:16];
						2'd3:	ff_cache_vram_rdata <= ff_cache1_data[31:24];
						endcase
						ff_cache_vram_rdata_en		<= 1'b1;
					end
					else begin
						//	cache#1 の中に必要なデータが存在しない場合（歯抜けで書き込んだだけで、その抜けてる部分のリードだった場合）
						//	対象のデータをリードする
						ff_vram_address		<= cache_vram_address[17:2];
						ff_vram_valid		<= 1'b1;
						ff_vram_data_mask	<= 4'b1111;
						ff_update_target	<= 2'd1;
					end
					ff_vram_write		<= 1'b0;
					ff_busy				<= 1'b1;
				end
				else if( w_cache2_hit ) begin
					//	Hit cache#2
					if( ff_cache2_already_read || ff_cache2_data_mask[ cache_vram_address[1:0] ] == 1'b0 ) begin
						//	cache#2 の中に必要なデータが存在する場合
						case( cache_vram_address[1:0] )
						2'd0:	ff_cache_vram_rdata <= ff_cache2_data[ 7: 0];
						2'd1:	ff_cache_vram_rdata <= ff_cache2_data[15: 8];
						2'd2:	ff_cache_vram_rdata <= ff_cache2_data[23:16];
						2'd3:	ff_cache_vram_rdata <= ff_cache2_data[31:24];
						endcase
						ff_cache_vram_rdata_en		<= 1'b1;
					end
					else begin
						//	cache#2 の中に必要なデータが存在しない場合（歯抜けで書き込んだだけで、その抜けてる部分のリードだった場合）
						//	対象のデータをリードする
						ff_vram_address		<= cache_vram_address[17:2];
						ff_vram_valid		<= 1'b1;
						ff_vram_data_mask	<= 4'b1111;
						ff_update_target	<= 2'd2;
					end
					ff_vram_write		<= 1'b0;
					ff_busy				<= 1'b1;
				end
				else if( w_cache3_hit ) begin
					//	Hit cache#3
					if( ff_cache3_already_read || ff_cache3_data_mask[ cache_vram_address[1:0] ] == 1'b0 ) begin
						//	cache#3 の中に必要なデータが存在する場合
						case( cache_vram_address[1:0] )
						2'd0:	ff_cache_vram_rdata <= ff_cache3_data[ 7: 0];
						2'd1:	ff_cache_vram_rdata <= ff_cache3_data[15: 8];
						2'd2:	ff_cache_vram_rdata <= ff_cache3_data[23:16];
						2'd3:	ff_cache_vram_rdata <= ff_cache3_data[31:24];
						endcase
						ff_cache_vram_rdata_en		<= 1'b1;
					end
					else begin
						//	cache#3 の中に必要なデータが存在しない場合（歯抜けで書き込んだだけで、その抜けてる部分のリードだった場合）
						//	対象のデータをリードする
						ff_vram_address		<= cache_vram_address[17:2];
						ff_vram_valid		<= 1'b1;
						ff_vram_data_mask	<= 4'b1111;
						ff_update_target	<= 2'd3;
					end
					ff_vram_write		<= 1'b0;
					ff_busy				<= 1'b1;
				end
				else begin
					//	4way の中にアドレスが一致するデータがなかった場合
					case( ff_update_target )
					2'd0: begin
						//	cache#0 に上書きする場合
						if( ff_cache0_data_en && ff_cache0_data_mask != 4'b1111 ) begin
							//	上書き前に cache#0 に書きかけのデータがあれば書き出す
							ff_vram_address				<= ff_cache0_address;
							ff_vram_valid				<= 1'b1;
							ff_vram_write				<= 1'b1;
							ff_vram_wdata				<= ff_cache0_data;
							ff_vram_data_mask			<= ff_cache0_data_mask;
							ff_cache0_data_mask			<= 4'b1111;
							ff_busy						<= 1'b1;
							ff_after_read				<= 1'b1;
							ff_cache0_address			<= cache_vram_address[17:2];
						end
						else begin
							//	書きかけのデータが存在しない場合は欲しいデータを読みに行く
							ff_vram_address				<= cache_vram_address[17:2];
							ff_vram_valid				<= 1'b1;
							ff_vram_write				<= 1'b0;
							ff_vram_data_mask			<= 4'b1111;
							ff_busy						<= 1'b1;
						end
					end
					2'd1: begin
						if( ff_cache1_data_en && ff_cache1_data_mask != 4'b1111 ) begin
							//	上書き前に cache#1 に書きかけのデータがあれば書き出す
							ff_vram_address				<= ff_cache1_address;
							ff_vram_valid				<= 1'b1;
							ff_vram_write				<= 1'b1;
							ff_vram_wdata				<= ff_cache1_data;
							ff_vram_data_mask			<= ff_cache1_data_mask;
							ff_cache1_data_mask			<= 4'b1111;
							ff_busy						<= 1'b1;
							ff_after_read				<= 1'b1;
							ff_cache1_address			<= cache_vram_address[17:2];
						end
						else begin
							//	書きかけのデータが存在しない場合は欲しいデータを読みに行く
							ff_vram_address				<= cache_vram_address[17:2];
							ff_vram_valid				<= 1'b1;
							ff_vram_write				<= 1'b0;
							ff_vram_data_mask			<= 4'b1111;
							ff_busy						<= 1'b1;
						end
					end
					2'd2: begin
						if( ff_cache2_data_en && ff_cache2_data_mask != 4'b1111 ) begin
							//	上書き前に cache#2 に書きかけのデータがあれば書き出す
							ff_vram_address				<= ff_cache2_address;
							ff_vram_valid				<= 1'b1;
							ff_vram_write				<= 1'b1;
							ff_vram_wdata				<= ff_cache2_data;
							ff_vram_data_mask			<= ff_cache2_data_mask;
							ff_cache2_data_mask			<= 4'b1111;
							ff_busy						<= 1'b1;
							ff_after_read				<= 1'b1;
							ff_cache2_address			<= cache_vram_address[17:2];
						end
						else begin
							//	書きかけのデータが存在しない場合は欲しいデータを読みに行く
							ff_vram_address				<= cache_vram_address[17:2];
							ff_vram_valid				<= 1'b1;
							ff_vram_write				<= 1'b0;
							ff_vram_data_mask			<= 4'b1111;
							ff_busy						<= 1'b1;
						end
					end
					2'd3: begin
						if( ff_cache3_data_en && ff_cache3_data_mask != 4'b1111 ) begin
							//	上書き前に cache#3 に書きかけのデータがあれば書き出す
							ff_vram_address				<= ff_cache3_address;
							ff_vram_valid				<= 1'b1;
							ff_vram_write				<= 1'b1;
							ff_vram_wdata				<= ff_cache3_data;
							ff_vram_data_mask			<= ff_cache3_data_mask;
							ff_cache3_data_mask			<= 4'b1111;
							ff_busy						<= 1'b1;
							ff_after_read				<= 1'b1;
							ff_cache3_address			<= cache_vram_address[17:2];
						end
						else begin
							//	書きかけのデータが存在しない場合は欲しいデータを読みに行く
							ff_vram_address				<= cache_vram_address[17:2];
							ff_vram_valid				<= 1'b1;
							ff_vram_write				<= 1'b0;
							ff_vram_data_mask			<= 4'b1111;
							ff_busy						<= 1'b1;
						end
					end
					endcase
				end
			end
			else begin
				//	書き込みアクセスの場合
				if(      w_cache0_hit ) begin
					//	cache#0 にヒットなら、その中の対応する位置に上書き
					case( cache_vram_address[1:0] )
					2'd0:	begin ff_cache0_data_mask[0] <= 1'b0; ff_cache0_data[ 7: 0] <= cache_vram_wdata; end
					2'd1:	begin ff_cache0_data_mask[1] <= 1'b0; ff_cache0_data[15: 8] <= cache_vram_wdata; end
					2'd2:	begin ff_cache0_data_mask[2] <= 1'b0; ff_cache0_data[23:16] <= cache_vram_wdata; end
					2'd3:	begin ff_cache0_data_mask[3] <= 1'b0; ff_cache0_data[31:24] <= cache_vram_wdata; end
					endcase
				end
				else if( w_cache1_hit ) begin
					//	cache#1 にヒットなら、その中の対応する位置に上書き
					case( cache_vram_address[1:0] )
					2'd0:	begin ff_cache1_data_mask[0] <= 1'b0; ff_cache1_data[ 7: 0] <= cache_vram_wdata; end
					2'd1:	begin ff_cache1_data_mask[1] <= 1'b0; ff_cache1_data[15: 8] <= cache_vram_wdata; end
					2'd2:	begin ff_cache1_data_mask[2] <= 1'b0; ff_cache1_data[23:16] <= cache_vram_wdata; end
					2'd3:	begin ff_cache1_data_mask[3] <= 1'b0; ff_cache1_data[31:24] <= cache_vram_wdata; end
					endcase
				end
				else if( w_cache2_hit ) begin
					//	cache#2 にヒットなら、その中の対応する位置に上書き
					case( cache_vram_address[1:0] )
					2'd0:	begin ff_cache2_data_mask[0] <= 1'b0; ff_cache2_data[ 7: 0] <= cache_vram_wdata; end
					2'd1:	begin ff_cache2_data_mask[1] <= 1'b0; ff_cache2_data[15: 8] <= cache_vram_wdata; end
					2'd2:	begin ff_cache2_data_mask[2] <= 1'b0; ff_cache2_data[23:16] <= cache_vram_wdata; end
					2'd3:	begin ff_cache2_data_mask[3] <= 1'b0; ff_cache2_data[31:24] <= cache_vram_wdata; end
					endcase
				end
				else if( w_cache3_hit ) begin
					//	cache#3 にヒットなら、その中の対応する位置に上書き
					case( cache_vram_address[1:0] )
					2'd0:	begin ff_cache3_data_mask[0] <= 1'b0; ff_cache3_data[ 7: 0] <= cache_vram_wdata; end
					2'd1:	begin ff_cache3_data_mask[1] <= 1'b0; ff_cache3_data[15: 8] <= cache_vram_wdata; end
					2'd2:	begin ff_cache3_data_mask[2] <= 1'b0; ff_cache3_data[23:16] <= cache_vram_wdata; end
					2'd3:	begin ff_cache3_data_mask[3] <= 1'b0; ff_cache3_data[31:24] <= cache_vram_wdata; end
					endcase
				end
				else if( ff_cache0_data_en && ff_cache1_data_en && ff_cache2_data_en && ff_cache3_data_en ) begin
					//	全ての cache が使用済みで、ヒットしない場合は ff_update_target が示す cache を吐き出して上書き
					case( ff_update_target )
					2'd0: begin
						//	Flush cache#0
						if( ff_cache0_data_mask == 4'b1111 ) begin
							ff_vram_valid		<= 1'b0;
						end
						else begin
							ff_vram_valid		<= 1'b1;
							ff_busy				<= 1'b1;
						end
						ff_vram_address			<= ff_cache0_address;
						ff_vram_write			<= 1'b1;
						ff_vram_wdata			<= ff_cache0_data;
						ff_vram_data_mask		<= ff_cache0_data_mask;
						ff_cache0_address		<= cache_vram_address[17:2];
						ff_cache0_already_read	<= 1'b0;
						case( cache_vram_address[1:0] )
						2'd0:	begin ff_cache0_data_mask <= 4'b1110; ff_cache0_data[ 7: 0] <= cache_vram_wdata; end
						2'd1:	begin ff_cache0_data_mask <= 4'b1101; ff_cache0_data[15: 8] <= cache_vram_wdata; end
						2'd2:	begin ff_cache0_data_mask <= 4'b1011; ff_cache0_data[23:16] <= cache_vram_wdata; end
						2'd3:	begin ff_cache0_data_mask <= 4'b0111; ff_cache0_data[31:24] <= cache_vram_wdata; end
						endcase
					end
					2'd1:begin
						//	Flush cache1
						if( ff_cache1_data_mask == 4'b1111 ) begin
							ff_vram_valid		<= 1'b0;
						end
						else begin
							ff_vram_valid		<= 1'b1;
							ff_busy				<= 1'b1;
						end
						ff_vram_address			<= ff_cache1_address;
						ff_vram_write			<= 1'b1;
						ff_vram_wdata			<= ff_cache1_data;
						ff_vram_data_mask		<= ff_cache1_data_mask;
						ff_cache1_address		<= cache_vram_address[17:2];
						ff_cache1_already_read	<= 1'b0;
						case( cache_vram_address[1:0] )
						2'd0:	begin ff_cache1_data_mask <= 4'b1110; ff_cache1_data[ 7: 0] <= cache_vram_wdata; end
						2'd1:	begin ff_cache1_data_mask <= 4'b1101; ff_cache1_data[15: 8] <= cache_vram_wdata; end
						2'd2:	begin ff_cache1_data_mask <= 4'b1011; ff_cache1_data[23:16] <= cache_vram_wdata; end
						2'd3:	begin ff_cache1_data_mask <= 4'b0111; ff_cache1_data[31:24] <= cache_vram_wdata; end
						endcase
					end
					2'd2:begin
						//	Flush cache2
						if( ff_cache2_data_mask == 4'b1111 ) begin
							ff_vram_valid		<= 1'b0;
						end
						else begin
							ff_vram_valid		<= 1'b1;
							ff_busy				<= 1'b1;
						end
						ff_vram_address			<= ff_cache2_address;
						ff_vram_write			<= 1'b1;
						ff_vram_wdata			<= ff_cache2_data;
						ff_vram_data_mask		<= ff_cache2_data_mask;
						ff_cache2_address		<= cache_vram_address[17:2];
						ff_cache2_already_read	<= 1'b0;
						case( cache_vram_address[1:0] )
						2'd0:	begin ff_cache2_data_mask <= 4'b1110; ff_cache2_data[ 7: 0] <= cache_vram_wdata; end
						2'd1:	begin ff_cache2_data_mask <= 4'b1101; ff_cache2_data[15: 8] <= cache_vram_wdata; end
						2'd2:	begin ff_cache2_data_mask <= 4'b1011; ff_cache2_data[23:16] <= cache_vram_wdata; end
						2'd3:	begin ff_cache2_data_mask <= 4'b0111; ff_cache2_data[31:24] <= cache_vram_wdata; end
						endcase
					end
					2'd3:begin
						//	Flush cache3
						if( ff_cache3_data_mask == 4'b1111 ) begin
							ff_vram_valid		<= 1'b0;
						end
						else begin
							ff_vram_valid		<= 1'b1;
							ff_busy				<= 1'b1;
						end
						ff_vram_address			<= ff_cache3_address;
						ff_vram_write			<= 1'b1;
						ff_vram_wdata			<= ff_cache3_data;
						ff_vram_data_mask		<= ff_cache3_data_mask;
						ff_cache3_address		<= cache_vram_address[17:2];
						ff_cache3_already_read	<= 1'b0;
						case( cache_vram_address[1:0] )
						2'd0:	begin ff_cache3_data_mask <= 4'b1110; ff_cache3_data[ 7: 0] <= cache_vram_wdata; end
						2'd1:	begin ff_cache3_data_mask <= 4'b1101; ff_cache3_data[15: 8] <= cache_vram_wdata; end
						2'd2:	begin ff_cache3_data_mask <= 4'b1011; ff_cache3_data[23:16] <= cache_vram_wdata; end
						2'd3:	begin ff_cache3_data_mask <= 4'b0111; ff_cache3_data[31:24] <= cache_vram_wdata; end
						endcase
					end
					endcase
					ff_update_target	<= ff_update_target + 2'd1;
				end
				else if( !ff_cache0_data_en ) begin
					//	Miss hit, and update cache0.
					ff_cache0_address		<= cache_vram_address[17:2];
					ff_cache0_already_read	<= 1'b0;
					ff_cache0_data_en		<= 1'b1;
					case( cache_vram_address[1:0] )
					2'd0:	begin ff_cache0_data_mask <= 4'b1110; ff_cache0_data[ 7: 0] <= cache_vram_wdata; end
					2'd1:	begin ff_cache0_data_mask <= 4'b1101; ff_cache0_data[15: 8] <= cache_vram_wdata; end
					2'd2:	begin ff_cache0_data_mask <= 4'b1011; ff_cache0_data[23:16] <= cache_vram_wdata; end
					2'd3:	begin ff_cache0_data_mask <= 4'b0111; ff_cache0_data[31:24] <= cache_vram_wdata; end
					endcase
				end
				else if( !ff_cache1_data_en ) begin
					//	Miss hit, and update cache0.
					ff_cache1_address		<= cache_vram_address[17:2];
					ff_cache1_already_read	<= 1'b0;
					ff_cache1_data_en		<= 1'b1;
					case( cache_vram_address[1:0] )
					2'd0:	begin ff_cache1_data_mask <= 4'b1110; ff_cache1_data[ 7: 0] <= cache_vram_wdata; end
					2'd1:	begin ff_cache1_data_mask <= 4'b1101; ff_cache1_data[15: 8] <= cache_vram_wdata; end
					2'd2:	begin ff_cache1_data_mask <= 4'b1011; ff_cache1_data[23:16] <= cache_vram_wdata; end
					2'd3:	begin ff_cache1_data_mask <= 4'b0111; ff_cache1_data[31:24] <= cache_vram_wdata; end
					endcase
				end
				else if( !ff_cache2_data_en ) begin
					//	Miss hit, and update cache0.
					ff_cache2_address		<= cache_vram_address[17:2];
					ff_cache2_already_read	<= 1'b0;
					ff_cache2_data_en		<= 1'b1;
					case( cache_vram_address[1:0] )
					2'd0:	begin ff_cache2_data_mask <= 4'b1110; ff_cache2_data[ 7: 0] <= cache_vram_wdata; end
					2'd1:	begin ff_cache2_data_mask <= 4'b1101; ff_cache2_data[15: 8] <= cache_vram_wdata; end
					2'd2:	begin ff_cache2_data_mask <= 4'b1011; ff_cache2_data[23:16] <= cache_vram_wdata; end
					2'd3:	begin ff_cache2_data_mask <= 4'b0111; ff_cache2_data[31:24] <= cache_vram_wdata; end
					endcase
				end
				else begin	//	if( ff_cache3_data_en ) begin
					//	Miss hit, and update cache0.
					ff_cache3_address		<= cache_vram_address[17:2];
					ff_cache3_already_read	<= 1'b0;
					ff_cache3_data_en		<= 1'b1;
					case( cache_vram_address[1:0] )
					2'd0:	begin ff_cache3_data_mask <= 4'b1110; ff_cache3_data[ 7: 0] <= cache_vram_wdata; end
					2'd1:	begin ff_cache3_data_mask <= 4'b1101; ff_cache3_data[15: 8] <= cache_vram_wdata; end
					2'd2:	begin ff_cache3_data_mask <= 4'b1011; ff_cache3_data[23:16] <= cache_vram_wdata; end
					2'd3:	begin ff_cache3_data_mask <= 4'b0111; ff_cache3_data[31:24] <= cache_vram_wdata; end
					endcase
				end
			end
		end
		else if( command_vram_rdata_en && (ff_read_discard == 2'd0) ) begin
			//	SDRAMから読んだデータを cache#n に書き込む
			//	MSXimus (BUG#16): con ff_read_discard != 0 esta respuesta es de
			//	una lectura de un comando ya ABORTADO — se deja caer entera (ni
			//	toca la cache, ni avanza ff_update_target, ni emite rdata_en).
			//	El descuento del contador vive en su propio always (abajo).
			ff_busy						<= 1'b0;
			case( ff_update_target )
			2'd0:	begin
				//	cache#0 を読んだデータで更新する
				ff_cache0_address		<= ff_vram_address;
				ff_cache0_data[ 7: 0]	<= ff_cache0_data_mask[0] ? command_vram_rdata[ 7: 0]: ff_cache0_data[ 7: 0];
				ff_cache0_data[15: 8]	<= ff_cache0_data_mask[1] ? command_vram_rdata[15: 8]: ff_cache0_data[15: 8];
				ff_cache0_data[23:16]	<= ff_cache0_data_mask[2] ? command_vram_rdata[23:16]: ff_cache0_data[23:16];
				ff_cache0_data[31:24]	<= ff_cache0_data_mask[3] ? command_vram_rdata[31:24]: ff_cache0_data[31:24];
				ff_cache0_data_en		<= 1'b1;
				ff_cache0_already_read	<= 1'b1;
			end
			2'd1:	begin
				//	cache#1 を読んだデータで更新する
				ff_cache1_address		<= ff_vram_address;
				ff_cache1_data[ 7: 0]	<= ff_cache1_data_mask[0] ? command_vram_rdata[ 7: 0]: ff_cache1_data[ 7: 0];
				ff_cache1_data[15: 8]	<= ff_cache1_data_mask[1] ? command_vram_rdata[15: 8]: ff_cache1_data[15: 8];
				ff_cache1_data[23:16]	<= ff_cache1_data_mask[2] ? command_vram_rdata[23:16]: ff_cache1_data[23:16];
				ff_cache1_data[31:24]	<= ff_cache1_data_mask[3] ? command_vram_rdata[31:24]: ff_cache1_data[31:24];
				ff_cache1_data_en		<= 1'b1;
				ff_cache1_already_read	<= 1'b1;
			end
			2'd2:	begin
				//	cache#2 を読んだデータで更新する
				ff_cache2_address		<= ff_vram_address;
				ff_cache2_data[ 7: 0]	<= ff_cache2_data_mask[0] ? command_vram_rdata[ 7: 0]: ff_cache2_data[ 7: 0];
				ff_cache2_data[15: 8]	<= ff_cache2_data_mask[1] ? command_vram_rdata[15: 8]: ff_cache2_data[15: 8];
				ff_cache2_data[23:16]	<= ff_cache2_data_mask[2] ? command_vram_rdata[23:16]: ff_cache2_data[23:16];
				ff_cache2_data[31:24]	<= ff_cache2_data_mask[3] ? command_vram_rdata[31:24]: ff_cache2_data[31:24];
				ff_cache2_data_en		<= 1'b1;
				ff_cache2_already_read	<= 1'b1;
			end
			2'd3:	begin
				//	cache#3 を読んだデータで更新する
				ff_cache3_address		<= ff_vram_address;
				ff_cache3_data[ 7: 0]	<= ff_cache3_data_mask[0] ? command_vram_rdata[ 7: 0]: ff_cache3_data[ 7: 0];
				ff_cache3_data[15: 8]	<= ff_cache3_data_mask[1] ? command_vram_rdata[15: 8]: ff_cache3_data[15: 8];
				ff_cache3_data[23:16]	<= ff_cache3_data_mask[2] ? command_vram_rdata[23:16]: ff_cache3_data[23:16];
				ff_cache3_data[31:24]	<= ff_cache3_data_mask[3] ? command_vram_rdata[31:24]: ff_cache3_data[31:24];
				ff_cache3_data_en		<= 1'b1;
				ff_cache3_already_read	<= 1'b1;
			end
			endcase

			case( cache_vram_address[1:0] )
			2'd0:	ff_cache_vram_rdata <= command_vram_rdata[ 7: 0];
			2'd1:	ff_cache_vram_rdata <= command_vram_rdata[15: 8];
			2'd2:	ff_cache_vram_rdata <= command_vram_rdata[23:16];
			2'd3:	ff_cache_vram_rdata <= command_vram_rdata[31:24];
			endcase

			ff_cache_vram_rdata_en		<= 1'b1;
			ff_update_target			<= ff_update_target + 2'd1;
		end
	end

	// --------------------------------------------------------------------
	//	MSXimus (BUG#16): MATADOR DE RESPUESTAS HUERFANAS DE LECTURA
	// --------------------------------------------------------------------
	//	POR QUE: una lectura ya ACEPTADA por el interface (valid & ready en el
	//	mismo ciclo) tiene su respuesta EN CAMINO y el shim la entrega 14-90+
	//	ciclos despues. Si entre medias llega `start` (escritura de R#46, legal
	//	sin esperar a CE=0), el comando se aborta y ff_update_target vuelve a
	//	2'd0... pero la respuesta sigue viniendo: la rama command_vram_rdata_en
	//	RESUCITA la entrada cache#0 — que a esas alturas ya es del comando
	//	NUEVO — cambiandole la direccion por la de la lectura ABORTADA y
	//	conservando su mascara sucia. Consecuencia medida en tb_cmdcache_abort:
	//	el byte del comando nuevo acaba escrito en la direccion VIEJA (1 byte de
	//	VRAM corrupto + el pixel bueno perdido) y ademas sale un
	//	cache_vram_rdata_en espurio que pisa ff_read_pixel/ff_read_byte del
	//	motor (vdp_command.v:1141).
	//	COMO: se cuenta cuantas lecturas hay aceptadas-sin-responder; al abortar
	//	se copia ese contador a ff_read_discard y la rama de respuesta se salta
	//	exactamente esas primeras respuestas.
	//	POR QUE UN always PROPIO: la aceptacion hay que verla EN EL CABLE. En el
	//	ciclo del `start` la cadena de prioridad del always principal ni mira el
	//	handshake, pero el interface SI acepta la peticion en ese mismo ciclo
	//	(vdp_vram_interface.v:259) — es justo el caso limite que hay que armar. Y
	//	al reves: una respuesta que llegue mientras manda una rama anterior
	//	(flush, aceptacion de una peticion nueva...) el always principal la
	//	ignora, y el contador tiene que descontarla igual para no quedarse
	//	armado y comerse la respuesta BUENA del comando siguiente.
	//	INVARIANTE (la misma de la que ya depende el motor, que se cuelga
	//	esperando su rdata_en si falta): cada lectura aceptada recibe UNA
	//	respuesta, por tarde que sea. Lecturas simultaneas en vuelo <= 2 (el
	//	motor espera su dato antes de pedir otro; solo un aborto puede juntar la
	//	del comando viejo con la del nuevo), asi que 2 bits sobran.
	assign w_read_accept		= ff_vram_valid & ~ff_vram_write & command_vram_ready;
	assign w_read_pending_next	= ff_read_pending
								+ ( w_read_accept                                          ? 2'd1 : 2'd0 )
								- ( ( command_vram_rdata_en && (ff_read_pending != 2'd0) ) ? 2'd1 : 2'd0 );

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_read_pending		<= 2'd0;
			ff_read_discard		<= 2'd0;
		end
		else begin
			ff_read_pending		<= w_read_pending_next;
			if( start ) begin
				//	toda lectura que siga en vuelo al acabar este ciclo es ya
				//	huerfana (la aceptada EN el ciclo del start incluida); si
				//	ademas llega una respuesta en este mismo ciclo, el propio
				//	`start` gana la cadena de prioridad y la tira: por eso se
				//	carga el contador YA descontado (w_read_pending_next).
				ff_read_discard	<= w_read_pending_next;
			end
			else if( command_vram_rdata_en && (ff_read_discard != 2'd0) ) begin
				ff_read_discard	<= ff_read_discard - 2'd1;
			end
		end
	end

	// --------------------------------------------------------------------
	//	VRAM Access
	// --------------------------------------------------------------------
	//	FIX ABORTO: durante un flush ff_busy puede caer al aceptarse cada
	//	palabra (linea ~181) — sin el termino ff_flush_state el comando nuevo
	//	veria ready=1 a mitad de flush y su peticion se PERDERIA (el motor
	//	baja valid al ver ready sin que la cache la haya procesado).
	assign w_vram_ready				= ~(ff_vram_valid | ff_busy | (ff_flush_state != 3'd0));
	assign cache_vram_ready			= w_vram_ready;
	assign cache_vram_rdata			= ff_cache_vram_rdata;
	assign cache_vram_rdata_en		= ff_cache_vram_rdata_en;
	assign command_vram_address		= { ff_vram_address, 2'd0 };
	assign command_vram_valid		= ff_vram_valid;
	assign command_vram_write		= ff_vram_write;
	assign command_vram_wdata		= ff_vram_wdata;
	assign command_vram_wdata_mask	= ff_vram_data_mask;
endmodule
