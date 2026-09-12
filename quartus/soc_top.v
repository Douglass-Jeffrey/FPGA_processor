// =============================================================================
// soc_top.v Board wrapper for the single-cycle RV32I core
//
// Target : Altera Cyclone II FPGA Starter Development Board (EP2C20F484C7N)
//
// Purpose
//   Connect CPU (top.v) to the boards I/O for observation, control, debug.
//   Also generate two slow clocks from the 50 MHz board clock since
//   single cycle design needs to run at lower rate.
// =============================================================================
module soc_top (
    input  wire        CLOCK_50,   // 50 MHz oscillator          (PIN_L1)
    input  wire [3:0]  KEY,        // push buttons, active-low
    input  wire [9:0]  SW,         // switches, active-high
    output wire [9:0]  LEDR,       // red leds
    output wire [7:0]  LEDG,       // green leds
    output wire [6:0]  HEX0,       // 7-segm displays, active-LOW segments
    output wire [6:0]  HEX1,       // segment order: bit0=a, bit1=b, ... bit6=g
    output wire [6:0]  HEX2,
    output wire [6:0]  HEX3
);

    // hold reset for 2^16 cc after power on, also enable push button reset
    reg [15:0] por_cnt = 16'd0;
    reg        por     = 1'b1;
    always @(posedge CLOCK_50) begin
        if (por_cnt != 16'hFFFF) begin
            por_cnt <= por_cnt + 16'd1;
            por     <= 1'b1;
        end else begin
            por     <= 1'b0;
        end
    end
    wire rst = por | ~KEY[0];      // active-high reset for the core

    // Clock divider, generate two slow clocks (ticks) from board clk
    // tick is a 1-cycle-wide pulse. slow_tick ~= 50e6/2^24 ~= 3 Hz,
    // med_tick ~= 50e6/2^19 ~= 95 Hz.
    reg [24:0] div = 25'd0;
    always @(posedge CLOCK_50) div <= div + 25'd1;

    wire slow_tick = (div[23:0] == 24'd0);
    wire med_tick  = (div[18:0] == 19'd0);
    wire run_tick  = SW[8] ? med_tick : slow_tick;

    // enable one tick per KEY[1] press debounced
    wire step_pulse;
    debounce_pulse #(.STABLE(16)) u_step (
        .clk   (CLOCK_50),
        .rst   (rst),
        .btn_n (KEY[1]),
        .pulse (step_pulse)
    );

    // pick between the three clocks (med, slow, step) 
    // sw9 ? (sw8 ? med_tick : slow_tick) : step_pulse
    wire advance = SW[9] ? run_tick : step_pulse;
    reg  cpu_clk = 1'b0;
    always @(posedge CLOCK_50) cpu_clk <= advance;

    // Cpu instance
    wire [31:0] dbg_pc, dbg_instr, dbg_wb_data;
    wire        dbg_reg_write;
    top u_cpu (
        .clk           (cpu_clk),
        .rst           (rst),
        .dbg_pc        (dbg_pc),
        .dbg_instr     (dbg_instr),
        .dbg_wb_data   (dbg_wb_data),
        .dbg_reg_write (dbg_reg_write)
    );

    // Cycle counter
    reg [31:0] cyc = 32'd0;
    always @(posedge cpu_clk or posedge rst) begin
        if (rst) cyc <= 32'd0;
        else     cyc <= cyc + 32'd1;
    end

    // Display select
    reg [31:0] disp_val;
    always @(*) begin
        case (SW[7:6])
            2'b00:   disp_val = dbg_pc; //show pc
            2'b01:   disp_val = dbg_instr; //show instr
            2'b10:   disp_val = dbg_wb_data; //show wb_data
            default: disp_val = cyc;          // show cycle count from rst
        endcase
    end

    // leds, if sw 5 high show upper 18 bits of disp_val, else lower 18 bits
    wire [17:0] window = SW[5] ? disp_val[31:14] : disp_val[17:0];
    assign LEDG = window[7:0];
    assign LEDR = window[17:8];

    // 7-seg, same as above
    wire [15:0] hex_val = SW[5] ? disp_val[31:16] : disp_val[15:0];
    assign HEX0 = seg7(hex_val[3:0]);
    assign HEX1 = seg7(hex_val[7:4]);
    assign HEX2 = seg7(hex_val[11:8]);
    assign HEX3 = seg7(hex_val[15:12]);

    // 7-segment decoder, active-low segments
    function [6:0] seg7;
        input [3:0] n;
        reg [6:0] p;   // active-high, bit0=a .. bit6=g
        begin
            case (n)
                4'h0: p = 7'h3F;  
                4'h1: p = 7'h06;
                4'h2: p = 7'h5B;
                4'h3: p = 7'h4F;
                4'h4: p = 7'h66;
                4'h5: p = 7'h6D;
                4'h6: p = 7'h7D;
                4'h7: p = 7'h07;
                4'h8: p = 7'h7F;
                4'h9: p = 7'h6F;
                4'hA: p = 7'h77;
                4'hB: p = 7'h7C;
                4'hC: p = 7'h39;
                4'hD: p = 7'h5E;
                4'hE: p = 7'h79;
                4'hF: p = 7'h71;
                default: p = 7'h00;
            endcase
            seg7 = ~p;    // active-low output
        end
    endfunction

endmodule

// debouncer, emit one cycle pulse on press
module debounce_pulse #(parameter STABLE = 16) (
    input  wire clk,
    input  wire rst,
    input  wire btn_n,
    output reg  pulse
);
    // 2-FF synchronizer; s1 is the pressed level, active-high
    reg s0, s1;
    always @(posedge clk) begin
        s0 <= ~btn_n;
        s1 <= s0;
    end

    // add to a counter only when the synced input differs from the last
    // accepted stable level; accept the new level only once the counter isa full
    reg [STABLE-1:0] cnt;
    reg              stable_lvl;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt        <= {STABLE{1'b0}};
            stable_lvl <= 1'b0;
        end else if (s1 == stable_lvl) begin
            cnt <= {STABLE{1'b0}};
        end else begin
            cnt <= cnt + 1'b1;
            if (&cnt) stable_lvl <= s1;
        end
    end

    // rising-edge detect on the debounced level = one pulse per press
    reg stable_d;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            stable_d <= 1'b0;
            pulse    <= 1'b0;
        end else begin
            stable_d <= stable_lvl;
            pulse    <= stable_lvl & ~stable_d;
        end
    end
endmodule
