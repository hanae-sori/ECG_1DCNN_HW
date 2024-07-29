//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/07/30 02:20:15
// Design Name: 
// Module Name: comp2
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


module comp2_gt
    #(parameter
        DW = 32
    )
    (
        i_a, 
        i_b,
        o_a_gt_b
    );
    
    input [DW-1:0] i_a, 
                   i_b;
    output o_a_gt_b;

    assign o_a_gt_b = i_a > i_b;
    
endmodule