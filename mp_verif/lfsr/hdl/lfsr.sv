module lfsr #(
    parameter bit   [15:0]  SEED_VALUE = 'hECEB
) (
    input   logic           clk,
    input   logic           rst,
    input   logic           en,
    output  logic           rand_bit,
    output  logic   [15:0]  shift_reg
);

    // TODO: Fill this out!
    logic shift_in, shift_out;
    logic [15:0] temp_reg;

    assign shift_in = (((shift_reg[0]^shift_reg[2])^shift_reg[3])^shift_reg[5]);
    assign temp_reg = shift_reg >> 1;

    always_ff @(posedge clk) begin
	    if(rst) begin
		    shift_reg <= SEED_VALUE;
	    end
	    else if(en) begin
		    rand_bit <= shift_reg[0];
		    shift_reg <= {shift_in,temp_reg[14:0]};   
	    end
	    else begin
		    shift_reg <= shift_reg;
	    end
    end

endmodule : lfsr
