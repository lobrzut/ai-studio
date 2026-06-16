class _Accelerator:
    def communication_backend_name(self) -> str:
        return "gloo"


def get_accelerator() -> _Accelerator:
    return _Accelerator()
