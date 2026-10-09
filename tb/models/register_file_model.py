from dataclasses import dataclass


@dataclass(frozen=True)
class RegisterFileReadInputs:
    read_addr_1: int
    read_addr_2: int


@dataclass(frozen=True)
class RegisterFileWriteInputs:
    write_addr: int
    write_data: int
    write_en: bool = True


@dataclass(frozen=True)
class RegisterFileReadOutputs:
    read_data_1: int | None
    read_data_2: int | None


class RegisterFileModel:
    def __init__(self, write_through: bool = False):
        self.registers: list[int | None] = [None] * 32
        self.write_through = write_through

    def _check_index(self, index: int) -> None:
        if not (0 <= index < len(self.registers)):
            raise IndexError("Register index out of range.")

    def _read_one(
        self, read_addr: int, pending_write: RegisterFileWriteInputs | None
    ) -> int | None:
        if read_addr == 0:
            return 0

        # Write-through bypass
        if (
            self.write_through
            and pending_write is not None
            and pending_write.write_en
            and pending_write.write_addr == read_addr
        ):
            return pending_write.write_data

        return self.registers[read_addr]

    def read(
        self,
        inputs: RegisterFileReadInputs,
        pending_write: RegisterFileWriteInputs | None = None,
    ) -> RegisterFileReadOutputs:
        """pending_write is the write port input not yet committed by a clock edge."""
        self._check_index(inputs.read_addr_1)
        self._check_index(inputs.read_addr_2)

        return RegisterFileReadOutputs(
            read_data_1=self._read_one(inputs.read_addr_1, pending_write),
            read_data_2=self._read_one(inputs.read_addr_2, pending_write),
        )

    def write(self, inputs: RegisterFileWriteInputs) -> None:
        self._check_index(inputs.write_addr)
        if inputs.write_en and inputs.write_addr != 0:  # Register x0 is hardwired to zero
            self.registers[inputs.write_addr] = inputs.write_data
