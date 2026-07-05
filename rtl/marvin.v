/*********************************************************************************
 * MaRVin v0.1 - RISC-V Soc (RV32I)
 * André Sarmento - 2025-2026
 *
 *
 * Devices:
 * 	Memory (maRVin_mem) : ROM  (Program Memory -> 0h'0000_0000)
 * 	                      RAM  (Data Memory    -> 0h'8000_0000)
 *********************************************************************************/

module maRVin (
	input clk,		            // Clock input
	input nrst,		            // Reset (low logic)
    output [31:0] address,
    output [31:0] dbg_x1,
    output [31:0] dbg_x2,
    output [31:0] dbg_x15,
    output [3:0]  dbg_state
);

    //Tests
    assign address = cpu_addr;

    // CPU signals
    wire [31:0] cpu_addr; 
    wire [31:0] cpu_rdata;
    wire [31:0] cpu_wdata;
    wire [3:0]  cpu_wmask; // Write mask for the 4 bytes of each word
    wire 	    cpu_valid;
    wire 	    cpu_ready;

    // Memory signals
    wire [31:0] mem_rdata;
    wire mem_ready;
    wire mem_valid;
    assign mem_valid = cpu_valid;
	assign cpu_ready =  mem_ready;
	assign cpu_rdata = mem_rdata;

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
        .dbg_x15 (dbg_x15),
        .dbg_state (dbg_state)
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

endmodule