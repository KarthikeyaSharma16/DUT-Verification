module spi_master(input clk, rst, new_data, [11:0] din, output reg cs, mosi, sclk);

    //Defining states of the state machine
    typedef enum bit { idle = 0, send = 1 } state_type;

    state_type state = idle;

    //A counter that changes the level of the clock signal, in this code, every 10 counts, the clock level transitions from either 0 -> 1 (or) 1 -> 0.
    int clkcnt = 0;

    //A counter that keeps track of the bits sent to the slave during the communication.
    int count = 0;

    //Logic for generating SCLK. Fsclk = Fclk/20 -> 10 cycles 0, 10 cycles 1
    always @(posedge clk) begin
        if (rst == 1'b1) begin
            clkcnt <= 0;
            sclk <= 1'b0;
        end
        else begin
            if (clkcnt < 10) begin
                clkcnt <= clkcnt + 1;
            end
            else begin
                clkcnt <= 0;
                sclk <= ~sclk;
            end
        end
    end

    reg [11:0] temp;

    //State machine for transmitting the contents of din bitwise.
    always @(posedge sclk) begin
        if (rst == 1'b1) begin
            cs <= 1'b1;
            mosi <= 1'b0;
        end
        else begin
            case (state)
                idle:
                    if (new_data == 1'b1) begin
                        state <= send;
                        temp <= din;
                        cs <= 1'b0;
                    end
                    else begin
                        state <= idle;  
                        temp <= 0;  
                    end 

                send:
                    if (count < 12) begin
                        mosi <= temp[count];
                        count <= count + 1;
                    end
                    else begin
                        count <= 0;
                        state <= idle;
                        cs <= 1'b1;
                        mosi <= 1'b0;
                    end
            endcase
        end
    end

endmodule

module spi_slave (input sclk, mosi, cs, output [11:0] dout, output reg done);
    
    typedef enum bit { detect_start, tx_data} state_type;

    state_type state = detect_start;
    bit [11:0] temp;
    int count = 0;

    always@(posedge sclk) begin
        case (state)
            detect_start: begin
              if (cs == 1'b0) begin
                    state <= tx_data;
                end
                else begin
                    state <= detect_start;
                end
            end

            tx_data: begin
                if (count < 12) begin
                    temp <= (temp >> 1) | (mosi << 11);
                    count <= count + 1;
                end 
                else begin
                    count <= 0;
                    done <= 1'b1;
                    state <= detect_start;
                end  
            end

        endcase 

    end
  
  	assign dout = temp;

endmodule

module spi_top(input clk, rst, new_data, [11:0] din, output [11:0] dout, done);
    wire sclk, cs, mosi;
    spi_master m1 (clk, rst, new_data, din, cs, mosi, sclk);
    spi_slave s1 (sclk, mosi, cs, dout, done);
endmodule

interface spi_if;
    logic clk, rst, new_data, done, sclk;
  	logic [11:0] din;
  	logic [11:0] dout;
endinterface