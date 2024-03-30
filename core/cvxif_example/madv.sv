module madv
#(

) (
    input logic clk_i,
    input logic rst_ni,

    input logic data_valid,
    input logic[11:0] data_count,
    input logic[31:0] data,
    input logic is_input,
    input logic is_weight,

    input logic execute,

    output logic result_valid,
    output logic[31:0] result
);

logic rst_ni_i;
logic reinit_ni_i = '1;
logic reinit_ni_i_2;
logic reinit_ni_i_3;

integer i;
integer k;

logic data_valid_i;

logic result_valid_i;
logic result_valid_o;
integer results1[128];
integer results2[32];
integer results3[8];
integer results4[2];

integer bus_a_counter = 0;
integer bus_b_counter = 0;
reg [0:128][7:0] bus_a;
reg [0:128][7:0] bus_b;

assign result_valid = result_valid_o;
assign rst_ni_i = rst_ni & reinit_ni_i_3;

genvar j;
generate
    for (j = 0; j < 128; j++) begin
        assign results1[j] = $signed(
            {bus_a[j][7] & 1'b0, bus_a[j]}
        ) * $signed(
            {bus_b[j][7] & 1'b1, bus_b[j]}
        );
    end
endgenerate

always @(posedge clk_i or negedge rst_ni_i) begin
    if (~rst_ni_i) begin
        reinit_ni_i_2 <= '1;
        reinit_ni_i_3 <= '1;
    end else begin
        reinit_ni_i_2 <= reinit_ni_i;
        reinit_ni_i_3 <= reinit_ni_i_2;
    end;
end

always @(posedge clk_i or negedge rst_ni_i) begin
    if (~rst_ni_i) begin
        bus_a_counter <= 0;
        bus_b_counter <= 0;
        for (i = 0; i < 128; i = i+1) bus_a[i] <= '0;
        for (i = 0; i < 128; i = i+1) bus_b[i] <= '0;

        data_valid_i <= '0;
    end else begin
        if (data_valid & ~data_valid_i) begin
            if (is_input) begin
                if (data_count >= 1 && bus_a_counter + 1 < 128) bus_a[bus_a_counter    ] <= data[7:0];
                if (data_count >= 2 && bus_a_counter + 2 < 128) bus_a[bus_a_counter + 1] <= data[15:8];
                if (data_count >= 3 && bus_a_counter + 3 < 128) bus_a[bus_a_counter + 2] <= data[23:16];
                if (data_count >= 4 && bus_a_counter + 4 < 128) bus_a[bus_a_counter + 3] <= data[31:24];
                bus_a_counter = bus_a_counter + data_count;
            end;

            if (is_weight) begin
                if (data_count >= 1 && bus_b_counter + 1 < 128) bus_b[bus_b_counter    ] <= data[7:0];
                if (data_count >= 2 && bus_b_counter + 2 < 128) bus_b[bus_b_counter + 1] <= data[15:8];
                if (data_count >= 3 && bus_b_counter + 3 < 128) bus_b[bus_b_counter + 2] <= data[23:16];
                if (data_count >= 4 && bus_b_counter + 4 < 128) bus_b[bus_b_counter + 3] <= data[31:24];
                bus_b_counter = bus_b_counter + data_count;
            end;

        end;

        data_valid_i <= data_valid & ~data_valid_i;
    end
end

integer valid_counter = 0;

// -----------------------
// Output pipeline register
// -----------------------
always_ff @(posedge clk_i or negedge rst_ni_i) begin
    if (~rst_ni_i) begin
        result         <= '0;
        result_valid_o <= '0;
        reinit_ni_i    <= '1;
        valid_counter <= 0;

        for (k = 0; k < 32; k = k+1) results2[k] <= '0;
        for (k = 0; k < 8; k = k+1) results3[k] <= '0;
        for (k = 0; k < 4; k = k+1) results4[k] <= '0;
    end else begin
        if (execute) begin
            for (k = 0; k < 32; k = k+1) results2[k] <= results1[k*4] + results1[k*4 + 1] + results1[k*4 + 2] + results1[k*4 + 3];
            for (k = 0; k < 8; k = k+1) results3[k] <= results2[k*4] + results2[k*4 + 1] + results2[k*4 + 2] + results2[k*4 + 3];
            for (k = 0; k < 2; k = k+1) results4[k] <= results3[k*4] + results3[k*4 + 1] + results3[k*4 + 2] + results3[k*4 + 3];
            result <= results4[0] + results4[1];
            valid_counter <= valid_counter + 1;
        end;

        if (result_valid_i) begin
            reinit_ni_i <= '0;
        end;
        result_valid_i <= (valid_counter >= 2) ? '1 : '0;
        result_valid_o <= ((result_valid_i & execute) | data_valid) & ~result_valid_o;
    end
end

endmodule