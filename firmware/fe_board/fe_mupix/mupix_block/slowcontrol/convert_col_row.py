# M. Mueller, March 2022

print("generating lookup table for reverse col row transformation")
print("https://www.physi.uni-heidelberg.de/Forschung/he/mu3e/restricted/notes/Mu3e-Note-0052-MuPix10_Documentation.pdf")

vhdl_input_order = []
vhdl_output_order = []

def convert(col,row):
  invrow = 0;
  newcol = 0;
  newrow = 0;
  newcol = col*2;
  invrow = (0x1FF & ~row)
  if invrow > 380:
      newcol +=1;
      newrow = int((499-invrow)/2);
      if (499-invrow)%2 == 1:
          newrow +=60;
  elif invrow > 255:
      newrow = (380-invrow)/2;
      if (380-invrow)%2 == 0:
          newrow += 62;
  elif invrow > 124:
      newrow = int((255-invrow)/2);
      newcol += 1;
      newrow += 119;
      if (255-invrow)%2 == 1:
          newrow += 66;
  else :
      newrow = int((124-invrow)/2);
      newrow += 125;
      if (124-invrow)%2 == 0:
          newrow += 62;


  # firmware gets the physical col row as input
  # and wants to know the location in memory (= digital addr.) where it should write it to.
  vhdl_input_order.append(newcol*250 + newrow)
  vhdl_output_order.append(row)
  #print(str(newcol*256+newrow) + ',')
  #print(col, row, newcol ,newrow);
  #print('when x"' + str(hex(newcol*250 + newrow)).replace('0x', '') + '" => mem_addr <= x"' + str(hex(row)).replace('0x', '') + '";')

def convert_mupix11(col, row):
  newrow = 0x1FF & (~row)
  newcol = col*2
  if newrow > 249:
    newcol += 1
    newrow -= 250

  vhdl_input_order.append(newcol*250 + newrow)
  vhdl_output_order.append(row)
  #print(str(newcol*256+newrow) + ',')
  #print(col, row, newcol ,newrow);
  first_str = str(hex(newcol*250 + newrow)).replace('0x', '')
  if len(first_str) == 2:
    first_str = "0" + first_str
  elif len(first_str) == 1:
    first_str = "00" + first_str
  second_str = str(hex(row)).replace('0x', '')
  if len(second_str) == 2:
    second_str = "0" + second_str
  elif len(second_str) == 1:
    second_str = "00" + second_str
  print('when x"' + first_str + '" => mem_addr <= x"' + second_str + '";')


for col in range(0, 1):
    for row in range(12, 512):
        #convert(col,row)
        convert_mupix11(col,row)
print(vhdl_input_order)
print(vhdl_output_order)

vhdl_inout = list(zip(vhdl_input_order,vhdl_output_order))
vhdl_inout_sorted = sorted(vhdl_inout, reverse = True)
print(vhdl_inout_sorted)
print(zip(*vhdl_inout_sorted)[1])
print("Length:", len(vhdl_inout_sorted))
print(vhdl_inout_sorted[250][1])
print(vhdl_inout_sorted[249])
print(vhdl_inout_sorted[250])
print(vhdl_inout_sorted[251])
