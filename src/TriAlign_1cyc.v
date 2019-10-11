module TRIALIGN #(
    parameter A_TOTAL_LEN = 512,
    parameter B_TOTAL_LEN = 512,
    parameter C_TOTAL_LEN = 512,
    parameter PE_LEN = 8,
    parameter SCORE_BITS = 12, 
    parameter SRAM_ADDR_BITS = 9
  )(
  clk, rst, start_align, A_symbol, B_symbol, C_symbol, A_idx, B_idx, C_idx, A_addr, B_addr, C_addr, Score, finish);
input clk, rst;
input start_align;
input [3:0] A_symbol;
input [3:0] B_symbol;
input [3:0] C_symbol;
input [14:0] A_idx;
input [14:0] B_idx;
input [14:0] C_idx;
output [14:0] A_addr;
output [14:0] B_addr;
output [14:0] C_addr;
output [SCORE_BITS-1:0] Score;
output finish;

//state parameters
  localparam IDLE = 3'd0;
  localparam INITIAL = 3'd1;
  localparam COMPUTE = 3'd2;
  localparam OUT = 3'd3;
  localparam IN = 3'd4;
  localparam WAIT = 3'd5;
//sequence parameters
  localparam A_TOTAL_LENGTH = A_TOTAL_LEN;
  localparam B_TOTAL_LENGTH = B_TOTAL_LEN;
  localparam C_TOTAL_LENGTH = C_TOTAL_LEN;
  localparam B_LENGTH = PE_LEN;
  localparam C_LENGTH = PE_LEN;
  localparam wordsize = SCORE_BITS;
  localparam B_LENGTHX2 = B_LENGTH*2;
  localparam SLICE_Y_NUM = B_TOTAL_LENGTH / B_LENGTH;
  localparam SLICE_Z_NUM = C_TOTAL_LENGTH / C_LENGTH;
  localparam SLICE_Y_NUM_1 = SLICE_Y_NUM-1;
  localparam SLICE_Z_NUM_1 = SLICE_Z_NUM-1;
  localparam TOTAL_PE_NUM = B_LENGTH * C_LENGTH;
  localparam TOTAL_SRAM_Y_LENGTH = A_TOTAL_LENGTH + B_LENGTHX2;

//wire
wire [7:0] slice_y_max_idx;
wire [7:0] slice_z_max_idx;

assign slice_y_max_idx = B_idx/PE_LEN-1;
assign slice_z_max_idx = C_idx/PE_LEN-1;



//sequence array 
reg [3:0] B_i [0:B_LENGTH][0:C_LENGTH];
reg [3:0] nxt_B_i [0:B_LENGTH][0:C_LENGTH];
reg [3:0] C_i [0:B_LENGTH][0:C_LENGTH];
reg [3:0] nxt_C_i [0:B_LENGTH][0:C_LENGTH];
//for output address
reg [14:0] A_addr, nxt_A_addr;
reg [14:0] B_addr, nxt_B_addr;
reg [14:0] C_addr, nxt_C_addr;

//PE connect wire
wire signed [wordsize-1:0] M_o [0:B_LENGTH][0:C_LENGTH];
wire signed [wordsize-1:0] Ix_o [0:B_LENGTH][0:C_LENGTH];
wire signed [wordsize-1:0] Iy_o [0:B_LENGTH][0:C_LENGTH];
wire signed [wordsize-1:0] Iz_o [0:B_LENGTH][0:C_LENGTH];
wire signed [wordsize-1:0] Ixy_o [0:B_LENGTH][0:C_LENGTH];
wire signed [wordsize-1:0] Iyz_o [0:B_LENGTH][0:C_LENGTH];
wire signed [wordsize-1:0] Ixz_o [0:B_LENGTH][0:C_LENGTH];
wire EN_o [0:B_LENGTH][0:C_LENGTH];
wire [3:0] A_o[0:B_LENGTH][0:C_LENGTH];

//READ, WRITE idx counter
wire [wordsize-1:0] border_00;
reg [9:0] y_read_idx, nxt_y_read_idx;
reg [9:0] y_write_idx, nxt_y_write_idx;

