//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/07/29 13:38:40
// Design Name: 
// Module Name: Conv1d_1
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


module layer_4
    #(parameter
        DW = 32,
        in_ch = 16,
        in_seq = 1, 
        out_ch = 5
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
    
    output [DW*out_ch-1:0] o_data;
    output o_stb_out;
    input i_ack_out;
    
    reg [DW-1:0] r_bias[0:out_ch-1];
    reg r_ack_w;
    reg r_EN_w;
    
    reg [31:0] cnt_arr;
    
    reg [1:0] state;
    localparam IDLE = 2'b00,
               BIAS = 2'b10,
               LOAD = 2'b01;
               
    integer i;
    always @(posedge clk, negedge RSTn)
        if (!RSTn) begin
            state <= IDLE;
            
            r_ack_w <= 0;
            r_EN_w <= 0;
            
            cnt_arr <= 0;
            
            for (i = 0; i < out_ch; i = i+1)
                r_bias[i] <= 0;
        end
        else begin
            case (state)
                IDLE : begin
                    r_ack_w <= 0;
                    r_EN_w <= 0;
                    
                    cnt_arr <= 0;
                    
                    if (i_EN_w)
                        state <= BIAS;
                    else 
                        state <= IDLE;
                end
                BIAS : begin
                    r_ack_w <= 1;
                    r_EN_w <= 0;
                    
                    if (i_stb_in && o_ack_in) begin
                        r_ack_w <= 0;
                        
                        for (i = 0; i < in_ch; i = i+1)
                            r_bias[(in_ch*cnt_arr)+i] <= i_data[i*DW +: DW];
                            
                        if (cnt_arr == (out_ch/in_ch)-1) begin
                            state <= LOAD;
                            
                            r_EN_w <= 1;
                            
                            cnt_arr <= 0;
                        end
                        else begin
                            state <= BIAS;
                            
                            cnt_arr <= cnt_arr+1;
                        end
                    end
                end
                LOAD : begin
                    r_ack_w <= 0;
                    r_EN_w <= 1;
                    
                    if (i_stb_in && o_ack_in) begin
                        if (cnt_arr == in_seq*out_ch-1) begin
                            state <= IDLE;
                            
                            r_EN_w <= 0;
                        end
                        else begin
                            state <= LOAD;
                            
                            cnt_arr <= cnt_arr+1;
                        end
                    end
                end
            endcase
        end
    
    wire [out_ch-1:0] w_EN_w;
    wire [out_ch-1:0] w_busy;
    wire [out_ch-1:0] w_ack_in;
    wire [DW-1:0] w_conv[0:out_ch-1];
    wire [DW-1:0] w_data[0:out_ch-1];
    wire [out_ch-1:0] w_stb_out;
    wire [out_ch-1:0] o_gt_z;
    
    genvar m;
    generate
        for (m = 0; m < out_ch; m = m + 1) begin : gen_Conv
            assign w_EN_w[m] = r_EN_w && ((cnt_arr/in_seq)==m);
            assign w_data[m] = w_conv[m] + r_bias[m];
            assign o_data[m*DW +: DW] = w_data[m];
        
            fc
            #(
                .DW(DW),
                .in_ch(in_ch),
                .in_seq(in_seq)
            )
            fc
            (
                .clk(clk),
                .RSTn(RSTn),
                .i_EN_w(w_EN_w[m]),
                .i_EN_c(i_EN_c),
                .o_busy(w_busy[m]),
                
                .i_data(i_data),
                .i_stb_in(i_stb_in),
                .o_ack_in(w_ack_in[m]),
                
                .o_data(w_conv[m]),
                .o_stb_out(w_stb_out[m]),
                .i_ack_out(i_ack_out)
            );
        end
    endgenerate
    
    assign o_busy = (|w_busy) | (|state);
    assign o_ack_in = (state[1] && r_ack_w) | (|w_ack_in);
    assign o_stb_out = &w_stb_out;
    
endmodule
