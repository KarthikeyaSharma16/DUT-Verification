/*
    Transaction Class Parameters to be tested - dout response to din. 
    Only varying signal(s) - din
    Stimuli for global signals like Clk, Rst will be generated in the testbench top, hence it is excluded from the transaction class.
*/

class transaction;

    //Randomized din input signal.
    rand bit din;
    bit dout;

    //Function to create a copy of the transaction class signals.
    function transaction copy();
        copy = new();
        copy.din = this.din;
        copy.dout = this.dout;
    endfunction
  
    //Function to display the transaction class signals
    function void display(input string s);
        $display("[%s] : din = %0b, dout = %0b", s, din, dout);
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

    //Declaring an object of the mailbox class.
    mailbox #(transaction) mbxref;

    //Count for the total number of transactions.
    int count;

    //Event highlighting the completion of verification of a single transaction by the scoreboard.
    event next;

    //Event highlighting the completion of verification of all the transactions.
    event done;

    //Custom constructor
    function new(mailbox #(transaction) mbx, mailbox #(transaction) mbxref);
        this.mbx = mbx;
        this.mbxref = mbxref;
        t = new();
    endfunction

  task run();
        repeat(count) begin
            assert (t.randomize()) else $display("[GEN] : Stimuli Generation Failed!");
            mbx.put(t.copy);
            mbxref.put(t.copy);
            t.display("GEN");
            @(next);
        end
        ->done;
    endtask

endclass

class driver;

    //Declaring an object of the interface.
    virtual dff_if vif;

    //Declaring an object of the transaction class.
    transaction t;

    //Declaring an object of the mailbox class.
    mailbox #(transaction) mbx;

    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
    endfunction

    task reset();
        vif.rst <= 1'b1;
        repeat(5) @(posedge vif.clk);
        vif.rst <= 1'b0;
        @(posedge vif.clk);
        $display("[DRV] : Reset Done!");
    endtask

    task run();
        forever begin
            mbx.get(t);
            vif.din <= t.din;
            @(posedge vif.clk);
            t.display("DRV");
            vif.din <= 1'b0;
          	@(posedge vif.clk);
        end
    endtask

endclass

class monitor;
    transaction t;
    mailbox #(transaction) mbx;
    virtual dff_if vif;

    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
        t = new();
    endfunction

    //Wait for 2 clock signals and receive the data.
    task run();
        forever begin
            repeat(2) @(posedge vif.clk);
            t.dout <= vif.dout;
            t.din <= vif.din;
            mbx.put(t);
            t.display("MON");
        end
    endtask

endclass

class scoreboard;
    transaction t;
    transaction tref;
    mailbox #(transaction) mbxref;
    mailbox #(transaction) mbx;
    event next;

    function new(mailbox #(transaction) mbx, mailbox #(transaction) mbxref);
        this.mbx = mbx;
        this.mbxref = mbxref;
    endfunction

    task run();
        forever begin
            mbx.get(t);
            mbxref.get(tref);
            if (tref.din == t.dout) begin
                $display("[SCO] : Data matched!");
            end 
            else begin
                $display("[SCO] : Data not matched!");
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
    mailbox #(transaction) mbxref; //connecting generator to scoreboard
    
    virtual dff_if vif;

  function new(virtual dff_if vif);
        //Initializing all the mailboxes.
        gdmbx = new();
      	msmbx = new();
        mbxref = new();

        //Initializing all the classes
        gen = new(gdmbx, mbxref);
        drv = new(gdmbx);
        mon = new(msmbx);
        sco = new(msmbx, mbxref);

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

    dff_if vif();

    dff dut (vif);

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