//sram registers/wires
reg y_WEN [0:A_TOTAL_LENGTH+B_LENGTHX2-1];
reg nxt_y_WEN [0:A_TOTAL_LENGTH+B_LENGTHX2-1];
reg y_CEN [0:A_TOTAL_LENGTH+B_LENGTHX2-1];
reg nxt_y_CEN [0:A_TOTAL_LENGTH+B_LENGTHX2-1];
reg [SRAM_ADDR_BITS-1:0] y_A_i [0:A_TOTAL_LENGTH+B_LENGTHX2-1];
reg [SRAM_ADDR_BITS-1:0] nxt_y_A_i [0:A_TOTAL_LENGTH+B_LENGTHX2-1];
wire signed [wordsize*7-1:0] y_D_i [0:A_TOTAL_LENGTH+B_LENGTHX2-1];
wire signed [wordsize*7-1:0] y_Q_o [0:A_TOTAL_LENGTH+B_LENGTHX2-1];

reg z_WEN [0:1][0:C_LENGTH];
reg nxt_z_WEN [0:1][0:C_LENGTH];
reg z_CEN [0:1][0:C_LENGTH];
reg nxt_z_CEN [0:1][0:C_LENGTH];
reg [SRAM_ADDR_BITS-1:0] z_A_i [0:1][0:C_LENGTH];
reg [SRAM_ADDR_BITS-1:0] nxt_z_A_i [0:1][0:C_LENGTH];
wire signed [wordsize*7-1:0] z_D_wire [0:1][0:C_LENGTH];
wire signed [wordsize*7-1:0] z_Q_o [0:1][0:C_LENGTH];

//control logic registers
reg [2:0] state, nxt_state;
reg [8:0] slice_y, nxt_slice_y;
reg [8:0] slice_z, nxt_slice_z;
reg [wordsize-1:0] input_counter, nxt_input_counter;
reg [wordsize-1:0] compute_counter;
reg [wordsize-1:0] nxt_compute_counter; 
reg EN_start, nxt_EN_start;
reg signed [wordsize-1:0] score_reg, nxt_score_reg;
reg finish, nxt_finish;
wire signed [wordsize-1:0] final_max_out;
integer i, j;

