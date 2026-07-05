/*********************************************************************************
 * MaRVin GPIO
 *	
 *
 *
 *********************************************************************************/

module maRVin_gpio (
	input 		 clk,
	input 		 nrst,
	input [31:0] address,
	input [31:0] data_in,
	output reg [31:0] data_out,
	input [3:0]	 wmask,
	input        valid,
	output reg   ready,
	inout [31:0] gpio   // GPIO bidirectional port
);

    // Register map (last byte of the address) for GPIO control
    // GPIO_READ     (00): read the current pin state (input or output)
    // GPIO_SET      (04): set gpio_out bits (atomic OR with data_in)
    // GPIO_CLR      (08): clear gpio_out bits (atomic AND with ~data_in)
    // GPIO_DIR_READ (0C): read the direction register
    // GPIO_DIR_SET  (10): set gpio_dir bits (atomic OR with data_in)
    // GPIO_DIR_CLR  (14): clear gpio_dir bits (atomic AND with ~data_in)
    // GPIO_TOG      (18): toggle gpio_out bits (atomic XOR with data_in)
    localparam GPIO_READ = 8'h00;
    localparam GPIO_SET  = 8'h04;
    localparam GPIO_CLR  = 8'h08;
    localparam GPIO_DIR_READ = 8'h0C;
	localparam GPIO_DIR_SET  = 8'h10;
	localparam GPIO_DIR_CLR  = 8'h14;
	localparam GPIO_TOG      = 8'h18;

    wire [7:0] adr_gpio = address[7:0];

    // Register that configures the pin direction
    reg [31:0] gpio_dir;
    // Register that holds the pin state, when configured as output
    reg [31:0] gpio_out;

    // Generates 32 assigns, one per pin. Each assign drives pin [i]
    // to gpio_out[i] or to high-impedance (1'bz), depending on gpio_dir[i]
    // In output mode: 0 = input, 1 = output
    genvar i;
	generate
		 for (i = 0; i < 32; i = i + 1) begin : gpio_ctrl
			  assign gpio[i] = (gpio_dir[i]) ? gpio_out[i] : 1'bz; 
		 end
	endgenerate

	always @(posedge clk) begin
		if (!nrst) begin
			gpio_out <= 32'b 0;
			gpio_dir <= 32'h 0;
			data_out <= 32'h 0;
			ready <= 0;
		end else begin
			ready <= valid; 

			if (valid) begin  
				case (adr_gpio)
    				GPIO_READ: begin 
                        data_out <= gpio;
					end

    				GPIO_SET: begin 
                        if (wmask[0]) gpio_out[ 7: 0] <= gpio_out[ 7: 0] | data_in[ 7: 0];
                        if (wmask[1]) gpio_out[15: 8] <= gpio_out[15: 8] | data_in[15: 8];
                        if (wmask[2]) gpio_out[23:16] <= gpio_out[23:16] | data_in[23:16];
                        if (wmask[3]) gpio_out[31:24] <= gpio_out[31:24] | data_in[31:24];
					end

    				GPIO_CLR: begin 
                        if (wmask[0]) gpio_out[ 7: 0] <= gpio_out[ 7: 0] & ~data_in[ 7: 0];
                        if (wmask[1]) gpio_out[15: 8] <= gpio_out[15: 8] & ~data_in[15: 8];
                        if (wmask[2]) gpio_out[23:16] <= gpio_out[23:16] & ~data_in[23:16];
                        if (wmask[3]) gpio_out[31:24] <= gpio_out[31:24] & ~data_in[31:24];
					end

					GPIO_DIR_READ: begin // GPIO_DIR_READ, read the direction register
						data_out <= gpio_dir;
					end

					GPIO_DIR_SET: begin // GPIO_DIR_SET, direction configuration (set)
                        if (wmask[0]) gpio_dir[ 7: 0] <= gpio_dir[ 7: 0] | data_in[ 7: 0];
                        if (wmask[1]) gpio_dir[15: 8] <= gpio_dir[15: 8] | data_in[15: 8];
                        if (wmask[2]) gpio_dir[23:16] <= gpio_dir[23:16] | data_in[23:16];
                        if (wmask[3]) gpio_dir[31:24] <= gpio_dir[31:24] | data_in[31:24];
					end

					GPIO_DIR_CLR: begin // GPIO_DIR_CLR, direction configuration (clr)
                        if (wmask[0]) gpio_dir[ 7: 0] <= gpio_dir[ 7: 0] & ~data_in[ 7: 0];
                        if (wmask[1]) gpio_dir[15: 8] <= gpio_dir[15: 8] & ~data_in[15: 8];
                        if (wmask[2]) gpio_dir[23:16] <= gpio_dir[23:16] & ~data_in[23:16];
                        if (wmask[3]) gpio_dir[31:24] <= gpio_dir[31:24] & ~data_in[31:24];
					end

					GPIO_TOG: begin
                        if (wmask[0]) gpio_out[ 7: 0] <= gpio_out[ 7: 0] ^ data_in[ 7: 0];
                        if (wmask[1]) gpio_out[15: 8] <= gpio_out[15: 8] ^ data_in[15: 8];
                        if (wmask[2]) gpio_out[23:16] <= gpio_out[23:16] ^ data_in[23:16];
                        if (wmask[3]) gpio_out[31:24] <= gpio_out[31:24] ^ data_in[31:24];
					end
    			endcase
			end
		end
	end
endmodule