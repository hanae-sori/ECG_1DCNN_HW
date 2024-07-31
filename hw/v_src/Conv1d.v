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
        in_ch = 1,
        
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
    
    input [DW*in_ch-1:0] i_data;
    input i_stb_in;
    output o_ack_in;
    
    output [DW*MaxPool-1:0] o_data;
    output o_stb_out;
    input i_ack_out;
    
    reg r_ack_in;
    assign o_ack_in = r_ack_in;
    reg [DW-1:0] arr_weight[0:in_ch-1][0:size_k-1];
    reg [DW-1:0] arr_data[0:in_ch-1][0:(size_k-1)+(stride*(MaxPool-1))];
    reg [DW-1:0] arr_mult[0:MaxPool-1][0:in_ch-1][0:size_k-1];
    
    reg [31:0] cnt_arr;
    
    reg [DW-1:0] r_conv[0:MaxPool-1];
    reg [DW*MaxPool-1:0] r_data;
    assign o_data = r_data;
    reg r_stb_out;
    assign o_stb_out = r_stb_out;
    
    wire [DW-1:0] arr_sum[0:MaxPool-1][0:in_ch-1][1:size_k-1];
    genvar m, n, o;
    generate
        for (m = 0; m < MaxPool; m = m+1) begin : gen_sum
            for (n = 0; n < in_ch; n = n+1) begin
                assign arr_sum[m][n][1] = arr_mult[m][n][1] + arr_mult[m][n][0];
                for (o = 2; o < size_k; o = o+1) begin
                    assign arr_sum[m][n][o] = arr_sum[m][n][o-1] + arr_mult[m][n][o];
                end
            end
        end
    endgenerate
    
    reg [2:0] state;
    localparam IDLE = 3'b000,
               LOAD = 3'b110,
               DATA = 3'b111,
               MULT = 3'b100,
               ADD  = 3'b101,
               WAIT = 3'b001;
    
    integer i, j, k;
    always @(posedge clk, negedge RSTn)
        if (!RSTn) begin
            state <= IDLE;
            
            r_ack_in <= 0;
            
            for (i = 0; i < in_ch; i = i+1) begin
                for (j = 0; j < size_k; j = j+1) begin
                    arr_weight[i][j] <= 0;
                    for (k = 0; k < MaxPool; k = k+1) begin 
                        arr_mult[k][i][j] <= 0;
                    end
                end
                for (j = 0; j < size_k+(stride*(MaxPool-1)); j = j+1) begin
                    arr_data[i][j] <= 0;
                end
            end
            for (i = 0; i < MaxPool; i = i+1) begin
                r_conv[i] <= 0;
            end
            
            r_data <= 0;
            r_stb_out <= 0;
            
            cnt_arr <= 0;
        end
        else begin
            case (state)
                IDLE : begin
                    r_ack_in <= 0;
                    
                    for (i = 0; i < MaxPool; i = i+1) begin
                        for (j = 0; j < in_ch; j = j+1) begin
                            for (k = 0; k < size_k; k = k+1) begin 
                                arr_mult[i][j][k] <= 0;
                            end
                        end
                    end
                    for (i = 0; i < MaxPool; i = i+1) begin
                        r_conv[i] <= 0;
                    end
                    
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
                        for (i = 0; i < in_ch; i = i+1) begin
                            for (j = 0; j < size_k-1; j = j+1) begin
                                arr_weight[i][j+1] <= arr_weight[i][j];
                            end
                            arr_weight[i][0] <= i_data[i*DW +: DW];
                        end
                        
                        if (cnt_arr == size_k-1)
                            state <= IDLE;
                        else begin
                            state <= LOAD;
                            
                            cnt_arr <= cnt_arr+1;
                        end
                    end
                end
                DATA : begin
                    r_ack_in <= 1;
                    
                    if (i_stb_in && o_ack_in) begin
                        r_ack_in <= 0;
                        for (i = 0; i < in_ch; i = i+1) begin
                            for (j = 0; j < (size_k-1)+(stride*(MaxPool-1)); j = j+1) begin
                                arr_data[i][j+1] <= arr_data[i][j];
                            end
                            arr_data[i][0] <= i_data[i*DW +: DW];
                        end
                        
                        if (cnt_arr == MaxPool-1) begin
                            state <= MULT;
                            
                            cnt_arr <= 0;
                        end
                        else begin
                            state <= DATA;
                            
                            cnt_arr <= cnt_arr+1;
                        end
                    end
                end
                MULT : begin
                    state <= ADD;
                    
                    r_ack_in <= 0;
                    
                    for (i = 0; i < MaxPool; i = i+1) begin
                        for (j = 0; j < in_ch; j = j+1) begin
                            for (k = 0; k < size_k; k = k+1) begin 
                                arr_mult[i][j][k] <= arr_data[j][(i*stride)+k] * arr_weight[j][k];
                            end
                        end
                    end
                end
                ADD : begin
                    r_ack_in <= 0;
                    
                    for (i = 0; i < MaxPool; i = i+1)
                        r_conv[i] <= r_conv[i] + arr_sum[i][cnt_arr][size_k-1];
                    
                    if (cnt_arr == in_ch-1) begin
                        state <= WAIT;
                        
                        cnt_arr <= 0;
                    end
                    else begin
                        state <= ADD;
                        
                        cnt_arr <= cnt_arr+1;
                    end
                end
                WAIT : begin
                    r_ack_in <= 0;
                    
                    if (!o_stb_out) begin
                        state <= IDLE;
                        
                        for (i = 0; i < MaxPool; i = i+1)
                            r_data[i*DW +: DW] <= r_conv[i];
                            
                        r_stb_out <= 1;
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