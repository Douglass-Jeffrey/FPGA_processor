`include "defines.vh"

module regfile (
    input wire clk,                 //clock
    input wire rst,                 //reset
    input wire [4:0] rs1_addr,      //source register 1 address
    input wire [4:0] rs2_addr,      //source register 2 address
    input wire [4:0] rd_addr,       //destination register address
    input wire [31:0] rd_data,      //destination register data
    input wire rd_we,               //destination register write enable
    output wire [31:0] rs1_data,    //source register 1 data
    output wire [31:0] rs2_data     //source register 2 data

);
    reg [31:0] registers [0:31];

    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : registers[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : registers[rs2_addr];

    always @(posedge clk) begin
        if (rd_we && rd_addr != 5'd0) begin
            registers[rd_addr] <= rd_data;
        end
    end
endmodule