class transaction;
    rand bit new_data;
    rand bit[11:0] din;
    bit cs, mosi;

    constraint c1 {
      new_data dist {0 := 0, 1 := 100};
    }

    //Function to perform deep copy.
    function transaction copy();
        copy = new();
        copy.new_data = this.new_data;
        copy.din = this.din;
        copy.cs = this.cs;
        copy.mosi = this.mosi;
    endfunction

    function void display(string s);
      $display("[%0s] : new_data = %0b, din = %0d, cs = %0b, mosi = %0b", s, new_data, din, cs, mosi);
    endfunction

endclass

class generator;

    mailbox #(transaction) mbx;
    transaction t;
    event next;
    event done;
    int count = 0;

    //Constructor
    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
        t = new();
    endfunction

    task run();
        repeat(count) begin
            assert (t.randomize()) else $error("[GEN] : Stimuli generation Failed!");
            mbx.put(t);
            t.display("GEN");
            @(next);
        end
        ->done;
    endtask

endclass

class driver;

    //Receive data from generator
    mailbox #(transaction) mbx;

    //Mailbox to transmit data from driver to scoreboard for verifying the sent data with the received data.
    mailbox #(bit [11:0]) mbxds;

    transaction t;

    bit [11:0] sdata;
    
    //Virtual interface to apply stimulus to the DUT.
    virtual spi_master_if vif;

    function new(mailbox #(transaction) mbx, mailbox #(bit [11:0]) mbxds);
        this.mbx = mbx;
        this.mbxds = mbxds;
        t = new();
    endfunction

    task reset();
        vif.rst <= 1'b1;
        vif.new_data <= 1'b0;
        vif.cs = 1'b1;
        vif.din <= 1'b0;
        vif.mosi <= 1'b0;
        repeat(5) @(posedge vif.clk);
        vif.rst <= 1'b0;
        $display("[DRV] : Reset Done!");
    endtask

    task run();
        forever begin
            mbx.get(t);
            @(posedge vif.sclk);
            vif.new_data <= t.new_data;
            vif.din <= t.din;
            sdata <= t.din;    
            mbxds.put(sdata);
            @(posedge vif.sclk);       
            wait(vif.cs == 1'b1);
            t.display("DRV");
        end
    endtask

endclass

class monitor;

    virtual spi_master_if vif;
    mailbox #(bit [11:0]) mbx;
    transaction t;
    bit [11:0] arr;

    function new(mailbox #(bit [11:0]) mbx);
        this.mbx = mbx;
        t = new();
    endfunction

    task run();
        forever begin
          @(posedge vif.sclk)
          wait(vif.cs == 1'b0);
          @(posedge vif.sclk)
          
          //Collecting contents of din in a local array arr to send it to the scoreboard.
          
          for (int i = 0; i < 12; i++) begin
            @(posedge vif.sclk);
            arr[i] = vif.mosi;
          end
          
          wait(vif.cs == 1'b1);
          mbx.put(arr);
          t.display("MON");
        end
    endtask
    
endclass

class scoreboard;

    mailbox #(bit [11:0]) mbx;
    mailbox #(bit [11:0]) mbxds;
    event next;
    bit [11:0] dsdin;
    bit [11:0] msdin;

    function new(mailbox #(bit [11:0]) mbx, mailbox #(bit [11:0]) mbxds);
        this.mbx = mbx;
        this.mbxds = mbxds;
    endfunction

    task run();
        forever begin
            mbx.get(msdin);
            mbxds.get(dsdin);
          $display("[SCO] : msdin = %0d, dsdin = %0d",msdin, dsdin);
            if (dsdin == msdin) begin
                $display("[SCO] : Data matched!");
            end
            else begin
                $display("[SCO] : Data mismatched!");
            end
            $display("---------------------------------------------------\n");
            ->next;
        end
    endtask

endclass

class environment;
    generator g;
    driver d;
    monitor m;
    scoreboard s;
    transaction t; 

    mailbox #(transaction) mbxgd;
    mailbox #(bit [11:0]) mbxds;
    mailbox #(bit [11:0]) mbxms;

    event next;
    event done;

    virtual spi_master_if vif;

    function new(virtual spi_master_if vif);
        mbxgd = new();
        mbxds = new();
        mbxms = new();

        g = new(mbxgd);
        d = new(mbxgd, mbxds);
        m = new(mbxms);
        s = new(mbxms,mbxds);

        this.vif = vif;
        d.vif = this.vif;
        m.vif = this.vif;

        g.next = next;
        s.next = next;

    endfunction

    task pre_test();
        d.reset();
    endtask

    task test();
        fork
            g.run();
            d.run();
            m.run();
            s.run();
        join_any
    endtask

    task post_test();
        wait(g.done.triggered);
        $finish();
    endtask

    task run();
        pre_test();
        test();
        post_test();
    endtask

endclass

module top_tb;
    spi_master_if vif();

    spi_master spi_m (.clk(vif.clk), .rst(vif.rst), .new_data(vif.new_data), .din(vif.din), .mosi(vif.mosi), .cs(vif.cs), .sclk(vif.sclk));

    environment e;

    initial begin
        vif.clk <= 0;
    end

    always #10 vif.clk = ~vif.clk;

    initial begin
        e = new(vif);
        e.g.count = 30;
        e.run();
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars();
    end

endmodule