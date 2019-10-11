// Triple Sequence Alignment Testbench 
// Serial I/O
// RAM simulation

// FPGA: use 128-bit-width RAM
`timescale 1ns/100ps

module AdaptiveBandedSW_FPGAIf_tb;

// Timing:
	localparam CLK = 10;
	localparam HCLK = CLK/2;
	localparam SIM_TIME = 3000000;

	logic clk;
	initial clk = 0;
	always #HCLK clk = ~clk;

	localparam S_IDLE = 0;
	localparam S_ABSW = 1;
	localparam S_FINISH = 3;

	localparam T_SIZE 	= 512;
	// localparam B 		= 128;

	// localparam SRAM_DQ_BITS 	= 64;
	// localparam SRAM_ADDR_BITS 	= 6;

	localparam TOTAL_SCORE_BITS = 16;
	localparam SEQ_LEN = 15;

	// localparam MAX_STEP = 	160;
	// localparam MATCH_STEP = 128;
	// localparam SEED_LEN = 	12;
	// localparam LEAST_STEP = 64;

	localparam GAP_EXTEND 	= 1;
	localparam GAP_OPEN 	= 2;
	localparam MATCH 		= 2;
	localparam MISMATCH 	= 1;

	localparam A = 0;
	localparam T = 1;
	localparam C = 2;
	localparam G = 3;
	localparam N = 4;

	localparam A_LENGTH = 64;
	localparam B_LENGTH = 64;
	localparam C_LENGTH = 64;
	localparam A_TOTAL_LENGTH = 512;
	localparam B_TOTAL_LENGTH = 512;
	localparam C_TOTAL_LENGTH = 512;
	localparam PE_LEN = 8;
	localparam SRAM_ADDR_BITS = 9;
	localparam SCORE_BITS = 12; //12

// utils:
	logic rst;

	logic [3:0] state_r, state_w;
	logic [15:0] counter_r, counter_w;
	logic finish_r, finish_w;
	logic start_ABSW_r, start_ABSW_w;
	
	logic [3:0] R_r [0:T_SIZE-1];
	logic [3:0] R_w [0:T_SIZE-1];
	logic [3:0] Q_r [0:T_SIZE-1];
	logic [3:0] Q_w [0:T_SIZE-1];

	logic signed [SCORE_BITS-1:0] score_matrix_r [0:3][0:3];
	logic signed [SCORE_BITS-1:0] score_matrix_w [0:3][0:3];
	logic signed [SCORE_BITS-1:0] M, X, o, e;

	// indicate the length of ABSW
	logic [SEQ_LEN-1:0] A_index, B_index, C_index;
	wire [3:0] A_char_ABSW, B_char_ABSW, C_char_ABSW;

	wire signed [SCORE_BITS-1:0] score_ABSW;
	wire [SEQ_LEN-1:0] A_char_idx_ABSW, B_char_idx_ABSW, C_char_idx_ABSW;
	wire [3:0] R_al_char_ABSW, Q_al_char_ABSW;
	wire [SEQ_LEN:0] R_al_index_ABSW, Q_al_index_ABSW;
	wire valid_al;
	wire finish_ABSW;
	wire [SEQ_LEN:0] al_index_ABSW;
	
	//wire [SEQ_LEN:0] index_al;
	// wire [SEQ_LEN-1:0] x_al_start, y_al_start, x_al_end, y_al_end;

	// FPGA 128-bit RAM
	// reg [127:0] seqR_al_ram [0:2**(SEQ_LEN+1-5)-1];
	// reg [127:0] seqQ_al_ram [0:2**(SEQ_LEN+1-5)-1];

	reg [127:0] seqA_ram [0:2**(SEQ_LEN-5)-1];
	reg [127:0] seqB_ram [0:2**(SEQ_LEN-5)-1];
	reg [127:0] seqC_ram [0:2**(SEQ_LEN-5)-1];

	wire [(SEQ_LEN-6):0] A_r_idx_RAM;	// for A_char_idx_ABSW
	wire [(SEQ_LEN-6):0] B_r_idx_RAM;
	wire [(SEQ_LEN-6):0] C_r_idx_RAM;

	reg [4:0] A_RAM_MUX_idx_r, A_RAM_MUX_idx_w; 
	reg [4:0] B_RAM_MUX_idx_r, B_RAM_MUX_idx_w; 
	reg [4:0] C_RAM_MUX_idx_r, C_RAM_MUX_idx_w; //

	reg [127:0] A_r_RAM;
	reg [127:0] B_r_RAM;
	reg [127:0] C_r_RAM;

	wire [3:0] A_r_data [0:31];			// for RAM read data
	wire [3:0] B_r_data [0:31];
	wire [3:0] C_r_data [0:31];//

	// wire [SEQ_LEN-5:0] R_w_idx_RAM;		// for R_al_index_ABSW
	// wire [SEQ_LEN-5:0] Q_w_idx_RAM;

	// wire [127:0] R_w_RAM;
	// wire [127:0] Q_w_RAM;

	// for seed-splitting-caused overlap (write back)
		// wire read_writeBack;
		// wire prepareOverlap;
		// wire [SEQ_LEN-5:0] writeBack_addr;

		// reg [127:0] R_writeBack;
		// reg [127:0] Q_writeBack;

		// wire [3:0] R_writeBack_vec [0:31];
		// wire [3:0] Q_writeBack_vec [0:31];

	// for 4-to-128-bit-write convertion
	// reg [3:0] R_w_data_r [0:31], R_w_data_w [0:31];
	// reg [3:0] Q_w_data_r [0:31], Q_w_data_w [0:31];

	// for debug
	// RAM al flatten 
	// reg [3:0] seqR_al_RAM_flat [0:2**(SEQ_LEN+1-5)-1][0:31];
	// reg [3:0] seqQ_al_RAM_flat [0:2**(SEQ_LEN+1-5)-1][0:31];


	assign M = MATCH;
	assign X = MISMATCH;
	assign o = GAP_OPEN;
	assign e = GAP_EXTEND;
	assign A_index = A_LENGTH;
	assign B_index = B_LENGTH;
	assign C_index = C_LENGTH;

	// ABSW addr -> RAM read addr
	assign A_r_idx_RAM = A_char_idx_ABSW[SEQ_LEN-1:5];
	assign B_r_idx_RAM = B_char_idx_ABSW[SEQ_LEN-1:5];
	assign C_r_idx_RAM = C_char_idx_ABSW[SEQ_LEN-1:5]; 

	genvar i_RAM_read;
	generate
		for(i_RAM_read = 0; i_RAM_read < 32; i_RAM_read++) begin: RAM_read_gen
			assign A_r_data[i_RAM_read] = A_r_RAM[4*(i_RAM_read+1)-1:4*(i_RAM_read)];
			assign B_r_data[i_RAM_read] = B_r_RAM[4*(i_RAM_read+1)-1:4*(i_RAM_read)];
			assign C_r_data[i_RAM_read] = C_r_RAM[4*(i_RAM_read+1)-1:4*(i_RAM_read)];//
		end
	endgenerate

	// MUX RAM read
	assign A_RAM_MUX_idx_w = A_char_idx_ABSW[4:0];
	assign B_RAM_MUX_idx_w = B_char_idx_ABSW[4:0];
	assign C_RAM_MUX_idx_w = C_char_idx_ABSW[4:0]; //
	assign A_char_ABSW = A_r_data[A_RAM_MUX_idx_r];
	assign B_char_ABSW = B_r_data[B_RAM_MUX_idx_r];
	assign C_char_ABSW = C_r_data[C_RAM_MUX_idx_r];//

	// ABSW write addr -> RAM write addr
	// assign R_w_idx_RAM = R_al_index_ABSW[SEQ_LEN:5];
	// assign Q_w_idx_RAM = Q_al_index_ABSW[SEQ_LEN:5];
	// assign writeBack_addr = al_index_ABSW[SEQ_LEN:5];

	// Flatten
	// RAM write 
	// genvar i_RAM_write;
	// generate
	// 	for(i_RAM_write = 0; i_RAM_write < 32; i_RAM_write++) begin: RAM_write_gen
	// 		assign R_w_RAM[4*(i_RAM_write+1)-1:4*i_RAM_write] = R_w_data_w[i_RAM_write];
	// 		assign Q_w_RAM[4*(i_RAM_write+1)-1:4*i_RAM_write] = Q_w_data_w[i_RAM_write];

	// 		assign R_writeBack_vec[i_RAM_write] = R_writeBack[4*(i_RAM_write+1)-1:4*i_RAM_write];
	// 		assign Q_writeBack_vec[i_RAM_write] = Q_writeBack[4*(i_RAM_write+1)-1:4*i_RAM_write];
	// 	end
	// endgenerate


	// for debug
	// RAM flatten
	// genvar i_RAM_flat;
	// genvar i_RAM_data_flat;
	// generate
	// 	for(i_RAM_flat = 0; i_RAM_flat < 2**(SEQ_LEN+1-5); i_RAM_flat++) begin: RAM_flat_gen
	// 		for(i_RAM_data_flat = 0; i_RAM_data_flat < 32; i_RAM_data_flat++) begin: RAM_data_flat_gen
	// 			assign seqR_al_RAM_flat[i_RAM_flat][i_RAM_data_flat] = seqR_al_ram[i_RAM_flat][4*(i_RAM_data_flat+1)-1:4*i_RAM_data_flat];
	// 			assign seqQ_al_RAM_flat[i_RAM_flat][i_RAM_data_flat] = seqQ_al_ram[i_RAM_flat][4*(i_RAM_data_flat+1)-1:4*i_RAM_data_flat];
	// 		end
	// 	end
	// endgenerate


	TRIALIGN # (
	.SCORE_BITS(SCORE_BITS),
	.A_TOTAL_LEN(A_TOTAL_LENGTH),
	.B_TOTAL_LEN(B_TOTAL_LENGTH),
	.C_TOTAL_LEN(C_TOTAL_LENGTH),
	.PE_LEN(PE_LEN),
	.SRAM_ADDR_BITS(SRAM_ADDR_BITS)
	)DUT(
		.clk(clk),
		.start_align(start_ABSW_r),
		.rst(rst),

		.A_symbol(A_char_ABSW),
		.B_symbol(B_char_ABSW),
		.C_symbol(C_char_ABSW),

		//.i_score_matrix(score_matrix_r), // order: 00 01 02 03...
		// .i_match(M),
		// .i_mismatch(X),
		// .i_gap_extend(e),
		// .i_gap_open(o),

		// indicate ABSW sequence last character position (0~2**SEQ_LEN-1)
		.A_idx(A_index),	
		.B_idx(B_index),
		.C_idx(C_index),

		.Score(score_ABSW),

		// for banded SW to fetch single R and Q characters 
		// extended from 9 to 15 bits
		.A_addr(A_char_idx_ABSW),
		.B_addr(B_char_idx_ABSW),
		.C_addr(C_char_idx_ABSW),

		// SERIAL OUTPUT
		// alignment output: output 1 character per cycle 
		// .o_R_al_char(R_al_char_ABSW),
		// .o_Q_al_char(Q_al_char_ABSW),
		// .o_R_al_index(R_al_index_ABSW),
		// .o_Q_al_index(Q_al_index_ABSW),
		// .o_valid_al(valid_al),

		// .o_al_index(al_index_ABSW),		// index of alignment (length)
		// .o_x_start(x_al_start),			// alignment start x position
		// .o_y_start(y_al_start),			// alignment start y position
		// .o_x_end(x_al_end),			// alignment end x position
		// .o_y_end(y_al_end),			// alignment end y position
		// .o_null(),

		// .o_write_back(read_writeBack),
		// .o_BSW_PE_init(prepareOverlap),

		// .o_counter(),
		// .o_cell_counter(),
		// .o_state(),
		// .o_finish(finish_ABSW)
		.finish(finish_ABSW)
);


	initial begin
		$fsdbDumpfile("TriAlign.fsdb");
	   	$fsdbDumpvars(0, "+mda");
		rst = 1;
		#(2*CLK)
		rst = 0;
	end

	initial begin
		#(SIM_TIME*CLK)
		$finish;
	end


	always_comb begin

		// for(int i = 0; i<4; i++) begin
		// 	for(int j = 0; j<4; j++) begin
		// 		if(i == j) begin
		// 			score_matrix_w[i][j] = MATCH;
		// 		end
		// 		else begin
		// 			score_matrix_w[i][j] = -MISMATCH;
		// 		end
		// 	end
		// end

		state_w = state_r;
		counter_w = counter_r + 1;
		start_ABSW_w = 0;
		finish_w = 0;

		// for(int i = 0; i < 32; i++) begin
		// 	R_w_data_w[i] = R_w_data_r[i];
		// 	Q_w_data_w[i] = Q_w_data_r[i];
		// end

		// if(valid_al) begin
		// 	R_w_data_w[R_al_index_ABSW[4:0]] = R_al_char_ABSW;
		// 	Q_w_data_w[Q_al_index_ABSW[4:0]] = Q_al_char_ABSW;
		// end
		// else if(prepareOverlap) begin
		// 	for(int i = 0; i < 32; i++) begin
		// 		R_w_data_w[i] = R_writeBack_vec[i];
		// 		Q_w_data_w[i] = Q_writeBack_vec[i];
		// 	end
		// end

		case(state_r)
			S_IDLE: begin
				
				start_ABSW_w = 1;
				state_w = S_ABSW;
			end

			S_ABSW: begin
				if(finish_ABSW) begin
					state_w = S_FINISH;
					finish_w = 1;
				end
				else begin end

			end

			S_FINISH: begin
				
			end
		endcase
	end


	// Print
	always_ff @(posedge clk) begin

		if(finish_ABSW) begin
			$display(" ");
			$display("TriAlign Score:        \t%d", score_ABSW);
			// $display("Alignment index:   \t%d", al_index_ABSW);
			// $display("Alignment start x: \t%d", x_al_start);
			// $display("Alignment start y: \t%d", y_al_start);
			// $display("Alignment end x:   \t%d", x_al_end);
			// $display("Alignment end y:   \t%d", y_al_end);
		end

		if(finish_r) begin
			
			$display("Finish simulation");
			$finish;
		end		
	end

	always_ff @ (posedge clk) begin
		if(rst != 1) begin
			state_r <= state_w;
			start_ABSW_r <= start_ABSW_w;
			counter_r <= counter_w;
			finish_r <= finish_w;

			// for(int i = 0; i < T_SIZE; i++) begin
			// 	R_r[i] <= R_w[i];
			// 	Q_r[i] <= Q_w[i];
			// end
			
			// for(int i = 0; i<4; i++) begin
			// 	for(int j = 0; j<4; j++) begin
			// 		score_matrix_r[i][j] <= score_matrix_w[i][j];
			// 	end
			// end

			
			// for(int i = 0; i < 32; i++) begin
			// 	R_w_data_r[i] <= R_w_data_w[i];
			// 	Q_w_data_r[i] <= Q_w_data_w[i];
			// end
			
			// if(read_writeBack) begin
			// 	R_writeBack <= seqR_al_ram[writeBack_addr];
			// 	Q_writeBack <= seqQ_al_ram[writeBack_addr];
			// end

			
			// RAM
			// if(valid_al) begin
			// 	seqR_al_ram[R_w_idx_RAM] <= R_w_RAM;
			// 	seqQ_al_ram[Q_w_idx_RAM] <= Q_w_RAM;
			// end
			A_r_RAM <= seqA_ram[A_r_idx_RAM];
			B_r_RAM <= seqB_ram[B_r_idx_RAM];
			C_r_RAM <= seqC_ram[C_r_idx_RAM];

			A_RAM_MUX_idx_r <= A_RAM_MUX_idx_w;
			B_RAM_MUX_idx_r <= B_RAM_MUX_idx_w;
			C_RAM_MUX_idx_r <= C_RAM_MUX_idx_w;
		end
		else begin

			state_r <= S_IDLE;
			start_ABSW_r <= 0;
			counter_r <= 0;
			finish_r <= 0;

			// for(int i = 0; i<4; i++) begin
			// 	for(int j = 0; j<4; j++) begin
			// 		score_matrix_r[i][j] <= 0;
			// 	end
			// end

			// for(int i = 0; i < 32; i++) begin
			// 	R_w_data_r[i] <= 4'd0;
			// 	Q_w_data_r[i] <= 4'd0;
			// end

			A_RAM_MUX_idx_r <= 0;
			B_RAM_MUX_idx_r <= 0;
			C_RAM_MUX_idx_r <= 0;
		end
	end

	initial begin
seqA_ram[0][3:0] <= A;
seqA_ram[0][7:4] <= A;
seqA_ram[0][11:8] <= A;
seqA_ram[0][15:12] <= A;
seqA_ram[0][19:16] <= A;
seqA_ram[0][23:20] <= A;
seqA_ram[0][27:24] <= A;
seqA_ram[0][31:28] <= A;
seqA_ram[0][35:32] <= A;
seqA_ram[0][39:36] <= A;
seqA_ram[0][43:40] <= A;
seqA_ram[0][47:44] <= A;
seqA_ram[0][51:48] <= A;
seqA_ram[0][55:52] <= A;
seqA_ram[0][59:56] <= A;
seqA_ram[0][63:60] <= A;
seqA_ram[0][67:64] <= A;
seqA_ram[0][71:68] <= A;
seqA_ram[0][75:72] <= A;
seqA_ram[0][79:76] <= A;
seqA_ram[0][83:80] <= A;
seqA_ram[0][87:84] <= A;
seqA_ram[0][91:88] <= A;
seqA_ram[0][95:92] <= A;
seqA_ram[0][99:96] <= A;
seqA_ram[0][103:100] <= A;
seqA_ram[0][107:104] <= A;
seqA_ram[0][111:108] <= A;
seqA_ram[0][115:112] <= A;
seqA_ram[0][119:116] <= A;
seqA_ram[0][123:120] <= A;
seqA_ram[0][127:124] <= A;
seqA_ram[1][3:0] <= A;
seqA_ram[1][7:4] <= A;
seqA_ram[1][11:8] <= A;
seqA_ram[1][15:12] <= A;
seqA_ram[1][19:16] <= A;
seqA_ram[1][23:20] <= A;
seqA_ram[1][27:24] <= A;
seqA_ram[1][31:28] <= A;
seqA_ram[1][35:32] <= A;
seqA_ram[1][39:36] <= A;
seqA_ram[1][43:40] <= A;
seqA_ram[1][47:44] <= A;
seqA_ram[1][51:48] <= A;
seqA_ram[1][55:52] <= A;
seqA_ram[1][59:56] <= A;
seqA_ram[1][63:60] <= A;
seqA_ram[1][67:64] <= A;
seqA_ram[1][71:68] <= A;
seqA_ram[1][75:72] <= A;
seqA_ram[1][79:76] <= A;
seqA_ram[1][83:80] <= A;
seqA_ram[1][87:84] <= A;
seqA_ram[1][91:88] <= A;
seqA_ram[1][95:92] <= A;
seqA_ram[1][99:96] <= A;
seqA_ram[1][103:100] <= A;
seqA_ram[1][107:104] <= A;
seqA_ram[1][111:108] <= A;
seqA_ram[1][115:112] <= A;
seqA_ram[1][119:116] <= A;
seqA_ram[1][123:120] <= A;
seqA_ram[1][127:124] <= A;
seqA_ram[2][3:0] <= A;
seqA_ram[2][7:4] <= A;
seqA_ram[2][11:8] <= A;
seqA_ram[2][15:12] <= A;
seqA_ram[2][19:16] <= A;
seqA_ram[2][23:20] <= A;
seqA_ram[2][27:24] <= A;
seqA_ram[2][31:28] <= A;
seqA_ram[2][35:32] <= A;
seqA_ram[2][39:36] <= A;
seqA_ram[2][43:40] <= A;
seqA_ram[2][47:44] <= A;
seqA_ram[2][51:48] <= A;
seqA_ram[2][55:52] <= A;
seqA_ram[2][59:56] <= A;
seqA_ram[2][63:60] <= A;
seqA_ram[2][67:64] <= A;
seqA_ram[2][71:68] <= A;
seqA_ram[2][75:72] <= A;
seqA_ram[2][79:76] <= A;
seqA_ram[2][83:80] <= A;
seqA_ram[2][87:84] <= A;
seqA_ram[2][91:88] <= A;
seqA_ram[2][95:92] <= A;
seqA_ram[2][99:96] <= A;
seqA_ram[2][103:100] <= A;
seqA_ram[2][107:104] <= A;
seqA_ram[2][111:108] <= A;
seqA_ram[2][115:112] <= A;
seqA_ram[2][119:116] <= A;
seqA_ram[2][123:120] <= A;
seqA_ram[2][127:124] <= A;
seqA_ram[3][3:0] <= A;
seqA_ram[3][7:4] <= A;
seqA_ram[3][11:8] <= A;
seqA_ram[3][15:12] <= A;
seqA_ram[3][19:16] <= A;
seqA_ram[3][23:20] <= A;
seqA_ram[3][27:24] <= A;
seqA_ram[3][31:28] <= A;
seqA_ram[3][35:32] <= A;
seqA_ram[3][39:36] <= A;
seqA_ram[3][43:40] <= A;
seqA_ram[3][47:44] <= A;
seqA_ram[3][51:48] <= A;
seqA_ram[3][55:52] <= A;
seqA_ram[3][59:56] <= A;
seqA_ram[3][63:60] <= A;
seqA_ram[3][67:64] <= A;
seqA_ram[3][71:68] <= A;
seqA_ram[3][75:72] <= A;
seqA_ram[3][79:76] <= A;
seqA_ram[3][83:80] <= A;
seqA_ram[3][87:84] <= A;
seqA_ram[3][91:88] <= A;
seqA_ram[3][95:92] <= A;
seqA_ram[3][99:96] <= A;
seqA_ram[3][103:100] <= A;
seqA_ram[3][107:104] <= A;
seqA_ram[3][111:108] <= A;
seqA_ram[3][115:112] <= A;
seqA_ram[3][119:116] <= A;
seqA_ram[3][123:120] <= A;
seqA_ram[3][127:124] <= A;
seqA_ram[4][3:0] <= A;
seqA_ram[4][7:4] <= A;
seqA_ram[4][11:8] <= A;
seqA_ram[4][15:12] <= A;
seqA_ram[4][19:16] <= A;
seqA_ram[4][23:20] <= A;
seqA_ram[4][27:24] <= A;
seqA_ram[4][31:28] <= A;
seqA_ram[4][35:32] <= A;
seqA_ram[4][39:36] <= A;
seqA_ram[4][43:40] <= A;
seqA_ram[4][47:44] <= A;
seqA_ram[4][51:48] <= A;
seqA_ram[4][55:52] <= A;
seqA_ram[4][59:56] <= A;
seqA_ram[4][63:60] <= A;
seqA_ram[4][67:64] <= A;
seqA_ram[4][71:68] <= A;
seqA_ram[4][75:72] <= A;
seqA_ram[4][79:76] <= A;
seqA_ram[4][83:80] <= A;
seqA_ram[4][87:84] <= A;
seqA_ram[4][91:88] <= A;
seqA_ram[4][95:92] <= A;
seqA_ram[4][99:96] <= A;
seqA_ram[4][103:100] <= A;
seqA_ram[4][107:104] <= A;
seqA_ram[4][111:108] <= A;
seqA_ram[4][115:112] <= A;
seqA_ram[4][119:116] <= A;
seqA_ram[4][123:120] <= A;
seqA_ram[4][127:124] <= A;
seqA_ram[5][3:0] <= A;
seqA_ram[5][7:4] <= A;
seqA_ram[5][11:8] <= A;
seqA_ram[5][15:12] <= A;
seqA_ram[5][19:16] <= A;
seqA_ram[5][23:20] <= A;
seqA_ram[5][27:24] <= A;
seqA_ram[5][31:28] <= A;
seqA_ram[5][35:32] <= A;
seqA_ram[5][39:36] <= A;
seqA_ram[5][43:40] <= A;
seqA_ram[5][47:44] <= A;
seqA_ram[5][51:48] <= A;
seqA_ram[5][55:52] <= A;
seqA_ram[5][59:56] <= A;
seqA_ram[5][63:60] <= A;
seqA_ram[5][67:64] <= A;
seqA_ram[5][71:68] <= A;
seqA_ram[5][75:72] <= A;
seqA_ram[5][79:76] <= A;
seqA_ram[5][83:80] <= A;
seqA_ram[5][87:84] <= A;
seqA_ram[5][91:88] <= A;
seqA_ram[5][95:92] <= A;
seqA_ram[5][99:96] <= A;
seqA_ram[5][103:100] <= A;
seqA_ram[5][107:104] <= A;
seqA_ram[5][111:108] <= A;
seqA_ram[5][115:112] <= A;
seqA_ram[5][119:116] <= A;
seqA_ram[5][123:120] <= A;
seqA_ram[5][127:124] <= A;
seqA_ram[6][3:0] <= A;
seqA_ram[6][7:4] <= A;
seqA_ram[6][11:8] <= A;
seqA_ram[6][15:12] <= A;
seqA_ram[6][19:16] <= A;
seqA_ram[6][23:20] <= A;
seqA_ram[6][27:24] <= A;
seqA_ram[6][31:28] <= A;
seqA_ram[6][35:32] <= A;
seqA_ram[6][39:36] <= A;
seqA_ram[6][43:40] <= A;
seqA_ram[6][47:44] <= A;
seqA_ram[6][51:48] <= A;
seqA_ram[6][55:52] <= A;
seqA_ram[6][59:56] <= A;
seqA_ram[6][63:60] <= A;
seqA_ram[6][67:64] <= A;
seqA_ram[6][71:68] <= A;
seqA_ram[6][75:72] <= A;
seqA_ram[6][79:76] <= A;
seqA_ram[6][83:80] <= A;
seqA_ram[6][87:84] <= A;
seqA_ram[6][91:88] <= A;
seqA_ram[6][95:92] <= A;
seqA_ram[6][99:96] <= A;
seqA_ram[6][103:100] <= A;
seqA_ram[6][107:104] <= A;
seqA_ram[6][111:108] <= A;
seqA_ram[6][115:112] <= A;
seqA_ram[6][119:116] <= A;
seqA_ram[6][123:120] <= A;
seqA_ram[6][127:124] <= A;
seqA_ram[7][3:0] <= A;
seqA_ram[7][7:4] <= A;
seqA_ram[7][11:8] <= A;
seqA_ram[7][15:12] <= A;
seqA_ram[7][19:16] <= A;
seqA_ram[7][23:20] <= A;
seqA_ram[7][27:24] <= A;
seqA_ram[7][31:28] <= A;
seqA_ram[7][35:32] <= A;
seqA_ram[7][39:36] <= A;
seqA_ram[7][43:40] <= A;
seqA_ram[7][47:44] <= A;
seqA_ram[7][51:48] <= A;
seqA_ram[7][55:52] <= A;
seqA_ram[7][59:56] <= A;
seqA_ram[7][63:60] <= A;
seqA_ram[7][67:64] <= A;
seqA_ram[7][71:68] <= A;
seqA_ram[7][75:72] <= A;
seqA_ram[7][79:76] <= A;
seqA_ram[7][83:80] <= A;
seqA_ram[7][87:84] <= A;
seqA_ram[7][91:88] <= A;
seqA_ram[7][95:92] <= A;
seqA_ram[7][99:96] <= A;
seqA_ram[7][103:100] <= A;
seqA_ram[7][107:104] <= A;
seqA_ram[7][111:108] <= A;
seqA_ram[7][115:112] <= A;
seqA_ram[7][119:116] <= A;
seqA_ram[7][123:120] <= A;
seqA_ram[7][127:124] <= A;
seqA_ram[8][3:0] <= A;
seqA_ram[8][7:4] <= A;
seqA_ram[8][11:8] <= A;
seqA_ram[8][15:12] <= A;
seqA_ram[8][19:16] <= A;
seqA_ram[8][23:20] <= A;
seqA_ram[8][27:24] <= A;
seqA_ram[8][31:28] <= A;
seqA_ram[8][35:32] <= A;
seqA_ram[8][39:36] <= A;
seqA_ram[8][43:40] <= A;
seqA_ram[8][47:44] <= A;
seqA_ram[8][51:48] <= A;
seqA_ram[8][55:52] <= A;
seqA_ram[8][59:56] <= A;
seqA_ram[8][63:60] <= A;
seqA_ram[8][67:64] <= A;
seqA_ram[8][71:68] <= A;
seqA_ram[8][75:72] <= A;
seqA_ram[8][79:76] <= A;
seqA_ram[8][83:80] <= A;
seqA_ram[8][87:84] <= A;
seqA_ram[8][91:88] <= A;
seqA_ram[8][95:92] <= A;
seqA_ram[8][99:96] <= A;
seqA_ram[8][103:100] <= A;
seqA_ram[8][107:104] <= A;
seqA_ram[8][111:108] <= A;
seqA_ram[8][115:112] <= A;
seqA_ram[8][119:116] <= A;
seqA_ram[8][123:120] <= A;
seqA_ram[8][127:124] <= A;
seqA_ram[9][3:0] <= A;
seqA_ram[9][7:4] <= A;
seqA_ram[9][11:8] <= A;
seqA_ram[9][15:12] <= A;
seqA_ram[9][19:16] <= A;
seqA_ram[9][23:20] <= A;
seqA_ram[9][27:24] <= A;
seqA_ram[9][31:28] <= A;
seqA_ram[9][35:32] <= A;
seqA_ram[9][39:36] <= A;
seqA_ram[9][43:40] <= A;
seqA_ram[9][47:44] <= A;
seqA_ram[9][51:48] <= A;
seqA_ram[9][55:52] <= A;
seqA_ram[9][59:56] <= A;
seqA_ram[9][63:60] <= A;
seqA_ram[9][67:64] <= A;
seqA_ram[9][71:68] <= A;
seqA_ram[9][75:72] <= A;
seqA_ram[9][79:76] <= A;
seqA_ram[9][83:80] <= A;
seqA_ram[9][87:84] <= A;
seqA_ram[9][91:88] <= A;
seqA_ram[9][95:92] <= A;
seqA_ram[9][99:96] <= A;
seqA_ram[9][103:100] <= A;
seqA_ram[9][107:104] <= A;
seqA_ram[9][111:108] <= A;
seqA_ram[9][115:112] <= A;
seqA_ram[9][119:116] <= A;
seqA_ram[9][123:120] <= A;
seqA_ram[9][127:124] <= A;
seqA_ram[10][3:0] <= A;
seqA_ram[10][7:4] <= A;
seqA_ram[10][11:8] <= A;
seqA_ram[10][15:12] <= A;
seqA_ram[10][19:16] <= A;
seqA_ram[10][23:20] <= A;
seqA_ram[10][27:24] <= A;
seqA_ram[10][31:28] <= A;
seqA_ram[10][35:32] <= A;
seqA_ram[10][39:36] <= A;
seqA_ram[10][43:40] <= A;
seqA_ram[10][47:44] <= A;
seqA_ram[10][51:48] <= A;
seqA_ram[10][55:52] <= A;
seqA_ram[10][59:56] <= A;
seqA_ram[10][63:60] <= A;
seqA_ram[10][67:64] <= A;
seqA_ram[10][71:68] <= A;
seqA_ram[10][75:72] <= A;
seqA_ram[10][79:76] <= A;
seqA_ram[10][83:80] <= A;
seqA_ram[10][87:84] <= A;
seqA_ram[10][91:88] <= A;
seqA_ram[10][95:92] <= A;
seqA_ram[10][99:96] <= A;
seqA_ram[10][103:100] <= A;
seqA_ram[10][107:104] <= A;
seqA_ram[10][111:108] <= A;
seqA_ram[10][115:112] <= A;
seqA_ram[10][119:116] <= A;
seqA_ram[10][123:120] <= A;
seqA_ram[10][127:124] <= A;
seqA_ram[11][3:0] <= A;
seqA_ram[11][7:4] <= A;
seqA_ram[11][11:8] <= A;
seqA_ram[11][15:12] <= A;
seqA_ram[11][19:16] <= A;
seqA_ram[11][23:20] <= A;
seqA_ram[11][27:24] <= A;
seqA_ram[11][31:28] <= A;
seqA_ram[11][35:32] <= A;
seqA_ram[11][39:36] <= A;
seqA_ram[11][43:40] <= A;
seqA_ram[11][47:44] <= A;
seqA_ram[11][51:48] <= A;
seqA_ram[11][55:52] <= A;
seqA_ram[11][59:56] <= A;
seqA_ram[11][63:60] <= A;
seqA_ram[11][67:64] <= A;
seqA_ram[11][71:68] <= A;
seqA_ram[11][75:72] <= A;
seqA_ram[11][79:76] <= A;
seqA_ram[11][83:80] <= A;
seqA_ram[11][87:84] <= A;
seqA_ram[11][91:88] <= A;
seqA_ram[11][95:92] <= A;
seqA_ram[11][99:96] <= A;
seqA_ram[11][103:100] <= A;
seqA_ram[11][107:104] <= A;
seqA_ram[11][111:108] <= A;
seqA_ram[11][115:112] <= A;
seqA_ram[11][119:116] <= A;
seqA_ram[11][123:120] <= A;
seqA_ram[11][127:124] <= A;
seqA_ram[12][3:0] <= A;
seqA_ram[12][7:4] <= A;
seqA_ram[12][11:8] <= A;
seqA_ram[12][15:12] <= A;
seqA_ram[12][19:16] <= A;
seqA_ram[12][23:20] <= A;
seqA_ram[12][27:24] <= A;
seqA_ram[12][31:28] <= A;
seqA_ram[12][35:32] <= A;
seqA_ram[12][39:36] <= A;
seqA_ram[12][43:40] <= A;
seqA_ram[12][47:44] <= A;
seqA_ram[12][51:48] <= A;
seqA_ram[12][55:52] <= A;
seqA_ram[12][59:56] <= A;
seqA_ram[12][63:60] <= A;
seqA_ram[12][67:64] <= A;
seqA_ram[12][71:68] <= A;
seqA_ram[12][75:72] <= A;
seqA_ram[12][79:76] <= A;
seqA_ram[12][83:80] <= A;
seqA_ram[12][87:84] <= A;
seqA_ram[12][91:88] <= A;
seqA_ram[12][95:92] <= A;
seqA_ram[12][99:96] <= A;
seqA_ram[12][103:100] <= A;
seqA_ram[12][107:104] <= A;
seqA_ram[12][111:108] <= A;
seqA_ram[12][115:112] <= A;
seqA_ram[12][119:116] <= A;
seqA_ram[12][123:120] <= A;
seqA_ram[12][127:124] <= A;
seqA_ram[13][3:0] <= A;
seqA_ram[13][7:4] <= A;
seqA_ram[13][11:8] <= A;
seqA_ram[13][15:12] <= A;
seqA_ram[13][19:16] <= A;
seqA_ram[13][23:20] <= A;
seqA_ram[13][27:24] <= A;
seqA_ram[13][31:28] <= A;
seqA_ram[13][35:32] <= A;
seqA_ram[13][39:36] <= A;
seqA_ram[13][43:40] <= A;
seqA_ram[13][47:44] <= A;
seqA_ram[13][51:48] <= A;
seqA_ram[13][55:52] <= A;
seqA_ram[13][59:56] <= A;
seqA_ram[13][63:60] <= A;
seqA_ram[13][67:64] <= A;
seqA_ram[13][71:68] <= A;
seqA_ram[13][75:72] <= A;
seqA_ram[13][79:76] <= A;
seqA_ram[13][83:80] <= A;
seqA_ram[13][87:84] <= A;
seqA_ram[13][91:88] <= A;
seqA_ram[13][95:92] <= A;
seqA_ram[13][99:96] <= A;
seqA_ram[13][103:100] <= A;
seqA_ram[13][107:104] <= A;
seqA_ram[13][111:108] <= A;
seqA_ram[13][115:112] <= A;
seqA_ram[13][119:116] <= A;
seqA_ram[13][123:120] <= A;
seqA_ram[13][127:124] <= A;
seqA_ram[14][3:0] <= A;
seqA_ram[14][7:4] <= A;
seqA_ram[14][11:8] <= A;
seqA_ram[14][15:12] <= A;
seqA_ram[14][19:16] <= A;
seqA_ram[14][23:20] <= A;
seqA_ram[14][27:24] <= A;
seqA_ram[14][31:28] <= A;
seqA_ram[14][35:32] <= A;
seqA_ram[14][39:36] <= A;
seqA_ram[14][43:40] <= A;
seqA_ram[14][47:44] <= A;
seqA_ram[14][51:48] <= A;
seqA_ram[14][55:52] <= A;
seqA_ram[14][59:56] <= A;
seqA_ram[14][63:60] <= A;
seqA_ram[14][67:64] <= A;
seqA_ram[14][71:68] <= A;
seqA_ram[14][75:72] <= A;
seqA_ram[14][79:76] <= A;
seqA_ram[14][83:80] <= A;
seqA_ram[14][87:84] <= A;
seqA_ram[14][91:88] <= A;
seqA_ram[14][95:92] <= A;
seqA_ram[14][99:96] <= A;
seqA_ram[14][103:100] <= A;
seqA_ram[14][107:104] <= A;
seqA_ram[14][111:108] <= A;
seqA_ram[14][115:112] <= A;
seqA_ram[14][119:116] <= A;
seqA_ram[14][123:120] <= A;
seqA_ram[14][127:124] <= A;
seqA_ram[15][3:0] <= A;
seqA_ram[15][7:4] <= A;
seqA_ram[15][11:8] <= A;
seqA_ram[15][15:12] <= A;
seqA_ram[15][19:16] <= A;
seqA_ram[15][23:20] <= A;
seqA_ram[15][27:24] <= A;
seqA_ram[15][31:28] <= A;
seqA_ram[15][35:32] <= A;
seqA_ram[15][39:36] <= A;
seqA_ram[15][43:40] <= A;
seqA_ram[15][47:44] <= A;
seqA_ram[15][51:48] <= A;
seqA_ram[15][55:52] <= A;
seqA_ram[15][59:56] <= A;
seqA_ram[15][63:60] <= A;
seqA_ram[15][67:64] <= A;
seqA_ram[15][71:68] <= A;
seqA_ram[15][75:72] <= A;
seqA_ram[15][79:76] <= A;
seqA_ram[15][83:80] <= A;
seqA_ram[15][87:84] <= A;
seqA_ram[15][91:88] <= A;
seqA_ram[15][95:92] <= A;
seqA_ram[15][99:96] <= A;
seqA_ram[15][103:100] <= A;
seqA_ram[15][107:104] <= A;
seqA_ram[15][111:108] <= A;
seqA_ram[15][115:112] <= A;
seqA_ram[15][119:116] <= A;
seqA_ram[15][123:120] <= A;
seqA_ram[15][127:124] <= A;
seqB_ram[0][3:0] <= A;
seqB_ram[0][7:4] <= A;
seqB_ram[0][11:8] <= A;
seqB_ram[0][15:12] <= A;
seqB_ram[0][19:16] <= A;
seqB_ram[0][23:20] <= A;
seqB_ram[0][27:24] <= A;
seqB_ram[0][31:28] <= A;
seqB_ram[0][35:32] <= A;
seqB_ram[0][39:36] <= A;
seqB_ram[0][43:40] <= A;
seqB_ram[0][47:44] <= A;
seqB_ram[0][51:48] <= A;
seqB_ram[0][55:52] <= A;
seqB_ram[0][59:56] <= A;
seqB_ram[0][63:60] <= A;
seqB_ram[0][67:64] <= A;
seqB_ram[0][71:68] <= A;
seqB_ram[0][75:72] <= A;
seqB_ram[0][79:76] <= A;
seqB_ram[0][83:80] <= A;
seqB_ram[0][87:84] <= A;
seqB_ram[0][91:88] <= A;
seqB_ram[0][95:92] <= A;
seqB_ram[0][99:96] <= A;
seqB_ram[0][103:100] <= A;
seqB_ram[0][107:104] <= A;
seqB_ram[0][111:108] <= A;
seqB_ram[0][115:112] <= A;
seqB_ram[0][119:116] <= A;
seqB_ram[0][123:120] <= A;
seqB_ram[0][127:124] <= A;
seqB_ram[1][3:0] <= A;
seqB_ram[1][7:4] <= A;
seqB_ram[1][11:8] <= A;
seqB_ram[1][15:12] <= A;
seqB_ram[1][19:16] <= A;
seqB_ram[1][23:20] <= A;
seqB_ram[1][27:24] <= A;
seqB_ram[1][31:28] <= A;
seqB_ram[1][35:32] <= A;
seqB_ram[1][39:36] <= A;
seqB_ram[1][43:40] <= A;
seqB_ram[1][47:44] <= A;
seqB_ram[1][51:48] <= A;
seqB_ram[1][55:52] <= A;
seqB_ram[1][59:56] <= A;
seqB_ram[1][63:60] <= A;
seqB_ram[1][67:64] <= A;
seqB_ram[1][71:68] <= A;
seqB_ram[1][75:72] <= A;
seqB_ram[1][79:76] <= A;
seqB_ram[1][83:80] <= A;
seqB_ram[1][87:84] <= A;
seqB_ram[1][91:88] <= A;
seqB_ram[1][95:92] <= A;
seqB_ram[1][99:96] <= A;
seqB_ram[1][103:100] <= A;
seqB_ram[1][107:104] <= A;
seqB_ram[1][111:108] <= A;
seqB_ram[1][115:112] <= A;
seqB_ram[1][119:116] <= A;
seqB_ram[1][123:120] <= A;
seqB_ram[1][127:124] <= A;
seqB_ram[2][3:0] <= A;
seqB_ram[2][7:4] <= A;
seqB_ram[2][11:8] <= A;
seqB_ram[2][15:12] <= A;
seqB_ram[2][19:16] <= A;
seqB_ram[2][23:20] <= A;
seqB_ram[2][27:24] <= A;
seqB_ram[2][31:28] <= A;
seqB_ram[2][35:32] <= A;
seqB_ram[2][39:36] <= A;
seqB_ram[2][43:40] <= A;
seqB_ram[2][47:44] <= A;
seqB_ram[2][51:48] <= A;
seqB_ram[2][55:52] <= A;
seqB_ram[2][59:56] <= A;
seqB_ram[2][63:60] <= A;
seqB_ram[2][67:64] <= A;
seqB_ram[2][71:68] <= A;
seqB_ram[2][75:72] <= A;
seqB_ram[2][79:76] <= A;
seqB_ram[2][83:80] <= A;
seqB_ram[2][87:84] <= A;
seqB_ram[2][91:88] <= A;
seqB_ram[2][95:92] <= A;
seqB_ram[2][99:96] <= A;
seqB_ram[2][103:100] <= A;
seqB_ram[2][107:104] <= A;
seqB_ram[2][111:108] <= A;
seqB_ram[2][115:112] <= A;
seqB_ram[2][119:116] <= A;
seqB_ram[2][123:120] <= A;
seqB_ram[2][127:124] <= A;
seqB_ram[3][3:0] <= A;
seqB_ram[3][7:4] <= A;
seqB_ram[3][11:8] <= A;
seqB_ram[3][15:12] <= A;
seqB_ram[3][19:16] <= A;
seqB_ram[3][23:20] <= A;
seqB_ram[3][27:24] <= A;
seqB_ram[3][31:28] <= A;
seqB_ram[3][35:32] <= A;
seqB_ram[3][39:36] <= A;
seqB_ram[3][43:40] <= A;
seqB_ram[3][47:44] <= A;
seqB_ram[3][51:48] <= A;
seqB_ram[3][55:52] <= A;
seqB_ram[3][59:56] <= A;
seqB_ram[3][63:60] <= A;
seqB_ram[3][67:64] <= A;
seqB_ram[3][71:68] <= A;
seqB_ram[3][75:72] <= A;
seqB_ram[3][79:76] <= A;
seqB_ram[3][83:80] <= A;
seqB_ram[3][87:84] <= A;
seqB_ram[3][91:88] <= A;
seqB_ram[3][95:92] <= A;
seqB_ram[3][99:96] <= A;
seqB_ram[3][103:100] <= A;
seqB_ram[3][107:104] <= A;
seqB_ram[3][111:108] <= A;
seqB_ram[3][115:112] <= A;
seqB_ram[3][119:116] <= A;
seqB_ram[3][123:120] <= A;
seqB_ram[3][127:124] <= A;
seqB_ram[4][3:0] <= A;
seqB_ram[4][7:4] <= A;
seqB_ram[4][11:8] <= A;
seqB_ram[4][15:12] <= A;
seqB_ram[4][19:16] <= A;
seqB_ram[4][23:20] <= A;
seqB_ram[4][27:24] <= A;
seqB_ram[4][31:28] <= A;
seqB_ram[4][35:32] <= A;
seqB_ram[4][39:36] <= A;
seqB_ram[4][43:40] <= A;
seqB_ram[4][47:44] <= A;
seqB_ram[4][51:48] <= A;
seqB_ram[4][55:52] <= A;
seqB_ram[4][59:56] <= A;
seqB_ram[4][63:60] <= A;
seqB_ram[4][67:64] <= A;
seqB_ram[4][71:68] <= A;
seqB_ram[4][75:72] <= A;
seqB_ram[4][79:76] <= A;
seqB_ram[4][83:80] <= A;
seqB_ram[4][87:84] <= A;
seqB_ram[4][91:88] <= A;
seqB_ram[4][95:92] <= A;
seqB_ram[4][99:96] <= A;
seqB_ram[4][103:100] <= A;
seqB_ram[4][107:104] <= A;
seqB_ram[4][111:108] <= A;
seqB_ram[4][115:112] <= A;
seqB_ram[4][119:116] <= A;
seqB_ram[4][123:120] <= A;
seqB_ram[4][127:124] <= A;
seqB_ram[5][3:0] <= A;
seqB_ram[5][7:4] <= A;
seqB_ram[5][11:8] <= A;
seqB_ram[5][15:12] <= A;
seqB_ram[5][19:16] <= A;
seqB_ram[5][23:20] <= A;
seqB_ram[5][27:24] <= A;
seqB_ram[5][31:28] <= A;
seqB_ram[5][35:32] <= A;
seqB_ram[5][39:36] <= A;
seqB_ram[5][43:40] <= A;
seqB_ram[5][47:44] <= A;
seqB_ram[5][51:48] <= A;
seqB_ram[5][55:52] <= A;
seqB_ram[5][59:56] <= A;
seqB_ram[5][63:60] <= A;
seqB_ram[5][67:64] <= A;
seqB_ram[5][71:68] <= A;
seqB_ram[5][75:72] <= A;
seqB_ram[5][79:76] <= A;
seqB_ram[5][83:80] <= A;
seqB_ram[5][87:84] <= A;
seqB_ram[5][91:88] <= A;
seqB_ram[5][95:92] <= A;
seqB_ram[5][99:96] <= A;
seqB_ram[5][103:100] <= A;
seqB_ram[5][107:104] <= A;
seqB_ram[5][111:108] <= A;
seqB_ram[5][115:112] <= A;
seqB_ram[5][119:116] <= A;
seqB_ram[5][123:120] <= A;
seqB_ram[5][127:124] <= A;
seqB_ram[6][3:0] <= A;
seqB_ram[6][7:4] <= A;
seqB_ram[6][11:8] <= A;
seqB_ram[6][15:12] <= A;
seqB_ram[6][19:16] <= A;
seqB_ram[6][23:20] <= A;
seqB_ram[6][27:24] <= A;
seqB_ram[6][31:28] <= A;
seqB_ram[6][35:32] <= A;
seqB_ram[6][39:36] <= A;
seqB_ram[6][43:40] <= A;
seqB_ram[6][47:44] <= A;
seqB_ram[6][51:48] <= A;
seqB_ram[6][55:52] <= A;
seqB_ram[6][59:56] <= A;
seqB_ram[6][63:60] <= A;
seqB_ram[6][67:64] <= A;
seqB_ram[6][71:68] <= A;
seqB_ram[6][75:72] <= A;
seqB_ram[6][79:76] <= A;
seqB_ram[6][83:80] <= A;
seqB_ram[6][87:84] <= A;
seqB_ram[6][91:88] <= A;
seqB_ram[6][95:92] <= A;
seqB_ram[6][99:96] <= A;
seqB_ram[6][103:100] <= A;
seqB_ram[6][107:104] <= A;
seqB_ram[6][111:108] <= A;
seqB_ram[6][115:112] <= A;
seqB_ram[6][119:116] <= A;
seqB_ram[6][123:120] <= A;
seqB_ram[6][127:124] <= A;
seqB_ram[7][3:0] <= A;
seqB_ram[7][7:4] <= A;
seqB_ram[7][11:8] <= A;
seqB_ram[7][15:12] <= A;
seqB_ram[7][19:16] <= A;
seqB_ram[7][23:20] <= A;
seqB_ram[7][27:24] <= A;
seqB_ram[7][31:28] <= A;
seqB_ram[7][35:32] <= A;
seqB_ram[7][39:36] <= A;
seqB_ram[7][43:40] <= A;
seqB_ram[7][47:44] <= A;
seqB_ram[7][51:48] <= A;
seqB_ram[7][55:52] <= A;
seqB_ram[7][59:56] <= A;
seqB_ram[7][63:60] <= A;
seqB_ram[7][67:64] <= A;
seqB_ram[7][71:68] <= A;
seqB_ram[7][75:72] <= A;
seqB_ram[7][79:76] <= A;
seqB_ram[7][83:80] <= A;
seqB_ram[7][87:84] <= A;
seqB_ram[7][91:88] <= A;
seqB_ram[7][95:92] <= A;
seqB_ram[7][99:96] <= A;
seqB_ram[7][103:100] <= A;
seqB_ram[7][107:104] <= A;
seqB_ram[7][111:108] <= A;
seqB_ram[7][115:112] <= A;
seqB_ram[7][119:116] <= A;
seqB_ram[7][123:120] <= A;
seqB_ram[7][127:124] <= A;
seqB_ram[8][3:0] <= A;
seqB_ram[8][7:4] <= A;
seqB_ram[8][11:8] <= A;
seqB_ram[8][15:12] <= A;
seqB_ram[8][19:16] <= A;
seqB_ram[8][23:20] <= A;
seqB_ram[8][27:24] <= A;
seqB_ram[8][31:28] <= A;
seqB_ram[8][35:32] <= A;
seqB_ram[8][39:36] <= A;
seqB_ram[8][43:40] <= A;
seqB_ram[8][47:44] <= A;
seqB_ram[8][51:48] <= A;
seqB_ram[8][55:52] <= A;
seqB_ram[8][59:56] <= A;
seqB_ram[8][63:60] <= A;
seqB_ram[8][67:64] <= A;
seqB_ram[8][71:68] <= A;
seqB_ram[8][75:72] <= A;
seqB_ram[8][79:76] <= A;
seqB_ram[8][83:80] <= A;
seqB_ram[8][87:84] <= A;
seqB_ram[8][91:88] <= A;
seqB_ram[8][95:92] <= A;
seqB_ram[8][99:96] <= A;
seqB_ram[8][103:100] <= A;
seqB_ram[8][107:104] <= A;
seqB_ram[8][111:108] <= A;
seqB_ram[8][115:112] <= A;
seqB_ram[8][119:116] <= A;
seqB_ram[8][123:120] <= A;
seqB_ram[8][127:124] <= A;
seqB_ram[9][3:0] <= A;
seqB_ram[9][7:4] <= A;
seqB_ram[9][11:8] <= A;
seqB_ram[9][15:12] <= A;
seqB_ram[9][19:16] <= A;
seqB_ram[9][23:20] <= A;
seqB_ram[9][27:24] <= A;
seqB_ram[9][31:28] <= A;
seqB_ram[9][35:32] <= A;
seqB_ram[9][39:36] <= A;
seqB_ram[9][43:40] <= A;
seqB_ram[9][47:44] <= A;
seqB_ram[9][51:48] <= A;
seqB_ram[9][55:52] <= A;
seqB_ram[9][59:56] <= A;
seqB_ram[9][63:60] <= A;
seqB_ram[9][67:64] <= A;
seqB_ram[9][71:68] <= A;
seqB_ram[9][75:72] <= A;
seqB_ram[9][79:76] <= A;
seqB_ram[9][83:80] <= A;
seqB_ram[9][87:84] <= A;
seqB_ram[9][91:88] <= A;
seqB_ram[9][95:92] <= A;
seqB_ram[9][99:96] <= A;
seqB_ram[9][103:100] <= A;
seqB_ram[9][107:104] <= A;
seqB_ram[9][111:108] <= A;
seqB_ram[9][115:112] <= A;
seqB_ram[9][119:116] <= A;
seqB_ram[9][123:120] <= A;
seqB_ram[9][127:124] <= A;
seqB_ram[10][3:0] <= A;
seqB_ram[10][7:4] <= A;
seqB_ram[10][11:8] <= A;
seqB_ram[10][15:12] <= A;
seqB_ram[10][19:16] <= A;
seqB_ram[10][23:20] <= A;
seqB_ram[10][27:24] <= A;
seqB_ram[10][31:28] <= A;
seqB_ram[10][35:32] <= A;
seqB_ram[10][39:36] <= A;
seqB_ram[10][43:40] <= A;
seqB_ram[10][47:44] <= A;
seqB_ram[10][51:48] <= A;
seqB_ram[10][55:52] <= A;
seqB_ram[10][59:56] <= A;
seqB_ram[10][63:60] <= A;
seqB_ram[10][67:64] <= A;
seqB_ram[10][71:68] <= A;
seqB_ram[10][75:72] <= A;
seqB_ram[10][79:76] <= A;
seqB_ram[10][83:80] <= A;
seqB_ram[10][87:84] <= A;
seqB_ram[10][91:88] <= A;
seqB_ram[10][95:92] <= A;
seqB_ram[10][99:96] <= A;
seqB_ram[10][103:100] <= A;
seqB_ram[10][107:104] <= A;
seqB_ram[10][111:108] <= A;
seqB_ram[10][115:112] <= A;
seqB_ram[10][119:116] <= A;
seqB_ram[10][123:120] <= A;
seqB_ram[10][127:124] <= A;
seqB_ram[11][3:0] <= A;
seqB_ram[11][7:4] <= A;
seqB_ram[11][11:8] <= A;
seqB_ram[11][15:12] <= A;
seqB_ram[11][19:16] <= A;
seqB_ram[11][23:20] <= A;
seqB_ram[11][27:24] <= A;
seqB_ram[11][31:28] <= A;
seqB_ram[11][35:32] <= A;
seqB_ram[11][39:36] <= A;
seqB_ram[11][43:40] <= A;
seqB_ram[11][47:44] <= A;
seqB_ram[11][51:48] <= A;
seqB_ram[11][55:52] <= A;
seqB_ram[11][59:56] <= A;
seqB_ram[11][63:60] <= A;
seqB_ram[11][67:64] <= A;
seqB_ram[11][71:68] <= A;
seqB_ram[11][75:72] <= A;
seqB_ram[11][79:76] <= A;
seqB_ram[11][83:80] <= A;
seqB_ram[11][87:84] <= A;
seqB_ram[11][91:88] <= A;
seqB_ram[11][95:92] <= A;
seqB_ram[11][99:96] <= A;
seqB_ram[11][103:100] <= A;
seqB_ram[11][107:104] <= A;
seqB_ram[11][111:108] <= A;
seqB_ram[11][115:112] <= A;
seqB_ram[11][119:116] <= A;
seqB_ram[11][123:120] <= A;
seqB_ram[11][127:124] <= A;
seqB_ram[12][3:0] <= A;
seqB_ram[12][7:4] <= A;
seqB_ram[12][11:8] <= A;
seqB_ram[12][15:12] <= A;
seqB_ram[12][19:16] <= A;
seqB_ram[12][23:20] <= A;
seqB_ram[12][27:24] <= A;
seqB_ram[12][31:28] <= A;
seqB_ram[12][35:32] <= A;
seqB_ram[12][39:36] <= A;
seqB_ram[12][43:40] <= A;
seqB_ram[12][47:44] <= A;
seqB_ram[12][51:48] <= A;
seqB_ram[12][55:52] <= A;
seqB_ram[12][59:56] <= A;
seqB_ram[12][63:60] <= A;
seqB_ram[12][67:64] <= A;
seqB_ram[12][71:68] <= A;
seqB_ram[12][75:72] <= A;
seqB_ram[12][79:76] <= A;
seqB_ram[12][83:80] <= A;
seqB_ram[12][87:84] <= A;
seqB_ram[12][91:88] <= A;
seqB_ram[12][95:92] <= A;
seqB_ram[12][99:96] <= A;
seqB_ram[12][103:100] <= A;
seqB_ram[12][107:104] <= A;
seqB_ram[12][111:108] <= A;
seqB_ram[12][115:112] <= A;
seqB_ram[12][119:116] <= A;
seqB_ram[12][123:120] <= A;
seqB_ram[12][127:124] <= A;
seqB_ram[13][3:0] <= A;
seqB_ram[13][7:4] <= A;
seqB_ram[13][11:8] <= A;
seqB_ram[13][15:12] <= A;
seqB_ram[13][19:16] <= A;
seqB_ram[13][23:20] <= A;
seqB_ram[13][27:24] <= A;
seqB_ram[13][31:28] <= A;
seqB_ram[13][35:32] <= A;
seqB_ram[13][39:36] <= A;
seqB_ram[13][43:40] <= A;
seqB_ram[13][47:44] <= A;
seqB_ram[13][51:48] <= A;
seqB_ram[13][55:52] <= A;
seqB_ram[13][59:56] <= A;
seqB_ram[13][63:60] <= A;
seqB_ram[13][67:64] <= A;
seqB_ram[13][71:68] <= A;
seqB_ram[13][75:72] <= A;
seqB_ram[13][79:76] <= A;
seqB_ram[13][83:80] <= A;
seqB_ram[13][87:84] <= A;
seqB_ram[13][91:88] <= A;
seqB_ram[13][95:92] <= A;
seqB_ram[13][99:96] <= A;
seqB_ram[13][103:100] <= A;
seqB_ram[13][107:104] <= A;
seqB_ram[13][111:108] <= A;
seqB_ram[13][115:112] <= A;
seqB_ram[13][119:116] <= A;
seqB_ram[13][123:120] <= A;
seqB_ram[13][127:124] <= A;
seqB_ram[14][3:0] <= A;
seqB_ram[14][7:4] <= A;
seqB_ram[14][11:8] <= A;
seqB_ram[14][15:12] <= A;
seqB_ram[14][19:16] <= A;
seqB_ram[14][23:20] <= A;
seqB_ram[14][27:24] <= A;
seqB_ram[14][31:28] <= A;
seqB_ram[14][35:32] <= A;
seqB_ram[14][39:36] <= A;
seqB_ram[14][43:40] <= A;
seqB_ram[14][47:44] <= A;
seqB_ram[14][51:48] <= A;
seqB_ram[14][55:52] <= A;
seqB_ram[14][59:56] <= A;
seqB_ram[14][63:60] <= A;
seqB_ram[14][67:64] <= A;
seqB_ram[14][71:68] <= A;
seqB_ram[14][75:72] <= A;
seqB_ram[14][79:76] <= A;
seqB_ram[14][83:80] <= A;
seqB_ram[14][87:84] <= A;
seqB_ram[14][91:88] <= A;
seqB_ram[14][95:92] <= A;
seqB_ram[14][99:96] <= A;
seqB_ram[14][103:100] <= A;
seqB_ram[14][107:104] <= A;
seqB_ram[14][111:108] <= A;
seqB_ram[14][115:112] <= A;
seqB_ram[14][119:116] <= A;
seqB_ram[14][123:120] <= A;
seqB_ram[14][127:124] <= A;
seqB_ram[15][3:0] <= A;
seqB_ram[15][7:4] <= A;
seqB_ram[15][11:8] <= A;
seqB_ram[15][15:12] <= A;
seqB_ram[15][19:16] <= A;
seqB_ram[15][23:20] <= A;
seqB_ram[15][27:24] <= A;
seqB_ram[15][31:28] <= A;
seqB_ram[15][35:32] <= A;
seqB_ram[15][39:36] <= A;
seqB_ram[15][43:40] <= A;
seqB_ram[15][47:44] <= A;
seqB_ram[15][51:48] <= A;
seqB_ram[15][55:52] <= A;
seqB_ram[15][59:56] <= A;
seqB_ram[15][63:60] <= A;
seqB_ram[15][67:64] <= A;
seqB_ram[15][71:68] <= A;
seqB_ram[15][75:72] <= A;
seqB_ram[15][79:76] <= A;
seqB_ram[15][83:80] <= A;
seqB_ram[15][87:84] <= A;
seqB_ram[15][91:88] <= A;
seqB_ram[15][95:92] <= A;
seqB_ram[15][99:96] <= A;
seqB_ram[15][103:100] <= A;
seqB_ram[15][107:104] <= A;
seqB_ram[15][111:108] <= A;
seqB_ram[15][115:112] <= A;
seqB_ram[15][119:116] <= A;
seqB_ram[15][123:120] <= A;
seqB_ram[15][127:124] <= A;
seqC_ram[0][3:0] <= A;
seqC_ram[0][7:4] <= A;
seqC_ram[0][11:8] <= A;
seqC_ram[0][15:12] <= A;
seqC_ram[0][19:16] <= A;
seqC_ram[0][23:20] <= A;
seqC_ram[0][27:24] <= A;
seqC_ram[0][31:28] <= A;
seqC_ram[0][35:32] <= A;
seqC_ram[0][39:36] <= A;
seqC_ram[0][43:40] <= A;
seqC_ram[0][47:44] <= A;
seqC_ram[0][51:48] <= A;
seqC_ram[0][55:52] <= A;
seqC_ram[0][59:56] <= A;
seqC_ram[0][63:60] <= A;
seqC_ram[0][67:64] <= A;
seqC_ram[0][71:68] <= A;
seqC_ram[0][75:72] <= A;
seqC_ram[0][79:76] <= A;
seqC_ram[0][83:80] <= A;
seqC_ram[0][87:84] <= A;
seqC_ram[0][91:88] <= A;
seqC_ram[0][95:92] <= A;
seqC_ram[0][99:96] <= A;
seqC_ram[0][103:100] <= A;
seqC_ram[0][107:104] <= A;
seqC_ram[0][111:108] <= A;
seqC_ram[0][115:112] <= A;
seqC_ram[0][119:116] <= A;
seqC_ram[0][123:120] <= A;
seqC_ram[0][127:124] <= A;
seqC_ram[1][3:0] <= A;
seqC_ram[1][7:4] <= A;
seqC_ram[1][11:8] <= A;
seqC_ram[1][15:12] <= A;
seqC_ram[1][19:16] <= A;
seqC_ram[1][23:20] <= A;
seqC_ram[1][27:24] <= A;
seqC_ram[1][31:28] <= A;
seqC_ram[1][35:32] <= A;
seqC_ram[1][39:36] <= A;
seqC_ram[1][43:40] <= A;
seqC_ram[1][47:44] <= A;
seqC_ram[1][51:48] <= A;
seqC_ram[1][55:52] <= A;
seqC_ram[1][59:56] <= A;
seqC_ram[1][63:60] <= A;
seqC_ram[1][67:64] <= A;
seqC_ram[1][71:68] <= A;
seqC_ram[1][75:72] <= A;
seqC_ram[1][79:76] <= A;
seqC_ram[1][83:80] <= A;
seqC_ram[1][87:84] <= A;
seqC_ram[1][91:88] <= A;
seqC_ram[1][95:92] <= A;
seqC_ram[1][99:96] <= A;
seqC_ram[1][103:100] <= A;
seqC_ram[1][107:104] <= A;
seqC_ram[1][111:108] <= A;
seqC_ram[1][115:112] <= A;
seqC_ram[1][119:116] <= A;
seqC_ram[1][123:120] <= A;
seqC_ram[1][127:124] <= A;
seqC_ram[2][3:0] <= A;
seqC_ram[2][7:4] <= A;
seqC_ram[2][11:8] <= A;
seqC_ram[2][15:12] <= A;
seqC_ram[2][19:16] <= A;
seqC_ram[2][23:20] <= A;
seqC_ram[2][27:24] <= A;
seqC_ram[2][31:28] <= A;
seqC_ram[2][35:32] <= A;
seqC_ram[2][39:36] <= A;
seqC_ram[2][43:40] <= A;
seqC_ram[2][47:44] <= A;
seqC_ram[2][51:48] <= A;
seqC_ram[2][55:52] <= A;
seqC_ram[2][59:56] <= A;
seqC_ram[2][63:60] <= A;
seqC_ram[2][67:64] <= A;
seqC_ram[2][71:68] <= A;
seqC_ram[2][75:72] <= A;
seqC_ram[2][79:76] <= A;
seqC_ram[2][83:80] <= A;
seqC_ram[2][87:84] <= A;
seqC_ram[2][91:88] <= A;
seqC_ram[2][95:92] <= A;
seqC_ram[2][99:96] <= A;
seqC_ram[2][103:100] <= A;
seqC_ram[2][107:104] <= A;
seqC_ram[2][111:108] <= A;
seqC_ram[2][115:112] <= A;
seqC_ram[2][119:116] <= A;
seqC_ram[2][123:120] <= A;
seqC_ram[2][127:124] <= A;
seqC_ram[3][3:0] <= A;
seqC_ram[3][7:4] <= A;
seqC_ram[3][11:8] <= A;
seqC_ram[3][15:12] <= A;
seqC_ram[3][19:16] <= A;
seqC_ram[3][23:20] <= A;
seqC_ram[3][27:24] <= A;
seqC_ram[3][31:28] <= A;
seqC_ram[3][35:32] <= A;
seqC_ram[3][39:36] <= A;
seqC_ram[3][43:40] <= A;
seqC_ram[3][47:44] <= A;
seqC_ram[3][51:48] <= A;
seqC_ram[3][55:52] <= A;
seqC_ram[3][59:56] <= A;
seqC_ram[3][63:60] <= A;
seqC_ram[3][67:64] <= A;
seqC_ram[3][71:68] <= A;
seqC_ram[3][75:72] <= A;
seqC_ram[3][79:76] <= A;
seqC_ram[3][83:80] <= A;
seqC_ram[3][87:84] <= A;
seqC_ram[3][91:88] <= A;
seqC_ram[3][95:92] <= A;
seqC_ram[3][99:96] <= A;
seqC_ram[3][103:100] <= A;
seqC_ram[3][107:104] <= A;
seqC_ram[3][111:108] <= A;
seqC_ram[3][115:112] <= A;
seqC_ram[3][119:116] <= A;
seqC_ram[3][123:120] <= A;
seqC_ram[3][127:124] <= A;
seqC_ram[4][3:0] <= A;
seqC_ram[4][7:4] <= A;
seqC_ram[4][11:8] <= A;
seqC_ram[4][15:12] <= A;
seqC_ram[4][19:16] <= A;
seqC_ram[4][23:20] <= A;
seqC_ram[4][27:24] <= A;
seqC_ram[4][31:28] <= A;
seqC_ram[4][35:32] <= A;
seqC_ram[4][39:36] <= A;
seqC_ram[4][43:40] <= A;
seqC_ram[4][47:44] <= A;
seqC_ram[4][51:48] <= A;
seqC_ram[4][55:52] <= A;
seqC_ram[4][59:56] <= A;
seqC_ram[4][63:60] <= A;
seqC_ram[4][67:64] <= A;
seqC_ram[4][71:68] <= A;
seqC_ram[4][75:72] <= A;
seqC_ram[4][79:76] <= A;
seqC_ram[4][83:80] <= A;
seqC_ram[4][87:84] <= A;
seqC_ram[4][91:88] <= A;
seqC_ram[4][95:92] <= A;
seqC_ram[4][99:96] <= A;
seqC_ram[4][103:100] <= A;
seqC_ram[4][107:104] <= A;
seqC_ram[4][111:108] <= A;
seqC_ram[4][115:112] <= A;
seqC_ram[4][119:116] <= A;
seqC_ram[4][123:120] <= A;
seqC_ram[4][127:124] <= A;
seqC_ram[5][3:0] <= A;
seqC_ram[5][7:4] <= A;
seqC_ram[5][11:8] <= A;
seqC_ram[5][15:12] <= A;
seqC_ram[5][19:16] <= A;
seqC_ram[5][23:20] <= A;
seqC_ram[5][27:24] <= A;
seqC_ram[5][31:28] <= A;
seqC_ram[5][35:32] <= A;
seqC_ram[5][39:36] <= A;
seqC_ram[5][43:40] <= A;
seqC_ram[5][47:44] <= A;
seqC_ram[5][51:48] <= A;
seqC_ram[5][55:52] <= A;
seqC_ram[5][59:56] <= A;
seqC_ram[5][63:60] <= A;
seqC_ram[5][67:64] <= A;
seqC_ram[5][71:68] <= A;
seqC_ram[5][75:72] <= A;
seqC_ram[5][79:76] <= A;
seqC_ram[5][83:80] <= A;
seqC_ram[5][87:84] <= A;
seqC_ram[5][91:88] <= A;
seqC_ram[5][95:92] <= A;
seqC_ram[5][99:96] <= A;
seqC_ram[5][103:100] <= A;
seqC_ram[5][107:104] <= A;
seqC_ram[5][111:108] <= A;
seqC_ram[5][115:112] <= A;
seqC_ram[5][119:116] <= A;
seqC_ram[5][123:120] <= A;
seqC_ram[5][127:124] <= A;
seqC_ram[6][3:0] <= A;
seqC_ram[6][7:4] <= A;
seqC_ram[6][11:8] <= A;
seqC_ram[6][15:12] <= A;
seqC_ram[6][19:16] <= A;
seqC_ram[6][23:20] <= A;
seqC_ram[6][27:24] <= A;
seqC_ram[6][31:28] <= A;
seqC_ram[6][35:32] <= A;
seqC_ram[6][39:36] <= A;
seqC_ram[6][43:40] <= A;
seqC_ram[6][47:44] <= A;
seqC_ram[6][51:48] <= A;
seqC_ram[6][55:52] <= A;
seqC_ram[6][59:56] <= A;
seqC_ram[6][63:60] <= A;
seqC_ram[6][67:64] <= A;
seqC_ram[6][71:68] <= A;
seqC_ram[6][75:72] <= A;
seqC_ram[6][79:76] <= A;
seqC_ram[6][83:80] <= A;
seqC_ram[6][87:84] <= A;
seqC_ram[6][91:88] <= A;
seqC_ram[6][95:92] <= A;
seqC_ram[6][99:96] <= A;
seqC_ram[6][103:100] <= A;
seqC_ram[6][107:104] <= A;
seqC_ram[6][111:108] <= A;
seqC_ram[6][115:112] <= A;
seqC_ram[6][119:116] <= A;
seqC_ram[6][123:120] <= A;
seqC_ram[6][127:124] <= A;
seqC_ram[7][3:0] <= A;
seqC_ram[7][7:4] <= A;
seqC_ram[7][11:8] <= A;
seqC_ram[7][15:12] <= A;
seqC_ram[7][19:16] <= A;
seqC_ram[7][23:20] <= A;
seqC_ram[7][27:24] <= A;
seqC_ram[7][31:28] <= A;
seqC_ram[7][35:32] <= A;
seqC_ram[7][39:36] <= A;
seqC_ram[7][43:40] <= A;
seqC_ram[7][47:44] <= A;
seqC_ram[7][51:48] <= A;
seqC_ram[7][55:52] <= A;
seqC_ram[7][59:56] <= A;
seqC_ram[7][63:60] <= A;
seqC_ram[7][67:64] <= A;
seqC_ram[7][71:68] <= A;
seqC_ram[7][75:72] <= A;
seqC_ram[7][79:76] <= A;
seqC_ram[7][83:80] <= A;
seqC_ram[7][87:84] <= A;
seqC_ram[7][91:88] <= A;
seqC_ram[7][95:92] <= A;
seqC_ram[7][99:96] <= A;
seqC_ram[7][103:100] <= A;
seqC_ram[7][107:104] <= A;
seqC_ram[7][111:108] <= A;
seqC_ram[7][115:112] <= A;
seqC_ram[7][119:116] <= A;
seqC_ram[7][123:120] <= A;
seqC_ram[7][127:124] <= A;
seqC_ram[8][3:0] <= A;
seqC_ram[8][7:4] <= A;
seqC_ram[8][11:8] <= A;
seqC_ram[8][15:12] <= A;
seqC_ram[8][19:16] <= A;
seqC_ram[8][23:20] <= A;
seqC_ram[8][27:24] <= A;
seqC_ram[8][31:28] <= A;
seqC_ram[8][35:32] <= A;
seqC_ram[8][39:36] <= A;
seqC_ram[8][43:40] <= A;
seqC_ram[8][47:44] <= A;
seqC_ram[8][51:48] <= A;
seqC_ram[8][55:52] <= A;
seqC_ram[8][59:56] <= A;
seqC_ram[8][63:60] <= A;
seqC_ram[8][67:64] <= A;
seqC_ram[8][71:68] <= A;
seqC_ram[8][75:72] <= A;
seqC_ram[8][79:76] <= A;
seqC_ram[8][83:80] <= A;
seqC_ram[8][87:84] <= A;
seqC_ram[8][91:88] <= A;
seqC_ram[8][95:92] <= A;
seqC_ram[8][99:96] <= A;
seqC_ram[8][103:100] <= A;
seqC_ram[8][107:104] <= A;
seqC_ram[8][111:108] <= A;
seqC_ram[8][115:112] <= A;
seqC_ram[8][119:116] <= A;
seqC_ram[8][123:120] <= A;
seqC_ram[8][127:124] <= A;
seqC_ram[9][3:0] <= A;
seqC_ram[9][7:4] <= A;
seqC_ram[9][11:8] <= A;
seqC_ram[9][15:12] <= A;
seqC_ram[9][19:16] <= A;
seqC_ram[9][23:20] <= A;
seqC_ram[9][27:24] <= A;
seqC_ram[9][31:28] <= A;
seqC_ram[9][35:32] <= A;
seqC_ram[9][39:36] <= A;
seqC_ram[9][43:40] <= A;
seqC_ram[9][47:44] <= A;
seqC_ram[9][51:48] <= A;
seqC_ram[9][55:52] <= A;
seqC_ram[9][59:56] <= A;
seqC_ram[9][63:60] <= A;
seqC_ram[9][67:64] <= A;
seqC_ram[9][71:68] <= A;
seqC_ram[9][75:72] <= A;
seqC_ram[9][79:76] <= A;
seqC_ram[9][83:80] <= A;
seqC_ram[9][87:84] <= A;
seqC_ram[9][91:88] <= A;
seqC_ram[9][95:92] <= A;
seqC_ram[9][99:96] <= A;
seqC_ram[9][103:100] <= A;
seqC_ram[9][107:104] <= A;
seqC_ram[9][111:108] <= A;
seqC_ram[9][115:112] <= A;
seqC_ram[9][119:116] <= A;
seqC_ram[9][123:120] <= A;
seqC_ram[9][127:124] <= A;
seqC_ram[10][3:0] <= A;
seqC_ram[10][7:4] <= A;
seqC_ram[10][11:8] <= A;
seqC_ram[10][15:12] <= A;
seqC_ram[10][19:16] <= A;
seqC_ram[10][23:20] <= A;
seqC_ram[10][27:24] <= A;
seqC_ram[10][31:28] <= A;
seqC_ram[10][35:32] <= A;
seqC_ram[10][39:36] <= A;
seqC_ram[10][43:40] <= A;
seqC_ram[10][47:44] <= A;
seqC_ram[10][51:48] <= A;
seqC_ram[10][55:52] <= A;
seqC_ram[10][59:56] <= A;
seqC_ram[10][63:60] <= A;
seqC_ram[10][67:64] <= A;
seqC_ram[10][71:68] <= A;
seqC_ram[10][75:72] <= A;
seqC_ram[10][79:76] <= A;
seqC_ram[10][83:80] <= A;
seqC_ram[10][87:84] <= A;
seqC_ram[10][91:88] <= A;
seqC_ram[10][95:92] <= A;
seqC_ram[10][99:96] <= A;
seqC_ram[10][103:100] <= A;
seqC_ram[10][107:104] <= A;
seqC_ram[10][111:108] <= A;
seqC_ram[10][115:112] <= A;
seqC_ram[10][119:116] <= A;
seqC_ram[10][123:120] <= A;
seqC_ram[10][127:124] <= A;
seqC_ram[11][3:0] <= A;
seqC_ram[11][7:4] <= A;
seqC_ram[11][11:8] <= A;
seqC_ram[11][15:12] <= A;
seqC_ram[11][19:16] <= A;
seqC_ram[11][23:20] <= A;
seqC_ram[11][27:24] <= A;
seqC_ram[11][31:28] <= A;
seqC_ram[11][35:32] <= A;
seqC_ram[11][39:36] <= A;
seqC_ram[11][43:40] <= A;
seqC_ram[11][47:44] <= A;
seqC_ram[11][51:48] <= A;
seqC_ram[11][55:52] <= A;
seqC_ram[11][59:56] <= A;
seqC_ram[11][63:60] <= A;
seqC_ram[11][67:64] <= A;
seqC_ram[11][71:68] <= A;
seqC_ram[11][75:72] <= A;
seqC_ram[11][79:76] <= A;
seqC_ram[11][83:80] <= A;
seqC_ram[11][87:84] <= A;
seqC_ram[11][91:88] <= A;
seqC_ram[11][95:92] <= A;
seqC_ram[11][99:96] <= A;
seqC_ram[11][103:100] <= A;
seqC_ram[11][107:104] <= A;
seqC_ram[11][111:108] <= A;
seqC_ram[11][115:112] <= A;
seqC_ram[11][119:116] <= A;
seqC_ram[11][123:120] <= A;
seqC_ram[11][127:124] <= A;
seqC_ram[12][3:0] <= A;
seqC_ram[12][7:4] <= A;
seqC_ram[12][11:8] <= A;
seqC_ram[12][15:12] <= A;
seqC_ram[12][19:16] <= A;
seqC_ram[12][23:20] <= A;
seqC_ram[12][27:24] <= A;
seqC_ram[12][31:28] <= A;
seqC_ram[12][35:32] <= A;
seqC_ram[12][39:36] <= A;
seqC_ram[12][43:40] <= A;
seqC_ram[12][47:44] <= A;
seqC_ram[12][51:48] <= A;
seqC_ram[12][55:52] <= A;
seqC_ram[12][59:56] <= A;
seqC_ram[12][63:60] <= A;
seqC_ram[12][67:64] <= A;
seqC_ram[12][71:68] <= A;
seqC_ram[12][75:72] <= A;
seqC_ram[12][79:76] <= A;
seqC_ram[12][83:80] <= A;
seqC_ram[12][87:84] <= A;
seqC_ram[12][91:88] <= A;
seqC_ram[12][95:92] <= A;
seqC_ram[12][99:96] <= A;
seqC_ram[12][103:100] <= A;
seqC_ram[12][107:104] <= A;
seqC_ram[12][111:108] <= A;
seqC_ram[12][115:112] <= A;
seqC_ram[12][119:116] <= A;
seqC_ram[12][123:120] <= A;
seqC_ram[12][127:124] <= A;
seqC_ram[13][3:0] <= A;
seqC_ram[13][7:4] <= A;
seqC_ram[13][11:8] <= A;
seqC_ram[13][15:12] <= A;
seqC_ram[13][19:16] <= A;
seqC_ram[13][23:20] <= A;
seqC_ram[13][27:24] <= A;
seqC_ram[13][31:28] <= A;
seqC_ram[13][35:32] <= A;
seqC_ram[13][39:36] <= A;
seqC_ram[13][43:40] <= A;
seqC_ram[13][47:44] <= A;
seqC_ram[13][51:48] <= A;
seqC_ram[13][55:52] <= A;
seqC_ram[13][59:56] <= A;
seqC_ram[13][63:60] <= A;
seqC_ram[13][67:64] <= A;
seqC_ram[13][71:68] <= A;
seqC_ram[13][75:72] <= A;
seqC_ram[13][79:76] <= A;
seqC_ram[13][83:80] <= A;
seqC_ram[13][87:84] <= A;
seqC_ram[13][91:88] <= A;
seqC_ram[13][95:92] <= A;
seqC_ram[13][99:96] <= A;
seqC_ram[13][103:100] <= A;
seqC_ram[13][107:104] <= A;
seqC_ram[13][111:108] <= A;
seqC_ram[13][115:112] <= A;
seqC_ram[13][119:116] <= A;
seqC_ram[13][123:120] <= A;
seqC_ram[13][127:124] <= A;
seqC_ram[14][3:0] <= A;
seqC_ram[14][7:4] <= A;
seqC_ram[14][11:8] <= A;
seqC_ram[14][15:12] <= A;
seqC_ram[14][19:16] <= A;
seqC_ram[14][23:20] <= A;
seqC_ram[14][27:24] <= A;
seqC_ram[14][31:28] <= A;
seqC_ram[14][35:32] <= A;
seqC_ram[14][39:36] <= A;
seqC_ram[14][43:40] <= A;
seqC_ram[14][47:44] <= A;
seqC_ram[14][51:48] <= A;
seqC_ram[14][55:52] <= A;
seqC_ram[14][59:56] <= A;
seqC_ram[14][63:60] <= A;
seqC_ram[14][67:64] <= A;
seqC_ram[14][71:68] <= A;
seqC_ram[14][75:72] <= A;
seqC_ram[14][79:76] <= A;
seqC_ram[14][83:80] <= A;
seqC_ram[14][87:84] <= A;
seqC_ram[14][91:88] <= A;
seqC_ram[14][95:92] <= A;
seqC_ram[14][99:96] <= A;
seqC_ram[14][103:100] <= A;
seqC_ram[14][107:104] <= A;
seqC_ram[14][111:108] <= A;
seqC_ram[14][115:112] <= A;
seqC_ram[14][119:116] <= A;
seqC_ram[14][123:120] <= A;
seqC_ram[14][127:124] <= A;
seqC_ram[15][3:0] <= A;
seqC_ram[15][7:4] <= A;
seqC_ram[15][11:8] <= A;
seqC_ram[15][15:12] <= A;
seqC_ram[15][19:16] <= A;
seqC_ram[15][23:20] <= A;
seqC_ram[15][27:24] <= A;
seqC_ram[15][31:28] <= A;
seqC_ram[15][35:32] <= A;
seqC_ram[15][39:36] <= A;
seqC_ram[15][43:40] <= A;
seqC_ram[15][47:44] <= A;
seqC_ram[15][51:48] <= A;
seqC_ram[15][55:52] <= A;
seqC_ram[15][59:56] <= A;
seqC_ram[15][63:60] <= A;
seqC_ram[15][67:64] <= A;
seqC_ram[15][71:68] <= A;
seqC_ram[15][75:72] <= A;
seqC_ram[15][79:76] <= A;
seqC_ram[15][83:80] <= A;
seqC_ram[15][87:84] <= A;
seqC_ram[15][91:88] <= A;
seqC_ram[15][95:92] <= A;
seqC_ram[15][99:96] <= A;
seqC_ram[15][103:100] <= A;
seqC_ram[15][107:104] <= A;
seqC_ram[15][111:108] <= A;
seqC_ram[15][115:112] <= A;
seqC_ram[15][119:116] <= A;
seqC_ram[15][123:120] <= A;
seqC_ram[15][127:124] <= A;
	end //initial
endmodule