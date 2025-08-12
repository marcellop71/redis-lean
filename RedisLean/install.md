# Installation

### Prerequisites

**Lean 4**: Install via `elan`
```bash
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh
```

**hiredis library**: System dependency
```bash
# Ubuntu/Debian
sudo apt-get install libhiredis-dev

# macOS  
brew install hiredis

# Arch Linux
sudo pacman -S hiredis
```

**Redis server**: For testing
```bash
# Start with Docker
docker run -d -p 6379:6379 redis:latest

# Or install locally
sudo apt-get install redis-server  # Ubuntu
brew install redis                 # macOS
```

### Build

```bash
git clone https://github.com/marcellop71/redis-lean.git
cd redis-lean
lake build
```
