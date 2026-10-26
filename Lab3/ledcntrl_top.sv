module ledcntrl_top #(
    parameter int CLK_FREQ_HZ = 100_000_000
)(
    // --------------------------------------------------------
    // Global signals
    // --------------------------------------------------------
    input  wire         clk,
    input  wire         reset_n,

    // --------------------------------------------------------
    // AHB slave interface
    // --------------------------------------------------------
    input  wire [31:0]  haddr,
    input  wire         hwrite,
    input  wire [1:0]   htrans,
    input  wire [31:0]  hwdata,
    output logic [31:0] hrdata,
    input  wire         hready,
    output logic        hready_out,
    output logic        hresp,
    input wire hsel,
    // --------------------------------------------------------
    // Interrupt
    // --------------------------------------------------------
    output logic        int_out,

    // --------------------------------------------------------
    // LEDs
    // --------------------------------------------------------
    output logic [15:0] led_out
);

    // ========================================================
    // Register addresses
    // ========================================================

    localparam logic [11:0] ADDR_INT_CLR    = 12'h000;
    localparam logic [11:0] ADDR_INT_MASK   = 12'h004;
    localparam logic [11:0] ADDR_INT_STAT   = 12'h008;
    localparam logic [11:0] ADDR_INT_MASKED = 12'h00C;
    localparam logic [11:0] ADDR_CTL        = 12'h010;
    localparam logic [11:0] ADDR_CFG        = 12'h014;


    // ========================================================
    // Internal registers
    // ========================================================

    logic        int_status;
    logic        int_mask;

    logic [15:0] led_enable;

    logic [7:0]  duty_cycle;
    logic [15:0] frequency;


    // ========================================================
    // AHB address/control phase storage
    // ========================================================
    //
    // AHB transfers the address/control first.
    // The write data arrives in the following data phase.
    //

    logic [11:0] addr_d;
    logic        write_d;
    logic        valid_d;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            addr_d  <= 12'h000;
            write_d <= 1'b0;
            valid_d <= 1'b0;
        end
        else if (hready) begin

            // HTRANS[1] = 1 means NONSEQ or SEQ:
            // a valid AHB transfer.
            valid_d <= hsel && htrans[1];

           if (hsel && htrans[1]) begin
                addr_d  <= haddr[11:0];
                write_d <= hwrite;
            end
        end
    end


    // ========================================================
    // AHB response
    // ========================================================

    // This slave does not insert wait states
    // and does not generate bus errors.

    always_comb begin
        hready_out = 1'b1;
        hresp      = 1'b0;
    end


    // ========================================================
    // PWM calculations
    // ========================================================

    logic [31:0] pwm_counter;
    logic [31:0] period_cycles;
    logic [31:0] on_cycles;

    logic frequency_valid;
    logic pwm_on;
    logic terminal_count;


    // Allowed range according to the specification:
    // 500 Hz ... 10 kHz

    always_comb begin

        frequency_valid =
            (frequency >= 16'd500) &&
            (frequency <= 16'd10000);


        if (frequency_valid) begin

            // Example:
            //
            // 100 MHz clock
            // 1000 Hz PWM
            //
            // 100,000,000 / 1000 = 100,000 clock cycles

            period_cycles = CLK_FREQ_HZ / frequency;


            // Duty cycle is interpreted as percentage.
            //
            // Example:
            // duty_cycle = 50
            // -> LED is ON for 50% of the PWM period.

            on_cycles =
                (period_cycles * duty_cycle) / 100;

        end
        else begin
            period_cycles = 32'd0;
            on_cycles     = 32'd0;
        end
    end


    // PWM is ON while the counter is below the
    // calculated ON time.

    always_comb begin
        pwm_on = 1'b0;

        if (frequency_valid) begin

            if (duty_cycle >= 8'd100)
                pwm_on = 1'b1;

            else if (pwm_counter < on_cycles)
                pwm_on = 1'b1;

        end
    end


    // Terminal count = end of one PWM period.

    always_comb begin
        terminal_count = 1'b0;

        if (frequency_valid &&
            (pwm_counter >= period_cycles - 1)) begin

            terminal_count = 1'b1;

        end
    end


    // ========================================================
    // PWM counter
    // ========================================================

    always_ff @(posedge clk or negedge reset_n) begin

        if (!reset_n) begin
            pwm_counter <= 32'd0;
        end

        else if (!frequency_valid) begin
            pwm_counter <= 32'd0;
        end

        else if (terminal_count) begin
            pwm_counter <= 32'd0;
        end

        else begin
            pwm_counter <= pwm_counter + 1'b1;
        end

    end


    // ========================================================
    // LED outputs
    // ========================================================
    //
    // led_enable decides WHICH LEDs are enabled.
    // pwm_on decides WHETHER the enabled LEDs are currently ON.
    //

    always_comb begin

        if (pwm_on)
            led_out = led_enable;
        else
            led_out = 16'h0000;

    end


    // ========================================================
    // Register writes
    // ========================================================

    always_ff @(posedge clk or negedge reset_n) begin

        if (!reset_n) begin

            // Interrupt masked after reset
            int_mask   <= 1'b1;
            int_status <= 1'b0;

            led_enable <= 16'h0000;

            duty_cycle <= 8'd0;
            frequency  <= 16'd0;

        end
        else begin

            // ------------------------------------------------
            // Interrupt generation
            // ------------------------------------------------

            // Set interrupt status whenever one PWM period
            // finishes.

            if (terminal_count)
                int_status <= 1'b1;


            // ------------------------------------------------
            // AHB write
            // ------------------------------------------------

            if (valid_d && write_d) begin

                case (addr_d)

                    // ----------------------------------------
                    // Interrupt clear
                    // ----------------------------------------
                    ADDR_INT_CLR: begin

                        // Writing 1 clears the interrupt.
                        if (hwdata[0])
                            int_status <= 1'b0;          

                    end


                    // ----------------------------------------
                    // Interrupt mask
                    // ----------------------------------------
                    ADDR_INT_MASK: begin

                        int_mask <= hwdata[0];

                    end


                    // ----------------------------------------
                    // LED enable register
                    // ----------------------------------------
                    ADDR_CTL: begin

                        led_enable <= hwdata[15:0];

                    end


                    // ----------------------------------------
                    // PWM configuration
                    // ----------------------------------------
                    ADDR_CFG: begin

                        duty_cycle <= hwdata[7:0];
                        frequency  <= hwdata[23:8];

                    end


                    default: begin
                        // No action
                    end

                endcase
            end
        end
    end


    // ========================================================
    // Register reads
    // ========================================================

    always_comb begin

        hrdata = 32'h0000_0000;

        case (addr_d)

            ADDR_INT_CLR: begin     ///
                hrdata = 32'h0000_0000;
            end


            ADDR_INT_MASK: begin
                hrdata[0] = int_mask;
            end


            ADDR_INT_STAT: begin
                hrdata[0] = int_status;
            end


            ADDR_INT_MASKED: begin
                hrdata[0] = int_status & ~int_mask;
            end


            ADDR_CTL: begin
                hrdata[15:0] = led_enable;
            end


            ADDR_CFG: begin
                hrdata[7:0]  = duty_cycle;
                hrdata[23:8] = frequency;
            end


            default: begin
                hrdata = 32'h0000_0000;
            end

        endcase
    end


    // ========================================================
    // Interrupt output
    // ========================================================

    // Interrupt appears at the output only when:
    //
    // status = 1
    // AND
    // mask   = 0

    always_comb begin
        int_out = int_status & ~int_mask;
    end


endmodule