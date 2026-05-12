//======================================================================
//
// tb_sha256_core.v
// ----------------
// Testbench for the SHA-256 core.
//
//======================================================================

`default_nettype none

module tb_sha256_core();

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter DEBUG = 0;

  parameter CLK_HALF_PERIOD = 2;
  parameter CLK_PERIOD = 2 * CLK_HALF_PERIOD;

  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  reg [31 : 0] cycle_ctr;
  reg [31 : 0] error_ctr;
  reg [31 : 0] tc_ctr;

  reg            tb_clk;
  reg            tb_reset_n;
  reg            tb_init;
  reg            tb_next;
  reg            tb_mode;
  reg [511 : 0]  tb_block;
  wire           tb_ready;
  wire [255 : 0] tb_digest;
  wire           tb_digest_valid;

  // NEW: Global register to hold the expected result for the waveform viewer!
  reg [255 : 0]  tb_expected_digest;


  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  sha256_core dut(
                  .clk(tb_clk),
                  .reset_n(tb_reset_n),
                  .init(tb_init),
                  .next(tb_next),
                  .mode(tb_mode),
                  .block(tb_block),
                  .ready(tb_ready),
                  .digest(tb_digest),
                  .digest_valid(tb_digest_valid)
                 );


  //----------------------------------------------------------------
  // clk_gen
  //----------------------------------------------------------------
  always
    begin : clk_gen
      #CLK_HALF_PERIOD;
      tb_clk = !tb_clk;
    end // clk_gen


  //----------------------------------------------------------------
  // sys_monitor()
  //----------------------------------------------------------------
  always
    begin : sys_monitor
      cycle_ctr = cycle_ctr + 1;
      #(2 * CLK_HALF_PERIOD);
      if (DEBUG) dump_dut_state();
    end

  task dump_dut_state;
    begin
      // Keeping this minimal for readability, original debug prints go here if needed.
    end
  endtask 

  //----------------------------------------------------------------
  // reset_dut()
  //----------------------------------------------------------------
  task reset_dut;
    begin
      $display("*** Toggle reset.");
      tb_reset_n = 0;
      #(4 * CLK_HALF_PERIOD);
      tb_reset_n = 1;
    end
  endtask // reset_dut


  //----------------------------------------------------------------
  // init_sim()
  //----------------------------------------------------------------
  task init_sim;
    begin
      cycle_ctr = 0;
      error_ctr = 0;
      tc_ctr = 0;

      tb_clk = 0;
      tb_reset_n = 1;

      tb_init = 0;
      tb_next = 0;
      tb_mode = 1;
      tb_block = 512'h0;
      tb_expected_digest = 256'h0; // Initialize expected to 0
    end
  endtask // init_sim


  //----------------------------------------------------------------
  // display_test_result()
  //----------------------------------------------------------------
  task display_test_result;
    begin
      if (error_ctr == 0)
        $display("*** All %02d test cases completed successfully", tc_ctr);
      else
        $display("*** %02d test cases did not complete successfully.", error_ctr);
    end
  endtask // display_test_result


  //----------------------------------------------------------------
  // wait_ready()
  //----------------------------------------------------------------
  task wait_ready;
    begin
      while (!tb_ready) begin
        #(CLK_PERIOD);
      end
    end
  endtask // wait_ready


  //----------------------------------------------------------------
  // single_block_test()
  //----------------------------------------------------------------
  task single_block_test(input [7 : 0]   tc_number,
                         input [511 : 0] block,
                         input [255 : 0] expected);
   begin
     $display("*** TC %0d single block test case started.", tc_number);
     tc_ctr = tc_ctr + 1;
     
     // Update the global waveform variable so we can see it!
     tb_expected_digest = expected;

     tb_block = block;
     tb_init = 1;
     #(CLK_PERIOD);
     wait_ready();

     if (tb_digest == expected) begin
         $display("*** TC %0d successful.\n", tc_number);
       end
     else begin
         $display("*** ERROR: TC %0d NOT successful.", tc_number);
         error_ctr = error_ctr + 1;
       end
   end
  endtask // single_block_test


  //----------------------------------------------------------------
  // double_block_test()
  //----------------------------------------------------------------
  task double_block_test(input [7 : 0]   tc_number,
                         input [511 : 0] block1,
                         input [255 : 0] expected1,
                         input [511 : 0] block2,
                         input [255 : 0] expected2);

     reg [255 : 0] db_digest1;
     reg [255 : 0] db_digest2;
     reg           db_error;
   begin
     $display("*** TC %0d double block test case started.", tc_number);
     db_error = 0;
     tc_ctr = tc_ctr + 1;

     // --- BLOCK 1 ---
     tb_expected_digest = expected1; // Show expected intermediate hash
     tb_block = block1;
     tb_init = 1;
     #(CLK_PERIOD);
     tb_init = 0;
     wait_ready();
     db_digest1 = tb_digest;

     // --- BLOCK 2 ---
     tb_expected_digest = expected2; // Show expected final hash
     tb_block = block2;
     tb_next = 1;
     #(CLK_PERIOD);
     tb_next = 0;
     wait_ready();
     db_digest2 = tb_digest;

     if (db_digest1 != expected1) begin
         db_error = 1;
       end
     if (db_digest2 != expected2) begin
         db_error = 1;
       end

     if (db_error) error_ctr = error_ctr + 1;
   end
  endtask // double_block_test


  //----------------------------------------------------------------
  // issue_test()
  //----------------------------------------------------------------
  task issue_test;
    reg [511 : 0] block0, block1, block2, block3, block4, block5, block6, block7, block8;
    reg [255 : 0] expected;
    begin : issue_test
      block0 = 512'h6b900001_496e2074_68652061_72656120_6f662049_6f542028_496e7465_726e6574_206f6620_5468696e_6773292c_206d6f72_6520616e_64206d6f_7265626f_6f6d2c20;
      block1 = 512'h69742068_61732062_65656e20_6120756e_69766572_73616c20_636f6e73_656e7375_73207468_61742064_61746120_69732074_69732061_206e6577_20746563_686e6f6c;
      block2 = 512'h6f677920_74686174_20696e74_65677261_74657320_64656365_6e747261_6c697a61_74696f6e_2c496e20_74686520_61726561_206f6620_496f5420_28496e74_65726e65;
      block3 = 512'h74206f66_20546869_6e677329_2c206d6f_72652061_6e64206d_6f726562_6f6f6d2c_20697420_68617320_6265656e_20612075_6e697665_7273616c_20636f6e_73656e73;
      block4 = 512'h75732074_68617420_64617461_20697320_74697320_61206e65_77207465_63686e6f_6c6f6779_20746861_7420696e_74656772_61746573_20646563_656e7472_616c697a;
      block5 = 512'h6174696f_6e2c496e_20746865_20617265_61206f66_20496f54_2028496e_7465726e_6574206f_66205468_696e6773_292c206d_6f726520_616e6420_6d6f7265_626f6f6d;
      block6 = 512'h2c206974_20686173_20626565_6e206120_756e6976_65727361_6c20636f_6e73656e_73757320_74686174_20646174_61206973_20746973_2061206e_65772074_6563686e;
      block7 = 512'h6f6c6f67_79207468_61742069_6e746567_72617465_73206465_63656e74_72616c69_7a617469_6f6e2c49_6e207468_65206172_6561206f_6620496f_54202849_6e746572;
      block8 = 512'h6e657420_6f662054_68696e67_73292c20_6d6f7265_20616e64_206d6f72_65800000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000010e8;

      expected = 256'h7758a30bbdfc9cd92b284b05e9be9ca3d269d3d149e7e82ab4a9ed5e81fbcf9d;
      
      // Update the global waveform variable
      tb_expected_digest = expected;

      tc_ctr = tc_ctr + 1;
      tb_block = block0; tb_init = 1; #(CLK_PERIOD); tb_init = 0; wait_ready();
      tb_block = block1; tb_next = 1; #(CLK_PERIOD); tb_next = 0; wait_ready();
      tb_block = block2; tb_next = 1; #(CLK_PERIOD); tb_next = 0; wait_ready();
      tb_block = block3; tb_next = 1; #(CLK_PERIOD); tb_next = 0; wait_ready();
      tb_block = block4; tb_next = 1; #(CLK_PERIOD); tb_next = 0; wait_ready();
      tb_block = block5; tb_next = 1; #(CLK_PERIOD); tb_next = 0; wait_ready();
      tb_block = block6; tb_next = 1; #(CLK_PERIOD); tb_next = 0; wait_ready();
      tb_block = block7; tb_next = 1; #(CLK_PERIOD); tb_next = 0; wait_ready();
      tb_block = block8; tb_next = 1; #(CLK_PERIOD); tb_next = 0; wait_ready();

      if (tb_digest != expected) error_ctr = error_ctr + 1;
    end
  endtask // issue_test

  //----------------------------------------------------------------
  // sha256_core_test
  //----------------------------------------------------------------
  task sha256_core_test;
    reg [511 : 0] tc1;
    reg [255 : 0] res1;
    reg [511 : 0] tc2_1;
    reg [255 : 0] res2_1;
    reg [511 : 0] tc2_2;
    reg [255 : 0] res2_2;
    begin : sha256_core_test
      // TC1
      tc1 = 512'h61626380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018;
      res1 = 256'hBA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD;
      single_block_test(1, tc1, res1);

      // TC2
      tc2_1 = 512'h6162636462636465636465666465666765666768666768696768696A68696A6B696A6B6C6A6B6C6D6B6C6D6E6C6D6E6F6D6E6F706E6F70718000000000000000;
      res2_1 = 256'h85E655D6417A17953363376A624CDE5C76E09589CAC5F811CC4B32C1F20E533A;

      tc2_2 = 512'h000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001C0;
      res2_2 = 256'h248D6A61D20638B8E5C026930C3E6039A33CE45964FF2167F6ECEDD419DB06C1;
      double_block_test(2, tc2_1, res2_1, tc2_2, res2_2);
    end
  endtask // sha256_core_test

  //----------------------------------------------------------------
  // main()
  //----------------------------------------------------------------
  initial
    begin : main
      $display("   -- Testbench for sha256 core started --");
      init_sim();
      reset_dut();
      
      sha256_core_test();
      issue_test();

      display_test_result();
      $display("*** Simulation done.");
      $finish;
    end // main
endmodule