//PE & Sram generation, data wire assignment
genvar ge, gi, gsy, gsz;
generate
  for (ge = 1; ge <= B_LENGTH; ge = ge + 1)begin:PE_y
    for(gi = 1; gi <= C_LENGTH; gi = gi+ 1)begin:PE_z
    	PE #(.wordsize(wordsize)) PEs(.clk(clk), .rst(rst), .A_o(A_o[ge][gi]),
       .M_o(M_o[ge][gi]), .Ix_o(Ix_o[ge][gi]), .Iy_o(Iy_o[ge][gi]), .Iz_o(Iz_o[ge][gi]), .Ixy_o(Ixy_o[ge][gi]), .Iyz_o(Iyz_o[ge][gi]), .Ixz_o(Ixz_o[ge][gi]), .EN_o(EN_o[ge][gi]), 
       .M_1_i(M_o[ge-1][gi-1]), .Ix_1_i(Ix_o[ge-1][gi-1]), .Iy_1_i(Iy_o[ge-1][gi-1]), .Iz_1_i(Iz_o[ge-1][gi-1]), .Ixy_1_i(Ixy_o[ge-1][gi-1]), .Iyz_1_i(Iyz_o[ge-1][gi-1]), .Ixz_1_i(Ixz_o[ge-1][gi-1]),
       .M_2_i(M_o[ge-1][gi]), .Ix_2_i(Ix_o[ge-1][gi]), .Iy_2_i(Iy_o[ge-1][gi]), .Iz_2_i(Iz_o[ge-1][gi]), .Ixy_2_i(Ixy_o[ge-1][gi]), .Iyz_2_i(Iyz_o[ge-1][gi]), .Ixz_2_i(Ixz_o[ge-1][gi]),
       .M_3_i(M_o[ge][gi-1]), .Ix_3_i(Ix_o[ge][gi-1]), .Iy_3_i(Iy_o[ge][gi-1]), .Iz_3_i(Iz_o[ge][gi-1]), .Ixy_3_i(Ixy_o[ge][gi-1]), .Iyz_3_i(Iyz_o[ge][gi-1]), .Ixz_3_i(Ixz_o[ge][gi-1]),
       .A_i(A_o[ge-1][gi]), .B_i(B_i[ge][gi]), .C_i(C_i[ge][gi]), .EN_i(EN_o[ge-1][gi]));
    end
  end
  
  for(ge = 0; ge <= 1; ge = ge + 1)begin:sram_z_01
    for(gsz = 1; gsz <= C_LENGTH; gsz = gsz + 1)begin:sram_z
      sram_1024x8_t13 #(.wordsize(wordsize), .ADDR_BITS(SRAM_ADDR_BITS)) sramz(.CLK(clk), .Q(z_Q_o[ge][gsz]), .D(z_D_wire[ge][gsz]), .A(z_A_i[ge][gsz]), .CEN(z_CEN[ge][gsz]), .WEN(z_WEN[ge][gsz]));
      assign z_D_wire[ge][gsz] = {M_o[B_LENGTH][gsz], Ix_o[B_LENGTH][gsz], Iy_o[B_LENGTH][gsz], Iz_o[B_LENGTH][gsz], Ixy_o[B_LENGTH][gsz], Iyz_o[B_LENGTH][gsz], Ixz_o[B_LENGTH][gsz]};    
    end
  end
  for(gsy = 0; gsy < TOTAL_SRAM_Y_LENGTH; gsy = gsy + 1)begin:sram_y
    sram_1024x8_t13 #(.wordsize(wordsize), .ADDR_BITS(SRAM_ADDR_BITS)) sramy(.CLK(clk), .Q(y_Q_o[gsy]), .D(y_D_i[gsy]), .A(y_A_i[gsy]), .CEN(y_CEN[gsy]), .WEN(y_WEN[gsy]));
  end
  for(ge = 0; ge < B_LENGTH; ge = ge + 1)begin:y_D_assign1
    for(gi = 0; gi < TOTAL_SRAM_Y_LENGTH/B_LENGTH; gi = gi + 1)begin:y_D_assign2
      assign y_D_i[gi*B_LENGTH+ge] = {M_o[ge+1][C_LENGTH], Ix_o[ge+1][C_LENGTH], Iy_o[ge+1][C_LENGTH], Iz_o[ge+1][C_LENGTH], Ixy_o[ge+1][C_LENGTH], Iyz_o[ge+1][C_LENGTH], Ixz_o[ge+1][C_LENGTH]};
    end
  end
  MAX7 #(.wordsize(wordsize)) FINAL_MAX(.G1_A(M_o[B_LENGTH][C_LENGTH]), .G1_B(Ix_o[B_LENGTH][C_LENGTH]), .G2_A(Iy_o[B_LENGTH][C_LENGTH]), .G2_B(Iz_o[B_LENGTH][C_LENGTH]), 
                                        .G3_A(Ixy_o[B_LENGTH][C_LENGTH]), .G3_B(Iyz_o[B_LENGTH][C_LENGTH]), .G4(Ixz_o[B_LENGTH][C_LENGTH]), .Max(final_max_out));
endgenerate

//Output assignement
assign Score = $signed(score_reg);

//(0, 0) corner idx logic
assign border_00 = (y_read_idx==0)? A_idx+B_LENGTHX2-1 : y_read_idx - 1;

//assign head EN register to PE input
assign EN_o[1][0] = EN_start;

