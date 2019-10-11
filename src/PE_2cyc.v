module MAX7 #(
    parameter wordsize = 11
    )(
    input signed [wordsize-1:0] G4,
    input signed [wordsize-1:0] G2_A,
    input signed [wordsize-1:0] G2_B,
    input signed [wordsize-1:0] G3_A,
    input signed [wordsize-1:0] G1_A,
    input signed [wordsize-1:0] G1_B,
    input signed [wordsize-1:0] G3_B,
    output signed [wordsize-1:0] Max
    // output reg [2:0] act
    );
    // `include "./dat/action.dat"
    wire signed [wordsize-1:0] temp_Ix_Iy;
    wire signed [wordsize-1:0] temp_Ixy_Iyz;
    wire signed [wordsize-1:0] temp_Ixz_Iz;
    wire signed [wordsize-1:0] temp_Ixz_Iz_M;
    wire signed [wordsize-1:0] temp_Ix_Iy_Ixy_Iyz;
    wire signed [wordsize-1:0] temp_out;

    assign temp_Ix_Iy   = ($signed(G1_A) > $signed(G1_B))? G1_A : G1_B;
    assign temp_Ixy_Iyz = ($signed(G2_A) > $signed(G2_B))? G2_A : G2_B;
    assign temp_Ixz_Iz  = ($signed(G3_A) > $signed(G3_B))? G3_A : G3_B;

    assign temp_Ix_Iy_Ixy_Iyz = ($signed(temp_Ix_Iy)         > $signed(temp_Ixy_Iyz))?  temp_Ix_Iy         : temp_Ixy_Iyz;
    assign temp_Ixz_Iz_M      = ($signed(temp_Ixz_Iz)        > $signed(G4))?            temp_Ixz_Iz        : G4;
    assign temp_out           = ($signed(temp_Ix_Iy_Ixy_Iyz) > $signed(temp_Ixz_Iz_M))? temp_Ix_Iy_Ixy_Iyz : temp_Ixz_Iz_M;
    assign Max = temp_out;
    // assign act = temp_out[2:0];

endmodule

module PE #(parameter wordsize = 11)
 (clk, rst, M_o, Ix_o, Iy_o, Iz_o, Ixy_o, Iyz_o, Ixz_o, A_i, B_i, C_i, A_o, EN_i,
 M_1_i, Ix_1_i, Iy_1_i, Iz_1_i, Ixy_1_i, Iyz_1_i, Ixz_1_i,
 M_2_i, Ix_2_i, Iy_2_i, Iz_2_i, Ixy_2_i, Iyz_2_i, Ixz_2_i, 
 M_3_i, Ix_3_i, Iy_3_i, Iz_3_i, Ixy_3_i, Iyz_3_i, Ixz_3_i, EN_o, pp_counter);

input clk;
input rst; 
input EN_i;
input [3:0] A_i;
input [3:0] B_i, C_i; //B, C will store in the same PE
input [2:0] pp_counter;
input signed [wordsize-1:0] M_1_i, Ix_1_i, Iy_1_i, Iz_1_i, Ixy_1_i, Iyz_1_i, Ixz_1_i;
input signed [wordsize-1:0] M_2_i, Ix_2_i, Iy_2_i, Iz_2_i, Ixy_2_i, Iyz_2_i, Ixz_2_i;
input signed [wordsize-1:0] M_3_i, Ix_3_i, Iy_3_i, Iz_3_i, Ixy_3_i, Iyz_3_i, Ixz_3_i;
output signed [wordsize-1:0] M_o, Ix_o, Iy_o, Iz_o, Ixy_o, Iyz_o, Ixz_o;
output [3:0] A_o;
output EN_o;


// parameter wordsize = 5;
localparam MATCH = 1;
localparam MISMATCH = -1;
localparam GO = 2;
localparam GE = 1;
localparam GO2 = GO << 1;
localparam GE2 = GE << 1;
localparam GOGE = GO + GE;

reg [1:0] A, nxt_A;
reg [1:0] A_d, nxt_A_d;
reg [1:0] B, nxt_B;
reg [1:0] C, nxt_C;
reg EN, nxt_EN;
reg EN_d, nxt_EN_d;
reg init, nxt_init;

reg signed [wordsize-1:0] M, nxt_M;
reg signed [wordsize-1:0] Ix, nxt_Ix;
reg signed [wordsize-1:0] Iy, nxt_Iy;
reg signed [wordsize-1:0] Iz, nxt_Iz;
reg signed [wordsize-1:0] Ixy, nxt_Ixy;
reg signed [wordsize-1:0] Iyz, nxt_Iyz;
reg signed [wordsize-1:0] Ixz, nxt_Ixz;

reg signed [wordsize-1:0] M_1_d1, nxt_M_1_d1;
reg signed [wordsize-1:0] Ix_1_d1, nxt_Ix_1_d1;
reg signed [wordsize-1:0] Iy_1_d1, nxt_Iy_1_d1;
reg signed [wordsize-1:0] Iz_1_d1, nxt_Iz_1_d1;
reg signed [wordsize-1:0] Ixy_1_d1, nxt_Ixy_1_d1;
reg signed [wordsize-1:0] Iyz_1_d1, nxt_Iyz_1_d1;
reg signed [wordsize-1:0] Ixz_1_d1, nxt_Ixz_1_d1;
reg signed [wordsize-1:0] M_1_d2, nxt_M_1_d2;
reg signed [wordsize-1:0] Ix_1_d2, nxt_Ix_1_d2;
reg signed [wordsize-1:0] Iy_1_d2, nxt_Iy_1_d2;
reg signed [wordsize-1:0] Iz_1_d2, nxt_Iz_1_d2;
reg signed [wordsize-1:0] Ixy_1_d2, nxt_Ixy_1_d2;
reg signed [wordsize-1:0] Iyz_1_d2, nxt_Iyz_1_d2;
reg signed [wordsize-1:0] Ixz_1_d2, nxt_Ixz_1_d2;

