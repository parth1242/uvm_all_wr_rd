class uvm_reg_single_all_wr_rd_seq extends uvm_reg_sequence #(uvm_sequence #(uvm_reg_item));

   // Variable: rg
   // The register to be tested
   uvm_reg rg;
   bit wr_rd;

   `uvm_object_utils(uvm_reg_single_all_wr_rd_seq)

   function new(string name="uvm_reg_single_all_wr_rd_seq");
     super.new(name);
   endfunction

   virtual task body();
      uvm_reg_field fields[$];
      string mode[`UVM_REG_DATA_WIDTH];
      uvm_reg_map maps[$];
      uvm_reg_data_t  dc_mask;
      uvm_reg_data_t  reset_val;
      int n_bits;
      string field_access;
         
      if (rg == null) begin
         `uvm_error("uvm_reg_all_wr_rd_seq", "No register specified to run sequence on");
         return;
      end

      // Registers with some attributes are not to be tested
      if (uvm_resource_db#(bit)::get_by_name({"REG::",rg.get_full_name()},
                                             "NO_REG_TESTS", 0) != null ||
          uvm_resource_db#(bit)::get_by_name({"REG::",rg.get_full_name()},
                                             "NO_REG_BIT_BASH_TEST", 0) != null )
            return;
      
      n_bits = rg.get_n_bytes() * 8;
         
      // Let's see what kind of bits we have...
      rg.get_fields(fields);
         
      // Registers may be accessible from multiple physical interfaces (maps)
      rg.get_maps(maps);
         
      // Bash the bits in the register via each map
      foreach (maps[j]) begin
         uvm_status_e status;
         uvm_reg_data_t  val, exp, v;
         int next_lsb;
         
         next_lsb = 0;
         dc_mask  = 0;
         foreach (fields[k]) begin
            int lsb, w, dc;

            field_access = fields[k].get_access(maps[j]);
            dc = (fields[k].get_compare() == UVM_NO_CHECK);
            lsb = fields[k].get_lsb_pos();
            w   = fields[k].get_n_bits();
            // Ignore Write-only fields because
            // you are not supposed to read them
            case (field_access)
             "WO", "WOC", "WOS", "WO1", "NOACCESS": dc = 1;
            endcase
            // Any unused bits on the right side of the LSB?
            while (next_lsb < lsb) mode[next_lsb++] = "RO";
            
            repeat (w) begin
               mode[next_lsb] = field_access;
               dc_mask[next_lsb] = dc;
               next_lsb++;
            end
         end
         // Any unused bits on the left side of the MSB?
         while (next_lsb < `UVM_REG_DATA_WIDTH)
            mode[next_lsb++] = "RO";
         
         `uvm_info("uvm_reg_all_wr_rd_seq", $sformatf("Verifying bits in register %s in map \"%s\"...",
                                    rg.get_full_name(), maps[j].get_full_name()),UVM_LOW);
         
         // Bash the kth bit
         //for (int k = 0; k < n_bits; k++) begin
            // Cannot test unpredictable bit behavior
          //  if (dc_mask[k]) continue;
            if(wr_rd == 0)    
                all_wr_pattern(maps[j]); 
            else
               all_rd_pattern(maps[j] , dc_mask);
         // bash_kth_bit(rg, k, mode[k], maps[j], dc_mask);
        // end
      end
   endtask: body

   task all_wr_pattern(uvm_reg_map     map);
       uvm_status_e status;
       uvm_reg_data_t val = '1;     
       rg.write(status, val, UVM_FRONTDOOR, map, this); 
   endtask
   
   task all_rd_pattern(uvm_reg_map     map , uvm_reg_data_t dc_mask);
       uvm_status_e status;
       uvm_reg_data_t exp , val;      
       exp = rg.get() & ~dc_mask;
       rg.read(status, val, UVM_FRONTDOOR, map, this);
       val &= ~dc_mask;    
       if (val !== exp) begin
            //`uvm_error("uvm_reg_all_wr_rd_seq", $sformatf("Writing a %b in bit #%0d of register \"%s\" with initial value 'h%h yielded 'h%h instead of 'h%h",
              //                          bit_val, k, rg.get_full_name(), v, val, exp));
             $display("Compare Error !!");  
        end
   endtask

endclass: uvm_reg_single_all_wr_rd_seq


//------------------------------------------------------------------------------
// Class: uvm_reg_all_wr_rd_seq
//
//
// Verify the implementation of all registers in a block
// by executing the <uvm_reg_single_all_wr_rd_seq> sequence on it.
//
// If bit-type resource named
// "NO_REG_TESTS" or "NO_REG_BIT_BASH_TEST"
// in the "REG::" namespace
// matches the full name of the block,
// the block is not tested.
//
//| uvm_resource_db#(bit)::set({"REG::",regmodel.blk.get_full_name(),".*"},
//|                            "NO_REG_TESTS", 1, this);
//
//------------------------------------------------------------------------------

class uvm_reg_all_wr_rd_seq extends uvm_reg_sequence #(uvm_sequence #(uvm_reg_item));

   // Variable: model
   //
   // The block to be tested. Declared in the base class.
   //
   //| uvm_reg_block model; 


   // Variable: reg_seq
   //
   // The sequence used to test one register
   //
   protected uvm_reg_single_all_wr_rd_seq reg_seq;
   
   `uvm_object_utils(uvm_reg_all_wr_rd_seq)

   function new(string name="uvm_reg_all_wr_rd_seq");
     super.new(name);
   endfunction


   // Task: body
   //
   // Executes the Register Bit Bash sequence.
   // Do not call directly. Use seq.start() instead.
   //
   virtual task body();
      
      if (model == null) begin
         `uvm_error("uvm_reg_all_wr_rd_seq", "No register model specified to run sequence on");
         return;
      end

      uvm_report_info("STARTING_SEQ",{"\n\nStarting ",get_name()," sequence...\n"},UVM_LOW);

      reg_seq = uvm_reg_single_all_wr_rd_seq::type_id::create("reg_single_bit_bash_seq");

      this.reset_blk(model);
      model.reset();

      do_block(model);
   endtask


   // Task: do_block
   //
   // Test all of the registers in a given ~block~
   //
   protected virtual task do_block(uvm_reg_block blk);
      uvm_reg regs[$];

      if (uvm_resource_db#(bit)::get_by_name({"REG::",blk.get_full_name()},
                                             "NO_REG_TESTS", 0) != null ||
          uvm_resource_db#(bit)::get_by_name({"REG::",blk.get_full_name()},
                                             "NO_REG_BIT_BASH_TEST", 0) != null )
         return;

      // Iterate over all registers, checking accesses
      blk.get_registers(regs, UVM_NO_HIER);
      foreach (regs[i]) begin
         // Registers with some attributes are not to be tested
         if (uvm_resource_db#(bit)::get_by_name({"REG::",regs[i].get_full_name()},
                                                "NO_REG_TESTS", 0) != null ||
	     uvm_resource_db#(bit)::get_by_name({"REG::",regs[i].get_full_name()},
                                                "NO_REG_BIT_BASH_TEST", 0) != null )
            continue;
         
         reg_seq.rg = regs[i];
         reg_seq.wr_rd = 0;   
         reg_seq.start(null,this);
      end

      foreach (regs[i]) begin
         // Registers with some attributes are not to be tested
         if (uvm_resource_db#(bit)::get_by_name({"REG::",regs[i].get_full_name()},
                                                "NO_REG_TESTS", 0) != null ||
	     uvm_resource_db#(bit)::get_by_name({"REG::",regs[i].get_full_name()},
                                                "NO_REG_BIT_BASH_TEST", 0) != null )
            continue;
         
         reg_seq.rg = regs[i];
         reg_seq.wr_rd = 1;   
         reg_seq.start(null,this);
      end        

      begin
         uvm_reg_block blks[$];
         
         blk.get_blocks(blks);
         foreach (blks[i]) begin
            do_block(blks[i]);
         end
      end
   endtask: do_block


   // Task: reset_blk
   //
   // Reset the DUT that corresponds to the specified block abstraction class.
   //
   // Currently empty.
   // Will rollback the environment's phase to the ~reset~
   // phase once the new phasing is available.
   //
   // In the meantime, the DUT should be reset before executing this
   // test sequence or this method should be implemented
   // in an extension to reset the DUT.
   //
   virtual task reset_blk(uvm_reg_block blk);
   endtask

endclass: uvm_reg_all_wr_rd_seq
