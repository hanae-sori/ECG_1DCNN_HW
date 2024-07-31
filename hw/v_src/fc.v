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


module fc
    #(parameter
        DW = 32,
        in_ch = 4,
        in_seq = 23
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
    
    output [DW-1:0] o_data;
    output o_stb_out;
    input i_ack_out;
    
    reg r_ack_in;
    assign o_ack_in = r_ack_in;
    reg [DW-1:0] arr_weight[0:in_ch-1][0:in_seq-1];
    reg [DW-1:0] arr_mult[0:in_ch-1][0:in_seq-1];
    
    reg [31:0] cnt_seq;
    
    reg [DW-1:0] r_conv;
    reg [DW-1:0] r_data;
    assign o_data = r_data;
    reg r_stb_out;
    assign o_stb_out = r_stb_out;
    
    wire [DW-1:0] arr_sum[0:in_ch-1][1:in_seq-1];
    genvar m, n;
    generate
        for (m = 0; m < in_seq; m = m+1) begin
            assign arr_sum[1][m] = arr_mult[1][m] + arr_mult[0][m];
            for (n = 2; n < in_ch; n = n+1) begin
                assign arr_sum[n][m] = arr_sum[n-1][m] + arr_mult[n][m];
            end
        end
    endgenerate
    
    reg [2:0] state;
    localparam IDLE = 3'b000,
               LOAD = 3'b110,
               MULT = 3'b100,
               ADD  = 3'b101,
               WAIT = 3'b001;
    
    integer i, j;
    always @(posedge clk, negedge RSTn)
        if (!RSTn) begin
            state <= IDLE;
            
            r_ack_in <= 0;
            
            for (i = 0; i < in_ch; i = i+1) begin
                for (j = 0; j < in_seq; j = j+1) begin
                    arr_weight[i][j] <= 0;
                    arr_mult[i][j] <= 0;
                end
            end
            r_conv <= 0;
            
            r_data <= 0;
            r_stb_out <= 0;
            
            cnt_seq <= 0;
        end
        else begin
            case (state)
                IDLE : begin
                    r_ack_in <= 0;
                    
                    for (i = 0; i < in_ch; i = i+1) begin
                        for (j = 0; j < in_seq; j = j+1) begin 
                            arr_mult[i][j] <= 0;
                        end
                    end
                   
                    r_conv <= 0;
                    
                    cnt_seq <= 0;
                    
                    case ({i_EN_w, i_EN_c})
                        2'b10 :
                            state <= LOAD;
                        2'b01 :
                            state <= MULT;
                        default :
                            state <= IDLE;
                    endcase
                end
                LOAD : begin
                    r_ack_in <= 1;
                    
                    if (i_stb_in && o_ack_in) begin
                        r_ack_in <= 0;
                        for (i = 0; i < in_ch; i = i+1) begin
                            for (j = 0; j < in_seq-1; j = j+1) begin
                                arr_weight[i][j+1] <= arr_weight[i][j];
                            end
                            arr_weight[i][0] <= i_data[i*DW +: DW];
                        end
                        
                        if (cnt_seq == in_seq-1)
                            state <= IDLE;
                        else begin
                            state <= LOAD;
                            
                            cnt_seq <= cnt_seq+1;
                        end
                    end
                end
                MULT : begin
                    r_ack_in <= 1;
                    
                    if (i_stb_in && o_ack_in) begin
                        r_ack_in <= 0;
                        for (i = 0; i < in_ch; i = i+1) begin
                            for (j = 0; j < in_seq; j = j+1) begin
                                arr_mult[i][j+1] <= arr_mult[i][j];
                            end
                            arr_mult[i][0] <= i_data[i*DW +: DW] * arr_weight[i][j];
                        end
                        
                        if (cnt_seq == in_seq-1) begin
                            state <= ADD;
                            
                            cnt_seq <= 0;
                        end
                        else begin
                            state <= MULT;
                            
                            cnt_seq <= cnt_seq+1;
                        end
                    end
                end
                ADD : begin
                    r_ack_in <= 0;
                    
                    r_conv <= r_conv + arr_sum[in_ch-1][cnt_seq];
                    
                    if (cnt_seq == in_ch-1) begin
                        state <= WAIT;
                        
                        cnt_seq <= 0;
                    end
                    else begin
                        state <= ADD;
                        
                        cnt_seq <= cnt_seq+1;
                    end
                end
                WAIT : begin
                    r_ack_in <= 0;
                    
                    if (!o_stb_out) begin
                        state <= IDLE;
                        
                        r_data <= r_conv;
                            
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