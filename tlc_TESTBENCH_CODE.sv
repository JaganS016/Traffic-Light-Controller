`timescale 1ns / 1ps

module TLC_tb();

    // Shorter durations for faster simulation (optional)
    parameter EW_GREEN_TIME = 30;              
    parameter NS_GREEN_TIME = 20;              
    parameter ALL_RED_TIME = 5;                
    parameter YELLOW_TIME = 5;                 
    parameter TEST_TIMEOUT = 10000;

    logic clk, rst_n, ped_ew, ped_ns;         
    logic [2:0] ns_light, ew_light;
    logic walk_ns, walk_ew;

    // DUT instance
    TLC #(
        .EW_GREEN_TIME(EW_GREEN_TIME),
        .NS_GREEN_TIME(NS_GREEN_TIME),
        .ALL_RED_TIME(ALL_RED_TIME),
        .YELLOW_TIME(YELLOW_TIME)
    ) dut (
        .clk(clk), 
        .rst_n(rst_n), 
        .ped_ew(ped_ew), 
        .ped_ns(ped_ns), 
        .ns_light(ns_light), 
        .ew_light(ew_light), 
        .walk_ns(walk_ns), 
        .walk_ew(walk_ew)
    );
    
    
    localparam GREEN  = 3'b100;
    localparam YELLOW = 3'b010;
    localparam RED    = 3'b001;
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz clock

    initial begin
        // Initialize inputs
        rst_n = 0;
        ped_ew = 0;
        ped_ns = 0;
        
        #20;
        rst_n = 1;
        @(posedge clk);  // wait one clock for reset propagation

        $dumpfile("Traffic_light_controller.vcd");
        $dumpvars(0, TLC_tb);

        $display("Test Case 1: Basic cycle without pedestrians");
        wait_for_state_ew_green();
        check_lights("EW Green", ns_light, ew_light, RED, GREEN);
        wait_cycles(EW_GREEN_TIME);
        success("EW Green");
        
        $display("Test Case 2: Basic cycle - switch to NS");
        wait_until_yellow_ew();
        wait_cycles(YELLOW_TIME + ALL_RED_TIME);
        wait_for_state_ns_green();
        check_lights("NS Green", ns_light, ew_light, GREEN, RED);
        wait_cycles(NS_GREEN_TIME);
        success("NS Green");

        $display("Test Case 3: Pedestrian request during NS green");
        wait_for_state_ns_green();
        #100;
        ped_ew = 1;
        #20;
        ped_ew = 0;
        wait_until_yellow_ns();
        check_lights("NS Yellow after ped", ns_light, ew_light, YELLOW, RED);
        success("NS Yellow");

        $display("Test Case 4: Multiple pedestrian requests");
        wait_for_state_ew_green();
        repeat (5) begin
            ped_ns = 1;
            #50;
            ped_ns = 0;
            #50;
        end
        wait_until_yellow_ew();
        check_lights("EW Yellow after multiple peds", ns_light, ew_light, RED, YELLOW);
        success("EW Yellow");

        $display("Test Case 5: Reset during operation");
        wait_cycles(10);
        rst_n = 0;
        #20;
        rst_n = 1;
        @(posedge clk);
        wait_for_state_ew_green();
        check_lights("After reset", ns_light, ew_light, RED, GREEN);
        success("Reset during operation");
        
        $display("Test Case 6: Simultaneous pedestrian requests during EW Green");
        wait_for_state_ew_green();
        ped_ns = 1;
        ped_ew = 1;
        #20;
        ped_ns = 0;
        ped_ew = 0;
        
        // EW Green should finish, but NS request should trigger EW->Yellow quickly
        wait_until_yellow_ew();
        check_lights("EW Yellow after simultaneous peds", ns_light, ew_light, RED, YELLOW);
        success("Test Case 6 passed");

        $display("Test Case 7: Pedestrian request during all-red");
        wait_for_state_ew_green();
        wait_cycles(EW_GREEN_TIME + YELLOW_TIME); // Transition to All_Red_2
        
        ped_ns = 1;   // Should latch request for NS before NS_Green
        #20;
        ped_ns = 0;
        
        wait_for_state_ns_green(); // Should quickly come as usual
        wait_until_yellow_ns();
        check_lights("NS Yellow after pedestrian pressed during all red", ns_light, ew_light, YELLOW, RED);
        success("Test Case 7 passed");

        $display("Test Case 8: Button bounce simulation");
        wait_for_state_ew_green();
        
        // Simulate rapid pressing/releasing
        repeat(4) begin
            ped_ns = 1; #10; ped_ns = 0; #10;
        end
        
        wait_until_yellow_ew();
        wait_for_state_ns_green();
        wait_cycles(5);
        
        // There should not be multiple, repeated transitions. NS Green should hold for full period.
        check_lights("NS Green after button bounce", ns_light, ew_light, GREEN, RED);
        success("Test Case 8 passed");

        $display("Test Case 9: Long hold on pedestrian button");
        wait_for_state_ew_green();
        ped_ns = 1;      // Hold down through entire EW Green and Yellow
        wait_until_yellow_ew();
        wait_for_state_ns_green();
        check_lights("NS Green after long hold", ns_light, ew_light, GREEN, RED);
        wait_cycles(NS_GREEN_TIME);
        ped_ns = 0;      // Release during NS Green
        
        // Should have only triggered once
        success("Test Case 9 passed");

        $display("Test Case 10: Immediate reset during yellow");
        wait_until_yellow_ns();
        #5;    // During yellow
        rst_n = 0;
        #20;
        rst_n = 1;
        @(posedge clk);
        wait_for_state_ew_green();
        check_lights("After reset during yellow", ns_light, ew_light, RED, GREEN);
        success("Test Case 10 passed");

        $display("Test Case 11: Stuck pedestrian button (held across cycles)");
        wait_for_state_ew_green();
        ped_ns = 1;
        repeat(2) begin
            wait_until_yellow_ew();
            wait_for_state_ns_green();
            wait_cycles(NS_GREEN_TIME + YELLOW_TIME + ALL_RED_TIME);
        end
        ped_ns = 0;
        // Walk should have engaged only once each time NS got green.
        success("Test Case 11 passed");


        $display("All test cases completed.");
        $finish;
    end     

    // Timeout protection
    initial begin
        #(10 * TEST_TIMEOUT);
        $error("Simulation timeout - possible deadlock");
        $finish;
    end

    // Sanity checks
    always @(posedge clk) begin
        if (ns_light[2] && ew_light[2]) begin
            $error("Illegal state: Both directions show GREEN");
        end
        if (ns_light[1] && ew_light[1]) begin
            $error("Illegal state: Both directions show YELLOW");
        end
        if (walk_ns && walk_ew) begin
            $error("Illegal state: Both walk signals active");
        end
        if ((ns_light != 3'b001) && (ew_light != 3'b001) &&
            (ns_light[1:0] != 2'b00) && (ew_light[1:0] != 2'b00)) begin
            $error("Illegal state: Conflicting traffic signals");
        end
    end

    // Utility Tasks
    task success (input string msg);
        $display("Phase '%s' - Success ",msg);
    endtask
    task wait_cycles (input int cycles);
        repeat (cycles) @(posedge clk);
    endtask

    task wait_for_state_ns_green();
        while (ns_light !== 3'b100) @(posedge clk);
    endtask

    task wait_for_state_ew_green();
        while (ew_light !== 3'b100) @(posedge clk);
    endtask

    task wait_until_yellow_ns();
        while (ns_light !== 3'b010) @(posedge clk);
    endtask

    task wait_until_yellow_ew();
        while (ew_light !== 3'b010) @(posedge clk);
    endtask

    task check_lights(
        input string phase,
        input logic [2:0] actual_ns,
        input logic [2:0] actual_ew,
        input logic [2:0] expected_ns,
        input logic [2:0] expected_ew
    );
        if (actual_ew !== expected_ew || actual_ns !== expected_ns) begin
            $error("Phase %s: Lights incorrect || EW: %b (expected: %b), NS: %b (expected: %b)",
                   phase, actual_ew, expected_ew, actual_ns, expected_ns);
        end
    endtask

endmodule