reg signed [wordsize-1:0] M_2_d1, nxt_M_2_d1;
reg signed [wordsize-1:0] Ix_2_d1, nxt_Ix_2_d1;
reg signed [wordsize-1:0] Iy_2_d1, nxt_Iy_2_d1;
reg signed [wordsize-1:0] Iz_2_d1, nxt_Iz_2_d1;
reg signed [wordsize-1:0] Ixy_2_d1, nxt_Ixy_2_d1;
reg signed [wordsize-1:0] Iyz_2_d1, nxt_Iyz_2_d1;
reg signed [wordsize-1:0] Ixz_2_d1, nxt_Ixz_2_d1;

reg signed [wordsize-1:0] M_3_d1, nxt_M_3_d1;
reg signed [wordsize-1:0] Ix_3_d1, nxt_Ix_3_d1;
reg signed [wordsize-1:0] Iy_3_d1, nxt_Iy_3_d1;
reg signed [wordsize-1:0] Iz_3_d1, nxt_Iz_3_d1;
reg signed [wordsize-1:0] Ixy_3_d1, nxt_Ixy_3_d1;
reg signed [wordsize-1:0] Iyz_3_d1, nxt_Iyz_3_d1;
reg signed [wordsize-1:0] Ixz_3_d1, nxt_Ixz_3_d1;

// reg signed [wordsize-1:0] M_max_d, nxt_M_max_d;
// reg signed [wordsize-1:0] Ix_max_d, nxt_Ix_max_d;
// reg signed [wordsize-1:0] Iy_max_d, nxt_Iy_max_d;
// reg signed [wordsize-1:0] Iz_max_d, nxt_Iz_max_d;
// reg signed [wordsize-1:0] Ixy_max_d, nxt_Ixy_max_d;
// reg signed [wordsize-1:0] Iyz_max_d, nxt_Iyz_max_d;
// reg signed [wordsize-1:0] Ixz_max_d, nxt_Ixz_max_d;

wire signed [wordsize-1:0] M_max_o;
wire signed [wordsize-1:0] Ix_max_o;
wire signed [wordsize-1:0] Iy_max_o;
wire signed [wordsize-1:0] Iz_max_o;
wire signed [wordsize-1:0] Ixy_max_o;
wire signed [wordsize-1:0] Iyz_max_o;
wire signed [wordsize-1:0] Ixz_max_o;

wire signed [wordsize-1:0] M_max_M_i, M_max_Ix_i, M_max_Iy_i, M_max_Iz_i, M_max_Ixy_i, M_max_Iyz_i, M_max_Ixz_i;
wire signed [wordsize-1:0] Ix_max_M_i, Ix_max_Ix_i, Ix_max_Iy_i, Ix_max_Iz_i, Ix_max_Ixy_i, Ix_max_Iyz_i, Ix_max_Ixz_i;
wire signed [wordsize-1:0] Iy_max_M_i, Iy_max_Ix_i, Iy_max_Iy_i, Iy_max_Iz_i, Iy_max_Ixy_i, Iy_max_Iyz_i, Iy_max_Ixz_i;
wire signed [wordsize-1:0] Iz_max_M_i, Iz_max_Ix_i, Iz_max_Iy_i, Iz_max_Iz_i, Iz_max_Ixy_i, Iz_max_Iyz_i, Iz_max_Ixz_i;
wire signed [wordsize-1:0] Ixy_max_M_i, Ixy_max_Ix_i, Ixy_max_Iy_i, Ixy_max_Iz_i, Ixy_max_Ixy_i, Ixy_max_Iyz_i, Ixy_max_Ixz_i;
wire signed [wordsize-1:0] Iyz_max_M_i, Iyz_max_Ix_i, Iyz_max_Iy_i, Iyz_max_Iz_i, Iyz_max_Ixy_i, Iyz_max_Iyz_i, Iyz_max_Ixz_i;
wire signed [wordsize-1:0] Ixz_max_M_i, Ixz_max_Ix_i, Ixz_max_Iy_i, Ixz_max_Iz_i, Ixz_max_Ixy_i, Ixz_max_Iyz_i, Ixz_max_Ixz_i;

reg signed [wordsize-1:0] M_max_M_d, M_max_Ix_d, M_max_Iy_d, M_max_Iz_d, M_max_Ixy_d, M_max_Iyz_d, M_max_Ixz_d;
reg signed [wordsize-1:0] Ix_max_M_d, Ix_max_Ix_d, Ix_max_Iy_d, Ix_max_Iz_d, Ix_max_Ixy_d, Ix_max_Iyz_d, Ix_max_Ixz_d;
reg signed [wordsize-1:0] Iy_max_M_d, Iy_max_Ix_d, Iy_max_Iy_d, Iy_max_Iz_d, Iy_max_Ixy_d, Iy_max_Iyz_d, Iy_max_Ixz_d;
reg signed [wordsize-1:0] Iz_max_M_d, Iz_max_Ix_d, Iz_max_Iy_d, Iz_max_Iz_d, Iz_max_Ixy_d, Iz_max_Iyz_d, Iz_max_Ixz_d;
reg signed [wordsize-1:0] Ixy_max_M_d, Ixy_max_Ix_d, Ixy_max_Iy_d, Ixy_max_Iz_d, Ixy_max_Ixy_d, Ixy_max_Iyz_d, Ixy_max_Ixz_d;
reg signed [wordsize-1:0] Iyz_max_M_d, Iyz_max_Ix_d, Iyz_max_Iy_d, Iyz_max_Iz_d, Iyz_max_Ixy_d, Iyz_max_Iyz_d, Iyz_max_Ixz_d;
reg signed [wordsize-1:0] Ixz_max_M_d, Ixz_max_Ix_d, Ixz_max_Iy_d, Ixz_max_Iz_d, Ixz_max_Ixy_d, Ixz_max_Iyz_d, Ixz_max_Ixz_d;

