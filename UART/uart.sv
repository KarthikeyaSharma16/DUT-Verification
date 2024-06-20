`timescale 1ns/1ps

module uart_tx #(
    parameter clk_freq = 1000000,
    parameter baud_rate = 9600
) (
    input clk, rst, new_data, 
    input [7:0] tx_data,
    output reg tx, 
    output reg donetx
);

    enum bit {idle = 1'b0, transfer = 1'b1} state_type;
    
    state_type state = idle;

    //For clk_freq value, baud_rate number of symbols (bits) are transmitted.
    //So, clk_freq/baud_rate gives the total number of clock cycles it takes to transmit one symbol (one bit).

    localparam clkcnt = clk_freq / baud_rate;

    int count = 0, cnt = 0;
    
    reg uclk = 0;

    always @(posedge clk) begin
        if (count < clkcnt / 2) begin
            count <= count + 1;
        end
        else begin
            count <= 0;
            uclk <= ~uclk;
        end
    end

    reg [7:0] din;

    always @(posedge uclk) begin
        if (rst == 1'b1) begin
            state <= idle;
        end
        else begin
            case (state) 

                idle: begin
                    tx <= 1'b0;
                    donetx <= 1'b0;
                    if (new_data == 1'b1) begin
                        state <= transfer;
                        din <= tx_data;
                    end
                    else begin
                        state <= idle;
                    end
                end

                transfer: begin
                    if (cnt < 8) begin
                        tx <= din[cnt];
                        cnt <= cnt + 1;
                    end
                    else begin
                        cnt <= 0;
                        state <= idle;
                        donetx <= 1'b1;
                        tx <= 1'b1;
                    end
                end

            endcase
        end
    end

endmodule

module uart_rx #(
    parameter clk_freq = 1000000,
    parameter baud_rate = 9600
) (
    input clk, rst, rx, 
    output reg [7:0] rxdata,
    output donerx
);

    enum bit {idle = 1'b0, receive = 1'b1} state_type;
    
    state_type state = idle;

    localparam clkcnt = clk_freq / baud_rate;

    int count = 0, cnt = 0;
    
    reg uclk = 0;

    always @(posedge clk) begin
        if (count < clkcnt / 2) begin
            count <= count + 1;
        end
        else begin
            count <= 0;
            uclk <= ~uclk;
        end
    end

    always @(posedge uclk) begin
        if (rst == 1'b1) begin
            state <= idle;
        end
        else begin
            case (state)

                idle: begin
                    rxdata <= 0;
                    cnt <= 0;
                    donerx <= 0;

                    if (rxdata == 1'b0) begin
                        state <= receive;
                    end
                    else begin
                        state <= idle;
                    end
                end

                receive: begin
                    if (cnt < 8) begin
                        cnt <= cnt + 1;
                        rxdata <= {rx, rxdata[7:1]};
                    end
                    else begin
                        cnt <= 0;
                        donerx <= 1'b1;
                        state <= idle;
                    end
                end

            endcase
        end
    end
    
endmodule

module uart_top #(
    parameter clk_freq = 1000000,
    parameter baud_rate = 9600
) (
    input clk, rst, new_data, rx
    input [7:0] tx_data,
    output reg [7:0] rx_data,
    output tx, donerx, donetx
);
    
    uart_tx #(clk_freq, baud_rate) utx (.clk(clk), .rst(rst), .new_data(new_data), .tx(tx),
                                        .tx_data(tx_data), .donetx(donetx));
    
    uart_rx #(clk_freq, baud_rate) urx (.clk(clk), .rst(rst), .rx(rx),
                                        .rx_data(rx_data), .donerx(donerx));

endmodule

interface uart;

    logic clk, rst, new_data, tx, rx, donetx, donerx;
    logic [7:0] tx_data, rx_data;

endinterface