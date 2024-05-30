// D Flip Flop

interface dff_if;
  logic din, clk, rst;
  logic dout;
endinterface


module dff (dff_if vif);
  
  always@(posedge vif.clk) begin
    if (vif.rst == 1'b1) begin
      dout <= 0;
    end
    else begin
      dout <= din;
    end
  end
  
endmodule