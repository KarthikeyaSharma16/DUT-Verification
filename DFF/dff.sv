// D Flip Flop

interface dff_if;
  
  logic din, clk, rst;
  logic dout;
  
endinterface


module dff (dff_if vif);
  
  always@(posedge vif.clk) begin
    if (vif.rst == 1'b1) begin
      vif.dout <= 0;
    end
    else begin
      vif.dout <= vif.din;
    end
  end
  
endmodule