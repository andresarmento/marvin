/*********************************************************************************
 * MaRVin v0.1 - RISC-V Soc (RV32I)
 * André Sarmento - 2025-2026
 *
 *
 * Devices:
 * 	 Memory (maRVin_mem) : 0h'0000_0000 (ROM)
 * 	                       0h'8000_0000 (RAM)
 * 	 GPIO   (maRVin_gpio): 0h'C000_0000
 *********************************************************************************/

module maRVin (
	input clk,		            // Clock input
	input nrst,		            // Reset (low logic)
    output [31:0] address,
    // inout [31:0] gpio,       // Real FPGA interface
    // Digital workaround:
    output  [1:0] gpio_out,     // pins 0,1: output 
    input         gpio_in,      // pin 2: dedicated input-only signal, workaround for Digital's
                                // ExternalFile/IVERILOG bridge not supporting true inout in cosimulation
    output [31:0] dbg_x1,
    output [31:0] dbg_x2,
    output [31:0] dbg_x15
);

    //Tests
    assign address = cpu_addr;
    wire [2:0] gpio;
    assign gpio_out = gpio[1:0];
    assign gpio[2]   = gpio_in;

    // CPU signals
    wire [31:0] cpu_addr; 
    wire [31:0] cpu_rdata;
    wire [31:0] cpu_wdata;
    wire [3:0]  cpu_wmask;
    wire 	    cpu_valid;
    wire 	    cpu_ready;

    // Memory signals
    wire [31:0] mem_rdata;
    wire mem_ready;
    wire mem_valid;

    // GPIO signals
    wire [31:0] gpio_rdata;
    wire gpio_ready;
    wire gpio_valid;

	// Mapeamento da memória ROM
    localparam ROM_ADDR_BASE = 32'h 0000_0000;	// Este endereco e máscara vão selecionar a ROM para
    localparam ROM_ADDR_MASK = 32'h 8000_0000;   // qualquer endereco na faixa de 0000_0000 a 7FFF_FFFF
    wire rom_selected  = ((cpu_addr & ROM_ADDR_MASK) == ROM_ADDR_BASE);	
  
  	// Mapeamento da memória RAM
    localparam RAM_ADDR_BASE = 32'h 8000_0000;	// Este endereco e máscara vão selecionar a RAM para
    localparam RAM_ADDR_MASK = 32'h C000_0000;   // qualquer endereco na faixa de 8000_0000 a BFFF_FFFF
    wire ram_selected  = ((cpu_addr & RAM_ADDR_MASK) == RAM_ADDR_BASE);	

    wire mem_selected = rom_selected | ram_selected;
    
    // Mapeamento do GPIO				
    localparam GPIO_ADDR_BASE = 32'h C000_0000; // Este endereco e máscara vão selecionar GPIO para
    localparam GPIO_ADDR_MASK = 32'h FFFF_FF00; // qualquer endereco na faixa de C000_0000 a C000_00FF
    wire gpio_selected = ((cpu_addr & GPIO_ADDR_MASK) == GPIO_ADDR_BASE);
    
    // Mux/Demux Devices
    assign mem_valid  = cpu_valid & mem_selected;
    assign gpio_valid = cpu_valid & gpio_selected;

    // Mux para o sinal de ready
	assign cpu_ready = (mem_selected) ? mem_ready :
    				   (gpio_selected) ? gpio_ready : 1'b0;

	// Mux para das leituras de dados 
	assign cpu_rdata = (mem_selected) ? mem_rdata :
					   (gpio_selected) ? gpio_rdata : 32'h0000_0000;

    /*********************************************************************************
    * CPU Instance (maRVin_cpu)
    *********************************************************************************/
    maRVin_cpu #(.RESET_ADDR(32'h0000_0000), .ADDR_WIDTH(32)) _maRVin_cpu (
        .clk  (clk),
        .nrst (nrst),
        .mem_addr  (cpu_addr),
        .mem_rdata (cpu_rdata),
        .mem_wdata (cpu_wdata),
        .mem_wmask (cpu_wmask),	
        .mem_valid (cpu_valid),
        .mem_ready (cpu_ready),
        .dbg_x1 (dbg_x1),
        .dbg_x2 (dbg_x2),
        .dbg_x15 (dbg_x15)
    );

    /*********************************************************************************
    *  ROM/RAM Memory Instance (maRVin_mem) 
    *********************************************************************************/
    maRVin_mem #(.WORDS(2048)) _maRVin_mem ( // 2K 32 bit words = 8K Bytes  
        .clk  (clk),
        .nrst (nrst),
        .address    (cpu_addr),
        .data_in    (cpu_wdata),	
        .wmask      (cpu_wmask),
        .valid      (mem_valid),
        .ready      (mem_ready),
        .data_out   (mem_rdata)
    );	

    /*********************************************************************************
    * GPIO Instance
    *********************************************************************************/
    maRVin_gpio #() _maRVin_gpio (
        .clk  (clk),
        .nrst (nrst),
        .address  (cpu_addr),
        .data_in  (cpu_wdata),
        .wmask    (cpu_wmask),
        .valid    (gpio_valid),
        .ready    (gpio_ready),
        .data_out (gpio_rdata),
        .gpio     (gpio)
    );

endmodule