reg signed [wordsize-1:0] nxt_M_max_M_d, nxt_M_max_Ix_d, nxt_M_max_Iy_d, nxt_M_max_Iz_d, nxt_M_max_Ixy_d, nxt_M_max_Iyz_d, nxt_M_max_Ixz_d;
reg signed [wordsize-1:0] nxt_Ix_max_M_d, nxt_Ix_max_Ix_d, nxt_Ix_max_Iy_d, nxt_Ix_max_Iz_d, nxt_Ix_max_Ixy_d, nxt_Ix_max_Iyz_d, nxt_Ix_max_Ixz_d;
reg signed [wordsize-1:0] nxt_Iy_max_M_d, nxt_Iy_max_Ix_d, nxt_Iy_max_Iy_d, nxt_Iy_max_Iz_d, nxt_Iy_max_Ixy_d, nxt_Iy_max_Iyz_d, nxt_Iy_max_Ixz_d;
reg signed [wordsize-1:0] nxt_Iz_max_M_d, nxt_Iz_max_Ix_d, nxt_Iz_max_Iy_d, nxt_Iz_max_Iz_d, nxt_Iz_max_Ixy_d, nxt_Iz_max_Iyz_d, nxt_Iz_max_Ixz_d;
reg signed [wordsize-1:0] nxt_Ixy_max_M_d, nxt_Ixy_max_Ix_d, nxt_Ixy_max_Iy_d, nxt_Ixy_max_Iz_d, nxt_Ixy_max_Ixy_d, nxt_Ixy_max_Iyz_d, nxt_Ixy_max_Ixz_d;
reg signed [wordsize-1:0] nxt_Iyz_max_M_d, nxt_Iyz_max_Ix_d, nxt_Iyz_max_Iy_d, nxt_Iyz_max_Iz_d, nxt_Iyz_max_Ixy_d, nxt_Iyz_max_Iyz_d, nxt_Iyz_max_Ixz_d;
reg signed [wordsize-1:0] nxt_Ixz_max_M_d, nxt_Ixz_max_Ix_d, nxt_Ixz_max_Iy_d, nxt_Ixz_max_Iz_d, nxt_Ixz_max_Ixy_d, nxt_Ixz_max_Iyz_d, nxt_Ixz_max_Ixz_d;


wire signed [wordsize-1:0] temp_AB, temp_BC, temp_AC, temp_ABC;

// MAX7 #(.wordsize(wordsize))M_max(.G4(M_max_d), .G1_A(Ix_max_d), .G1_B(Iy_max_d), .G3_A(Iz_max_d), .G2_A(Ixy_max_d), .G2_B(Iyz_max_d), .G3_B(Ixz_max_d), .Max(M_max_o));
// MAX7 #(.wordsize(wordsize))M_max(.G4(M_max_M_i), .G1_A(Ix_max_o), .G1_B(Iy_max_o), .G3_A(Iz_max_o), .G2_A(Ixy_max_o), .G2_B(Iyz_max_o), .G3_B(Ixz_max_o), .Max(M_max_o));
// MAX7 #(.wordsize(wordsize))M_max(.G4(M_max_M_i), .G1_A(M_max_Ix_i), .G1_B(M_max_Iy_i), .G3_A(M_max_Iz_i), .G2_A(M_max_Ixy_i), .G2_B(M_max_Iyz_i), .G3_B(M_max_Ixz_i), .Max(M_max_o));
// MAX7 #(.wordsize(wordsize))Ix_max(.G4(Ix_max_Ix_i), .G1_A(Ix_max_M_i), .G1_B(Ix_max_Iyz_i), .G3_A(Ix_max_Iy_i), .G2_A(Ix_max_Ixy_i), .G2_B(Ix_max_Ixz_i), .G3_B(Ix_max_Iz_i), .Max(Ix_max_o));
// MAX7 #(.wordsize(wordsize))Iy_max(.G4(Iy_max_Iy_i), .G1_A(Iy_max_M_i), .G1_B(Iy_max_Ixz_i), .G3_A(Iy_max_Ix_i), .G2_A(Iy_max_Ixy_i), .G2_B(Iy_max_Iyz_i), .G3_B(Iy_max_Iz_i), .Max(Iy_max_o));
// MAX7 #(.wordsize(wordsize))Iz_max(.G4(Iz_max_Iz_i), .G1_A(Iz_max_M_i), .G1_B(Iz_max_Ixy_i), .G3_A(Iz_max_Ix_i), .G2_A(Iz_max_Ixz_i), .G2_B(Iz_max_Iyz_i), .G3_B(Iz_max_Iy_i), .Max(Iz_max_o));
// MAX7 #(.wordsize(wordsize))Ixy_max(.G4(Ixy_max_Iy_i), .G1_A(Ixy_max_M_i), .G1_B(Ixy_max_Ixz_i), .G3_A(Ixy_max_Iyz_i), .G2_A(Ixy_max_Ixy_i), .G2_B(Ixy_max_Ix_i), .G3_B(Ixy_max_Iz_i), .Max(Ixy_max_o));
// MAX7 #(.wordsize(wordsize))Iyz_max(.G4(Iyz_max_Iz_i), .G1_A(Iyz_max_M_i), .G1_B(Iyz_max_Ixy_i), .G3_A(Iyz_max_Iyz_i), .G2_A(Iyz_max_Ixz_i), .G2_B(Iyz_max_Ix_i), .G3_B(Iyz_max_Iy_i), .Max(Iyz_max_o));
// MAX7 #(.wordsize(wordsize))Ixz_max(.G4(Ixz_max_Iz_i), .G1_A(Ixz_max_M_i), .G1_B(Ixz_max_Ixy_i), .G3_A(Ixz_max_Iyz_i), .G2_A(Ixz_max_Ixz_i), .G2_B(Ixz_max_Ix_i), .G3_B(Ixz_max_Iy_i), .Max(Ixz_max_o));
MAX7 #(.wordsize(wordsize))M_max(.G4(M_max_M_d), .G1_A(M_max_Ix_d), .G1_B(M_max_Iy_d), .G3_A(M_max_Iz_d), .G2_A(M_max_Ixy_d), .G2_B(M_max_Iyz_d), .G3_B(M_max_Ixz_d), .Max(M_max_o));
MAX7 #(.wordsize(wordsize))Ix_max(.G4(Ix_max_Ix_d), .G1_A(Ix_max_M_d), .G1_B(Ix_max_Iyz_d), .G3_A(Ix_max_Iy_d), .G2_A(Ix_max_Ixy_d), .G2_B(Ix_max_Ixz_d), .G3_B(Ix_max_Iz_d), .Max(Ix_max_o));
MAX7 #(.wordsize(wordsize))Iy_max(.G4(Iy_max_Iy_d), .G1_A(Iy_max_M_d), .G1_B(Iy_max_Ixz_d), .G3_A(Iy_max_Ix_d), .G2_A(Iy_max_Ixy_d), .G2_B(Iy_max_Iyz_d), .G3_B(Iy_max_Iz_d), .Max(Iy_max_o));
MAX7 #(.wordsize(wordsize))Iz_max(.G4(Iz_max_Iz_d), .G1_A(Iz_max_M_d), .G1_B(Iz_max_Ixy_d), .G3_A(Iz_max_Ix_d), .G2_A(Iz_max_Ixz_d), .G2_B(Iz_max_Iyz_d), .G3_B(Iz_max_Iy_d), .Max(Iz_max_o));
MAX7 #(.wordsize(wordsize))Ixy_max(.G4(Ixy_max_Iy_d), .G1_A(Ixy_max_M_d), .G1_B(Ixy_max_Ixz_d), .G3_A(Ixy_max_Iyz_d), .G2_A(Ixy_max_Ixy_d), .G2_B(Ixy_max_Ix_d), .G3_B(Ixy_max_Iz_d), .Max(Ixy_max_o));
MAX7 #(.wordsize(wordsize))Iyz_max(.G4(Iyz_max_Iz_d), .G1_A(Iyz_max_M_d), .G1_B(Iyz_max_Ixy_d), .G3_A(Iyz_max_Iyz_d), .G2_A(Iyz_max_Ixz_d), .G2_B(Iyz_max_Ix_d), .G3_B(Iyz_max_Iy_d), .Max(Iyz_max_o));
MAX7 #(.wordsize(wordsize))Ixz_max(.G4(Ixz_max_Iz_d), .G1_A(Ixz_max_M_d), .G1_B(Ixz_max_Ixy_d), .G3_A(Ixz_max_Iyz_d), .G2_A(Ixz_max_Ixz_d), .G2_B(Ixz_max_Ix_d), .G3_B(Ixz_max_Iy_d), .Max(Ixz_max_o));

