`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/10/2025 03:42:16 PM
// Design Name: 
// Module Name: TLC
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module TLC #(
    parameter EW_GREEN_TIME = 'd300,
    parameter NS_GREEN_TIME = 'd120,
    parameter ALL_RED_TIME = 'd5,
    parameter YELLOW_TIME = 'd30,
    parameter PED_DELAY_TIME = 'd50,
    parameter MIN_GREEN_TIME = 'd50
)(
    input logic clk,
    input logic rst_n,
    input logic ped_ew,
    input logic ped_ns,
    output logic [2:0] ns_light,
    output logic [2:0] ew_light,
    output logic walk_ns,
    output logic walk_ew
    );
    
    typedef enum logic [2:0] {
        All_Red_1,
        EW_Green,
        EW_Yellow,
        All_Red_2,
        NS_Green,
        NS_Yellow
    }state;
    
    localparam GREEN  = 3'b100;
    localparam YELLOW = 3'b010;
    localparam RED    = 3'b001; 
    
    state current_state, next_state;
    
    logic [15:0] green_time;
    logic [15:0] current_time, time_out;
    logic timer_done;
    

    logic ped_ew_pressed, ped_ns_pressed;
    logic [15:0] ped_ew_timer, ped_ns_timer;
    logic ped_request_served;
    logic ped_ew_allowed, ped_ns_allowed; 

    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_time <= 'b0;
        else if (timer_done)
            current_time <= 'b0;
        else
            current_time <= current_time + 1'b1;
    end
    
    assign timer_done = (current_time >= time_out);
    
    
    
    always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n)
                green_time <= 'b0;
            else if (current_state != EW_Green && current_state != NS_Green)
                green_time <= 'b0;
            else if (timer_done)
                green_time <= 'b0;
            else
                green_time <= green_time + 1'b1;
        end

    
    
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ped_ew_timer <= 'b0;
            ped_ns_timer <= 'b0;
        end 
        else begin
            if (walk_ew) ped_ew_timer <= 'b0;
            else ped_ew_timer <= ped_ew_timer + 1'b1;
            
            if (walk_ns) ped_ns_timer <= 'b0;
            else ped_ns_timer <= ped_ns_timer + 1'b1;
        end
    end
    
    assign ped_ew_allowed = (ped_ew_timer >= PED_DELAY_TIME);
    assign ped_ns_allowed = (ped_ns_timer >= PED_DELAY_TIME);
    
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ped_ew_pressed <= 1'b0;
            ped_ns_pressed <= 1'b0;
        end else begin
        
        if (ped_ew && !walk_ew && ped_ew_allowed) ped_ew_pressed <= 1'b1;
        else if (current_state == EW_Yellow && timer_done) ped_ew_pressed <= 1'b0;
        
        if (ped_ns && !walk_ns && ped_ns_allowed) ped_ns_pressed <= 1'b1;
        else if (current_state == NS_Yellow && timer_done) ped_ns_pressed <= 1'b0;
        
       end 
    end
    
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= All_Red_1;
        end 
        else begin
            current_state <= next_state;
        end
    end
    
    
    always_comb begin
        
        time_out = ALL_RED_TIME;
        walk_ew = 1'b0;
        walk_ns = 1'b0;
        ns_light = RED;
        ew_light = RED;
        
        next_state = current_state;
    
    
        case (current_state)
            All_Red_1: begin
                time_out = ALL_RED_TIME;
                ns_light = RED;
                ew_light = RED;
                if (timer_done) next_state = EW_Green;
            end
            
            
            
            EW_Green: begin
                time_out = EW_GREEN_TIME;
                ew_light = GREEN;
                ns_light = RED;
                walk_ew = 1'b1;
                walk_ns = 1'b0;
                if ((timer_done) || (ped_ns_pressed && (green_time >= MIN_GREEN_TIME)))  next_state = EW_Yellow;
            end
            
            EW_Yellow: begin
                time_out = YELLOW_TIME;
                ew_light = YELLOW;
                walk_ew = 1'b0;
                walk_ns = 1'b0;
                if (timer_done) next_state = All_Red_2;
            end
            
            All_Red_2: begin
                time_out = ALL_RED_TIME;
                ns_light = RED;
                ew_light = RED;
                walk_ew = 1'b0;
                walk_ns = 1'b0;
                if (timer_done) next_state = NS_Green;
            end
            
            NS_Green: begin
                time_out = NS_GREEN_TIME;
                ns_light = GREEN;
                ew_light = RED;
                walk_ns = 1'b1;
                if ((timer_done) || (ped_ew_pressed && (green_time >= MIN_GREEN_TIME))) next_state = NS_Yellow;
            end           
            
            NS_Yellow: begin
                time_out = YELLOW_TIME;
                ns_light = YELLOW;
                walk_ew = 1'b0;
                walk_ns = 1'b0;
                if (timer_done) next_state = All_Red_1;
            end
            
            default: next_state = All_Red_1;
    endcase
    end

endmodule
