`timescale 1ns / 1ps

module sev_seg_tb;

    localparam int ADDR_W = 12;

    // --------------------------------------------------
    // Clock and reset
    // --------------------------------------------------
    logic clk;
    logic rst_n;

    // --------------------------------------------------
    // APB signals
    // --------------------------------------------------
    logic [ADDR_W-1:0] paddr;
    logic              penable;
    logic              psel;
    logic              pwrite;
    logic [31:0]       pwdata;

    logic              pready;
    logic              pslverr;
    logic [31:0]       prdata;

    // --------------------------------------------------
    // 7-segment outputs
    // --------------------------------------------------
    logic [6:0] seg7_seg;
    logic [3:0] seg7_an;
    logic       seg7_dp;


    // --------------------------------------------------
    // DUT
    // --------------------------------------------------
    sev_seg #(
        .ADDR_W(ADDR_W)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),

        .paddr    (paddr),
        .penable  (penable),
        .psel     (psel),
        .pwrite   (pwrite),
        .pwdata   (pwdata),

        .pready   (pready),
        .pslverr  (pslverr),
        .prdata   (prdata),

        .seg7_seg (seg7_seg),
        .seg7_an  (seg7_an),
        .seg7_dp  (seg7_dp)
    );


    // --------------------------------------------------
    // 100 MHz clock
    //
    // Period = 10 ns
    // --------------------------------------------------
    initial begin
        clk = 1'b0;

        forever #5 clk = ~clk;
    end


    // --------------------------------------------------
    // APB write task
    // --------------------------------------------------
    task automatic apb_write(
        input logic [ADDR_W-1:0] address,
        input logic [31:0]       data
    );

        begin

            // -------------------------------
            // APB setup phase
            // -------------------------------
            @(posedge clk);

            paddr   <= address;
            pwdata  <= data;
            pwrite  <= 1'b1;
            psel    <= 1'b1;
            penable <= 1'b0;


            // -------------------------------
            // APB access phase
            // -------------------------------
            @(posedge clk);

            penable <= 1'b1;


            // -------------------------------
            // Finish transaction
            // -------------------------------
            @(posedge clk);

            psel    <= 1'b0;
            penable <= 1'b0;
            pwrite  <= 1'b0;
            paddr   <= '0;
            pwdata  <= '0;

        end

    endtask


    // --------------------------------------------------
    // Main stimulus
    // --------------------------------------------------
    initial begin

        // Initial values
        rst_n   = 1'b0;

        paddr   = '0;
        penable = 1'b0;
        psel    = 1'b0;
        pwrite  = 1'b0;
        pwdata  = 32'd0;


        // Hold reset for a few clocks
        repeat (5)
            @(posedge clk);

        rst_n = 1'b1;


        // --------------------------------------------------
        // Write VAL register
        //
        // digit3 = 1
        // digit2 = 2
        // digit1 = 3
        // digit0 = 4
        //
        // Therefore lower 16 bits:
        //
        // 0001 0010 0011 0100
        //
        // = 0x1234
        // --------------------------------------------------

        apb_write(
            12'h004,
            32'h0000_1234
        );


        // --------------------------------------------------
        // DIM = 15
        // Maximum brightness
        // --------------------------------------------------

        apb_write(
            12'h008,
            32'h0000_000F
        );


        // --------------------------------------------------
        // Enable controller
        // CTL.EN = 1
        // --------------------------------------------------

        apb_write(
            12'h000,
            32'h0000_0001
        );


        // --------------------------------------------------
        // Allow display to run
        // --------------------------------------------------

        repeat (1000)
            @(posedge clk);


        $finish;

    end

endmodule