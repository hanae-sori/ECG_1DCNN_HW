//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 07/25/2024 05:19:50 AM
// Design Name:
// Module Name: 1DConv_1
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


module Conv1d
    #(parameter
        DW = 32,
        size_k = 3, 
        stride = 1,
        MaxPool = 2
    )
    
    (
        clk,
        RSTn,
        i_EN_w,
        i_EN_c,
        o_busy,
        
        i_data,
        i_stb_in,
        o_ack_in,
        
        o_data,
        o_stb_out,
        i_ack_out
    );
    
    input clk,
          RSTn;
          
    input i_EN_w,
          i_EN_c;
    output o_busy;
    
    input [DW-1:0] i_data;
    input i_stb_in;
    output o_ack_in;
    
    output [DW-1:0] o_data;
    output o_stb_out;
    input i_ack_out;
    
    reg r_ack_in;
    assign o_ack_in = r_ack_in;
    reg [DW-1:0] r_conv[0:MaxPool-1];
    reg [DW-1:0] r_data;
    assign o_data = r_data;
    reg r_stb_out;
    assign o_stb_out = r_stb_out;
    
    reg [DW-1:0] arr_weight[0:size_k-1];
    reg [DW-1:0] r_bias;
    reg [DW-1:0] arr_data[0:(size_k-1)+stride];
    reg [DW-1:0] arr_temp[0:size_k-1][0:MaxPool-1];
    reg [$clog2(size_k-1):0] cnt_arr;
    
    wire z_gt_o;
    comp2
    #(
        .DW(DW)
    )
    comp
    (
        .i_a(r_conv[0]), 
        .i_b(r_conv[1]),
        .o_a_gt_b(z_gt_o)
    );
    
    reg [2:0] state;
    localparam IDLE = 3'b000,
               LOAD = 3'b110,
               DATA = 3'b111,
               MULT = 3'b100,
               ADD  = 3'b101,
               WAIT = 3'b010;
    
    integer i, j;
    always @(posedge clk, negedge RSTn)
        if (!RSTn) begin
            state <= IDLE;
            
            r_ack_in <= 0;
            for (i = 0; i < MaxPool; i = i+1) 
                r_conv[i] <= 0;
            r_data <= 0;
            r_stb_out <= 0;
            
            for (i = 0; i < size_k; i = i+1)
                arr_weight[i] <= 0;
            r_bias <= 0;
            for (i = 0; i < size_k+stride; i = i+1)
                arr_data[i] <= 0;
            for (i = 0; i <= stride; i = i+1)
                for (j = 0; j < size_k; j = j+1)
                    arr_temp[j][i] <= 0;
            cnt_arr <= 0;
        end
        else begin
            case (state)
                IDLE : begin
                    r_ack_in <= 0;
                    for (i = 0; i < MaxPool; i = i+1) 
                        r_conv[i] <= 0;
                    
                    cnt_arr <= 0;
                    
                    case ({i_EN_w, i_EN_c})
                        2'b10 :
                            state <= LOAD;
                        2'b01 :
                            state <= DATA;
                        default :
                            state <= IDLE;
                    endcase
                end
                LOAD : begin
                    r_ack_in <= 1;
                    
                    if (i_stb_in && o_ack_in) begin
                        r_ack_in <= 0;
                        
                        if (cnt_arr == size_k) begin
                            state <= IDLE;
                            
                            r_bias <= i_data;
                        end
                        else begin
                            state <= LOAD;
                            
                            cnt_arr <= cnt_arr+1;
                            for (i = 0; i < size_k-1; i = i+1)
                                arr_weight[i+1] <= arr_weight[i];
                            arr_weight[0] <= i_data;
                        end
                    end
                end
                DATA : begin
                    r_ack_in <= 1;
                    
                    if (i_stb_in && o_ack_in) begin
                        r_ack_in <= 0;
                        
                        for (i = 0; i < (size_k-1)+stride; i = i+1)
                            arr_data[i+1] <= arr_data[i];
                        arr_data[0] <= i_data;
                        
                        if (cnt_arr == stride)
                            state <= MULT;
                        else begin
                            state <= DATA;
                            
                            cnt_arr <= cnt_arr+1;
                        end
                    end
                end
                MULT : begin
                    r_ack_in <= 0;
                    
                    for (i = 0; i <= stride; i = i+1)
                        for (j = 0; j < size_k; j = j+1)
                            arr_temp[j][i] <= arr_data[j+i] * arr_weight[j];
                        
                    state <= ADD;
                end
                ADD : begin
                    r_ack_in <= 0;
                    
                    r_conv[0] <= arr_temp[0][0] + arr_temp[1][0] + arr_temp[2][0];
                    r_conv[1] <= arr_temp[0][1] + arr_temp[1][1] + arr_temp[2][1];
                    /*
                    for (i = 0; i <= stride; i = i+1)
                        for (j = 0; j < size_k; j = j+1)
                            r_conv[i] <= r_conv[i] + arr_temp[j][i];
                    */
                    
                    state <= WAIT;
                end
                WAIT : begin
                    r_ack_in <= 0;
                    
                    if (!o_stb_out) begin
                        state <= IDLE;
                        
                        r_stb_out <= 1;
                        if (z_gt_o)
                            r_data <= r_conv[0] + r_bias;
                        else
                            r_data <= r_conv[1] + r_bias;
                    end
                    else
                        state <= WAIT;
                end
            endcase
            
            if (o_stb_out && i_ack_out)
                r_stb_out <= 0;
        end
        
        assign o_busy = |state;
    
endmodule
