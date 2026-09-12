// instruction memory
`include "defines.vh"

module imem #(
    parameter DEPTH_WORDS = 256,
    parameter INIT_FILE   = "program.hex"
)(
    input  wire [31:0] addr,    // byte address (PC); addr[1:0] assumed 0
    output wire [31:0] instr
);
    localparam AW = $clog2(DEPTH_WORDS);

    reg [31:0] mem [0:DEPTH_WORDS-1];

    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end

    assign instr = mem[addr[AW+1:2]];
endmodule
