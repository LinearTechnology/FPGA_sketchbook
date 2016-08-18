# -*- coding: utf-8 -*-
"""
Created on Wed Jul 15 10:35:05 2015

@author: mark_t
"""

import numpy as np
from matplotlib import pyplot as plt
from math import sin

windowme = True

#Generate funky SINC data
total_samples = 65536 # n.BuffSize
data = total_samples * [0]
dataraw = total_samples * [0]
window = np.hanning(len(data))
for i in range(0, total_samples):
    x = ((i - 32768) / (512.0)) + 0.0001 # Add a tiny offset to avoid divide by zero
    data[i] = int(32000 * (sin(x) / x))
    dataraw[i] = data[i]
    if windowme == True:
        data[i] *= window[i]
        dataraw[i] *= window[i]
    data[i] = int(data[i])
    if(data[i] < 0):
        data[i] += 65536

plt.figure(1)
plt.title("Actual data")
plt.plot(dataraw)
plt.show()

plt.figure(2)
plt.title("After putting into unsigned MIF format")
plt.plot(data)
plt.show()

# Testing file I/O

print('writing data out to file')
outfile = open('lut_initialization.mif', 'w')
outfile2 = open('lut_initialization.txt', 'w')
# Write out header information
outfile.write("-- Quartus II generated Memory Initialization File (.mif)" + "\n")
outfile.write("WIDTH=16;" + "\n")
outfile.write("DEPTH=65536;" + "\n")
outfile.write("ADDRESS_RADIX=UNS;" + "\n")
outfile.write("DATA_RADIX=UNS;" + "\n")
outfile.write("CONTENT BEGIN" + "\n")

for i in range(0, total_samples):
    outfile.write(str(i) + " : " + str(data[i]) + ";\n")
    outfile2.write(str(data[i]) + "\n")
outfile.write("END;")
outfile.close()
print('done writing!')