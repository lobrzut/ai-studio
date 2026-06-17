# AI Studio — Linux edition

## One-command install

```bash
curl -fsSL https://raw.githubusercontent.com/lobrzut/ai-studio/main/linux/bootstrap.sh | sudo bash
```

## Options

```bash
# CPU only (hub in Docker)
curl -fsSL .../linux/bootstrap.sh | sudo bash -s -- --profile cpu

# AMD ROCm (native ComfyUI)
curl -fsSL .../linux/bootstrap.sh | sudo bash -s -- --profile native-rocm

# Custom paths
curl -fsSL .../linux/bootstrap.sh | sudo bash -s -- --dir /srv/ai-studio --data /mnt/ai-data
```

## After install

```bash
/opt/ai-studio/linux/scripts/status.sh
/opt/ai-studio/linux/scripts/restart.sh
/opt/ai-studio/linux/scripts/stop.sh
```

## Manual

```bash
git clone https://github.com/lobrzut/ai-studio.git
cd ai-studio
sudo linux/install.sh
```

Uses `shared/web` and `shared/hub` from the monorepo root.
