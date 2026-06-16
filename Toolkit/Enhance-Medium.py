"""Resemble Enhance - single file (uzywane z Enhance.ps1 -Mode medium)."""
import sys
from pathlib import Path

_stub = Path(__file__).resolve().parent / "deepspeed_stub"
if _stub.is_dir():
    sys.path.insert(0, str(_stub))

def main() -> int:
    if len(sys.argv) < 3:
        print("Uzycie: Enhance-Medium.py <input> <output.wav>")
        return 2

    inp = Path(sys.argv[1]).resolve()
    out = Path(sys.argv[2]).resolve()
    if not inp.is_file():
        print(f"ERROR: brak pliku: {inp}")
        return 1

    out.parent.mkdir(parents=True, exist_ok=True)

    import torch
    import torchaudio
    from resemble_enhance.enhancer.inference import denoise, enhance

    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"Urzadzenie: {device}")

    dwav, sr = torchaudio.load(str(inp))
    if dwav.shape[0] > 1:
        dwav = dwav.mean(dim=0)
    else:
        dwav = dwav.squeeze(0)

    print("Denoise...")
    dwav, sr = denoise(dwav, sr, device)

    print("Enhance (nfe=64)...")
    wav2, sr2 = enhance(
        dwav,
        sr,
        device,
        nfe=64,
        solver="midpoint",
        lambd=0.1,
        tau=0.5,
    )

    torchaudio.save(str(out), wav2.unsqueeze(0).cpu(), sr2)
    print(f"Zapisano: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
