\m4_TLV_version 1d: tl-x.org
\SV

   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/main/lib/risc-v_shell_lib.tlv'])


   //---------------------------------------------------------------------------------
   m4_test_prog()
 
   m4_define(['M4_MAX_CYC'], 2000)
   //---------------------------------------------------------------------------------



\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
   /* verilator lint_on WIDTH */
\TLV
   
   $reset = *reset;
   $pc[31:0]      = >>1$next_pc;
   $inc_pc[31:0]   = $pc + 32'd4;
   $next_pc[31:0]  = $reset ? 32'b0 :    
   $is_jalr      ? $jalr_tgt_pc        :
   $is_j_instr   ? $br_tgt_pc          :   // JAL uses PC+imm
   $taken_br ? $br_tgt_pc : $inc_pc ;
   `READONLY_MEM($pc, $$instr[31:0]);

   $is_u_instr = ($instr[6:2] ==? 5'b0x101);
   $is_b_instr = ($instr[6:2] ==? 5'b11000);
   $is_j_instr = ($instr[6:2] ==? 5'b11011);
   $is_s_instr = ($instr[6:2] ==? 5'b0100x);
   $is_i_instr = ($instr[6:2] ==? 5'b0000x)  ||  // LOAD family
                 ($instr[6:2] ==  5'b00011)  || // FENCE
                 ($instr[6:2] ==  5'b00100)  || // OP-IMM
                 ($instr[6:2] ==  5'b11001)  || // JALR
                 ($instr[6:2] ==  5'b11100);    // SYSTEM
   $is_r_instr = ($instr[6:2] ==  5'b01100);
   $is_load    = ($instr[6:2] ==? 5'b0000x);   // LB/LH/LW/LBU/LHU (the LOAD family)

   $opcode[6:0] = $instr[6:0] ;
   
   $rd[4:0]     = $instr[11:7];
   $rd_valid = $is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr; 
   
   $funct3[2:0] = $instr[14:12];
   $funct3_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr; 
   
   $rs1[4:0]    = $instr[19:15];
   $rs1_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr; 
   
   $rs2[4:0]    = $instr[24:20];
   $rs2_valid = $is_r_instr || $is_s_instr || $is_b_instr; 
   
   $imm_valid = $is_u_instr || $is_i_instr || $is_s_instr || $is_b_instr || $is_j_instr; 
   
   
   $imm[31:0]   =
    // I-type:  imm[11:0] = instr[31:20]
    $is_i_instr ? { {21{$instr[31]}}, $instr[30:20] } :

    // S-type:  imm[11:5]=instr[31:25], imm[4:0]=instr[11:7]
    $is_s_instr ? { {21{$instr[31]}}, $instr[30:25], $instr[11:7] } :

    // B-type:  imm[12|10:5|4:1|11] << 1 (LSB is 0)
    $is_b_instr ? { {19{$instr[31]}},  // sign bits [31:13]
                  $instr[31],        // imm[12]
                  $instr[7],         // imm[11]
                  $instr[30:25],     // imm[10:5]
                  $instr[11:8],      // imm[4:1]
                  1'b0 } :           // imm[0]
    // U-type:  imm[31:12]=instr[31:12], low 12 zeros
    $is_u_instr ? { $instr[31:12], 12'b0 } :

    // J-type:  imm[20|10:1|11|19:12] << 1 (LSB is 0)
    $is_j_instr ? { {11{$instr[31]}},  // sign bits [31:21]
                  $instr[31],        // imm[20]
                  $instr[19:12],     // imm[19:12]
                  $instr[20],        // imm[11]
                  $instr[30:21],     // imm[10:1]
                  1'b0 } :


    32'b0;   // (R-type default)

   $dec_bits[10:0] = { $instr[30], $funct3, $opcode };
   $is_lui    = $dec_bits ==? 11'bx_xxx_0110111;
   $is_auipc  = $dec_bits ==? 11'bx_xxx_0010111;
   $is_jal    = $dec_bits ==? 11'bx_xxx_1101111;
   $is_jalr   = $dec_bits ==? 11'bx_000_1100111;

   $is_beq  = $dec_bits ==? 11'bx_000_1100011;
   $is_bne  = $dec_bits ==? 11'bx_001_1100011;
   $is_blt  = $dec_bits ==? 11'bx_100_1100011;
   $is_bge  = $dec_bits ==? 11'bx_101_1100011;
   $is_bltu = $dec_bits ==? 11'bx_110_1100011;
   $is_bgeu = $dec_bits ==? 11'bx_111_1100011;
   
   $is_slti  = $dec_bits ==? 11'bx_010_0010011;
   $is_sltiu = $dec_bits ==? 11'bx_011_0010011;
   $is_xori  = $dec_bits ==? 11'bx_100_0010011;
   $is_ori   = $dec_bits ==? 11'bx_110_0010011;
   $is_andi  = $dec_bits ==? 11'bx_111_0010011;
   
   $is_slli  = $dec_bits ==? 11'b0_001_0010011;
   $is_srli  = $dec_bits ==? 11'b0_101_0010011;
   $is_srai  = $dec_bits ==? 11'b1_101_0010011;

   $is_addi = $dec_bits ==? 11'bx_000_0010011;
   $is_add  = $dec_bits ==  11'b0_000_0110011;
   
   $is_sub   = $dec_bits == 11'b1_000_0110011;
   $is_sll   = $dec_bits == 11'b0_001_0110011;
   $is_slt   = $dec_bits == 11'b0_010_0110011;
   $is_sltu  = $dec_bits == 11'b0_011_0110011;
   $is_xor   = $dec_bits == 11'b0_100_0110011;
   $is_srl   = $dec_bits == 11'b0_101_0110011;
   $is_sra   = $dec_bits == 11'b1_101_0110011;
   $is_or    = $dec_bits == 11'b0_110_0110011;
   $is_and   = $dec_bits == 11'b0_111_0110011;

   $sltu_rslt[31:0] = {31'b0,$src1_value < $src2_value}; 
   $sltiu_rslt[31:0] = {31'b0,$src1_value < $imm};
   $sext_src1[63:0] = {{32{$src1_value[31]}},$src1_value}; 
   $sra_rslt[63:0]  = $sext_src1 >> $src2_value[4:0]; 
   $srai_rslt[63:0] = $sext_src1 >> $imm[4:0]; 


   
   $result[31:0] = 
                   $is_load   ? ($src1_value + $imm) :     // address for LOAD
                   $is_s_instr? ($src1_value + $imm) :     // address for STORE
                   $is_addi ? $src1_value + $imm :
                   $is_add  ? $src1_value + $src2_value:
                   $is_ori  ? $src1_value | $imm :
                   $is_xori  ? $src1_value ^ $imm :
                   $is_andi  ? $src1_value & $imm :
                   $is_and  ? $src1_value & $src2_value :
                   $is_or  ? $src1_value | $src2_value :
                   $is_xor  ? $src1_value ^ $src2_value :
                   $is_sub  ? $src1_value - $src2_value :
                   $is_slli ? ($src1_value <<  $imm[4:0]) :
                   $is_srli ? ($src1_value >>  $imm[4:0]) :

                   $is_sltu ? $sltu_rslt :
                   $is_sltiu ? $sltiu_rslt:
                   $is_lui   ? { $imm[31:12], 12'b0 } :
                   $is_auipc ? ($pc + $imm)  :
                   $is_jal   ? ($pc + 32'd4) : 
                   $is_jalr  ? ($pc + 32'd4) :
                   
                   $is_slt   ? ( ($src1_value[31] == $src2_value[31]) ? 
                                     $sltu_rslt :
                                     {31'b0, $src1_value[31]}) :      
                                     
                   $is_slti  ? ( ($src1_value[31] == $imm[31]) ? 
                                    $sltiu_rslt :
                                    {31'b0, $src1_value[31]} ) :
                                    
                   $is_sra   ? $sra_rslt[31:0]  :
                   $is_srai  ? $srai_rslt[31:0] :
                   32'b0;
                  
   $taken_br = $is_beq ? ($src1_value == $src2_value) :
               $is_bne ? ($src1_value != $src2_value) :
               $is_blt ? (($src1_value < $src2_value) ^ ($src1_value[31] != $src2_value[31]) ) :
               $is_bge ? (($src1_value >= $src2_value)^ ($src1_value[31] != $src2_value[31]) ) :
               $is_bltu ? ($src1_value < $src2_value) :
               $is_bgeu ? ($src1_value >= $src2_value) :
               1'b0;
   $br_tgt_pc[31:0] = $pc + $imm;
   $jalr_tgt_pc[31:0] = ($src1_value + $imm) & 32'hFFFF_FFFE;



   `BOGUS_USE($rd $rd_valid 
                 $rs1 $rs1_valid 
                 $rs2 $rs2_valid 
                 $funct3 $funct3_valid 
                 $imm_valid $imm 
                 $opcode 
                 $is_u_instr $is_b_instr $is_j_instr $is_s_instr $is_i_instr $is_r_instr
                 $dec_bits $is_beq $is_bne $is_blt $is_bge $is_bltu $is_bgeu
                 $is_addi $is_add);
   `BOGUS_USE($src1_value $src2_value $result $is_load $ld_data);
             

 



   // Assert these to end simulation (before Makerchip cycle limit).
   m4+tb()
   *failed = *cyc_cnt > M4_MAX_CYC;

   m4+rf(32, 32, $reset,
      $rd_valid, $rd, ($is_load ? $ld_data : $result),
      $rs1_valid, $rs1, $src1_value,
      $rs2_valid, $rs2, $src2_value)

   m4+dmem(32, 32, $reset,
      $result[6:2],   // word index (byte addr -> word addr)
      $is_s_instr,    // write enable for stores
      $src2_value,    // store data (rs2)
      $is_load,       // read enable for loads
      $ld_data)       // load data (output)

   m4+cpu_viz()

\SV
   endmodule