//PE output assignment
assign M_o = (EN==1)?  M : 5'bz;
assign Ix_o = Ix;
assign Iy_o = Iy;
assign Iz_o = Iz;
assign Ixy_o = Ixy;
assign Ixz_o = Ixz;
assign Iyz_o = Iyz;
assign A_o = A;
assign EN_o = EN;

//Max input assignment
  assign temp_AB = (A==B)? MATCH : MISMATCH;
  assign temp_BC = (B==C)? MATCH : MISMATCH;
  assign temp_AC = (A==C)? MATCH : MISMATCH;
  assign temp_ABC = (A==B)? (B==C)? (A==C)? MATCH*3 : (MATCH<<1+MISMATCH) : (MATCH+MISMATCH<<1) : MISMATCH*3;
  //M max
  assign M_max_M_i   = (EN_i==1&&EN==0)? $signed(0+temp_ABC) : $signed(M_1_d2+temp_ABC);
  assign M_max_Ix_i  = (EN_i==1&&EN==0)? $signed(0+temp_ABC) : $signed(Ix_1_d2+temp_ABC);
  assign M_max_Iy_i  = (EN_i==1&&EN==0)? $signed(0+temp_ABC) : $signed(Iy_1_d2+temp_ABC);
  assign M_max_Iz_i  = (EN_i==1&&EN==0)? $signed(0+temp_ABC) : $signed(Iz_1_d2+temp_ABC);
  assign M_max_Ixy_i = (EN_i==1&&EN==0)? $signed(0+temp_ABC) : $signed(Ixy_1_d2+temp_ABC);
  assign M_max_Iyz_i = (EN_i==1&&EN==0)? $signed(0+temp_ABC) : $signed(Iyz_1_d2+temp_ABC);
  assign M_max_Ixz_i = (EN_i==1&&EN==0)? $signed(0+temp_ABC) : $signed(Ixz_1_d2+temp_ABC);
  //Ix max
  assign Ix_max_M_i   = (EN_i==1&&EN==0)? $signed(0-GO2) : $signed(M-GO2);
  assign Ix_max_Ix_i  = (EN_i==1&&EN==0)? $signed(0-GE2) : $signed(Ix-GE2);
  assign Ix_max_Iy_i  = (EN_i==1&&EN==0)? $signed(0-GOGE) : $signed(Iy-GOGE);
  assign Ix_max_Iz_i  = (EN_i==1&&EN==0)? $signed(0-GOGE) : $signed(Iz-GOGE);
  assign Ix_max_Ixy_i = (EN_i==1&&EN==0)? $signed(0-GOGE) : $signed(Ixy-GOGE);
  assign Ix_max_Iyz_i = (EN_i==1&&EN==0)? $signed(0-GO2) : $signed(Iyz-GO2);
  assign Ix_max_Ixz_i = (EN_i==1&&EN==0)? $signed(0-GOGE) : $signed(Ixz-GOGE);
  //Iy max
  assign Iy_max_M_i   = $signed(M_2_i-GO2);
  assign Iy_max_Ix_i  = $signed(Ix_2_i-GOGE);
  assign Iy_max_Iy_i  = $signed(Iy_2_i-GE2);
  assign Iy_max_Iz_i  = $signed(Iz_2_i-GOGE);
  assign Iy_max_Ixy_i = $signed(Ixy_2_i-GOGE);
  assign Iy_max_Iyz_i = $signed(Iyz_2_i-GOGE);
  assign Iy_max_Ixz_i = $signed(Ixz_2_i-GO2);
  //Iz max
  assign Iz_max_M_i   = $signed(M_3_i-GO2);
  assign Iz_max_Ix_i  = $signed(Ix_3_i-GOGE);
  assign Iz_max_Iy_i  = $signed(Iy_3_i-GOGE);
  assign Iz_max_Iz_i  = $signed(Iz_3_i-GE2);
  assign Iz_max_Ixy_i = $signed(Ixy_3_i-GO2);
  assign Iz_max_Iyz_i = $signed(Iyz_3_i-GOGE);
  assign Iz_max_Ixz_i = $signed(Ixz_3_i-GOGE);
  //Ixy max
  assign Ixy_max_M_i   = (EN_i==1&&EN==0)? $signed(0-GO+temp_AB) : $signed(M_2_d1-GO+temp_AB);
  assign Ixy_max_Ix_i  = (EN_i==1&&EN==0)? $signed(0-GE+temp_AB) : $signed(Ix_2_d1-GE+temp_AB);
  assign Ixy_max_Iy_i  = (EN_i==1&&EN==0)? $signed(0-GE+temp_AB) : $signed(Iy_2_d1-GE+ temp_AB);
  assign Ixy_max_Iz_i  = (EN_i==1&&EN==0)? $signed(0-GO+temp_AB) : $signed(Iz_2_d1-GO+temp_AB);
  assign Ixy_max_Ixy_i = (EN_i==1&&EN==0)? $signed(0-GE+temp_AB) : $signed(Ixy_2_d1-GE+temp_AB);
  assign Ixy_max_Iyz_i = (EN_i==1&&EN==0)? $signed(0-GO+temp_AB) : $signed(Iyz_2_d1-GO+temp_AB);
  assign Ixy_max_Ixz_i = (EN_i==1&&EN==0)? $signed(0-GO+temp_AB) : $signed(Ixz_2_d1-GO+temp_AB);
  //Iyz max
  assign Iyz_max_M_i   = $signed(M_1_d1-GO+temp_BC);
  assign Iyz_max_Ix_i  = $signed(Ix_1_d1-GO+temp_BC);
  assign Iyz_max_Iy_i  = $signed(Iy_1_d1-GE+temp_BC);
  assign Iyz_max_Iz_i  = $signed(Iz_1_d1-GE+temp_BC);
  assign Iyz_max_Ixy_i = $signed(Ixy_1_d1-GO+temp_BC);
  assign Iyz_max_Iyz_i = $signed(Iyz_1_d1-GE+temp_BC);
  assign Iyz_max_Ixz_i = $signed(Ixz_1_d1-GO+temp_BC);
  //Ixz max
  assign Ixz_max_M_i   = (EN_i==1&&EN==0)? $signed(0-GO+temp_AC) : $signed(M_3_d1-GO+temp_AC);
  assign Ixz_max_Ix_i  = (EN_i==1&&EN==0)? $signed(0-GE+temp_AC) : $signed(Ix_3_d1-GE+temp_AC);
  assign Ixz_max_Iy_i  = (EN_i==1&&EN==0)? $signed(0-GO+temp_AC) : $signed(Iy_3_d1-GO+temp_AC);
  assign Ixz_max_Iz_i  = (EN_i==1&&EN==0)? $signed(0-GE+temp_AC) : $signed(Iz_3_d1-GE+temp_AC);
  assign Ixz_max_Ixy_i = (EN_i==1&&EN==0)? $signed(0-GO+temp_AC) : $signed(Ixy_3_d1-GO+temp_AC);
  assign Ixz_max_Iyz_i = (EN_i==1&&EN==0)? $signed(0-GO+temp_AC) : $signed(Iyz_3_d1-GO+temp_AC);
  assign Ixz_max_Ixz_i = (EN_i==1&&EN==0)? $signed(0-GE+temp_AC) : $signed(Ixz_3_d1-GE+temp_AC);
