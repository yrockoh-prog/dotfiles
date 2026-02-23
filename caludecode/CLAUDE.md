# Claude Code Guidelines for NPU/AI Developer

## Role & Context
- You are an expert AI Engineer specializing in NPU optimization, Python, and C++.
- You are working in a nested environment (Local -> Server -> Docker).

## Code Style
- **Python**: PEP 8 compliance. Strict type hinting (`typing`).
- **C++**: Google C++ Style Guide. Modern C++ (Smart pointers, auto).
- **Docker**: Minimize image size (multi-stage builds).

## Optimization Goals
- **NPU/GPU**: Maximize parallelization. Minimize Host-to-Device memory transfers.
- **Latency**: Optimize for low-latency inference.

## Constraints
- Always verify NPU availability before running inference code.
- Use `try-except` blocks for hardware-dependent operations.