//Define PE borders
generate
  for(gi = 1; gi <= B_LENGTH; gi=gi+1 )begin:z_border
    assign M_o[0][gi] = (slice_y==0)? 0 : (slice_y%2 == 1)? z_Q_o[0][gi][wordsize*7-1:wordsize*6] : z_Q_o[1][gi][wordsize*7-1:wordsize*6];
    assign Ix_o[0][gi] = (slice_y==0)? 0 : (slice_y%2 == 1)? z_Q_o[0][gi][wordsize*6-1:wordsize*5] : z_Q_o[1][gi][wordsize*6-1:wordsize*5];
    assign Iy_o[0][gi] = (slice_y==0)? 0 : (slice_y%2 == 1)? z_Q_o[0][gi][wordsize*5-1:wordsize*4] : z_Q_o[1][gi][wordsize*5-1:wordsize*4];
    assign Iz_o[0][gi] = (slice_y==0)? 0 : (slice_y%2 == 1)? z_Q_o[0][gi][wordsize*4-1:wordsize*3] : z_Q_o[1][gi][wordsize*4-1:wordsize*3];
    assign Ixy_o[0][gi] = (slice_y==0)? 0 : (slice_y%2 == 1)? z_Q_o[0][gi][wordsize*3-1:wordsize*2] : z_Q_o[1][gi][wordsize*3-1:wordsize*2];
    assign Iyz_o[0][gi] = (slice_y==0)? 0 : (slice_y%2 == 1)? z_Q_o[0][gi][wordsize*2-1:wordsize*1] : z_Q_o[1][gi][wordsize*2-1:wordsize*1];
    assign Ixz_o[0][gi] = (slice_y==0)? 0 : (slice_y%2 == 1)? z_Q_o[0][gi][wordsize-1:0] : z_Q_o[1][gi][wordsize-1:0];
    assign EN_o[0][gi] = EN_o[1][gi-1];
  end 
  for(ge = 1; ge <= B_LENGTH; ge = ge+1)begin:y_border
    assign M_o[ge][0]  = (slice_z==0)? 0 : y_Q_o[ y_read_idx+ge-1 ][wordsize*7-1:wordsize*6];
    assign Ix_o[ge][0] = (slice_z==0)? 0 : y_Q_o[ y_read_idx+ge-1 ][wordsize*6-1:wordsize*5];
    assign Iy_o[ge][0] = (slice_z==0)? 0 : y_Q_o[ y_read_idx+ge-1 ][wordsize*5-1:wordsize*4];
    assign Iz_o[ge][0] = (slice_z==0)? 0 : y_Q_o[ y_read_idx+ge-1 ][wordsize*4-1:wordsize*3];
    assign Ixy_o[ge][0] = (slice_z==0)? 0 : y_Q_o[ y_read_idx+ge-1 ][wordsize*3-1:wordsize*2];
    assign Iyz_o[ge][0] = (slice_z==0)? 0 : y_Q_o[ y_read_idx+ge-1 ][wordsize*2-1:wordsize*1];
    assign Ixz_o[ge][0] = (slice_z==0)? 0 : y_Q_o[ y_read_idx+ge-1 ][wordsize-1:0];
  end
  assign M_o[0][0]  = (slice_y==0 || slice_z==0)? 0 : y_Q_o[border_00][wordsize*7-1:wordsize*6];
  assign Ix_o[0][0]  = (slice_y==0 || slice_z==0)? 0 : y_Q_o[border_00][wordsize*6-1:wordsize*5];
  assign Iy_o[0][0]  = (slice_y==0 || slice_z==0)? 0 : y_Q_o[border_00][wordsize*5-1:wordsize*4];
  assign Iz_o[0][0]  = (slice_y==0 || slice_z==0)? 0 : y_Q_o[border_00][wordsize*4-1:wordsize*3];
  assign Ixy_o[0][0]  = (slice_y==0 || slice_z==0)? 0 : y_Q_o[border_00][wordsize*3-1:wordsize*2];
  assign Iyz_o[0][0]  = (slice_y==0 || slice_z==0)? 0 : y_Q_o[border_00][wordsize*2-1:wordsize*1];
  assign Ixz_o[0][0]  = (slice_y==0 || slice_z==0)? 0 : y_Q_o[border_00][wordsize-1:0];
endgenerate

//Define Aseq border
generate
  assign A_o[0][1] = A_symbol;
  for(ge = 2; ge <= C_LENGTH; ge=ge+1)begin:Aseq_border
    assign A_o[0][ge] = A_o[1][ge-1];
  end
endgenerate

