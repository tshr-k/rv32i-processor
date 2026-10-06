from dataclasses import dataclass


@dataclass
class RegisterFileOutput:
    read_value_1: int | None
    read_value_2: int | None


class RegisterFileModel:
    def __init__(self):
        self.registers: list[int | None] = [None] * 32

    def _check_index(self, index: int) -> None:
        if not (0 <= index < len(self.registers)):
            raise IndexError("Register index out of range.")

    def read(self, index_1: int, index_2: int) -> RegisterFileOutput:
        self._check_index(index_1)
        self._check_index(index_2)

        return RegisterFileOutput(
            read_value_1=self.registers[index_1] if index_1 != 0 else 0,
            read_value_2=self.registers[index_2] if index_2 != 0 else 0,
        )

    def write(self, index: int, value: int, en: bool = True) -> None:
        self._check_index(index)
        if en and index != 0:  # Register x0 is hardwired to zero
            self.registers[index] = value
