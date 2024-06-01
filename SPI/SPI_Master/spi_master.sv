module spi_master(input clk, rst, new_data, [7:0] din, output reg cs, mosi, sclk);

    //Defining states of the state machine
    typedef enum bit { idle = 0, send = 1 } state_type;

    state_type state = idle;

    int clkcnt = 0;
    int count = 0;

    //Logic for generating SCLK. Fsclk = Fclk/20
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
                    end 

                send:
                    if (count < 11) begin
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

interface spi_master_if;
    logic clk, rst, new_data;
    logic [11:0] din;
    logic cs, mosi, sclk;
endinterface