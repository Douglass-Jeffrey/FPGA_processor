//data memory + load/store alignment

`include "defines.vh"

module dmem #(
    parameter DEPTH_WORDS = 256,
    parameter INIT_FILE   = ""
)(
    input  wire        clk,
    input  wire [31:0] addr,       // byte address (ALU result)
    input  wire [2:0]  funct3,     // instr[14:12]
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [31:0] wdata,      // raw rs2_data
    output reg  [31:0] rdata       // sign/zero-extended load result
);
    localparam AW = $clog2(DEPTH_WORDS);

    reg [31:0] mem [0:DEPTH_WORDS-1];

    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end

    wire [AW-1:0] widx = addr[AW+1:2];
    wire [1:0]    boff = addr[1:0];
    wire [31:0]   word = mem[widx];

    // ---- load: slice out the accessed bytes, then extend ----
    always @(*) begin
        if (!mem_read) begin
            rdata = 32'd0;
        end else begin
            case (funct3)
                3'b000: rdata = {{24{word[8*boff+7]}},      word[8*boff     +: 8]};  // LB
                3'b001: rdata = {{16{word[16*boff[1]+15]}}, word[16*boff[1] +: 16]}; // LH
                3'b010: rdata = word;                                               // LW
                3'b100: rdata = {24'b0,                     word[8*boff     +: 8]};  // LBU
                3'b101: rdata = {16'b0,                     word[16*boff[1] +: 16]}; // LHU
                default: rdata = word;
            endcase
        end
    end

    // ---- store: replicate across lanes + per-byte write enable ----
    reg [31:0] st_wdata;
    reg [3:0]  st_be;
    always @(*) begin
        case (funct3)
            3'b000: begin st_wdata = {4{wdata[7:0]}};  st_be = 4'b0001 << boff; end // SB
            3'b001: begin st_wdata = {2{wdata[15:0]}}; st_be = 4'b0011 << boff; end // SH
            3'b010: begin st_wdata = wdata;            st_be = 4'b1111;         end // SW
            default:begin st_wdata = wdata;            st_be = 4'b0000;         end
        endcase
    end

    integer i;
    always @(posedge clk) begin
        if (mem_write)
            for (i = 0; i < 4; i = i + 1)
                if (st_be[i]) mem[widx][8*i +: 8] <= st_wdata[8*i +: 8];
    end
endmodule