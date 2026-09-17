`timescale 1ns / 1ps

module ieee754_alu_fsm (
    input clk, rst, start,
    input [31:0] A, B,
    input [2:0] op_sel,
    output reg [31:0] result,
    output reg cmp_gt, cmp_eq, cmp_lt,
    output reg done
);

    // State Encoding
    localparam IDLE=0, UNPACK=1, EXECUTE=2, NORMALIZE=3, PACK=4, DONE=5;
    reg [2:0] state;

    // Internal Registers
    reg signA, signB, signR;
    reg [7:0] expA, expB, expR;
    reg [23:0] manA, manB;
    reg [24:0] manR; 
    
    // Wide registers for intermediate math
    reg [47:0] mant_mult, mant_div;
    reg [8:0]  exp_sum; 
    
    // Internal wires for alignment (Fixes the 4.0 + 0.02 bug)
    reg [23:0] aligned_A, aligned_B;

    // Exception Flags
    reg isZeroA, isZeroB, isInfA, isInfB, isNaNA, isNaNB;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state  <= IDLE;
            result <= 32'b0;
            done   <= 1'b0;
            cmp_gt <= 1'b0; cmp_eq <= 1'b0; cmp_lt <= 1'b0;
            manR   <= 25'b0;
        end else begin
            case (state)

                IDLE: begin
                    done   <= 1'b0;
                    if (start) state <= UNPACK;
                end

                UNPACK: begin
                    signA <= A[31];
                    signB <= B[31];
                    expA  <= A[30:23];
                    expB  <= B[30:23];
                    manA  <= (A[30:23] == 8'h00) ? {1'b0, A[22:0]} : {1'b1, A[22:0]};
                    manB  <= (B[30:23] == 8'h00) ? {1'b0, B[22:0]} : {1'b1, B[22:0]};
                    
                    isZeroA <= ~(|A[30:0]);  
                    isZeroB <= ~(|B[30:0]);
                    isInfA  <= (&A[30:23]) & (~(|A[22:0]));
                    isInfB  <= (&B[30:23]) & (~(|B[22:0]));
                    isNaNA  <= (&A[30:23]) & (|A[22:0]);
                    isNaNB  <= (&B[30:23]) & (|B[22:0]);
                    
                    state <= EXECUTE;
                end

                EXECUTE: begin
                    if (isNaNA || isNaNB) begin
                        result <= 32'h7FC00000; 
                        state  <= DONE;
                    end
                    else if (isInfA || isInfB) begin
                        state <= DONE;
                        case(op_sel)
                            3'b000: result <= (isInfA && isInfB && (signA != signB)) ? 32'h7FC00000 : {signA, 8'hFF, 23'b0};
                            3'b001: result <= (isInfA && isInfB && (signA == signB)) ? 32'h7FC00000 : {signA, 8'hFF, 23'b0};
                            3'b010: result <= ((isInfA && isZeroB) || (isInfB && isZeroA)) ? 32'h7FC00000 : {signA ^ signB, 8'hFF, 23'b0};
                            default: result <= 32'h7FC00000;
                        endcase
                    end
                    else begin
                        case (op_sel)
                            3'b000, 3'b001: begin // ADD / SUB
                                // Alignment using blocking assignments to ensure same-cycle math
                                if (expA > expB) begin
                                    aligned_A = manA;
                                    aligned_B = manB >> (expA - expB);
                                    expR     <= expA;
                                end else begin
                                    aligned_A = manA >> (expB - expA);
                                    aligned_B = manB;
                                    expR     <= expB;
                                end
                                
                                if (signA == (op_sel[0] ? ~signB : signB)) begin
                                    manR  <= aligned_A + aligned_B;
                                    signR <= signA;
                                end else begin
                                    if (aligned_A >= aligned_B) begin
                                        manR  <= aligned_A - aligned_B;
                                        signR <= signA;
                                    end else begin
                                        manR  <= aligned_B - aligned_A;
                                        signR <= (op_sel[0] ? ~signB : signB);
                                    end
                                end
                                state <= NORMALIZE;
                            end

                            3'b010: begin // MUL
                                signR     <= signA ^ signB;
                                exp_sum   <= expA + expB - 8'd127;
                                mant_mult <= manA * manB;
                                state     <= NORMALIZE;
                            end
                            
                            // DIV
                           3'b011: begin // DIV
                                if (isZeroB) begin
                                    result <= {signA ^ signB, 8'hFF, 23'b0};
                                    state  <= DONE;
                                end else if (isZeroA) begin
                                    result <= 32'b0;
                                    state  <= DONE;
                                end else begin
                                    signR <= signA ^ signB;
                                    exp_sum <= expA - expB + 8'd127;
                                    
                                    // Shift by 23 instead of 24 to align the decimal point correctly
                                    mant_div <= ({manA, 23'b0} / manB); 
                                    state <= NORMALIZE;
                                end
                            end


                            3'b100: begin // COMPARE
                                cmp_eq <= (A == B);
                                if (signA != signB) begin
                                    cmp_gt <= (signA == 0); 
                                    cmp_lt <= (signA == 1);
                                end else if (expA != expB) begin
                                    cmp_gt <= (signA == 0) ? (expA > expB) : (expA < expB);
                                    cmp_lt <= (signA == 0) ? (expA < expB) : (expA > expB);
                                end else begin
                                    cmp_gt <= (signA == 0) ? (manA > manB) : (manA < manB);
                                    cmp_lt <= (signA == 0) ? (manA < manB) : (manA > manB);
                                end
                                state <= DONE;
                            end

                            default: state <= IDLE;
                        endcase
                    end
                end

                    NORMALIZE: begin
                            if (op_sel == 3'b010 || op_sel == 3'b011) begin // MUL or DIV
                                if (op_sel == 3'b011) begin
                                    // Division Normalization Logic
                                    if (mant_div[24]) begin
                                        manR <= {1'b0, mant_div[23:0]}; 
                                        expR <= exp_sum[7:0] + 1'b1;
                                    end else if (!mant_div[23]) begin
                                        manR <= mant_div[23:0] << 1;
                                        expR <= exp_sum[7:0] - 1'b1;
                                    end else begin
                                        manR <= mant_div[23:0];
                                        expR <= exp_sum[7:0];
                                    end
                                end else begin
                                    // Multiplication Normalization Logic
                                    if (mant_mult[47]) begin
                                        manR <= {2'b00, mant_mult[46:24]}; 
                                        expR <= exp_sum[7:0] + 1'b1;
                                    end else begin
                                        manR <= {2'b00, mant_mult[45:23]}; 
                                        expR <= exp_sum[7:0];
                                    end
                                end
                                state <= PACK; // Moved here to cover BOTH Mul and Div
                            end else begin 
                                // ADD / SUB Normalization Logic
                                if (manR == 0) begin
                                    result <= 32'b0;
                                    state  <= DONE;
                                end else if (manR[24]) begin 
                                    manR <= manR >> 1;
                                    expR <= expR + 1'b1;
                                    state <= PACK;
                                end else if (!manR[23]) begin 
                                    manR <= manR << 1;
                                    expR <= expR - 1'b1;
                                    state <= NORMALIZE; 
                                end else begin
                                    state <= PACK;
                                end
                            end
                        end

                PACK: begin
                    result <= {signR, expR, manR[22:0]};
                    state  <= DONE;
                end

                DONE: begin
                    done  <= 1'b1;
                    if (!start) state <= IDLE; // Auto-return to IDLE
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule