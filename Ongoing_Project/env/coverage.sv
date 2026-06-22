`ifndef SPI_COVERAGE_COL_SV
`define SPI_COVERAGE_COL_SV

class spi_coverage_col;

    // Config coverage state
    bit [1:0] cv_mode;
    bit       cv_lsb_first;
    bit [1:0] cv_width;
    bit       cv_loopback;
    bit [15:0] cv_clk_div;
    bit [7:0] cv_delay;

    // FIFO occupancy state
    int cv_tx_occ;
    int cv_rx_occ;

    // Interrupt state
    bit [4:0] cv_irq_event; 

    // Register access state
    bit [7:0] cv_reg_addr;
    bit       cv_reg_write;
    bit [31:0] cv_reg_value;

    bit cv_reset;
    bit reset_seen;

    covergroup cg_config;
        option.per_instance = 1;   //1
        cp_mode : coverpoint cv_mode { bins modes[] = {[0:3]}; }
        cp_first: coverpoint cv_lsb_first { bins msb={0}; bins lsb={1}; }
        cp_width: coverpoint cv_width { bins w8={2'b00}; bins w16={2'b01}; bins w32={2'b10}; }
        cx_mode_width_first: cross cp_mode, cp_width, cp_first;
        
        cp_clk_div: coverpoint cv_clk_div {   //2
            bins zero = {0};
            bins one = {1};
            bins two = {2};
            bins three = {3};
            bins b255 = {255};
            bins b1024 = {1024};
            bins b65535 = {65535};
            bins others = {[4:254], [256:1023], [1025:65534]};
        }
        
        cp_delay: coverpoint cv_delay {//6
            bins zero = {0};
            bins one = {1};
            ignore_bins del_mid = {[2:127]};
            bins del_large = {[128:255]};
        }
        
        cp_loopback: coverpoint cv_loopback {//7
            bins off = {0};
            bins on = {1};
        }
        cx_loopback_width: cross cp_loopback, cp_width;
    endgroup

    covergroup cg_fifo; //3
        option.per_instance = 1;
        cp_tx_occ: coverpoint cv_tx_occ {
            bins empty = {0};
            bins one = {1};
            bins mid = {4};
            bins partial = {[2:3], [5:6]};
            bins seven = {7};
            bins full = {8};
        }
        cp_rx_occ: coverpoint cv_rx_occ {
            bins empty = {0};
            bins one = {1};
            bins mid = {4};
            bins partial = {[2:3], [5:6]};
            bins seven = {7};
            bins full = {8};
        }
    endgroup

    // State for advanced interrupt coverage
    bit [4:0] cv_irq_mask;
    bit       cv_irq_clear_op; 

    covergroup cg_interrupts;//4
   
        option.per_instance = 1;
        cp_irq_event: coverpoint cv_irq_event {
            option.auto_bin_max=0;
            bins events[] = {5'b00001, 5'b00010, 5'b00100, 5'b01000, 5'b10000};
        }
         
        cp_mask: coverpoint cv_irq_mask {
            bins masked = {0};
            bins unmasked = {[1:$]}; // simplified check per bit in cross
        }
        
        cp_clear: coverpoint cv_irq_clear_op {
            bins set = {0};
            bins clear_w1c = {1}; //never reached?
        }
  
        // Cross to cover "asserted while masked" and "cleared via W1C"
        cx_event_mask: cross cp_irq_event, cp_mask {
            // We want to see each bit of irq_event with its corresponding mask bit 0 and 1
        }
        cx_event_clear: cross cp_irq_event, cp_clear;
        //???cv_irq_mask missed in cross
    endgroup

    covergroup cg_reg_access;//5
        option.per_instance = 1;
        cp_addr: coverpoint cv_reg_addr {
            bins ctrl = {8'h00};
            bins status = {8'h04};
            bins tx_data = {8'h08};
            bins rx_data = {8'h0C};
            bins clk_div = {8'h10};
            bins ss_ctrl = {8'h14};
            bins int_en = {8'h18};
            bins int_stat = {8'h1C};
            bins delay_cfg = {8'h20};
            bins reserved = {[8'h24:8'hFF]}; //test iclude address of undefined registers
        }
        cp_write_read: coverpoint cv_reg_write { bins read={0}; bins write={1}; }
        cx_addr_write: cross cp_addr, cp_write_read {
            /*ignore_bins ro_write = binsof(cp_addr.status) && binsof(cp_write_read.write) || 
                                   binsof(cp_addr.rx_data) && binsof(cp_write_read.write) ||
                                   binsof(cp_addr.reserved) && binsof(cp_write_read.write);
            ignore_bins wo_read  = binsof(cp_addr.tx_data) && binsof(cp_write_read.read);*/
        }
        cp_reset_vlaues:coverpoint cv_reg_value iff(reset_seen){ //get cv_reg && reset from  from function
            option.auto_bin_max=0;
            bins reset={32'h0000_0000,32'h0000_0014};
        }

        cx_reg_reset_vlaues: cross cp_addr, cp_reset_vlaues {}
        


    endgroup

    function new();
        cg_config = new();
        cg_fifo = new();
        cg_interrupts = new();
        cg_reg_access = new();
    endfunction

    task sample_config(input bit [1:0] mode, input bit lsb_first, input bit [1:0] width,
                       input bit [15:0] clk_div = 0, input bit [7:0] delay_val = 0, input bit loopback = 0);
        cv_mode = mode;
        cv_lsb_first = lsb_first;
        cv_width = width;
        cv_clk_div = clk_div;
        cv_delay = delay_val;
        cv_loopback = loopback;
        cg_config.sample();
    endtask

    task sample_fifo(input int tx_occ, input int rx_occ);
        cv_tx_occ = tx_occ;
        cv_rx_occ = rx_occ;
        cg_fifo.sample();
    endtask

    task sample_interrupt(input bit [4:0] irq_event, input bit [4:0] mask = 5'h1F, input bit is_clear = 0);
        cv_irq_event = irq_event;
        cv_irq_mask = mask;
        cv_irq_clear_op = is_clear;
        cg_interrupts.sample();
    endtask

    task sample_reg_access(input bit [7:0] addr, input bit is_write, input [31:0] Val = 32'h0000_0000);
        cv_reg_addr = addr;
        cv_reg_value = Val;
        cv_reg_write = is_write;
        cg_reg_access.sample();
    endtask

    task sample_reg_reset_value(input bit [7:0] addr, input bit [31:0] Val);
        cv_reg_addr = addr;
        cv_reg_value = Val;
        cg_reg_access.sample();
    endtask

    task sample_reset(input bit reset);
        cv_reset = reset;
        if (reset == 1'b0)
            reset_seen = 1'b1;
        cg_reg_access.sample();
    endtask

endclass

`endif // SPI_COVERAGE_COL_SV
