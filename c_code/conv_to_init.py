import sys
from pathlib import Path


def main():
    if len(sys.argv) != 4:
        print(
            "Usage: conv_to_init.py clk_freq sram_addr_width filename",
            file=sys.stderr,
        )
        sys.exit(1)

    try:
        clk_freq = int(sys.argv[1])
    except ValueError:
        print("clk_freq must be positive", file=sys.stderr)
        sys.exit(1)

    try:
        sram_addr_width = int(sys.argv[2])
    except ValueError:
        print("sram_addr_width must be positive", file=sys.stderr)
        sys.exit(1)

    if clk_freq <= 0:
        print("clk_freq must be positive", file=sys.stderr)
        sys.exit(1)

    if sram_addr_width <= 0:
        print("sram_addr_width must be positive", file=sys.stderr)
        sys.exit(1)

    mem_bytes = 4 * (1 << sram_addr_width)

    input_file = Path(sys.argv[3])

    if not input_file.exists():
        print(f"Could not open {input_file}", file=sys.stderr)
        sys.exit(1)

    src_dir = Path("../src")

    try:
        data = input_file.read_bytes()
    except OSError as exc:
        print(f"Could not read {input_file}: {exc}", file=sys.stderr)
        sys.exit(1)

    output_files = []

    try:
        for i in range(4):
            output_file = src_dir / f"mem_init{i}.ini"
            output_files.append(output_file.open("w", newline="\n"))

        sys_parameters = src_dir / "sys_parameters.v"

        with sys_parameters.open("w", newline="\n") as fp_param:
            fp_param.write(
                f"localparam SRAM_ADDR_WIDTH = {sram_addr_width};\n"
            )
            fp_param.write(
                f"localparam CLK_FREQ = {clk_freq};\n"
            )

        byte_count = 0

        for byte_value in data:
            output_files[byte_count % 4].write(f"{byte_value:02X}\n")
            byte_count += 1

        while byte_count % 16 != 0:
            output_files[byte_count % 4].write("00\n")
            byte_count += 1

    except OSError as exc:
        print(f"Could not create output files: {exc}", file=sys.stderr)
        sys.exit(1)

    finally:
        for fp in output_files:
            fp.close()

    if byte_count > mem_bytes:
        print(
            f"ERROR: PROGRAM IS TOO LARGE: {byte_count} bytes is",
            file=sys.stderr,
        )
        print(
            f"       greater than {mem_bytes} bytes",
            file=sys.stderr,
        )
        print(
            "And don't forget to leave room for the stack",
            file=sys.stderr,
        )
        sys.exit(1)

    print(f"NOTE: program occupies {byte_count} bytes")


if __name__ == "__main__":
    main()