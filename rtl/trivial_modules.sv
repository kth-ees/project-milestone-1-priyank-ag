
module demux #(parameter N)(
    input logic   demux_in,
    input logic  [($clog2(N)-1):0] sel,
    output logic [(N-1):0] demux_out
);

always_comb begin
    demux_out = '0;
    demux_out[sel] = demux_in;    
end

endmodule

// mux [Nbit] with enable
module mux_en #(parameter N)(
    input logic [(N-1):0] mux_in,
    input logic  [($clog2(N)-1):0] sel,
    input logic en,
    output logic   mux_out
);

always_comb begin
    mux_out = '0;
    mux_out = en ? mux_in[sel] : 1'b0;   
end

endmodule

// mux [Nbit]
module mux #(parameter N)(
    input logic [(N-1):0] mux_in,
    input logic  [($clog2(N)-1):0] sel,
    output logic   mux_out
);

always_comb begin
    mux_out = '0;
    mux_out = mux_in[sel];    
end

endmodule


// adder N bit [slow] for N <= 3
module adder_Nbit_slow #(parameter N=3)(
    input logic [(N-1):0] a,b,
    input logic cin, 
    output logic [(N-1):0] sum,
    output logic cout
);

genvar i;
logic [N:0] carry;
assign carry[0] = cin;

generate
for(i=0;i<N;i++) begin:adder_gen
    adder_1bit inst(
        .a(a[i]),
        .b(b[i]),
        .cin(carry[i]),
        .sum(sum[i]),
        .cout(carry[i+1])
    );
end  
endgenerate

assign cout = carry[N];

endmodule

// adder1 bit [slow]
module adder_1bit(
    input logic a,b,cin,
    output logic sum, cout
);
assign sum = a ^ b ^ cin;
assign cout = (a & b) | (cin & ( a ^ b ));
endmodule




module adder_Nbit_fast #(parameter N = 16)(
    input logic [(N-1):0] A,B,
    input logic cin,
    output logic [(N-1):0] sum,
    output logic cout
);
 
logic [(N/4):0] carry;
assign carry [0] = cin;

genvar i;
generate
    for(i=0;i<N/4;i++) begin:Nbit_fast
        CLA_4bit inst(
            .A(A[(i*4+3):i*4]),
            .B(B[(i*4+3):i*4]),
            .cin(carry[i]),
            .sum(sum[(i*4+3):i*4]),
            .cout(carry[i+1])
        );
    end
endgenerate

endmodule


// Carry lookahead adder for higher bits
module CLA_4bit(
    input logic [3:0] A,B,
    input logic cin,
    output logic [3:0] sum,
    output logic cout
);

logic [4:0] gen, prop, carry;

assign carry[0] = cin;

genvar i;

generate
   for (i=0;i<4;i++) begin:gen_prop
    assign gen[i] = A[i] & B[i];
    assign prop[i] = A[i] ^ B[i];
    assign sum[i] = prop[i] ^ carry[i];
   end
endgenerate

assign carry[1] = gen[0] | prop[0] & carry [0];
assign carry[2] = gen[1] | prop[1] & (gen[0] | prop[0] & carry [0]);
assign carry[3] = gen[2] | prop[2] & (gen[1] | prop[1] & (gen[0] | prop[0] & carry [0]));
assign carry[4] = gen[3] | prop[3] & (gen[2] | prop[2] & (gen[1] | prop[1] & (gen[0] | prop[0] & carry [0])));
assign cout = carry[4];
endmodule


module and_Nbit #(parameter N =16)(
    input logic [N-1:0] a,b,
    output logic [N-1:0] out
);

genvar i;
generate
    for(i=0;i<N;i++) begin: and_gate_Nbit
        assign out[i] = a[i] &b[i];
    end
endgenerate
endmodule

module or_Nbit #(parameter N =16)(
    input logic [N-1:0] a,b,
    output logic [N-1:0] out
);

genvar i;
generate
    for(i=0;i<N;i++) begin: or_gate_Nbit
        assign out[i] = a[i] | b[i];
    end
endgenerate
endmodule

module xor_Nbit #(parameter N =16)(
    input logic [N-1:0] a,b,
    output logic [N-1:0] out
);

genvar i;
generate
    for(i=0;i<N;i++) begin: xor_gate_Nbit
        assign out[i] = a[i] ^ b[i];
    end
endgenerate
endmodule


