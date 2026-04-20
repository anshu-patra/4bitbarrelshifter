//=============================================================================
// Design      : barrel_shifter_4bit
// Description : 4-bit Pipelined Barrel Shifter (Left Rotate)
//               2-stage pipeline; 8 Flip-Flops total (all replaced with
//               Scan-FFs by Genus during DFT insertion).
// DFT Ports   : scan_en, scan_in, scan_out  (stitched by Genus)
//=============================================================================

module barrel_shifter_4bit (
    // Functional Ports
    input  wire       clk,        // System Clock
    input  wire       rst_n,      // Active-low Asynchronous Reset
    input  wire [3:0] data_in,    // 4-bit Data input
    input  wire [1:0] shift_amt,  // Shift amount: 00=0, 01=1, 10=2, 11=3

    output reg  [3:0] data_out,   // Shifted (rotated-left) Output

    // DFT / Scan Ports
    // Genus will override the scan_out assignment and stitch the full
    // 8-FF scan chain automatically during connect_scan_chains.
    input  wire       scan_en,    // 1 = Shift mode   0 = Capture mode
    input  wire       scan_in,    // Serial scan data input  (chain head)
    output wire       scan_out    // Serial scan data output (chain tail)
);

    // -----------------------------------------------------------------------
    // Pipeline Stage 1 register  (4 FFs)
    // -----------------------------------------------------------------------
    reg [3:0] stage1;

    // -----------------------------------------------------------------------
    // Stage 1 : Conditional left-rotate by 1 bit  (shift_amt[0])
    // Stage 2 : Conditional left-rotate by 2 bits (shift_amt[1])
    // Combined effect : left-rotate by 0, 1, 2 or 3 positions
    // -----------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1   <= 4'b0000;
            data_out <= 4'b0000;
        end else begin
            // Stage 1 : rotate left by 1 when shift_amt[0] = 1
            stage1 <= shift_amt[0] ? {data_in[2:0], data_in[3]}
                                   :  data_in;

            // Stage 2 : rotate left by 2 when shift_amt[1] = 1
            data_out <= shift_amt[1] ? {stage1[1:0], stage1[3:2]}
                                     :  stage1;
        end
    end

    // -----------------------------------------------------------------------
    // Scan Chain Tail
    // This is a PLACEHOLDER.  Genus will disconnect this assignment and
    // re-wire scan_out to the Q pin of the last scan-FF in the chain
    // during the 'connect_scan_chains' step.
    // -----------------------------------------------------------------------
    assign scan_out = data_out[3];

endmodule