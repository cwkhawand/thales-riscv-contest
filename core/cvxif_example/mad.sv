module mad
#(

) (
    input logic clk_i,
    input logic rst_ni,
    input logic input_valid,
    input logic[31:0] operand_a,
    input logic[31:0] operand_b,
    output logic result_valid,
    output logic[31:0] result
);

logic result_valid_i;
integer result1;
integer result2;
integer result3;
integer result4;

reg [7 : 0] bus_a_31_24;
reg [7 : 0] bus_a_23_16;
reg [7 : 0] bus_a_15_8;
reg [7 : 0] bus_a_7_0;

reg [7 : 0] bus_b_31_24;
reg [7 : 0] bus_b_23_16;
reg [7 : 0] bus_b_15_8;
reg [7 : 0] bus_b_7_0;

assign result1 = $signed(
    {bus_a_7_0[7] & 1'b0, bus_a_7_0}
) * $signed(
    {bus_b_7_0[7] & 1'b1, bus_b_7_0}
);
assign result2 = $signed(
    {bus_a_15_8[7] & 1'b0, bus_a_15_8}
) * $signed(
    {bus_b_15_8[7] & 1'b1, bus_b_15_8}
);
assign result3 = $signed(
    {bus_a_23_16[7] & 1'b0, bus_a_23_16}
) * $signed(
    {bus_b_23_16[7] & 1'b1, bus_b_23_16}
);
assign result4 = $signed(
    {bus_a_31_24[7] & 1'b0, bus_a_31_24}
) * $signed(
    {bus_b_31_24[7] & 1'b1, bus_b_31_24}
);

always @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
        bus_a_31_24 <='0;
        bus_a_23_16 <='0;
        bus_a_15_8  <='0;   
        bus_a_7_0   <='0;

        bus_b_31_24 <='0;
        bus_b_23_16 <='0;
        bus_b_15_8  <='0;
        bus_b_7_0   <='0;

        result_valid_i <='0;
    end else begin
        bus_a_31_24 <= operand_a[31:24];
        bus_a_23_16 <= operand_a[23:16];
        bus_a_15_8  <= operand_a[15:8];
        bus_a_7_0   <= operand_a[7:0];

        bus_b_31_24 <= operand_b[31:24];
        bus_b_23_16 <= operand_b[23:16];
        bus_b_15_8  <= operand_b[15:8];
        bus_b_7_0   <= operand_b[7:0];

        result_valid_i <= input_valid;
    end
end

// -----------------------
// Output pipeline register
// -----------------------
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
        result     <='0;
        result_valid <='0;
    end else begin
        // Output Register
        result <= result1 + result2 + result3 + result4;

        result_valid <= result_valid_i & input_valid;
    end
end

endmodule