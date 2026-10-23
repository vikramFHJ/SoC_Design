`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.10.2026 15:27:10
// Design Name: 
// Module Name: sev_seg
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps

module sev_seg#(
    parameter int ADDR_W = 12
)(
    // --------------------------------------------------
    // Global signals
    // --------------------------------------------------
    input  wire                 clk,
    input  wire                 rst_n,

    // --------------------------------------------------
    // APB slave interface
    // --------------------------------------------------
    input  wire [ADDR_W-1:0]    paddr,
    input  wire                 penable,
    input  wire                 psel,
    input  wire                 pwrite,
    input  wire [31:0]          pwdata,

    output logic                pready,
    output logic                pslverr,
    output logic [31:0]         prdata,

    // --------------------------------------------------
    // 7-segment outputs
    // --------------------------------------------------
    output logic [6:0]          seg7_seg,
    output logic [3:0]          seg7_an,
    output logic                seg7_dp
);

    // ==================================================
    // Register addresses
    // ==================================================

    localparam logic [ADDR_W-1:0] ADDR_CTL = 'h000;
    localparam logic [ADDR_W-1:0] ADDR_VAL = 'h004;
    localparam logic [ADDR_W-1:0] ADDR_DIM = 'h008;


    // ==================================================
    // Internal registers
    // ==================================================

    logic        enable;

    logic [3:0]  digit0;
    logic [3:0]  digit1;
    logic [3:0]  digit2;
    logic [3:0]  digit3;

    logic        dp0;
    logic        dp1;
    logic        dp2;
    logic        dp3;

    logic [3:0]  dim_value;


    // ==================================================
    // APB write logic
    // ==================================================

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin

        enable    <= 1'b0;

        digit0    <= 4'd0;
        digit1    <= 4'd0;
        digit2    <= 4'd0;
        digit3    <= 4'd0;

        dp0       <= 1'b0;
        dp1       <= 1'b0;
        dp2       <= 1'b0;
        dp3       <= 1'b0;

        dim_value <= 4'd0;

    end
    else begin

        if (psel && penable && pwrite) begin

            case (paddr)

                ADDR_CTL: begin
                    enable <= pwdata[0];
                end


                ADDR_VAL: begin

                    // Only values 0...9 are valid
                    if (pwdata[3:0] <= 4'd9)
                        digit0 <= pwdata[3:0];

                    if (pwdata[7:4] <= 4'd9)
                        digit1 <= pwdata[7:4];

                    if (pwdata[11:8] <= 4'd9)
                        digit2 <= pwdata[11:8];

                    if (pwdata[15:12] <= 4'd9)
                        digit3 <= pwdata[15:12];

                    // Decimal points
                    dp0 <= pwdata[16];
                    dp1 <= pwdata[20];
                    dp2 <= pwdata[24];
                    dp3 <= pwdata[28];

                end


                ADDR_DIM: begin
                    dim_value <= pwdata[3:0];
                end


                default: begin
                    // Keep previous register values
                end

            endcase
        end
    end
end

    // ==================================================
    // APB response
    // ==================================================

    always_comb begin

        pready  = 1'b1;
        pslverr = 1'b0;

    end


    // ==================================================
    // APB read logic
    // ==================================================

    always_comb begin

        prdata = 32'h0000_0000;

        case (paddr)

            ADDR_CTL: begin
            prdata[0]=enable;
            prdata[31:1]=31'd0;
                // TODO:
                
                // return enable bit
            end

            ADDR_VAL: begin
              prdata[3:0]=digit0;
              prdata[7:4]=digit1;
              prdata[11:8]=digit2;
              prdata[15:12]=digit3;
              
              prdata[16]=dp0;
              prdata[20]=dp1;
              prdata[24]=dp2;
              prdata[28]=dp3;              
              
                
            end

            ADDR_DIM: begin
              
                prdata[3:0] = dim_value;
                // return dimming value
            end

            default: begin
                prdata = 32'h0000_0000;
            end

        endcase

    end


    // ==================================================
    // Digit multiplexing
    // ==================================================

    logic [15:0] refresh_counter;
    logic [1:0]  display_number;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            refresh_counter <= 16'd0;
            display_number    <= 2'd0;

        end
        else begin
           

            if(refresh_counter==20) begin

                refresh_counter<=0;

                if(display_number==2'b11)

                    display_number<=2'b00;

                else begin

                    display_number<=display_number+1;
                end

            end

            else begin
                 refresh_counter <= refresh_counter + 1'b1;
            end


            // TODO:
            // increment refresh_counter

            // TODO:
            // when counter reaches chosen value:
            // reset counter
            // move to next digit

        end
    end


    // ==================================================
    // Select active digit
    // ==================================================

    logic [3:0] current_digit;
    logic       current_dp;
    logic [3:0] dim_counter;
    logic       dim_on;


    always_comb begin

        current_digit = 4'd0;
        current_dp    = 1'b0;
        seg7_an       = 4'b1111;

        if (enable) begin

            case (display_number)

                2'd0: begin
                    current_digit = digit0;
                    current_dp    = dp0;
                    if(dim_on)
                        seg7_an       = 4'b1110;
                    else
                        seg7_an       = 4'b1111;


                    // TODO:
                    // enable digit 0
                end

                2'd1: begin
                    current_digit = digit1;
                    current_dp    = dp1;
                    if(dim_on)
                        seg7_an       = 4'b1101;
                    else
                        seg7_an       = 4'b1111;
                    // TODO:
                    // enable digit 1
                end

                2'd2: begin
                    current_digit = digit2;
                    current_dp    = dp2;
                    if(dim_on)
                        seg7_an       = 4'b1011;
                
                    else
                        seg7_an       = 4'b1111;
                    // TODO:
                    // enable digit 2
                end

                2'd3: begin
                    current_digit = digit3;
                    current_dp    = dp3;
                    if(dim_on)
                        seg7_an       = 4'b0111;
                    else
                        seg7_an       = 4'b1111;
                    // TODO:
                    // enable digit 3
                end

                default: begin
                    current_digit = 4'd0;
                    current_dp    = 1'b0;
                    seg7_an       = 4'b1111;
                end

            endcase

        end

    end


    // ==================================================
    // 7-segment decoder
    // ==================================================

    always_comb begin

        case (current_digit)

            4'd0: seg7_seg = 7'b1000000; 
            4'd1: seg7_seg = 7'b1111001; // TODO
            4'd2: seg7_seg = 7'b0100100; // TODO
            4'd3: seg7_seg = 7'b0110000; // TODO
            4'd4: seg7_seg = 7'b0011001; // TODO
            4'd5: seg7_seg = 7'b0010010; // TODO
            4'd6: seg7_seg = 7'b0000010; // TODO
            4'd7: seg7_seg = 7'b1111000; // TODO
            4'd8: seg7_seg = 7'b0000000; // TODO
            4'd9: seg7_seg = 7'b0010000; // TODO

            default:
                seg7_seg = 7'b1111111;

        endcase

    end


    // ==================================================
    // Decimal point
    // ==================================================

    always_comb begin

        // TODO:
        // Basys3 decimal point is typically active-low,
        // so think carefully about inversion here.

        seg7_dp = 1'b1;

        if(enable)
        begin
        seg7_dp = ~current_dp;  //Active low
        end

    end


    // ==================================================
    // Dimming
    // ==================================================



always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || refresh_counter==16'd0)
        dim_counter <= 4'd0;
    else
        dim_counter <= dim_counter + 1'b1;
end

always_comb begin
    dim_on = (dim_counter<dim_value);  //15 clks is the maximum, it won't be on for more than that
end


endmodule
