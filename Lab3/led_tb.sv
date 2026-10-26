`timescale 1ns / 1ps

module ledcntrl_top_tb;

    import ahb3lite_pkg::*;

    // ========================================================
    // Clock / reset
    // ========================================================

    logic clk;
    logic reset_n;


    // ========================================================
    // AHB signals
    // ========================================================

    logic        hsel;
    logic [31:0] haddr;
    logic [31:0] hwdata;
    logic [31:0] hrdata;

    logic        hwrite;
    logic [2:0]  hsize;
    logic [2:0]  hburst;
    logic [3:0]  hprot;
    logic [1:0]  htrans;
    logic        hmastlock;
    logic [7:0]  hmaster;

    logic        hready;
    logic        hready_out;
    logic        hresp;


    // ========================================================
    // DUT outputs
    // ========================================================

    logic        int_out;
    logic [15:0] led_out;


    // ========================================================
    // Data arrays required by the provided AHB master
    // ========================================================

    logic [31:0] wr_data [1];
    logic [31:0] rd_data [1];


    // ========================================================
    // 10 kHz simulation clock
    // ========================================================

    initial begin
    clk = 1'b0;
    forever #25_000 clk = ~clk;
end

    // ========================================================
    // Provided AHB master BFM
    // ========================================================

    ahb3lite_master_bfm #(
        .HADDR_SIZE   (32),
        .HDATA_SIZE   (32),
        .HMASTER_SIZE (8)
    ) master (
        .HRESETn   (reset_n),
        .HCLK      (clk),

        .HSEL      (hsel),
        .HADDR     (haddr),
        .HWDATA    (hwdata),
        .HRDATA    (hrdata),

        .HWRITE    (hwrite),
        .HSIZE     (hsize),
        .HBURST    (hburst),
        .HPROT     (hprot),
        .HTRANS    (htrans),
        .HMASTLOCK (hmastlock),
        .HMASTER   (hmaster),

        .HREADY    (hready),
        .HRESP     (hresp)
    );


    // ========================================================
    // LED controller DUT
    // ========================================================

    ledcntrl_top #(
        .CLK_FREQ_HZ(20_000)
    ) dut (
        .clk        (clk),
        .reset_n    (reset_n),

        .haddr      (haddr),
        .hwrite     (hwrite),
        .htrans     (htrans),
        .hwdata     (hwdata),
        .hrdata     (hrdata),

        .hready     (hready),
        .hready_out (hready_out),
        .hresp      (hresp),
        .hsel       (hsel),

        .int_out    (int_out),
        .led_out    (led_out)
    );


    // ========================================================
    // Single-slave connection
    // ========================================================

    assign hready = hready_out;


    // ========================================================
    // Test sequence
    // ========================================================

    initial begin

        reset_n = 1'b0;

        repeat (3)
            @(posedge clk);

        reset_n = 1'b1;


        // ----------------------------------------------------
        // Enable interrupt
        // INT_MASK = 0
        // ----------------------------------------------------

        wr_data[0] = 32'h0000_0000;

        master.write(
            32'h0000_0004,
            wr_data,
            HSIZE_B32,
            8'h00,
            HBURST_SINGLE
        );

        master.idle();


        // ----------------------------------------------------
        // Enable alternate LEDs
        // CTL = 0xAAAA
        // ----------------------------------------------------

        wr_data[0] = 32'h0000_AAAA;

        master.write(
            32'h0000_0010,
            wr_data,
            HSIZE_B32,
            8'h00,
            HBURST_SINGLE
        );

        master.idle();


        // ----------------------------------------------------
        // Configure:
        // 1000 Hz
        // 50% duty cycle
        //
        // CFG = 0x0003E832
        // ----------------------------------------------------

        wr_data[0] = 32'h0003_E832;

        master.write(
            32'h0000_0014,
            wr_data,
            HSIZE_B32,
            8'h00,
            HBURST_SINGLE
        );

        master.idle();


        // ----------------------------------------------------
        // Read CTL
        // ----------------------------------------------------

        master.read_blocking(
            32'h0000_0010,
            rd_data,
            HSIZE_B32,
            8'h00,
            HBURST_SINGLE
        );


        // ----------------------------------------------------
        // Read CFG
        // ----------------------------------------------------

        master.read_blocking(
            32'h0000_0014,
            rd_data,
            HSIZE_B32,
            8'h00,
            HBURST_SINGLE
        );


        // ----------------------------------------------------
        // Wait for interrupt
        // ----------------------------------------------------

        wait(int_out == 1'b1);


        // ----------------------------------------------------
        // Read interrupt status
        // ----------------------------------------------------

        master.read_blocking(
            32'h0000_0008,
            rd_data,
            HSIZE_B32,
            8'h00,
            HBURST_SINGLE
        );


        // ----------------------------------------------------
        // Read masked interrupt status
        // ----------------------------------------------------

        master.read_blocking(
            32'h0000_000C,
            rd_data,
            HSIZE_B32,
            8'h00,
            HBURST_SINGLE
        );


        // ----------------------------------------------------
        // Clear interrupt
        // ----------------------------------------------------

        wr_data[0] = 32'h0000_0001;

        master.write(
            32'h0000_0000,
            wr_data,
            HSIZE_B32,
            8'h00,
            HBURST_SINGLE
        );

        master.idle();


        // ----------------------------------------------------
        // Wait until interrupt goes low
        // ----------------------------------------------------

        wait(int_out == 1'b0);


        // ----------------------------------------------------
        // Read interrupt status after clearing
        // ----------------------------------------------------

        master.read_blocking(
            32'h0000_0008,
            rd_data,
            HSIZE_B32,
            8'h00,
            HBURST_SINGLE
        );


        // Let waveform continue a little longer
        repeat (20)
            @(posedge clk);

        $finish;

    end

endmodule