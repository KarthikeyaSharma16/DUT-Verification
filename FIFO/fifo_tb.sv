/*
    Transaction Class Parameters to be tested - dout response to din. 
    Only varying signal(s) - din
    Stimuli for global signals like Clk, Rst will be generated in the testbench top, hence it is excluded from the transaction class.
*/

class transaction;

    //Randomized din input signal.
    randc bit wr;
    randc bit rd;
    randc bit [7:0] din;
    bit full, empty;
    bit [7:0] dout;
  
  constraint c1 { (wr == 0) <-> (rd == 1);
                 (wr == 1) <-> (rd == 0); }

    //Function to create a copy of the transaction class signals.
    function transaction copy();
        copy = new();
        copy.wr = this.wr;
        copy.rd = this.rd;
        copy.din = this.din;
        copy.full = this.full;
        copy.empty = this.empty;
        copy.dout = this.dout;
    endfunction
  
    //Function to display the transaction class signals
    function void display(input string s);
        $display("[%0s] : wr = %0b, rd = %0b, din = %0b, full = %0b, empty = %0b, dout = %0b", s, wr, rd, din, full, empty, dout);
    endfunction

endclass

/*
    Generator Class - Generates random stimuli for the DUT.
*/

class generator;

    //Declaring an object of the transaction class.
    transaction t;

    //Declaring an object of the mailbox class.
    mailbox #(transaction) mbx;

    //Count for the total number of transactions.
    int count;

    //Event highlighting the completion of verification of a single transaction by the scoreboard.
    event next;

    //Event highlighting the completion of verification of all the transactions.
    event done;

    //Custom constructor
    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
        t = new();
    endfunction

  task run();
        repeat(count) begin
            assert (t.randomize()) else $error("[GEN] : Stimuli Generation Failed!");
            mbx.put(t.copy);
            t.display("GEN");
            @(next);
        end
        ->done;
    endtask

endclass

class driver;

    //Declaring an object of the interface.
    virtual fifo_if vif;

    //Declaring an object of the transaction class.
    transaction t;

    //Declaring an object of the mailbox class.
    mailbox #(transaction) mbx;

    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
    endfunction

    task reset();
        $display("[DRV] : Starting Reset..");
        vif.rst <= 1'b1;
        vif.rd <= 1'b0;
        vif.wr <= 1'b0;
        vif.din <= 7'b0;
        repeat(5) @(posedge vif.clk);
        vif.rst <= 1'b0;
        @(posedge vif.clk);
        $display("[DRV] : Reset Done!");
    endtask

    task run();
        forever begin
            mbx.get(t);
            vif.wr <= t.wr;
            vif.rd <= t.rd;
            vif.din <= t.din;
            @(posedge vif.clk);
            t.display("DRV");
        end
    endtask

endclass

class monitor;
    transaction t;
    mailbox #(transaction) mbx;
    virtual fifo_if vif;

    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
    endfunction

    //Wait for 2 clock signals and receive the data.
    task run();
      t = new();
        forever begin
            repeat(2) @(posedge vif.clk);
            t.rd = vif.rd;
            t.wr = vif.wr;
            t.din = vif.din;
            t.full = vif.full;
            t.empty = vif.empty;
            t.dout = vif.dout;
            mbx.put(t);
            t.display("MON");
        end
    endtask

endclass

class scoreboard;
    transaction t;
    mailbox #(transaction) mbx;
    bit [7:0] dtemp[$];
    bit [7:0] temp;
    event next;
    int err = 0; //count errors

    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
    endfunction

    task run();
        forever begin
            mbx.get(t);
            t.display("SCO");
            if (t.wr == 1'b1 && t.full == 1'b0) begin
                dtemp.push_front(t.din);
                $display("[SCO] : Data stored in Queue : %0b", t.din);
                $display("[SCO] : List  - %0p", dtemp);
            end 
          else if (t.rd == 1'b1 && t.empty == 1'b0) begin
                temp = dtemp.pop_back();
                $display("[SCO] : Data popped - %0d", temp);
                $display("[SCO] : Updated List  - %0p", dtemp);
                if (t.dout == temp) begin
                    $display("[SCO] : Data Match!");
                end
                else begin
                    $display("[SCO] : Data mismatched!");
                    err++;
                end
            end
            else if (t.empty == 1'b1) begin
                $display("[SCO] : FIFO empty!");
            end
            else if (t.full == 1'b1) begin
                $display("[SCO] : FIFO full!");
            end
            $display("-----------------------------------------------------\n");
            ->next;
        end
    endtask

endclass

class environment;

    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco;

    event next;

    mailbox #(transaction) gdmbx; //connecting generator to driver
    mailbox #(transaction) msmbx; //connecting monitor to scoreboard
    
    virtual fifo_if vif;

  function new(virtual fifo_if vif);
        //Initializing all the mailboxes.
        gdmbx = new();
      	msmbx = new();

        //Initializing all the classes
        gen = new(gdmbx);
        drv = new(gdmbx);
        mon = new(msmbx);
        sco = new(msmbx);

        //connecting the virtual interfaces
        this.vif = vif;
        drv.vif = this.vif;
        mon.vif = this.vif;
    
        //Linking the event signals.
        gen.next = next;
        sco.next = next;

    endfunction

    task pre_test();
        drv.reset();
    endtask

    task test();
        fork
            gen.run();
            drv.run();
            mon.run();
            sco.run();
        join_any
    endtask

    task post_test();
        wait(gen.done.triggered);
        $finish();
    endtask

    task run();
        pre_test();
        test();
        post_test();
    endtask

endclass

module top_tb;

    fifo_if vif();

    fifo dut (.clk(vif.clk), .rd(vif.rd), .wr(vif.wr), .rst(vif.rst), .din(vif.din), .dout(vif.dout), .full(vif.full), .empty(vif.empty));

    initial begin
        vif.clk <= 0;
    end

    always #10 vif.clk <= ~vif.clk;

    environment e;
    
    initial begin
        e = new(vif);
        e.gen.count = 30;
        e.run();
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
    end

endmodule