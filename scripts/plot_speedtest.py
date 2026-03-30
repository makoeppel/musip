import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("/home/mu3e/mkoeppel/musip/build/speed_test.csv", sep=";")

cut = df["num_hits_per_package"] > 0

time = df[cut].index
x = (df[cut]["#DMA-hit"] * 1e6 / time) / 1000000   # MHz
y = df[cut]["num_hits_per_package"]
z = df[cut]["#DMA-skip"] / (df[cut]["#DMA-hit"] + df[cut]["#DMA-skip"])

# Conversion functions: MHz <-> Gbit/s (64 bits per hit)
BITS_PER_HIT = 64

def MHz_to_Gbps(x):
    return x * BITS_PER_HIT / 1000

def Gbps_to_MHz(x):
    return x * 1000 / BITS_PER_HIT


fig, ax = plt.subplots(figsize=(8,6))

sc = ax.scatter(x, y, c=z, cmap='viridis')
fig.colorbar(sc, label='DMA skip ratio')

ax.set_xlabel('DMA hit rate [MHz]')
ax.set_ylabel('# hits per sorter package')

secax = ax.secondary_xaxis('bottom', functions=(MHz_to_Gbps, Gbps_to_MHz))
secax.set_xlabel('PCIe throughput [Gbit/s]')
secax.spines['bottom'].set_position(('outward', 40))

fig.subplots_adjust(bottom=0.22)   # make more room at the bottom
fig.savefig("scan-dma.pdf", bbox_inches="tight")


x = ((df["#hits0"] + df["#hits1"] + df["#hits2"] + df["#hits3"]) * 1e6 / time) / 1000000   # MHz
y = (df["#MUX"] * 1e6 / time) / 1000000   # MHz

plt.figure(figsize=(8,6))
plt.plot(x, y, '.')

plt.xlabel('hit rate input [MHz]')
plt.ylabel('hit rate MUX output [MHz]')

plt.savefig("scan-mux.pdf")