//end Max input


always @( * )begin
  nxt_init = init;
  if(EN)begin
    nxt_init = 1;
  end
end

//Max input delay assignment
always @( * )begin
  nxt_M_max_M_d = M_max_M_i;
  nxt_M_max_Ix_d = M_max_Ix_i;
  nxt_M_max_Iy_d = M_max_Iy_i;
  nxt_M_max_Iz_d = M_max_Iz_i;
  nxt_M_max_Ixy_d = M_max_Ixy_i;
  nxt_M_max_Iyz_d = M_max_Iyz_i;
  nxt_M_max_Ixz_d = M_max_Ixz_i;

  nxt_Ix_max_M_d = Ix_max_M_i;
  nxt_Ix_max_Ix_d = Ix_max_Ix_i;
  nxt_Ix_max_Iy_d = Ix_max_Iy_i;
  nxt_Ix_max_Iz_d = Ix_max_Iz_i;
  nxt_Ix_max_Ixy_d = Ix_max_Ixy_i;
  nxt_Ix_max_Iyz_d = Ix_max_Iyz_i;
  nxt_Ix_max_Ixz_d = Ix_max_Ixz_i;

  nxt_Iy_max_M_d = Iy_max_M_i;
  nxt_Iy_max_Ix_d = Iy_max_Ix_i;
  nxt_Iy_max_Iy_d = Iy_max_Iy_i;
  nxt_Iy_max_Iz_d = Iy_max_Iz_i;
  nxt_Iy_max_Ixy_d = Iy_max_Ixy_i;
  nxt_Iy_max_Iyz_d = Iy_max_Iyz_i;
  nxt_Iy_max_Ixz_d = Iy_max_Ixz_i;

  nxt_Iz_max_M_d = Iz_max_M_i;
  nxt_Iz_max_Ix_d = Iz_max_Ix_i;
  nxt_Iz_max_Iy_d = Iz_max_Iy_i;
  nxt_Iz_max_Iz_d = Iz_max_Iz_i;
  nxt_Iz_max_Ixy_d = Iz_max_Ixy_i;
  nxt_Iz_max_Iyz_d = Iz_max_Iyz_i;
  nxt_Iz_max_Ixz_d = Iz_max_Ixz_i;

  nxt_Ixy_max_M_d = Ixy_max_M_i;
  nxt_Ixy_max_Ix_d = Ixy_max_Ix_i;
  nxt_Ixy_max_Iy_d = Ixy_max_Iy_i;
  nxt_Ixy_max_Iz_d = Ixy_max_Iz_i;
  nxt_Ixy_max_Ixy_d = Ixy_max_Ixy_i;
  nxt_Ixy_max_Iyz_d = Ixy_max_Iyz_i;
  nxt_Ixy_max_Ixz_d = Ixy_max_Ixz_i;

  nxt_Iyz_max_M_d = Iyz_max_M_i;
  nxt_Iyz_max_Ix_d = Iyz_max_Ix_i;
  nxt_Iyz_max_Iy_d = Iyz_max_Iy_i;
  nxt_Iyz_max_Iz_d = Iyz_max_Iz_i;
  nxt_Iyz_max_Ixy_d = Iyz_max_Ixy_i;
  nxt_Iyz_max_Iyz_d = Iyz_max_Iyz_i;
  nxt_Iyz_max_Ixz_d = Iyz_max_Ixz_i;

  nxt_Ixz_max_M_d = Ixz_max_M_i;
  nxt_Ixz_max_Ix_d = Ixz_max_Ix_i;
  nxt_Ixz_max_Iy_d = Ixz_max_Iy_i;
  nxt_Ixz_max_Iz_d = Ixz_max_Iz_i;
  nxt_Ixz_max_Ixy_d = Ixz_max_Ixy_i;
  nxt_Ixz_max_Iyz_d = Ixz_max_Iyz_i;
  nxt_Ixz_max_Ixz_d = Ixz_max_Ixz_i;
