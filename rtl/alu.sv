module alu #(parameter BW=16)(
    input logic [(BW-1):0] in_a,in_b,
    input logic [2:0] opcode,
    output [(BW-1) : 0] result,
    output [2:0] onz_flags
);

logic au_lu_select;
    logic [BW-1:0] op_A_demux_au, op_A_demux_lu, op_B_demux_au, op_B_demux_lu;
    logic [1:0][(BW-1):0] au_lu_out_mux_in;
logic [1:0][2:0] onz_collector;

// 0-> au, 1-> lu
assign au_lu_select = (opcode[2] & ~ opcode[0]) | opcode[1];

genvar i;

generate

    for(i =0 ; i<BW ; i++) begin:demux_op_a
        demux #(.N(2)) au_lu_slect_A (
            .demux_in(in_a[i]),
            .sel(au_lu_select),
            .demux_out({op_A_demux_lu[i], op_A_demux_au[i]})
        );
    end

    for(i =0 ; i<BW ; i++) begin:demux_op_b
        demux #(.N(2)) au_lu_slect_B (
            .demux_in(in_b[i]),
            .sel(au_lu_select),
            .demux_out({op_B_demux_lu[i], op_B_demux_au[i]})
        );
    end

endgenerate


    logic_unit #(.N(BW)) logic_alu(
    .A(au_lu_select ? op_A_demux_lu : '0),
    .B(au_lu_select ? op_B_demux_lu : '0),
    .opcode(opcode),
    .result_out(au_lu_out_mux_in [1]),
    .onz_flags(onz_collector[0])
);

    arith_unit #(.N(BW)) arith_alu(
    .A(au_lu_select ? '0 : op_A_demux_au),
    .B(au_lu_select ? '0 : op_B_demux_au),
    .opcode(opcode),
    .result_out(au_lu_out_mux_in [0]),
    .onz_flags(onz_collector[1])
);

generate

    for(genvar i = 0 ; i<BW ; i++) begin:final_stage_alu
        mux #(.N(2)) final_res (
            .mux_in ({au_lu_out_mux_in [1][i], au_lu_out_mux_in [0][i]}),
            .sel(au_lu_select),
            .mux_out(result[i])
        );
    end

    for(genvar i = 0 ; i<3 ; i++) begin:final_stage_onz
        mux #(.N(2)) final_res_onz (
            .mux_in ({onz_collector[1][i], onz_collector [0][i]}),
            .sel(au_lu_select),
            .mux_out(onz_flags[i])
        );
    end

endgenerate



endmodule





// -------------------------------------------------------------------------------------------

// handles add, subtract, increment 

module arith_unit #(parameter N=16)(
    // input logic en;                     // active high enable
    input logic [(N-1):0] A,B,          // operands
    input [2:0] opcode,                 // 
    output [N-1:0] result_out,
    output [2:0] onz_flags
);

// row 0 -> B
// row 1 -> 1 (increment)
logic [1:0][(N-1):0] B_mux_in_op_sel;
logic [(N-1):0] B_adder_in_mux_out;

// assign carry input to the adder , select operand B mux for inc vs add and sub , carry out
logic cin, op_B_mux_sel, cout , cal_ov_neg;

// opcode for sub  cin = 1 -> sub tract with 2's complemnt cin = 0 -> add
assign cin = ~opcode[2] & ~opcode[1] & opcode[0];

// inc means op_B is 1 else it is cin ^ B[i]
assign op_B_mux_sel = opcode[2] & ~opcode[1] & opcode[0];

//calculates ov and neg only then the bit is set
assign cal_ov_neg = ~opcode[1] & (opcode[0] | opcode[2]);

genvar i;

generate
    for(i=0;i<N;i++) begin:op_B_sel_mux
        assign B_mux_in_op_sel[0][i] = cin ^ B[i];
        assign B_mux_in_op_sel[1][i] = (i==0 ? 1'b1 : 1'b0);
        
        mux #(.N(2)) op_B_sel (
            .mux_in({B_mux_in_op_sel[1][i],B_mux_in_op_sel[0][i]}),
            .sel(op_B_mux_sel),
            .mux_out(B_adder_in_mux_out[i])
        );
    end
