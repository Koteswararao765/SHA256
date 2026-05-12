`default_nettype none

module uart_tx #(
    parameter CLKS_PER_BIT = 434 // 50 MHz / 115200 baud = 434
)(
    input  wire       clk,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx_active,
    output reg        tx_serial,
    output reg        tx_done
);

    localparam s_IDLE         = 3'b000;
    localparam s_TX_START_BIT = 3'b001;
    localparam s_TX_DATA_BITS = 3'b010;
    localparam s_TX_STOP_BIT  = 3'b011;
    localparam s_CLEANUP      = 3'b100;

    reg [2:0]  r_SM_Main     = 0;
    reg [15:0] r_Clock_Count = 0;
    reg [2:0]  r_Bit_Index   = 0;
    reg [7:0]  r_Tx_Data     = 0;

    always @(posedge clk) begin
        case (r_SM_Main)
            s_IDLE: begin
                tx_serial <= 1'b1; tx_done <= 1'b0;
                r_Clock_Count <= 0; r_Bit_Index <= 0;
                if (tx_start == 1'b1) begin
                    tx_active <= 1'b1; r_Tx_Data <= tx_data; r_SM_Main <= s_TX_START_BIT;
                end else tx_active <= 1'b0;
            end

            s_TX_START_BIT: begin
                tx_serial <= 1'b0;
                if (r_Clock_Count < CLKS_PER_BIT-1) r_Clock_Count <= r_Clock_Count + 1;
                else begin r_Clock_Count <= 0; r_SM_Main <= s_TX_DATA_BITS; end
            end

            s_TX_DATA_BITS: begin
                tx_serial <= r_Tx_Data[r_Bit_Index];
                if (r_Clock_Count < CLKS_PER_BIT-1) r_Clock_Count <= r_Clock_Count + 1;
                else begin
                    r_Clock_Count <= 0;
                    if (r_Bit_Index < 7) r_Bit_Index <= r_Bit_Index + 1;
                    else begin r_Bit_Index <= 0; r_SM_Main <= s_TX_STOP_BIT; end
                end
            end

            s_TX_STOP_BIT: begin
                tx_serial <= 1'b1;
                if (r_Clock_Count < CLKS_PER_BIT-1) r_Clock_Count <= r_Clock_Count + 1;
                else begin
                    r_Clock_Count <= 0; tx_done <= 1'b1; tx_active <= 1'b0; r_SM_Main <= s_CLEANUP;
                end
            end

            s_CLEANUP: begin tx_done <= 1'b1; r_SM_Main <= s_IDLE; end
            default: r_SM_Main <= s_IDLE;
        endcase
    end
endmodule
