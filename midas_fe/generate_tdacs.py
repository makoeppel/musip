import json

x = 10
vec = []
for col in range(256):
    for row in range(250):
        if col < (0+x) or col > (256-x) or row < (0+x) or row > (250-x) or (col==44 and row==19):
            vec.append(0x00)
        else:
            vec.append(0x40)
    # fill up col
    # -- store 0xdada as end-of-col marker
    vec.append(0xda)
    vec.append(0xda)
    # -- store number of col
    vec.append(0xda)
    vec.append(col)
    # -- store LVDS error flag
    vec.append(0xda)
    vec.append(0x00) # for now we don't use this
print(len(vec))

with open("mask_edge.h", "w") as f:
    json.dump(vec, f)