endgenerate

if (N <4 || N%4 !=0 ) begin
    adder_Nbit_slow #(.N(N)) slow_adder(
        .a(A),
        .b(B_adder_in_mux_out),
        .cin(cin),
        .sum(result_out),
        .cout (cout)                //deal with cout flags
    );
end

if (N==4) begin
    CLA_4bit bit_4_adder(
        .A(A),
        .B(B_adder_in_mux_out),
        .cin(cin),
        .sum(result_out),
        .cout (cout)                //deal with cout flags
    );
end

if (N>4 && N%4 ==0) begin
    adder_Nbit_fast #(.N(N)) fast_adder_condn(
        .A(A),
        .B(B_adder_in_mux_out),
        .cin(cin),
        .sum(result_out),
        .cout (cout)                //deal with cout flags
    );
end

assign onz_flags[0] = (result_out == 0);
assign onz_flags[1] = cal_ov_neg & result_out[N-1];
assign onz_flags[2] = cal_ov_neg & (A[N-1] & B[N-1] & ~result_out[N-1]) |
                      (~A[N-1] & ~B[N-1] & result_out[N-1]);

endmodule



// -----------------------------------------------------------------------------------------------------------------
// handles and, or, mov, xor

module logic_unit #(parameter N=16)(
    // input logic en;                     // active high enable
    input logic [(N-1):0] A,B,          // operands
    input logic [2:0] opcode,                 // 
    output logic [N-1:0] result_out,
    output [2:0] onz_flags
);

// row 0 -> B
// row 1 -> 1 [for Mov] 
logic [1:0][(N-1):0] B_mux_in_op_sel;
logic [(N-1):0] B_logic_in_mux_out;

// row 0 -> A
// row 1 -> 1 [for Mov] 
logic [1:0][(N-1):0] A_mux_in_op_sel;
logic [(N-1):0] A_logic_in_mux_out;

logic op_A_mux_sel , op_B_mux_sel;
assign op_A_mux_sel= opcode[2] & opcode [1] & opcode [0];
assign op_B_mux_sel = opcode[2] & opcode [1] & ~opcode [0];

logic [(N-1):0] and_out, or_out, xor_out;

genvar i;



generate
    for(i=0;i<N;i++) begin:op_B_assign_mux

        assign A_mux_in_op_sel[0][i] = A[i];
        assign A_mux_in_op_sel[1][i] = 1'b1;

        assign B_mux_in_op_sel[0][i] = B[i];
        assign B_mux_in_op_sel[1][i] = 1'b1;
    end

    for(i=0;i<N;i++) begin:op_B_sel_mux
        mux #(.N(2)) op_A_sel (
            .mux_in({A_mux_in_op_sel[1][i],A_mux_in_op_sel[0][i]}),
            .sel(op_A_mux_sel),
            .mux_out(A_logic_in_mux_out[i])
        );
        
        mux #(.N(2)) op_B_sel (
            .mux_in({B_mux_in_op_sel[1][i],B_mux_in_op_sel[0][i]}),
            .sel(op_B_mux_sel),
            .mux_out(B_logic_in_mux_out[i])
        );
    end
endgenerate


// Instantiate all operators (always present)
and_Nbit #(.N(N)) and_array (.a(A_logic_in_mux_out), .b(B_logic_in_mux_out), .out(and_out));
or_Nbit  #(.N(N)) or_array  (.a(A_logic_in_mux_out), .b(B_logic_in_mux_out), .out(or_out));
xor_Nbit #(.N(N)) xor_array (.a(A_logic_in_mux_out), .b(B_logic_in_mux_out), .out(xor_out));

always_comb begin
    result_out = '0;
        case (opcode)
            3'b010: result_out = and_out;
            3'b011: result_out = or_out;
            3'b100: result_out = xor_out;
            3'b110: result_out = and_out;
            3'b111: result_out = and_out;
            default: result_out = '0;
        endcase
end

assign onz_flags[0] = (result_out == 0);
    assign onz_flags[1] = (result_out[N-1]);
assign onz_flags[2] = 1'b0;

endmodule