end


//Max output assignment
always @( * )begin
  nxt_M = M_max_o;
  nxt_Ix = Ix_max_o;
  nxt_Iy = Iy_max_o;
  nxt_Iz = Iz_max_o;
  nxt_Ixy = Ixy_max_o;
  nxt_Iyz = Iyz_max_o;
  nxt_Ixz = Ixz_max_o;
  // nxt_M = M_max_d;
  // nxt_Ix = Ix_max_d;
  // nxt_Iy = Iy_max_d;
  // nxt_Iz = Iz_max_d;
  // nxt_Ixy = Ixy_max_d;
  // nxt_Iyz = Iyz_max_d;
  // nxt_Ixz = Ixz_max_d;

end


//Delay register assignment
always @( * )begin
  nxt_M_1_d2 = M_1_d1;
  nxt_Ix_1_d2 = Ix_1_d1;
  nxt_Iy_1_d2 = Iy_1_d1;
  nxt_Iz_1_d2 = Iz_1_d1;
  nxt_Ixy_1_d2 = Ixy_1_d1;
  nxt_Iyz_1_d2 = Iyz_1_d1;
  nxt_Ixz_1_d2 = Ixz_1_d1;

  // nxt_M_max_d = M_max_o;
  // nxt_Ix_max_d = Ix_max_o;
  // nxt_Iy_max_d = Iy_max_o;
  // nxt_Iz_max_d = Iz_max_o;
  // nxt_Ixy_max_d = Ixy_max_o;
  // nxt_Iyz_max_d = Iyz_max_o;
  // nxt_Ixz_max_d = Ixz_max_o;
end

//PE input assignment
always @( * )begin
  nxt_M_1_d1 = M_1_i;
  nxt_Ix_1_d1 = Ix_1_i;
  nxt_Iy_1_d1 = Iy_1_i;
  nxt_Iz_1_d1 = Iz_1_i;
  nxt_Ixy_1_d1 = Ixy_1_i;
  nxt_Iyz_1_d1 = Iyz_1_i;
  nxt_Ixz_1_d1 = Ixz_1_i;

  nxt_M_2_d1 = M_2_i;
  nxt_Ix_2_d1 = Ix_2_i;
  nxt_Iy_2_d1 = Iy_2_i;
  nxt_Iz_2_d1 = Iz_2_i;
  nxt_Ixy_2_d1 = Ixy_2_i;
  nxt_Iyz_2_d1 = Iyz_2_i;
  nxt_Ixz_2_d1 = Ixz_2_i;

  nxt_M_3_d1 = M_3_i;
  nxt_Ix_3_d1 = Ix_3_i;
  nxt_Iy_3_d1 = Iy_3_i;
  nxt_Iz_3_d1 = Iz_3_i;
  nxt_Ixy_3_d1 = Ixy_3_i;
  nxt_Iyz_3_d1 = Iyz_3_i;
  nxt_Ixz_3_d1 = Ixz_3_i;

  nxt_A = A_d;
  nxt_A_d = A_i;
  // nxt_A = A_i;
  nxt_B = B_i;
  nxt_C = C_i;
  nxt_EN = EN_d;
  nxt_EN_d = EN_i;
  // nxt_EN = EN_i;
end


