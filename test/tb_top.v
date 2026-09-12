`timescale 1ns/1ps
module tb_top;
    reg clk = 0;
    reg rst = 1;
    wire [31:0] dbg_pc, dbg_instr, dbg_wb_data;
    wire dbg_reg_write;

    top dut (
        .clk(clk), .rst(rst),
        .dbg_pc(dbg_pc), .dbg_instr(dbg_instr),
        .dbg_wb_data(dbg_wb_data), .dbg_reg_write(dbg_reg_write)
    );

    always #5 clk = ~clk;

    initial begin
        rst = 1;
        repeat (2) @(posedge clk);
        rst = 0;
        repeat (400) @(posedge clk);
        $display("gp(testnum)=%0d a0(pass/fail)=%0d pc=%0d",
            dut.u_rf.registers[3], dut.u_rf.registers[10], dut.dbg_pc);
        if (dut.u_rf.registers[10] == 32'd1)
            $display("ALL TESTS PASSED");
        else
            $display("FAILED at test %0d", dut.u_rf.registers[3]);
        $finish;
    end
endmodule
