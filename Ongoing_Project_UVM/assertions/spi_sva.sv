// =============================================================================
// spi_sva.sv  (SV-only starter scaffold)
// -----------------------------------------------------------------------------
// SVA target module. `tb_top` binds it into `dut_wrapper.u_dut.u_regfile`:
//
//   bind u_wrap.u_dut.u_regfile spi_sva u_sva (.*);
//   (use the instance path of your dut_wrapper instance, here `u_wrap`)
//
// Add assertions for every spec requirement that you can prove without
// modifying the DUT. The scaffold ships two starter assertions so that the
// file compiles and the grader sees at least one SVA active.
// =============================================================================

`ifndef SPI_SVA_SV
`define SPI_SVA_SV
`timescale 1ns/1ps

module regfile_sva (
    input wire PCLK,
    input wire PRESETn,
    input wire PSEL,
    input wire PENABLE,
    input wire PWRITE,
    input wire [7:0] PADDR,
    input wire [31:0] PWDATA,
    input wire IRQ,
    input wire [4:0] int_stat,
    input wire [4:0] int_en,
    input wire tx_full,
    input wire tx_push_valid,
    input wire rx_full,
    input wire rx_push_valid,
    input wire tx_ovf,
    input wire rx_ovf,
    // Add signals for R20
    input wire [3:0] ss_en,
    input wire [3:0] ss_val,
    input wire [3:0] SS_n
);

    // 1. APB: PSEL=1 for at least 2 PCLK to complete a transaction.
    property p_apb_psel_2cycles;
        @(posedge PCLK) disable iff (!PRESETn)
        $rose(PSEL) |=> PSEL; 
    endproperty

    a_apb_psel_2cycles: assert property (p_apb_psel_2cycles) else $error("[ASSERTION_ERROR] PSEL not held for 2 cycles");
    c_apb_psel_2cycles: cover property(p_apb_psel_2cycles);


    // 2. APB: PENABLE must only assert while PSEL=1.
    property p_apb_penable;
        @(posedge PCLK) disable iff (!PRESETn)
        PENABLE |-> PSEL;
    endproperty

    a_apb_penable: assert property (p_apb_penable) else $error("[ASSERTION_ERROR] PENABLE asserted without PSEL");
    c_apb_penable: cover property(p_apb_penable);

    // 3. APB: PADDR, PWRITE, PWDATA stable from SETUP to ACCESS of the same transaction.
    property p_apb_stable;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && !PENABLE) |=> (PSEL && PENABLE) |-> ($stable(PADDR) && $stable(PWRITE) && $stable(PWDATA));
    endproperty

    a_apb_stable: assert property (p_apb_stable) else $error("[ASSERTION_ERROR] APB signals not stable during ACCESS phase");
    c_apb_stable: cover property(p_apb_stable);


    // 7. FIFO: no push when full (after OVF clear) without explicit OVF assertion.
    property p_tx_ovf;
        @(posedge PCLK) disable iff (!PRESETn)
        (tx_push_valid && tx_full) |=> tx_ovf;
    endproperty

    a_tx_ovf: assert property (p_tx_ovf) else $error("[ASSERTION_ERROR] TX push when full did not assert OVF");
    c_tx_ovf: cover property (p_tx_ovf);


    property p_rx_ovf;
        @(posedge PCLK) disable iff (!PRESETn)
        (rx_push_valid && rx_full) |=> rx_ovf;
    endproperty

    a_rx_ovf: assert property (p_rx_ovf) else $error("[ASSERTION_ERROR] RX push when full did not assert OVF");
    c_rx_ovf:  cover property (p_rx_ovf);


    // 8. IRQ: IRQ == |(INT_STAT & INT_EN) every PCLK (combinational assertion).

    property IRQ_Mask_property;
        @(posedge PCLK) disable iff (!PRESETn)
        IRQ == |(int_stat & int_en);
    endproperty

    a_irq_comb: assert property (IRQ_Mask_property) else $error("[ASSERTION_ERROR] IRQ Mismatch");
    c_irq_comb: cover property (IRQ_Mask_property);



    property SS_n_property;
        @(posedge PCLK) disable iff (!PRESETn)
        SS_n == (~ss_en | ss_val);
    endproperty

    a_ss_n_logic: assert property (SS_n_property) else $error("[ASSERTION_ERROR] R20: SS_n logic mismatch");
    c_ss_n_logic: cover property (SS_n_property);




endmodule

module core_sva (
    input wire PCLK,
    input wire PRESETn,
    input wire busy,
    input wire SCLK,
    input wire MOSI,
    input wire [1:0] cfg_mode,
    input wire [3:0] ss_n_drive,
    input wire       cfg_en,
    // Add internal sampled versions for R25 check
    input wire [1:0]  xfer_mode,
    input wire        xfer_lsb_first,
    input wire [1:0]  xfer_width,
    input wire [15:0] xfer_div
);

    // 4. SPI: SCLK idle level matches CPOL whenever BUSY=0.
    property p_sclk_idle;
        @(posedge PCLK) disable iff (!PRESETn)
        (!busy && cfg_en) |-> (SCLK == cfg_mode[1]);
    endproperty
    a_sclk_idle: assert property (p_sclk_idle) else $error("[ASSERTION_ERROR] SCLK idle level mismatch");
    c_sclk_idle: cover property (p_sclk_idle);

    // 5. SPI: MOSI stable for at least 1 PCLK around each sample edge (WIRE-STABILITY).
    property p_mosi_stable;
        @(posedge PCLK) disable iff (!PRESETn || !busy)
        ((xfer_mode[1] == xfer_mode[0]) ? $rose(SCLK) : $fell(SCLK)) |-> $stable(MOSI);
    endproperty
    a_mosi_stable: assert property (p_mosi_stable) else $error("[ASSERTION_ERROR] MOSI not stable at sample edge");
    c_mosi_stable: cover property (p_mosi_stable);

    // 6. SPI: SS_n held asserted for the entire WIDTH-bit transfer.
    property p_ss_stable;
        @(posedge PCLK) disable iff (!PRESETn)
        (busy && $past(busy)) |-> $stable(ss_n_drive);
    endproperty
    a_ss_stable: assert property (p_ss_stable) else $error("[ASSERTION_ERROR] SS_n changed while BUSY=1");
    c_ss_stable: cover property (p_ss_stable);
    

    // R25: Config stability during transfer   property p_cfg_stable;
    property p_cfg_stable;
        @(posedge PCLK) disable iff (!PRESETn)
        (busy && $past(busy)) |-> ($stable(xfer_mode) && $stable(xfer_lsb_first) && $stable(xfer_width) && $stable(xfer_div));
    endproperty
    a_cfg_stable: assert property (p_cfg_stable) else $error("[ASSERTION_ERROR] R25: Internal config not stable during transfer");
    c_cfg_stable: cover property (p_cfg_stable);


    //Division Correct Implementation Assertion
    property p_clk_div;
        int counter;

        ($changed(SCLK), counter = xfer_div) 
        |=>
            if (counter == 0 && $past(busy))
                $changed(SCLK)
            else
                ((!$changed(SCLK), counter = counter - 1)[*1:$]) ##0 (counter <= 0) ##1 $changed(SCLK);
    endproperty

    // Fix the unclocked directive issue by specifying the clocking event here
    a_clk_div: assert property (@(posedge PCLK) disable iff (!PRESETn || !busy) p_clk_div) else $error("[ASSERTION_ERROR]: CLK_DIV timing mismatch");
    a_clk_div_cover: cover property (@(posedge PCLK) disable iff (!PRESETn || !busy) p_clk_div);



    property p_disable_behavior;
        @(posedge PCLK)
        !cfg_en |=> ((SCLK == $past(cfg_mode[1])));
    endproperty

    a_disable_behavior : assert property(p_disable_behavior) else $error("[ASSERTION_ERROR]: clk wasn't IDLE when disabled");
    c_disable_behavior: cover property (p_disable_behavior);


endmodule

`endif // SPI_SVA_SV