//Sequential part
always @(posedge clk or posedge rst)begin
  if(rst)begin
    M_max_M_d <= 0;
    M_max_Ix_d <= 0;
    M_max_Iy_d <= 0;
    M_max_Iz_d <= 0;
    M_max_Ixy_d <= 0;
    M_max_Iyz_d <= 0;
    M_max_Ixz_d <= 0;
    Ix_max_M_d <= 0;
    Ix_max_Ix_d <= 0;
    Ix_max_Iy_d <= 0;
    Ix_max_Iz_d <= 0;
    Ix_max_Ixy_d <= 0;
    Ix_max_Iyz_d <= 0;
    Ix_max_Ixz_d <= 0;
    Iy_max_M_d <= 0;
    Iy_max_Ix_d <= 0;
    Iy_max_Iy_d <= 0;
    Iy_max_Iz_d <= 0;
    Iy_max_Ixy_d <= 0;
    Iy_max_Iyz_d <= 0;
    Iy_max_Ixz_d <= 0;
    Iz_max_M_d <= 0;
    Iz_max_Ix_d <= 0;
    Iz_max_Iy_d <= 0;
    Iz_max_Iz_d <= 0;
    Iz_max_Ixy_d <= 0;
    Iz_max_Iyz_d <= 0;
    Iz_max_Ixz_d <= 0;
    Ixy_max_M_d <= 0;
    Ixy_max_Ix_d <= 0;
    Ixy_max_Iy_d <= 0;
    Ixy_max_Iz_d <= 0;
    Ixy_max_Ixy_d <= 0;
    Ixy_max_Iyz_d <= 0;
    Ixy_max_Ixz_d <= 0;
    Iyz_max_M_d <= 0;
    Iyz_max_Ix_d <= 0;
    Iyz_max_Iy_d <= 0;
    Iyz_max_Iz_d <= 0;
    Iyz_max_Ixy_d <= 0;
    Iyz_max_Iyz_d <= 0;
    Iyz_max_Ixz_d <= 0;
    Ixz_max_M_d <= 0;
    Ixz_max_Ix_d <= 0;
    Ixz_max_Iy_d <= 0;
    Ixz_max_Iz_d <= 0;
    Ixz_max_Ixy_d <= 0;
    Ixz_max_Iyz_d <= 0;
    Ixz_max_Ixz_d <= 0;
  end else begin
    M_max_M_d <= nxt_M_max_M_d;
    M_max_Ix_d <= nxt_M_max_Ix_d;
    M_max_Iy_d <= nxt_M_max_Iy_d;
    M_max_Iz_d <= nxt_M_max_Iz_d;
    M_max_Ixy_d <= nxt_M_max_Ixy_d;
    M_max_Iyz_d <= nxt_M_max_Iyz_d;
    M_max_Ixz_d <= nxt_M_max_Ixz_d;
    Ix_max_M_d <= nxt_Ix_max_M_d;
    Ix_max_Ix_d <= nxt_Ix_max_Ix_d;
    Ix_max_Iy_d <= nxt_Ix_max_Iy_d;
    Ix_max_Iz_d <= nxt_Ix_max_Iz_d;
    Ix_max_Ixy_d <= nxt_Ix_max_Ixy_d;
    Ix_max_Iyz_d <= nxt_Ix_max_Iyz_d;
    Ix_max_Ixz_d <= nxt_Ix_max_Ixz_d;
    Iy_max_M_d <= nxt_Iy_max_M_d;
    Iy_max_Ix_d <= nxt_Iy_max_Ix_d;
    Iy_max_Iy_d <= nxt_Iy_max_Iy_d;
    Iy_max_Iz_d <= nxt_Iy_max_Iz_d;
    Iy_max_Ixy_d <= nxt_Iy_max_Ixy_d;
    Iy_max_Iyz_d <= nxt_Iy_max_Iyz_d;
    Iy_max_Ixz_d <= nxt_Iy_max_Ixz_d;
    Iz_max_M_d <= nxt_Iz_max_M_d;
    Iz_max_Ix_d <= nxt_Iz_max_Ix_d;
    Iz_max_Iy_d <= nxt_Iz_max_Iy_d;
    Iz_max_Iz_d <= nxt_Iz_max_Iz_d;
    Iz_max_Ixy_d <= nxt_Iz_max_Ixy_d;
    Iz_max_Iyz_d <= nxt_Iz_max_Iyz_d;
    Iz_max_Ixz_d <= nxt_Iz_max_Ixz_d;
    Ixy_max_M_d <= nxt_Ixy_max_M_d;
    Ixy_max_Ix_d <= nxt_Ixy_max_Ix_d;
    Ixy_max_Iy_d <= nxt_Ixy_max_Iy_d;
    Ixy_max_Iz_d <= nxt_Ixy_max_Iz_d;
    Ixy_max_Ixy_d <= nxt_Ixy_max_Ixy_d;
    Ixy_max_Iyz_d <= nxt_Ixy_max_Iyz_d;
    Ixy_max_Ixz_d <= nxt_Ixy_max_Ixz_d;
    Iyz_max_M_d <= nxt_Iyz_max_M_d;
    Iyz_max_Ix_d <= nxt_Iyz_max_Ix_d;
    Iyz_max_Iy_d <= nxt_Iyz_max_Iy_d;
    Iyz_max_Iz_d <= nxt_Iyz_max_Iz_d;
    Iyz_max_Ixy_d <= nxt_Iyz_max_Ixy_d;
    Iyz_max_Iyz_d <= nxt_Iyz_max_Iyz_d;
    Iyz_max_Ixz_d <= nxt_Iyz_max_Ixz_d;
    Ixz_max_M_d <= nxt_Ixz_max_M_d;
    Ixz_max_Ix_d <= nxt_Ixz_max_Ix_d;
    Ixz_max_Iy_d <= nxt_Ixz_max_Iy_d;
    Ixz_max_Iz_d <= nxt_Ixz_max_Iz_d;
    Ixz_max_Ixy_d <= nxt_Ixz_max_Ixy_d;
    Ixz_max_Iyz_d <= nxt_Ixz_max_Iyz_d;
    Ixz_max_Ixz_d <= nxt_Ixz_max_Ixz_d;
  end
end