//combinational part
always @(  *  )begin
  nxt_state = state;
  nxt_input_counter = input_counter;
  nxt_compute_counter = compute_counter;
  nxt_slice_y = slice_y;
  nxt_slice_z = slice_z;
  for(j=0; j<=B_LENGTH; j=j+1)begin
    for(i=0; i<=C_LENGTH; i=i+1)begin
      nxt_B_i[j][i] = B_i[j][i];
      nxt_C_i[j][i] = C_i[j][i];
    end
  end
  nxt_EN_start = EN_start;
  for(i = 0; i < A_TOTAL_LENGTH+B_LENGTHX2; i = i + 1)begin
    nxt_y_WEN[i] = y_WEN[i];
    nxt_y_CEN[i] = y_CEN[i];
    nxt_y_A_i[i] = y_A_i[i];
  end
  for(i = 0; i <= 1; i = i + 1)begin
    for(j = 0; j <= C_LENGTH; j = j + 1)begin
      nxt_z_WEN[i][j] = z_WEN[i][j];
      nxt_z_CEN[i][j] = z_CEN[i][j];
      nxt_z_A_i[i][j] = z_A_i[i][j];
    end
  end
  nxt_y_read_idx = y_read_idx;
  nxt_y_write_idx = y_write_idx;
  nxt_score_reg = score_reg;
  nxt_finish = finish;
  nxt_A_addr = A_addr;
  nxt_B_addr = B_addr;
  nxt_C_addr = C_addr;
  case(state)
    IDLE:begin
      if(start_align)begin
        nxt_state = INITIAL;
        nxt_input_counter = 0;
        nxt_y_A_i[0] = 0;
        nxt_z_A_i[0][0] = 0;
        nxt_z_A_i[1][0] = 0;
        nxt_A_addr = 0;
        nxt_B_addr = 0;
        nxt_C_addr = 0;    
      end
    end
    INITIAL:begin
      if(input_counter >= 1)begin
        nxt_B_i[(input_counter-1)%B_LENGTH+1][(input_counter-1)/B_LENGTH+1] = B_symbol;
        nxt_C_i[(input_counter-1)%C_LENGTH+1][(input_counter-1)/C_LENGTH+1] = C_symbol;
      end
      //set read or write mode for sRAM
      for(j = 1; j <= C_LENGTH; j = j + 1)begin
        nxt_z_WEN[0][j] = (slice_y%2 == 1)? 1 : 0;
        nxt_z_WEN[1][j] = (slice_y%2 == 1)? 0 : 1;
        nxt_z_CEN[0][j] = 0;
        nxt_z_CEN[1][j] = 0;
        nxt_z_A_i[0][j] = 0;
        nxt_z_A_i[1][j] = 0;
      end
      for(i = 0; i < B_LENGTH; i = i + 1)begin
        nxt_y_WEN[i+y_read_idx] = 1;
        nxt_y_CEN[i+y_read_idx] = 0;
        nxt_y_CEN[i+y_write_idx] = 0;
        nxt_y_WEN[i+y_write_idx] = 0;
        nxt_y_CEN[border_00] = 0;
      end

      //set initial address
      if(input_counter < TOTAL_PE_NUM)begin
        for(i = 0; i < A_TOTAL_LENGTH+B_LENGTHX2; i = i + 1)begin
          nxt_y_A_i[i] = 0;
        end
      end else begin
        nxt_y_A_i[border_00] = 1;
      end

      nxt_state = (input_counter == TOTAL_PE_NUM)? COMPUTE : INITIAL;
      nxt_input_counter = (input_counter == TOTAL_PE_NUM)? 0 : input_counter + 1;
      nxt_C_addr = (B_addr == (slice_y+1)*B_LENGTH-1)? (C_addr == (slice_z+1)*C_LENGTH-1)? slice_z*C_LENGTH : C_addr + 1 : C_addr;
      nxt_B_addr = (B_addr == (slice_y+1)*B_LENGTH-1)? slice_y*B_LENGTH : B_addr + 1;
      nxt_A_addr = (input_counter == TOTAL_PE_NUM)? 1 : 0;
      nxt_compute_counter = 0;
    end
    COMPUTE:begin
      //set PEs to enable
      if(compute_counter == 0) nxt_EN_start = 1;
     
      //set PEs to disable
      if(compute_counter == A_idx) nxt_EN_start = 0;

      //set A sequence
      if(compute_counter < A_idx-1)begin
        nxt_A_addr = A_addr + 1;
      end
      
      //set READ sRAM address
      if(compute_counter < A_idx-2)begin  //0 ~ 7
        nxt_y_A_i[border_00] = compute_counter+2;
        nxt_y_A_i[y_read_idx] = compute_counter+1;
        if(slice_y%2==1)begin
          nxt_z_A_i[0][1] = compute_counter+1;
        end else begin
          nxt_z_A_i[1][1] = compute_counter+1;
        end
      end
      else if(compute_counter >= A_idx-2 && compute_counter < A_idx-1+B_LENGTH) begin //8~10
        nxt_y_A_i[y_read_idx] = A_idx-1;
        nxt_z_A_i[0][1] = A_idx-1;
        nxt_z_A_i[1][1] = A_idx-1;
      end
      else begin
      end

      //set WRITE sRAM address
      if(compute_counter >= B_LENGTH && compute_counter < B_LENGTH+A_idx)begin//4~12
        if(slice_y%2 == 1)begin
          nxt_z_A_i[1][1] = compute_counter-C_LENGTH;
        end else begin
          nxt_z_A_i[0][1] = compute_counter-C_LENGTH;
        end
        
        nxt_y_A_i[y_write_idx] = compute_counter-B_LENGTH;
      end
      else if(compute_counter >= B_LENGTH + A_idx && compute_counter < B_LENGTHX2+A_idx-1)begin //13 14
        //disable WEN for sRAM
        nxt_z_CEN[0][1] = 1;
        nxt_z_CEN[1][1] = 1;
        nxt_y_CEN[y_write_idx] = 1;
      end
      else begin
      end
      nxt_compute_counter = (compute_counter==B_LENGTHX2+A_idx-1)? 0 : compute_counter + 1;

      if(compute_counter == (B_LENGTHX2+A_idx-1))begin
        nxt_slice_y = (slice_y == slice_y_max_idx)? 0 : slice_y + 1;
        nxt_slice_z = (slice_y == slice_y_max_idx)? (slice_z == slice_z_max_idx)? 0 : slice_z + 1 : slice_z;

        nxt_y_write_idx = (y_write_idx == A_idx + B_LENGTH)? 0 : y_write_idx + B_LENGTH;         
        if(slice_z > 0)begin
          nxt_y_read_idx = (y_read_idx >= A_idx + B_LENGTH)? 0 : y_read_idx + B_LENGTH;
        end else begin
          nxt_y_read_idx = y_read_idx;
        end

        nxt_state = (slice_y==slice_y_max_idx && slice_z==slice_z_max_idx)? OUT : INITIAL;
        nxt_A_addr = 0;
        nxt_B_addr = (slice_y==slice_y_max_idx)? 0 : (slice_y+1)*B_LENGTH;
        nxt_C_addr = (slice_y==slice_y_max_idx)? (slice_z==slice_z_max_idx)? 0 : (slice_z+1)*C_LENGTH : C_addr;
        //END, display output
        if(slice_z==slice_z_max_idx && slice_y==slice_y_max_idx)begin
        nxt_score_reg = $signed(final_max_out);
        nxt_finish = 1;
        end
      end
    end
  endcase
