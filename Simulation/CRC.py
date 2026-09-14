POLY = 0x4599
WIDTH = 15
MASK = (1 << WIDTH) - 1

bits = (
"1"
)

crc = 16384

print("bit  input  crc_before  feedback  crc_after")
print("-" * 50)

for i, bit in enumerate(bits):
    bit = int(bit)

    crc_before = crc

    feedback = ((crc >> 14) & 1) ^ bit

    crc = (crc << 1) & MASK

    if feedback:
        crc ^= POLY

    print(
        f"{i:3d}    {bit}     "
        f"{crc_before:04X}        "
        f"{feedback}       "
        f"{crc:04X}"
    )

print()
print(f"Number of bits : {len(bits)}")
print(f"Final CRC      : 0x{crc:04X}")