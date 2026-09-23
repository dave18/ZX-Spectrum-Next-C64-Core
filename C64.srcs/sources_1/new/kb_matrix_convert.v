`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.09.2026 10:12:08
// Design Name: 
// Module Name: kb_matrix_convert
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


module kb_matrix_convert(
    input clk,
    input reset,
    input [6:0] spec_col,
    input [7:0] spec_row,
  //  input [7:0] c64_col,
  //  output reg [7:0] c64_row,
    
    input [6:0] joyA,
    input [6:0] joyB,
		
	input [7:0] pai,
	input [7:0] pbi,
	output reg [7:0] pao,
	output reg [7:0] pbo

    );
    
reg [7:0] c64_matrix [0:7];
reg extend_released;
reg extend;

initial begin
        c64_matrix [0]=8'b11111111;
        c64_matrix [1]=8'b11111111;
        c64_matrix [2]=8'b11111111;
        c64_matrix [3]=8'b11111111;
        c64_matrix [4]=8'b11111111;
        c64_matrix [5]=8'b11111111;
        c64_matrix [6]=8'b11111111;
        c64_matrix [7]=8'b11111111;
        extend<=0; 
        extend_released<=0;   
end
    
always @ (posedge clk) begin
    if (reset) begin
        c64_matrix [0]=8'b11111111;
        c64_matrix [1]=8'b11111111;
        c64_matrix [2]=8'b11111111;
        c64_matrix [3]=8'b11111111;
        c64_matrix [4]=8'b11111111;
        c64_matrix [5]=8'b11111111;
        c64_matrix [6]=8'b11111111;
        c64_matrix [7]=8'b11111111;
        extend<=0;
        extend_released<=0;    
    end
    else
    begin
        case (spec_row)
            8'b11111110: begin                    // fe - sft z x c v  extend  cur_up
                //if (spec_col[0]) c64_matrix [1] [7]<=1; else c64_matrix [1] [7]<=0;           
                if ((!spec_col[0]) && (extend))  c64_matrix [6] [4]<=0; else c64_matrix [6] [4]<=1;
                if ((!spec_col[0]) && (!extend))  c64_matrix [1] [7]<=0; else c64_matrix [1] [7]<=1;     
                if (spec_col[1]) c64_matrix [1] [4]<=1; else c64_matrix [1] [4]<=0;
                if (spec_col[2]) c64_matrix [2] [7]<=1; else c64_matrix [2] [7]<=0;
                if (spec_col[3]) c64_matrix [2] [4]<=1; else c64_matrix [2] [4]<=0;
                if (spec_col[4]) c64_matrix [3] [7]<=1; else c64_matrix [3] [7]<=0;
                if (spec_col[5]) extend_released<=0; else begin
                     if (!extend_released) begin
                        extend<=~extend;
                        extend_released<=1;
                     end
                 end                
                if ((!spec_col[6]) && (extend))  c64_matrix [6] [6]<=0; else c64_matrix [6] [6]<=1;
                if ((!spec_col[6]) && (!extend))  c64_matrix [6] [1]<=0; else c64_matrix [6] [1]<=1;                                
            end
            8'b11111101: begin                    // fd - a s d f g capslock graph
                if (spec_col[0]) c64_matrix [1] [2]<=1; else c64_matrix [1] [2]<=0;                
                if (spec_col[1]) c64_matrix [1] [5]<=1; else c64_matrix [1] [5]<=0;
                if (spec_col[2]) c64_matrix [2] [2]<=1; else c64_matrix [2] [2]<=0;
                if (spec_col[3]) c64_matrix [2] [5]<=1; else c64_matrix [2] [5]<=0;
                if (spec_col[4]) c64_matrix [3] [2]<=1; else c64_matrix [3] [2]<=0;
                if (spec_col[5]) c64_matrix [7] [7]<=1; else c64_matrix [7] [7]<=0;
                if (spec_col[6]) c64_matrix [7] [2]<=1; else c64_matrix [7] [2]<=0;                                                                
            end
            8'b11111011: begin                    // fb - q w e r t tvid ivid
                if (spec_col[0]) c64_matrix [7] [6]<=1; else c64_matrix [7] [6]<=0;                
                if (spec_col[1]) c64_matrix [1] [1]<=1; else c64_matrix [1] [1]<=0;
                if (spec_col[2]) c64_matrix [1] [6]<=1; else c64_matrix [1] [6]<=0;
                if (spec_col[3]) c64_matrix [2] [1]<=1; else c64_matrix [2] [1]<=0;
                if (spec_col[4]) c64_matrix [2] [6]<=1; else c64_matrix [2] [6]<=0;
                if (spec_col[5]) c64_matrix [0] [6]<=1; else c64_matrix [0] [6]<=0;
                if (spec_col[6]) c64_matrix [0] [3]<=1; else c64_matrix [0] [3]<=0;                                
            end
            8'b11110111: begin                    // f7 - 1 2 3 4 5 brk edit
                if (spec_col[0]) c64_matrix [7] [0]<=1; else c64_matrix [7] [0]<=0;                
                if (spec_col[1]) c64_matrix [7] [3]<=1; else c64_matrix [7] [3]<=0;
                if (spec_col[2]) c64_matrix [1] [0]<=1; else c64_matrix [1] [0]<=0;
                //if (spec_col[3]) c64_matrix [1] [3]<=1; else c64_matrix [1] [3]<=0;
                if ((!spec_col[3]) && (extend))  c64_matrix [6] [0]<=0; else c64_matrix [6] [0]<=1;
                if ((!spec_col[3]) && (!extend))  c64_matrix [1] [3]<=0; else c64_matrix [1] [3]<=1;
                if (spec_col[4]) c64_matrix [2] [0]<=1; else c64_matrix [2] [0]<=0;
                if (spec_col[5]) c64_matrix [0] [4]<=1; else c64_matrix [0] [4]<=0;
                if (spec_col[6]) c64_matrix [0] [5]<=1; else c64_matrix [0] [5]<=0;                                                
            end
            8'b11101111: begin                    // ef - 0 9 8 7 6 ; "
                if (spec_col[0]) c64_matrix [4] [3]<=1; else c64_matrix [4] [3]<=0;                
                if (spec_col[1]) c64_matrix [4] [0]<=1; else c64_matrix [4] [0]<=0;
                if (spec_col[2]) c64_matrix [3] [3]<=1; else c64_matrix [3] [3]<=0;
                if (spec_col[3]) c64_matrix [3] [0]<=1; else c64_matrix [3] [0]<=0;
                if (spec_col[4]) c64_matrix [2] [3]<=1; else c64_matrix [2] [3]<=0;
                if ((!spec_col[5]) && (extend))  c64_matrix [5] [6]<=0; else c64_matrix [5] [6]<=1;
                if ((!spec_col[5]) && (!extend))  c64_matrix [6] [2]<=0; else c64_matrix [6] [2]<=1;
                if ((!spec_col[6]) && (extend))  c64_matrix [6] [7]<=0; else c64_matrix [6] [7]<=1;
                if ((!spec_col[6]) && (!extend))  c64_matrix [5] [5]<=0; else c64_matrix [5] [5]<=1;
                                                    
            end
            8'b11011111: begin                    // df - p o i u y , .
                if (spec_col[0]) c64_matrix [5] [1]<=1; else c64_matrix [5] [1]<=0;                
                if (spec_col[1]) c64_matrix [4] [6]<=1; else c64_matrix [4] [6]<=0;
                if (spec_col[2]) c64_matrix [4] [1]<=1; else c64_matrix [4] [1]<=0;
                if (spec_col[3]) c64_matrix [3] [6]<=1; else c64_matrix [3] [6]<=0;
                if (spec_col[4]) c64_matrix [3] [1]<=1; else c64_matrix [3] [1]<=0;                
                if ((!spec_col[5]) && (extend))  c64_matrix [5] [0]<=0; else c64_matrix [5] [0]<=1;
                if ((!spec_col[5]) && (!extend))  c64_matrix [5] [7]<=0; else c64_matrix [5] [7]<=1;
                if ((!spec_col[6]) && (extend))  c64_matrix [5] [3]<=0; else c64_matrix [5] [3]<=1;
                if ((!spec_col[6]) && (!extend))  c64_matrix [5] [4]<=0; else c64_matrix [5] [4]<=1;                                
            end
            8'b10111111: begin                    // bf - ent l k j h del cur_right
                if (spec_col[0]) c64_matrix [0] [1]<=1; else c64_matrix [0] [1]<=0;                
                if (spec_col[1]) c64_matrix [5] [2]<=1; else c64_matrix [5] [2]<=0;
                if (spec_col[2]) c64_matrix [4] [5]<=1; else c64_matrix [4] [5]<=0;
                if (spec_col[3]) c64_matrix [4] [2]<=1; else c64_matrix [4] [2]<=0;
                if (spec_col[4]) c64_matrix [3] [5]<=1; else c64_matrix [3] [5]<=0;                
                if ((!spec_col[5]) && (extend))  c64_matrix [6] [3]<=0; else c64_matrix [6] [3]<=1;
                if ((!spec_col[5]) && (!extend))  c64_matrix [0] [0]<=0; else c64_matrix [0] [0]<=1;                
                if (spec_col[6]) c64_matrix [0] [2]<=1; else c64_matrix [0] [2]<=0;                                
            end
            8'b01111111: begin                    // 7f - sp sym m n b cur_left cur_down
                if (spec_col[0]) c64_matrix [7] [4]<=1; else c64_matrix [7] [4]<=0;                
                if (spec_col[1]) c64_matrix [7] [5]<=1; else c64_matrix [7] [5]<=0;
                if (spec_col[2]) c64_matrix [4] [4]<=1; else c64_matrix [4] [4]<=0;
                if (spec_col[3]) c64_matrix [4] [7]<=1; else c64_matrix [4] [7]<=0;
                if (spec_col[4]) c64_matrix [3] [4]<=1; else c64_matrix [3] [4]<=0;                
                if ((!spec_col[5]) && (extend))  c64_matrix [7] [1]<=0; else c64_matrix [7] [1]<=1;
                if ((!spec_col[5]) && (!extend))  c64_matrix [6] [5]<=0; else c64_matrix [6] [5]<=1;
                if (spec_col[6]) c64_matrix [0] [7]<=1; else c64_matrix [0] [7]<=0;                                
            end
                        

            
            
        endcase
    end    
end 

wire [7:0] c64_matrix_2 [0:7];
assign c64_matrix_2[0]=pai[0]?8'b11111111:c64_matrix[0];// & {7'b1111111,joyA[0]};
assign c64_matrix_2[1]=pai[1]?8'b11111111:c64_matrix[1];// & {7'b111111,joyA[1],1'b1};
assign c64_matrix_2[2]=pai[2]?8'b11111111:c64_matrix[2];// & {7'b11111,joyA[2],2'b11};
assign c64_matrix_2[3]=pai[3]?8'b11111111:c64_matrix[3];// & {7'b1111,joyA[3],3'b111};
assign c64_matrix_2[4]=pai[4]?8'b11111111:c64_matrix[4];// & {7'b111,joyA[4],4'b1111};
assign c64_matrix_2[5]=pai[5]?8'b11111111:c64_matrix[5];
assign c64_matrix_2[6]=pai[6]?8'b11111111:c64_matrix[6];
assign c64_matrix_2[7]=pai[7]?8'b11111111:c64_matrix[7] & {7'b111,joyA};

wire [7:0] c64_matrix_comb=c64_matrix_2[0]&c64_matrix_2[1]&c64_matrix_2[2]&c64_matrix_2[3]&c64_matrix_2[4]&c64_matrix_2[5]&c64_matrix_2[6]&c64_matrix_2[7];

always @ (posedge clk) begin

   //pao<=pai & {8'b111,joyB[4:0]};
   //pbo<=pbi & {8'b111,joyA[4:0]} & c64_matrix_comb;
   pao<=pai & {3'b111,joyB};
   pbo<=pbi & c64_matrix_comb;
   
   
end
    
endmodule
