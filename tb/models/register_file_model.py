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
    def __init__(self):
        self.registers: list[int | None] = [None] * 32

    def _check_index(self, index: int) -> None:
        if not (0 <= index < len(self.registers)):
            raise IndexError("Register index out of range.")

    def read(self, inputs: RegisterFileReadInputs) -> RegisterFileReadOutputs:
        self._check_index(inputs.read_addr_1)
        self._check_index(inputs.read_addr_2)

        return RegisterFileReadOutputs(
            read_data_1=self.registers[inputs.read_addr_1] if inputs.read_addr_1 != 0 else 0,
            read_data_2=self.registers[inputs.read_addr_2] if inputs.read_addr_2 != 0 else 0,
        )

    def write(self, inputs: RegisterFileWriteInputs) -> None:
        self._check_index(inputs.write_addr)
        if inputs.write_en and inputs.write_addr != 0:  # Register x0 is hardwired to zero
            self.registers[inputs.write_addr] = inputs.write_data
