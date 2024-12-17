module regfile
(
    input   logic           clk,
    input   logic           rst,
    input   logic           regf_we,
    input   logic   [31:0]  rd_v,
    input   logic   [4:0]   rs1_s, rs2_s, rd_s,
    output  logic   [31:0]  rs1_v, rs2_v,
    input logic             data_hazard_rs1,
    input logic             data_hazard_rs2
);

            logic   [31:0]  data [32];
            logic   [31:0]  rs1_out;
            logic   [31:0]  rs2_out;

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 32; i++) begin
                data[i] <= '0;
            end
        end else if (regf_we && (rd_s != 5'd0)) begin
            data[rd_s] <= rd_v;
        end
    end

    always_comb begin
        rs1_v = '0;
        rs2_v = '0;
        if (rst) begin
            rs1_out = 'x;
            rs2_out = 'x;
        end else begin

            // if(regf_we && (rd_sz))
            // rs1_v = '0;
            // rs2_v = '0;

            if(data_hazard_rs1 && regf_we && (rd_s == rs1_s) && (rd_s!=5'b00000)) begin
                rs1_v = rd_v;
            end

            else if(rs1_s != 5'b00000) begin
                rs1_v = data[rs1_s];
            end

            else begin
                rs1_v = '0;
            end

            if(data_hazard_rs2 && regf_we && (rd_s == rs2_s) && (rd_s!=5'b00000)) begin
                rs2_v = rd_v;
            end
            else if(rs2_s != 5'b00000) begin
                rs2_v = data[rs2_s];
            end
            else begin
                rs2_v = '0;
            end



            // rs1_out = (rs1_s != 5'd0) ? data[rs1_s] : '0;
            // rs2_out = (rs2_s != 5'd0) ? data[rs2_s] : '0;
        end
    end

    // always_comb begin
    //     rs1_v = (data_hazard_rs1) ? rd_v : rs1_out;
    //     rs2_v = (data_hazard_rs2) ? rd_v : rs2_out;
    // end 


endmodule : regfile
