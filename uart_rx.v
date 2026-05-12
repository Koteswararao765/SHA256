`default_nettype none

module uart_rx #(
    parameter CLKS_PER_BIT = 434 // 50 MHz / 115200 baud = 434
)(
    input  wire       clk,
    input  wire       rx_serial,
    output reg        rx_dv,     // Data Valid pulse
    output reg [7:0]  rx_byte    // The received character
);

    localparam s_IDLE         = 3'b000;
    localparam s_RX_START_BIT = 3'b001;
    localparam s_RX_DATA_BITS = 3'b010;
    localparam s_RX_STOP_BIT  = 3'b011;
    localparam s_CLEANUP      = 3'b100;

    reg [2:0]  r_SM_Main     = 0;
    reg [15:0] r_Clock_Count = 0;
    reg [2:0]  r_Bit_Index   = 0;

    always @(posedge clk) begin
        case (r_SM_Main)
            s_IDLE: begin
                rx_dv         <= 1'b0;
                r_Clock_Count <= 0;
                r_Bit_Index   <= 0;
                if (rx_serial == 1'b0) r_SM_Main <= s_RX_START_BIT;
            end

            s_RX_START_BIT: begin
                if (r_Clock_Count == (CLKS_PER_BIT-1)/2) begin 
                    if (rx_serial == 1'b0) begin
                        r_Clock_Count <= 0;
                        r_SM_Main     <= s_RX_DATA_BITS;
                    end else r_SM_Main <= s_IDLE; 
                end else r_Clock_Count <= r_Clock_Count + 1;
            end

            s_RX_DATA_BITS: begin
                if (r_Clock_Count < CLKS_PER_BIT-1) begin
                    r_Clock_Count <= r_Clock_Count + 1;
                end else begin
                    r_Clock_Count          <= 0;
                    rx_byte[r_Bit_Index]   <= rx_serial;
                    if (r_Bit_Index < 7) r_Bit_Index <= r_Bit_Index + 1;
                    else begin r_Bit_Index <= 0; r_SM_Main <= s_RX_STOP_BIT; end
                end
            end

            s_RX_STOP_BIT: begin
                if (r_Clock_Count < CLKS_PER_BIT-1) r_Clock_Count <= r_Clock_Count + 1;
                else begin rx_dv <= 1'b1; r_Clock_Count <= 0; r_SM_Main <= s_CLEANUP; end
            end

            s_CLEANUP: begin rx_dv <= 1'b0; r_SM_Main <= s_IDLE; end
            default: r_SM_Main <= s_IDLE;
        endcase
    end
endmodule
