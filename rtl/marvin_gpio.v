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
	inout [31:0] gpio   // Porta bidirecional de GPIO 
);

    // Mapeamento do registrador (último byte do endereço) para controle de gpio
    // GPIO_DIR (00): configuração da direção (0 = input, 1 = output)
    // GPIO_OUT (04): controle da saída + leitura dos pinos (configurado como entrada ou saída)
    localparam GPIO_DIR = 8'h00;
    localparam GPIO_OUT = 8'h04;
    wire [7:0] adr_gpio = address[7:0];

    // Registrador que configura da direção do pino 
    reg [31:0] gpio_dir;
    // Registrador que armazena o estado do pino, quando é uma saída
    reg [31:0] gpio_out;

    // Gera 32 assigns, um para cada pino. Cada assign configura o pino [i]
    // para apontar para gpio_out[i] ou para estado de alta impedância (1'bz),
    // dependendo do valor de gpio_dir[i]
    // No modo saída 0 = input, 1 = output
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
    				GPIO_DIR: begin // GPIO_DIR, configuração da direção
						data_out <= gpio_dir;

                        if (wmask[0]) gpio_dir[ 7: 0] <= data_in[ 7: 0];
                        if (wmask[1]) gpio_dir[15: 8] <= data_in[15: 8];
                        if (wmask[2]) gpio_dir[23:16] <= data_in[23:16];
                        if (wmask[3]) gpio_dir[31:24] <= data_in[31:24];
					end

    				GPIO_OUT: begin // GPIO_OUT, controle da saída + leitura dos pinos (configurado como entrada ou saída)
						data_out <= gpio;

						if (wmask[0]) gpio_out[ 7: 0] <= data_in[ 7: 0];
						if (wmask[1]) gpio_out[15: 8] <= data_in[15: 8];
						if (wmask[2]) gpio_out[23:16] <= data_in[23:16];
						if (wmask[3]) gpio_out[31:24] <= data_in[31:24];
					end

    				default: data_out <= 32'h0; // endereço não mapeado dentro do periférico
    			endcase
			end
		end
	end

endmodule