end

//print
always @(*)begin
  if(finish)begin
    $display("Score = ", score_reg);
    $display("Finish Computation");    
  end
end

//sequential part
//neg edge triggered registers (for sRAM)
always @(posedge clk or posedge rst)begin
  if(rst)begin
    for(i = 0; i < A_TOTAL_LENGTH+B_LENGTHX2; i = i + 1)begin
      y_WEN[i] <= 1;
      y_CEN[i] <= 1;
      y_A_i[i] <= 0;
    end
    for(i = 0; i <= 1; i = i + 1)begin
      for(j = 0; j <= C_LENGTH; j = j + 1)begin
        z_WEN[i][j] <= 1;
        z_CEN[i][j] <= 1;
        z_A_i[i][j] <= 0;
      end
    end
  end 
  else begin
    for(i = 0; i < A_TOTAL_LENGTH+B_LENGTHX2; i = i + 1)begin
      y_WEN[i] <= nxt_y_WEN[i];
    end
    for(i = 0; i <= 1; i = i + 1)begin
      for(j = 0; j <= C_LENGTH; j = j + 1)begin
        z_WEN[i][j] <= nxt_z_WEN[i][j];
      end
    end
    
    //shift functions
    for(i = 0; i < A_TOTAL_LENGTH+B_LENGTHX2; i = i + 1)begin
      if(i > y_write_idx && i < y_write_idx + B_LENGTH && i >= 1)begin
        y_A_i[i] <= y_A_i[i-1];
        y_CEN[i] <= y_CEN[i-1];
      end
      else if(i == y_read_idx)begin
        y_A_i[i] <= nxt_y_A_i[i];
        y_CEN[i] <= nxt_y_CEN[i];
      end
      else if(i == y_write_idx)begin
        y_A_i[i] <= nxt_y_A_i[i];
        y_CEN[i] <= nxt_y_CEN[i];
      end
      else if(i == border_00)begin
        y_A_i[i] <= nxt_y_A_i[i];
        y_CEN[i] <= nxt_y_CEN[i];
      end
      else if(i > y_read_idx && i < y_read_idx + B_LENGTH && i >= 1)begin
        y_A_i[i] <= y_A_i[i-1];
        y_CEN[i] <= nxt_y_CEN[i];
      end
      else begin
        y_A_i[i] <= nxt_y_A_i[i];
        y_CEN[i] <= nxt_y_CEN[i];
      end
    end
    for(i = 0; i <= 1; i = i + 1)begin
      z_A_i[i][1] <= nxt_z_A_i[i][1];
      z_CEN[i][1] <= nxt_z_CEN[i][1];
      for(j = 2; j <= C_LENGTH; j = j + 1)begin
        z_A_i[i][j] <= z_A_i[i][j-1];
        z_CEN[i][j] <= z_CEN[i][j-1];
      end
    end

  end
