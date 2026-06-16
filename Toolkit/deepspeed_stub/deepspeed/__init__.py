"""Minimal deepspeed stub for resemble-enhance inference on Windows (no native build)."""


def init_distributed(backend: str) -> None:
    del backend


class DeepSpeedConfig:
    def __init__(self, *args, **kwargs):
        del args, kwargs
