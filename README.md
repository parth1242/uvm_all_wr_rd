# uvm_all_wr_rd
UVM register sequence to write all registers and read back with fix pattern 

How to use ? 
Use this sequence same as uvm reg bit bash sequnce . Pass  register model and start sequence same as bit_bash / hw_reset sequence. 

Sequence Flow 

-> Write all Register in block with data as all '1 
-> Read back and compare
-> Write all Register in block with random data 
-> Read back and compare