end

//pos edge triggered registers
always @(posedge clk or posedge rst)begin
  if(rst)begin
    state <= IDLE;
    input_counter <= 0;
    compute_counter <= 0;
    slice_y <= 0;
    slice_z <= 0;
    for(j = 0; j <= B_LENGTH; j = j + 1)begin
      for(i = 0;i <= C_LENGTH; i = i + 1)begin
        B_i[j][i] <= 2'b0;
        C_i[j][i] <= 2'b0;
      end
    end
    EN_start <= 0;
    y_read_idx <= 0;
    y_write_idx <= 0;
    score_reg <= 0;
    finish <= 0;
    A_addr <= 0;
    B_addr <= 0;
    C_addr <= 0;
  end else begin
    state <= nxt_state;
    input_counter <= nxt_input_counter;
    compute_counter <= nxt_compute_counter;
    slice_y <= nxt_slice_y;
    slice_z <= nxt_slice_z;
    for(j = 0; j <= B_LENGTH; j = j + 1)begin
      for(i = 0;i <= C_LENGTH; i = i + 1)begin
        B_i[j][i] <= nxt_B_i[j][i];
        C_i[j][i] <= nxt_C_i[j][i];
      end
    end
    EN_start <= nxt_EN_start;
    y_read_idx <= nxt_y_read_idx;
    y_write_idx <= nxt_y_write_idx;
    score_reg <= nxt_score_reg;
    finish <= nxt_finish;
    A_addr <= nxt_A_addr;
    B_addr <= nxt_B_addr;
    C_addr <= nxt_C_addr;
  end
end

endmodule

module sram_1024x8_t13#(
  parameter wordsize = 11, parameter ADDR_BITS = 7
  )(
   Q,
   CLK,
   CEN,
   WEN,
   A,
   D
  );
  localparam		 BITS = wordsize*7;
  localparam	   word_depth = 1024;
	
  output reg [BITS-1:0] Q;
  input CLK;
  input CEN;
  input WEN;
  input [ADDR_BITS-1:0] A;
  input [BITS-1:0] D;

  reg [BITS-1:0]	mem [2**ADDR_BITS-1:0];
  always @ (posedge CLK) begin
    if(WEN==0 && CEN==0)begin //write
      mem[A] <= D;  
    end
    else if(WEN==1 && CEN==0)begin //read
      Q <= mem[A];
    end
  end
endmodule
