/*****************************************************************************************
 * Marvin UART
 *
 *  Crude UART
 *  - 8N1 only
 *  - no FIFO
 *  - no interrupts
 *****************************************************************************************/

module maRVin_uart #(parameter integer CLOCK_FREQ = 9, parameter integer BAUDRATE = 3) (
    input clk,
    input nrst,
    input [31:0] address,
    input [31:0] data_in,
    output reg [31:0] data_out,
    input [3:0] wmask,
    input  valid,
    output reg ready,
    output reg uart_tx,
    input uart_rx
);
    
    localparam BIT_PERIOD = CLOCK_FREQ / BAUDRATE;
    localparam BIT_PERIOD_HALF = (CLOCK_FREQ / BAUDRATE) / 2;
    wire [7:0] addr_uart = address[7:0];

    reg  [7:0] data_tx;
    reg  [7:0] data_rx;
    reg strobe_tx;
    reg available_rx; 
    reg finish_rx;
    reg ready_tx;
    reg busy_rx;
    reg [$clog2(BIT_PERIOD)-1:0] tick_count_tx;
    reg [$clog2(BIT_PERIOD)-1:0] tick_count_rx;
    reg [2:0] bit_count_tx;    // Contador de bits transmitidos quando no estado S_DATA
    reg [2:0] bit_count_rx;    // Contador de bits recebidos quando no estado S_DATA
    
    localparam IDLE_bit  = 0;
    localparam START_bit = 1;
    localparam DATA_bit  = 2;
    localparam STOP_bit  = 3;
    localparam NSTATES   = 4;

    localparam S_IDLE  = 1 << IDLE_bit;
    localparam S_START = 1 << START_bit;
    localparam S_DATA  = 1 << DATA_bit;
    localparam S_STOP  = 1 << STOP_bit;

    (* onehot *)
    reg [NSTATES-1:0] tx_state;
    (* onehot *)
    reg [NSTATES-1:0] rx_state;

    /***************************************************************************
     * Decoding funcion register by address
     ***************************************************************************/
	always @(posedge clk) begin
        if (!nrst)
            available_rx <= 0;
        else begin
            ready <= valid;
            strobe_tx <= 1'b0;

            if (finish_rx) available_rx <= 1;

            if (valid) begin  
                case (addr_uart)
                    8'h00: begin // TX Port
                        if (wmask[0] & ready_tx) begin
                            strobe_tx <= 1'b1;  // sinaliza para começar a transmissão
                        end
                    end

                    8'h04: begin // RX Port
                        if (available_rx) begin
                            data_out <= { 24'b0, data_rx};
                            available_rx <= 0;
                        end
                    end

                    8'h08: begin // Status Port
                        data_out <= { 30'b0, available_rx, ready_tx};  // Retorna as flags da UART
                    end
                endcase
            end
        end
	end


    /***************************************************************************
     * Tick Counter for TX
     ***************************************************************************/
    always @(posedge clk) begin
        if (!nrst)
            tick_count_tx <= 0;
        else if (!ready_tx) begin
            if (tick_count_tx < BIT_PERIOD - 1)
                tick_count_tx <= tick_count_tx + 1;
            else
                tick_count_tx <= 0;
        end else
            tick_count_tx <= 0; // Zerar quando não estiver transmitindo
    end

    /***************************************************************************
     * Tick Counter for RX
     ***************************************************************************/
    always @(posedge clk) begin
        if (!nrst)
            tick_count_rx <= 0;
        else if (busy_rx) begin
            if (tick_count_rx < BIT_PERIOD - 1)
                tick_count_rx <= tick_count_rx + 1;
            else
                tick_count_rx <= 0;
        end else
            tick_count_rx <= 0; // Zerar quando não estiver recebendo
    end

    /***************************************************************************
     * State Machine for TX
     ***************************************************************************/
    always @(posedge clk) begin
        if(!nrst) begin
            tx_state <= S_IDLE;
            uart_tx <= 1'b1;
            ready_tx <= 1'b1;
            bit_count_tx <= 3'd0;
        end else
        (* parallel_case *)
        case(1'b1)
            tx_state[IDLE_bit]: begin
                uart_tx <= 1'b1;    // Idle: tx is HIGH
                ready_tx <= 1'b1;    // tx is free
                bit_count_tx <= 0;
                if (strobe_tx) begin
					data_tx <= data_in[7:0]; // Latch data to be sent
                    tx_state <= S_START;
                    ready_tx <= 1'b0;
                end
            end

            tx_state[START_bit]: begin
                uart_tx <= 1'b0; 
                if (tick_count_tx == BIT_PERIOD - 1)
                    tx_state <= S_DATA;
            end

            tx_state[DATA_bit]: begin
                uart_tx <= data_tx[0];          // Transmite o bit menos significativo (vai mudar com o shift)
                if (tick_count_tx == BIT_PERIOD - 1) begin
                    data_tx  <= data_tx >> 1;   // Desloca para pegar o proximo bit
                    if (bit_count_tx < 3'd7)
                        bit_count_tx <= bit_count_tx + 1;
                    else begin
                        bit_count_tx <= 3'd0;
                        tx_state <= S_STOP;
                    end
                end
            end

            tx_state[STOP_bit]: begin
                uart_tx <= 1'b1; 
                if (tick_count_tx == BIT_PERIOD - 1) begin
                    tx_state <= S_IDLE;
                    ready_tx <= 1'b1;
                end
            end
        endcase
    end

    /***************************************************************************
     * State Machine for RX
     ***************************************************************************/
    always @(posedge clk) begin
        if(!nrst) begin
            rx_state <= S_IDLE;
            busy_rx <= 1'b0;
            bit_count_rx <= 0;
            finish_rx <= 0;
        end else
        (* parallel_case *)
        case(1'b1)
            rx_state[IDLE_bit]: begin
                busy_rx <= 1'b0;    // tx is free
                finish_rx <= 0;
                if (!uart_rx) begin         //Se a linha cai pra zero é start bit!
                    bit_count_rx <= 0;
                    rx_state <= S_START;
                    busy_rx <= 1'b1; 
                end
            end

            rx_state[START_bit]: begin
                if (tick_count_rx == BIT_PERIOD_HALF) begin // Vai até a metade de bit period e checa novamente
                    if (!uart_rx) begin
                        data_rx <= 8'h0;
                        busy_rx <= 0;
                        rx_state <= S_DATA;
                    end else
                        rx_state <= S_IDLE;
                end
            end

            rx_state[DATA_bit]: begin
                busy_rx <= 1;
                if (tick_count_rx == BIT_PERIOD - 1) begin
                    data_rx <= {uart_rx, data_rx[7:1]};
                    if (bit_count_rx < 3'd7)
                        bit_count_rx <= bit_count_rx + 1;
                    else begin
                        bit_count_rx <= 3'd0;
                        rx_state <= S_STOP;
                    end
                end
            end

            rx_state[STOP_bit]: begin
                if (tick_count_rx == BIT_PERIOD - 1) begin
                    if (uart_rx) begin          // verifica se é Stop bit
                        finish_rx <= 1;
                    end 
                    rx_state <= S_IDLE;
                    busy_rx <= 1'b0; 
                end
            end
        endcase
    end

endmodule