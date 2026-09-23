`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:51:24 09/28/2022 
// Design Name: 
// Module Name:    CtrlModule 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module CtrlModule(
    input clk,
    input reset_n,
    output [31:0] host_bootdata,
    output host_bootdata_req,
    input host_bootdata_ack
    );


// ZPU signals
localparam maxAddrBit = 20; //Optional - defaults to 32 - but helps keep the logic element count down.
wire mem_busy;
wire [wordSize-1:0] mem_read;
wire [wordSize-1:0] mem_write;
wire [maxAddrBit:0] mem_addr;
wire mem_writeEnable; 
wire mem_readEnable;
wire mem_hEnable; 
wire mem_bEnable; 

ZPU_ToROM zpu_to_rom;
ZPU_FromROM zpu_from_rom;



// Main CPU
// We instantiate the CPU with the optional instructions enabled, which allows us to reduce
// the size of the ROM by leaving out emulation code.
zpu_core_flex #(
	
		.IMPL_MULTIPLY(true),
		.IMPL_COMPARISON_SUB(true),
		.IMPL_EQBRANCH(true),
		.IMPL_STOREBH(true),
		.IMPL_LOADBH(true),
		.IMPL_CALL(true),
		.IMPL_SHIFT(true),
		.IMPL_XOR(true),
		.CACHE(true),	// Modest speed-up when running from ROM
//		.IMPL_EMULATION(minimal, // Emulate only byte/halfword accesses, with alternateive emulation table
		.REMAP_STACK(false), // We're not using SDRAM so no need to remap the Boot ROM / Stack RAM
		.EXECUTE_RAM(false), // We don't need to execute code from external RAM.
		.maxAddrBit(maxAddrBit),
		.maxAddrBitBRAM(13)
		) 
	   zpu( 
		.clk(clk),
		.reset(~reset_n),
		.in_mem_busy(mem_busy),
		.mem_read(mem_read),
		.mem_write(mem_write),
		.out_mem_addr(mem_addr),
		.out_mem_writeEnable(mem_writeEnable),
		.out_mem_hEnable(mem_hEnable),
		.out_mem_bEnable(mem_bEnable),
		.out_mem_readEnable(mem_readEnable),
		.from_rom(zpu_from_rom),
		.to_rom(zpu_to_rom),
		.interrupt(int_req)
	);




endmodule
