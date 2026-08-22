`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/18/2026 10:12:48 AM
// Design Name: 
// Module Name: func
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


module func(
    input clk,rst,
    input [1:0] opcode,
    input [31:0] x_in,
    output reg [31:0] x,
    input valid,
    output reg [4:0] state,next_state,
    output reg [31:0] exp,inv_exp,sigmoid,tanh,fraction_x,integer_x,
    output reg done,
    output [31:0] result,
    output reg [31:0] A,B, mac, power_x, term,numerator,denominator,
    output reg [5:0] count,
    output reg start,fpu_rst, is_neg,
    output reg [2:0] op_sel,
    output wire cmp_gt,cmp_eq,cmp_lt,fpu_done
    
    );
    
    /*wire [31:0] result;
    reg [31:0] A,B;
    reg [3:0] count;
    reg start,fpu_rst;
    reg [2:0] op_sel;
    wire cmp_gt,cmp_eq,cmp_lt,fpu_done;*/
    
ieee754_alu_fsm  FPU(
    .clk(clk),
    .rst(fpu_rst),
    .start(start),
    .A(A),
    .B(B),
    .op_sel(op_sel),
    .result(result),
    .cmp_gt(cmp_gt),
    .cmp_eq(cmp_eq),
    .cmp_lt(cmp_lt),
    .done(fpu_done)
);
    
    wire [31:0] e [0:10];
    assign e[0]  = 32'h3F800000;
    assign e[1]  = 32'h402DF854; // e^1  ≈ 2.7182817
    assign e[2]  = 32'h40EC7326; // e^2  ≈ 7.3890562
    assign e[3]  = 32'h41A0AF2E; // e^3  ≈ 20.085537
    assign e[4]  = 32'h425A6481; // e^4  ≈ 54.598152
    assign e[5]  = 32'h431469C5; // e^5  ≈ 148.41316
    assign e[6]  = 32'h43C9B6E3; // e^6  ≈ 403.42880
    assign e[7]  = 32'h44891443; // e^7  ≈ 1096.6332
    assign e[8]  = 32'h453A4F54; // e^8  ≈ 2980.9580
    assign e[9]  = 32'h45FD38AC; // e^9  ≈ 8103.0840
    assign e[10] = 32'h46AC14EE; // e^10 ≈ 22026.465  
    
    wire [31:0] val [0:10];
    assign val[0]  = 32'h00000000;
    assign val[1]  = 32'h3F800000; // 1.0
    assign val[2]  = 32'h40000000; // 2.0
    assign val[3]  = 32'h40400000; // 3.0
    assign val[4]  = 32'h40800000; // 4.0
    assign val[5]  = 32'h40A00000; // 5.0
    assign val[6]  = 32'h40C00000; // 6.0
    assign val[7]  = 32'h40E00000; // 7.0
    assign val[8]  = 32'h41000000; // 8.0
    assign val[9]  = 32'h41100000; // 9.0
    assign val[10] = 32'h41200000; // 10.0
    
    wire [31:0] inv_fact[0:15];
    assign inv_fact[0] = 32'h0;
    assign inv_fact[1] = 32'h3F800000; // 1/1! = 1.000000
    assign inv_fact[2] = 32'h3F000000; // 1/2! = 0.500000
    assign inv_fact[3] = 32'h3E2AAAAB; // 1/3! ≈ 0.166667
    assign inv_fact[4] = 32'h3D2AAAAB; // 1/4! ≈ 0.041667
    assign inv_fact[5] = 32'h3C088889; // 1/5! ≈ 0.008333
    assign inv_fact[6] = 32'h3AC88889; // 1/6! ≈ 0.001389
    assign inv_fact[7] = 32'h39500D01; // 1/7! ≈ 0.000198
    assign inv_fact[8] = 32'h37D00D01; // 1/8!  ≈ 0.0000248016
    assign inv_fact[9]  = 32'h3645A1CB; // 1/9!  ≈ 2.7557319e-6
    assign inv_fact[10] = 32'h3493F27E; // 1/10! ≈ 2.7557319e-7
    assign inv_fact[11] = 32'h32D7322B; // 1/11! ≈ 2.5052108e-8
    assign inv_fact[12] = 32'h310324EB; // 1/12! ≈ 2.0876756e-9
    assign inv_fact[13] = 32'h2F1B0452; // 1/13! ≈ 1.6059044e-10
    assign inv_fact[14] = 32'h2D283305; // 1/14! ≈ 1.1470745e-11
    assign inv_fact[15] = 32'h2B20A862; // 1/15! ≈ 7.6471637e-13
    
    
    always @(posedge clk) begin
        if(rst) begin
            state<=4'd0;
            mac <= 32'h3F800000;
            term <= 32'h3F800000;
            power_x <= 32'h3F800000;
            exp<=32'h3F800000;
            inv_exp<=32'h3F800000;
            sigmoid<=32'h3F800000;
            tanh<=32'h3F800000;
            count<=6'd0;
            start<=1'd0;
            op_sel<=3'b100;
            fpu_rst<=1'd1;
            done<=1'b0;         
        end
        else begin
            state<=next_state;
            case(state)
                5'd0:begin
                        is_neg <= x_in[31];
                        mac <= 32'h3F800000;
                        term <= 32'h3F800000;
                        power_x <= 32'h3F800000;
                        exp<=32'h3F800000;
                        inv_exp<=32'h3F800000;
                        sigmoid<=32'h3F800000;
                        tanh<=32'h3F800000;
                        count<=6'd0;
                        start<=1'd0;
                        op_sel<=3'b100;
                        fpu_rst<=1'd1;
                        done<=1'b0;             
                        end
                5'd1:begin
                        if(is_neg)
                            x[31] <= ~x_in[31];
                        else 
                            x[31] <= x_in[31];
                        x[30:0] <= x_in[30:0];
                            
                     end
                5'd2:begin
                        start<=1'b1;
                        fpu_rst<=1'b0;
                        A<=x;
                        B<=val[count];
                        op_sel<=3'b100;
                         //setting the opcode for fpu to compoare between x and value[count]
                     end
                5'd3:begin
                
                        //since after first comparison the value of x is greter than value[count], 
                        //we are incrementing count and checking again                        
                        count<=count+1'b1; 
                        //before any new operation in the fpu, we are resetting it since the fpu is in done state and 
                        //we need to get it back to the idle state                     
                        fpu_rst<=1'b1; 
                                        
                     end
                5'd4:begin
                        // integer_x stores the integer part of x
                        integer_x<=count-2'd2;
                        
                        // setting A and B accordingly as we have to find x-integer_x, which will be equal to fraction_x
                        A<=x;
                        B<=val[count-2'd2];
                        //setting the opcode for fpu to substraction
                        fpu_rst<=1'b0;
                        op_sel<=3'b001;
                     end
                5'd5:begin
                        //splitting is done in this state and we are saving the fractional part aand reseting the fpu
                        fraction_x<=result;
                        fpu_rst<=1'b1;
                        count <= 6'd1;
                     end
                5'd6:begin
                        A <= power_x;
                        B <= fraction_x;
                        fpu_rst <= 1'b0;
                        op_sel <= 3'b010;
                     end
                5'd7:begin
                        power_x <= result;
                        fpu_rst <= 1'b1;
                     end
                5'd8:begin
                        A <= power_x;
                        B <= inv_fact[count];
                        fpu_rst <= 1'b0;
                        op_sel <= 3'b010;
                     end
                5'd9:begin
                        term <= result; 
                        fpu_rst <= 1'b1;
                     end
                5'd10:begin
                        A <= mac;
                        B <= term;
                        fpu_rst <= 1'd0;
                        op_sel <= 3'b000;
                     end
                5'd11:begin
                        mac <= result;
                        count <= count+1'b1;
                        fpu_rst <= 1'b1;
                     end
                5'd12:begin
                        A <= mac;
                        B <= e[integer_x];
                        op_sel <= 3'b010;
                        fpu_rst <= 1'b0;
                        count <= 5'd0;
                     end
                5'd13:begin
                        if(is_neg)
                            inv_exp <= result;
                        else
                            exp <= result;
                        fpu_rst <= 1'b1;
                     end
                5'd14:begin
                        A <= val[1];
                        if(is_neg)
                            B <= inv_exp;
                        else
                            B <= exp;
                        op_sel <= 3'b011;
                        fpu_rst <= 1'b0;
                     end
                5'd15:begin
                        if(is_neg)
                            exp <= result;
                        else
                            inv_exp <= result;
                        fpu_rst <= 1'b1;
                     end
                5'd16:begin
                        A<=inv_exp;
                        B<=val[1'b1];
                        op_sel<=3'b000;
                        fpu_rst<=1'b0;
                        end
                5'd17:begin
                        term<=result;
                        fpu_rst<=1'b1;
                        end
                5'd18:begin
                        A<=val[1];
                        B<=term;
                        op_sel<=3'b011;
                        fpu_rst<=1'b0;
                        end
                5'd19:begin
                        sigmoid<=result;
                        fpu_rst<=1'b1;
                        end
                5'd20: begin // Numerator: e^x - e^-x
                        A <= exp;
                        B <= inv_exp;
                        op_sel <= 3'b001; // Subtract
                        fpu_rst <= 1'b0;
                       end
                5'd21: begin
                        numerator <= result;
                        fpu_rst <= 1'b1;
                       end
                5'd22: begin // Denominator: e^x + e^-x
                        A <= exp;
                        B <= inv_exp;
                        op_sel <= 3'b000; // Add
                        fpu_rst <= 1'b0;
                       end
                5'd23: begin
                        denominator <= result;
                        fpu_rst <= 1'b1;
                       end
                5'd24: begin // Divide
                        A <= numerator;
                        B <= denominator;
                        op_sel <= 3'b011; // Divide
                        fpu_rst <= 1'b0;
                       end
                5'd25: begin
                        tanh <= result;
                        done <= 1'b1;
                        fpu_rst <= 1'b1;
                       end
                default:;
            endcase
         end
    end
    
    always @(*) begin
        case(state)
            5'd0:next_state=5'd1;
            5'd1:next_state=5'd2;
            5'd2:next_state=(fpu_done==1'b1)?5'd3:5'd2;
            5'd3:next_state=(cmp_gt==1'b1)?5'd2:5'd4;
            5'd4:next_state=(fpu_done==1'b1)?5'd5:5'd4;
            5'd5:next_state=5'd6;
            5'd6:next_state=(fpu_done==1'b1)?5'd7:5'd6;
            5'd7:next_state=5'd8;
            5'd8:next_state=(fpu_done==1'b1)?5'd9:4'd8;
            5'd9:next_state=5'd10;
            5'd10:next_state=(fpu_done==1'b1)?5'd11:5'd10;
            5'd11:next_state=(count==6'd12)?5'd12:5'd6;
            5'd12:next_state=(fpu_done==1'b1)?5'd13:5'd12;
            5'd13:next_state=5'd14;
            5'd14:next_state=(fpu_done==1'b1)?5'd15:5'd14;
            5'd15:next_state=5'd16;
            5'd16:next_state=(fpu_done==1'b1)?5'd17:5'd16;
            5'd17:next_state=5'd18;
            5'd18:next_state=(fpu_done==1'b1)?5'd19:5'd18;
            5'd19: next_state = 5'd20; // Transition from Sigmoid completion to Tanh
            5'd20: next_state = (fpu_done) ? 5'd21 : 5'd20;
            5'd21: next_state = 5'd22;
            5'd22: next_state = (fpu_done) ? 5'd23 : 5'd22;
            5'd23: next_state = 5'd24;
            5'd24: next_state = (fpu_done) ? 5'd25 : 5'd24;
            5'd25: next_state = 5'd25; // Terminal state
            
            
            
            default:;
            endcase
    end
    
    
endmodule