always @(posedge clk or posedge rst)begin
  if(rst)begin
    M <= 0;
    Ix <= 0;
    Iy <= 0;
    Iz <= 0;
    Ixy <= 0;
    Iyz <= 0;
    Ixz <= 0;
    // M_max_d <= 0;
    // Ix_max_d <= 0;
    // Iy_max_d <= 0;
    // Iz_max_d <= 0;
    // Ixy_max_d <= 0;
    // Iyz_max_d <= 0;
    // Ixz_max_d <= 0;
    A <= 2'bz;
    A_d <= 2'bz;
    B <= 2'bz;
    C <= 2'bz;
    EN <= 0;
    init <= 0;
  end else begin
    M <= nxt_M;
    Ix <= nxt_Ix;
    Iy <= nxt_Iy;
    Iz <= nxt_Iz;
    Ixy <= nxt_Ixy;
    Iyz <= nxt_Iyz;
    Ixz <= nxt_Ixz;
    // M_max_d <= nxt_M_max_d;
    // Ix_max_d <= nxt_Ix_max_d;
    // Iy_max_d <= nxt_Iy_max_d;
    // Iz_max_d <= nxt_Iz_max_d;
    // Ixy_max_d <= nxt_Ixy_max_d;
    // Iyz_max_d <= nxt_Iyz_max_d;
    // Ixz_max_d <= nxt_Ixz_max_d;
    A <= nxt_A;
    A_d <= nxt_A_d;
    B <= nxt_B;
    C <= nxt_C;
    EN <= nxt_EN;
    init <= nxt_init;
  end
end

//Enable delay register
always @(posedge clk or posedge rst)begin
  if(rst)begin
    EN_d <= 0;
  end else begin
    EN_d <= nxt_EN_d;
  end
end

//Delay registers Sequential part
always @(posedge clk or posedge rst)begin
  if(rst)begin
    M_1_d1 <= 0;
    Ixy_1_d1 <= 0;
    Iyz_1_d1 <= 0;
    Ixz_1_d1 <= 0;
    Ix_1_d1 <= 0;
    Iy_1_d1 <= 0;
    Iz_1_d1 <= 0;
    M_1_d2 <= 0;
    Ixy_1_d2 <= 0;
    Iyz_1_d2 <= 0;
    Ixz_1_d2 <= 0;
    Ix_1_d2 <= 0;
    Iy_1_d2 <= 0;
    Iz_1_d2 <= 0;
    M_2_d1 <= 0;
    Ixy_2_d1 <= 0;
    Iyz_2_d1 <= 0;
    Ixz_2_d1 <= 0;
    Ix_2_d1 <= 0;
    Iy_2_d1 <= 0;
    Iz_2_d1 <= 0;
    M_3_d1 <= 0;
    Ixy_3_d1 <= 0;
    Iyz_3_d1 <= 0;
    Ixz_3_d1 <= 0;
    Ix_3_d1 <= 0;
    Iy_3_d1 <= 0;
    Iz_3_d1 <= 0;
    // Ix_max_d <= 0;
  end else if(pp_counter == 1) begin
    M_1_d1 <= nxt_M_1_d1;
    Ix_1_d1 <= nxt_Ix_1_d1;
    Iy_1_d1 <= nxt_Iy_1_d1;
    Iz_1_d1 <= nxt_Iz_1_d1;
    Ixy_1_d1 <= nxt_Ixy_1_d1;
    Iyz_1_d1 <= nxt_Iyz_1_d1;
    Ixz_1_d1 <= nxt_Ixz_1_d1;
    M_1_d2 <= nxt_M_1_d2;
    Ix_1_d2 <= nxt_Ix_1_d2;
    Iy_1_d2 <= nxt_Iy_1_d2;
    Iz_1_d2 <= nxt_Iz_1_d2;
    Ixy_1_d2 <= nxt_Ixy_1_d2;
    Iyz_1_d2 <= nxt_Iyz_1_d2;
    Ixz_1_d2 <= nxt_Ixz_1_d2;
    M_2_d1 <= nxt_M_2_d1;
    Ix_2_d1 <= nxt_Ix_2_d1;
    Iy_2_d1 <= nxt_Iy_2_d1;
    Iz_2_d1 <= nxt_Iz_2_d1;
    Ixy_2_d1 <= nxt_Ixy_2_d1;
    Iyz_2_d1 <= nxt_Iyz_2_d1;
    Ixz_2_d1 <= nxt_Ixz_2_d1;
    M_3_d1 <= nxt_M_3_d1;
    Ix_3_d1 <= nxt_Ix_3_d1;
    Iy_3_d1 <= nxt_Iy_3_d1;
    Iz_3_d1 <= nxt_Iz_3_d1;
    Ixy_3_d1 <= nxt_Ixy_3_d1;
    Iyz_3_d1 <= nxt_Iyz_3_d1;
    Ixz_3_d1 <= nxt_Ixz_3_d1;
  end else begin
    M_1_d1 <= M_1_d1;
    Ix_1_d1 <= Ix_1_d1;
    Iy_1_d1 <= Iy_1_d1;
    Iz_1_d1 <= Iz_1_d1;
    Ixy_1_d1 <= Ixy_1_d1;
    Iyz_1_d1 <= Iyz_1_d1;
    Ixz_1_d1 <= Ixz_1_d1;
    M_1_d2 <= M_1_d2;
    Ix_1_d2 <= Ix_1_d2;
    Iy_1_d2 <= Iy_1_d2;
    Iz_1_d2 <= Iz_1_d2;
    Ixy_1_d2 <= Ixy_1_d2;
    Iyz_1_d2 <= Iyz_1_d2;
    Ixz_1_d2 <= Ixz_1_d2;
    M_2_d1 <= M_2_d1;
    Ix_2_d1 <= Ix_2_d1;
    Iy_2_d1 <= Iy_2_d1;
    Iz_2_d1 <= Iz_2_d1;
    Ixy_2_d1 <= Ixy_2_d1;
    Iyz_2_d1 <= Iyz_2_d1;
    Ixz_2_d1 <= Ixz_2_d1;
    M_3_d1 <= M_3_d1;
    Ix_3_d1 <= Ix_3_d1;
    Iy_3_d1 <= Iy_3_d1;
    Iz_3_d1 <= Iz_3_d1;
    Ixy_3_d1 <= Ixy_3_d1;
    Iyz_3_d1 <= Iyz_3_d1;
    Ixz_3_d1 <= Ixz_3_d1;
    // Ix_max_d <= Ix_max_d;
  end
end


endmodule
