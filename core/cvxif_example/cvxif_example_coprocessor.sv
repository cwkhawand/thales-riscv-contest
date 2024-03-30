// Copyright 2021 Thales DIS design services SAS
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0
// You may obtain a copy of the License at https://solderpad.org/licenses/
//
// Original Author: Guillaume Chauvon (guillaume.chauvon@thalesgroup.com)
// Example coprocessor adds rs1,rs2(,rs3) together and gives back the result to the CPU via the CoreV-X-Interface.
// Coprocessor delays the sending of the result depending on result least significant bits.

module cvxif_example_coprocessor
  import cvxif_pkg::*;
  import cvxif_instr_pkg::*;
(
    input  logic        clk_i,        // Clock
    input  logic        rst_ni,       // Asynchronous reset active low
    input  cvxif_req_t  cvxif_req_i,
    output cvxif_resp_t cvxif_resp_o
);

  //Compressed interface
  logic               x_compressed_valid_i;
  logic               x_compressed_ready_o;
  x_compressed_req_t  x_compressed_req_i;
  x_compressed_resp_t x_compressed_resp_o;
  //Issue interface
  logic               x_issue_valid_i;
  logic               x_issue_ready_o;
  x_issue_req_t       x_issue_req_i;
  x_issue_resp_t      x_issue_resp_o;
  //Commit interface
  logic               x_commit_valid_i;
  x_commit_t          x_commit_i;
  //Memory interface
  logic               x_mem_valid_o;
  logic               x_mem_ready_i;
  x_mem_req_t         x_mem_req_o;
  x_mem_resp_t        x_mem_resp_i;
  //Memory result interface
  logic               x_mem_result_valid_i;
  x_mem_result_t      x_mem_result_i;
  //Result interface
  logic               x_result_valid_o;
  logic               x_result_ready_i;
  x_result_t          x_result_o;

  assign x_compressed_valid_i            = cvxif_req_i.x_compressed_valid;
  assign x_compressed_req_i              = cvxif_req_i.x_compressed_req;
  assign x_issue_valid_i                 = cvxif_req_i.x_issue_valid;
  assign x_issue_req_i                   = cvxif_req_i.x_issue_req;
  assign x_commit_valid_i                = cvxif_req_i.x_commit_valid;
  assign x_commit_i                      = cvxif_req_i.x_commit;
  assign x_mem_ready_i                   = cvxif_req_i.x_mem_ready;
  assign x_mem_resp_i                    = cvxif_req_i.x_mem_resp;
  assign x_mem_result_valid_i            = cvxif_req_i.x_mem_result_valid;
  assign x_mem_result_i                  = cvxif_req_i.x_mem_result;
  assign x_result_ready_i                = cvxif_req_i.x_result_ready;

  assign cvxif_resp_o.x_compressed_ready = x_compressed_ready_o;
  assign cvxif_resp_o.x_compressed_resp  = x_compressed_resp_o;
  assign cvxif_resp_o.x_issue_ready      = x_issue_ready_o;
  assign cvxif_resp_o.x_issue_resp       = x_issue_resp_o;
  assign cvxif_resp_o.x_mem_valid        = x_mem_valid_o;
  assign cvxif_resp_o.x_mem_req          = x_mem_req_o;
  assign cvxif_resp_o.x_result_valid     = x_result_valid_o;
  assign cvxif_resp_o.x_result           = x_result_o;

  //Compressed interface
  assign x_compressed_ready_o            = '0;
  assign x_compressed_resp_o.instr       = '0;
  assign x_compressed_resp_o.accept      = '0;

  instr_decoder #(
      .NbInstr   (cvxif_instr_pkg::NbInstr),
      .CoproInstr(cvxif_instr_pkg::CoproInstr)
  ) instr_decoder_i (
      .clk_i         (clk_i),
      .x_issue_req_i (x_issue_req_i),
      .x_issue_resp_o(x_issue_resp_o)
  );

  typedef struct packed {
    x_issue_req_t  req;
    x_issue_resp_t resp;
  } x_issue_t;

  logic fifo_full, fifo_empty;
  logic x_issue_ready_q;
  logic instr_push, instr_pop;
  x_issue_t req_i;
  x_issue_t req_o;



  assign instr_push = x_issue_resp_o.accept ? 1 : 0;
  assign instr_pop = (x_commit_i.x_commit_kill && x_commit_valid_i) || x_result_valid_o;
  assign x_issue_ready_q = fifo_empty; // if something is in the fifo, the instruction is being processed
                                       // so we can't receive anything else
  assign req_i.req = x_issue_req_i;
  assign req_i.resp = x_issue_resp_o;

  always_ff @(posedge clk_i or negedge rst_ni) begin : regs
    if (!rst_ni) begin
      x_issue_ready_o <= 1;
    end else begin
      x_issue_ready_o <= x_issue_ready_q;
    end
  end

  fifo_v3 #(
      .FALL_THROUGH(1),         //data_o ready and pop in the same cycle
      .DATA_WIDTH  (64),
      .DEPTH       (1),
      .dtype       (x_issue_t)
  ) fifo_commit_i (
      .clk_i     (clk_i),
      .rst_ni    (rst_ni),
      .flush_i   (1'b0),
      .testmode_i(1'b0),
      .full_o    (fifo_full),
      .empty_o   (fifo_empty),
      .usage_o   (),
      .data_i    (req_i),
      .push_i    (instr_push),
      .data_o    (req_o),
      .pop_i     (instr_pop)
  );

  logic is_mad_instruction, is_madsiv_instruction, is_madswv_instruction, is_madev_instruction;
  logic is_mad_done, is_madv_done;
  logic[31:0] mad_result, madv_result;

  always_comb begin
    is_mad_instruction = ~fifo_empty & ((cvxif_instr_pkg::CoproInstr[2].mask & req_o.req.instr) == cvxif_instr_pkg::CoproInstr[2].instr);
    is_madsiv_instruction = ~fifo_empty & ((cvxif_instr_pkg::CoproInstr[3].mask & req_o.req.instr) == cvxif_instr_pkg::CoproInstr[3].instr);
    is_madswv_instruction = ~fifo_empty & ((cvxif_instr_pkg::CoproInstr[4].mask & req_o.req.instr) == cvxif_instr_pkg::CoproInstr[4].instr);
    is_madev_instruction = ~fifo_empty & ((cvxif_instr_pkg::CoproInstr[5].mask & req_o.req.instr) == cvxif_instr_pkg::CoproInstr[5].instr);

    x_result_o.data    = (is_mad_instruction) ? mad_result :
                         (is_madev_instruction) ? madv_result :
                         8'h00000000;
    x_result_valid_o   = (is_mad_done | is_madv_done) && ~fifo_empty ? 1 : 0;
    x_result_o.id      = req_o.req.id;
    x_result_o.rd      = req_o.req.instr[11:7];
    x_result_o.we      = req_o.resp.writeback & x_result_valid_o;
    x_result_o.exc     = 0;
    x_result_o.exccode = 0;
  end

  mad #() mad_i (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .input_valid(is_mad_instruction),
    .operand_a(req_o.req.rs[0]),
    .operand_b(req_o.req.rs[1]),
    .result_valid(is_mad_done),
    .result(mad_result)
  );

logic[11:0] data_count;
assign data_count = {req_o.req.instr[31:25], req_o.req.instr[11:7]};

  madv #() madv_i (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .data_valid(is_madsiv_instruction | is_madswv_instruction),
    .data_count(data_count),
    .data(req_o.req.rs[1]),
    .is_input(is_madsiv_instruction),
    .is_weight(is_madswv_instruction),
    .execute(is_madev_instruction),
    .result_valid(is_madv_done),
    .result(madv_result)
  );
endmodule
