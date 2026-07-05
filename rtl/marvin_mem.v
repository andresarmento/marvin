/*****************************************************************************************
 * RISC-V Memory
 *
 *
 *****************************************************************************************/
`define HEX_FILES_PATH "C:/Users/andre/Downloads/PROJECTS/marvin/sw/examples/"

module maRVin_mem #(parameter integer WORDS = 1024) (
    input wire        clk,
    input wire        nrst,
    input wire [31:0] address,
    output reg [31:0] data_out,
    input wire        valid,
    output reg        ready,
    input wire [31:0] data_in,
    input wire [3:0]  wmask
);   

    (* ram_style = "block" *)
    reg [31:0] memory [0:WORDS-1];

    initial $readmemh({`HEX_FILES_PATH, "02_loop_c/loop_c.hex"}, memory);

    // ROM/RAM Mapping
    parameter RAM_ADDR_BASE = 32'h 8000_0000;	// RAM Base Address
    parameter RAM_ADDR_MASK = 32'h C000_0000;   // RAM Mask (8000_0000 a BFFF_FFFF)
    wire ram_selected  = ((address & RAM_ADDR_MASK) == RAM_ADDR_BASE);
    // Only the low 12 bits of the address are actually decoded, so the real 4KB of
    // physical RAM (the array's upper half, offset by 0x1000) is mirrored across the
    // entire 1GB RAM window (0x8000_0000-0xBFFF_FFFF): any address in that range with
    // the same low 12 bits hits the same physical word.
    wire [31:0] phy_address = ram_selected ? (address & 16'h0FFF) | 16'h1000 : address;
    
    always @(posedge clk) begin
        if (!nrst) begin 
            ready <= 1'h1;
        end else begin
            ready <= valid;

            if (valid) begin
                data_out <= memory[phy_address[31:2]];   

                if(wmask[0]) memory[phy_address[31:2]][ 7:0 ] <= data_in[ 7:0 ];
                if(wmask[1]) memory[phy_address[31:2]][15:8 ] <= data_in[15:8 ];
                if(wmask[2]) memory[phy_address[31:2]][23:16] <= data_in[23:16];
                if(wmask[3]) memory[phy_address[31:2]][31:24] <= data_in[31:24];
            end
        end
    end
endmodule
