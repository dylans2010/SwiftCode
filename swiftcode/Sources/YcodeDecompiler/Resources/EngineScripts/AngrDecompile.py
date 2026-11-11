# AngrDecompile.py — SwiftCode YcodeDecompiler angr bridge script.
#
# Runs under a CPython interpreter that has `angr` installed. Loads the
# target binary once with angr/cle (no external libraries), builds one
# CFGFast model, then runs angr's Decompiler on each requested function
# address. Writes one JSON object per line to the output path given as the
# first script argument:
#
#   {"address": "0x...", "name": "...", "signature": "...",
#    "cCode": "...", "parameters": [...], "returnType": "...",
#    "localVariables": [...], "warnings": [...]}
#
# Per-function failures are recorded as {"error": "..."} records instead of
# aborting the run. Addresses with no recoverable function emit
# {"error": "function-not-found"}.
#
# Usage (assembled by AngrDecompiler):
#   python3 AngrDecompile.py <binaryPath> <outputJson> [--arch=NAME] <addrHex>...
#
# Progress lines are printed to stderr; analysis output goes only to the
# JSON file so angr/claripy logging cannot corrupt the contract.

import json
import os
import signal
import sys


class _Deadline(BaseException):
    """Raised by the SIGALRM handler when an analysis step exceeds its budget.

    Inherits BaseException (not Exception) so angr/claripy internals that
    swallow ``except Exception`` cannot accidentally absorb the deadline.
    """


def _alarm_handler(signum, frame):
    raise _Deadline()


signal.signal(signal.SIGALRM, _alarm_handler)


def _arm(seconds):
    signal.setitimer(signal.ITIMER_REAL, float(seconds))


def _disarm():
    signal.setitimer(signal.ITIMER_REAL, 0)


def signature_of(text):
    """First non-empty line of angr codegen text, up to the opening brace."""
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if "{" in stripped:
            return stripped.split("{", 1)[0].strip()
        return stripped
    return ""


def main():
    if len(sys.argv) < 4:
        print("AngrDecompile.py: usage: <binary> <out.json> [--arch=NAME] <addrHex>...", file=sys.stderr)
        return 2

    binary_path = sys.argv[1]
    out_path = sys.argv[2]
    # Records stream to the output file as they are produced so a timed-out
    # or killed run still yields every completed decompilation.
    out_fh = open(out_path, "w")
    arch = None
    raw_addrs = []
    for arg in sys.argv[3:]:
        if arg.startswith("--arch="):
            arch = arg.split("=", 1)[1]
        else:
            raw_addrs.append(arg)
    # Each target is "0xADDR" optionally followed by ":0xEND" — the end
    # bound lets the per-function fallback run a region-limited CFGFast
    # when the whole-binary CFG did not finish in time.
    entries = []
    for raw in raw_addrs:
        addr_text, _, end_text = raw.partition(":")
        try:
            addr = int(addr_text, 16)
        except ValueError:
            try:
                addr = int(addr_text, 0)
            except ValueError:
                print("AngrDecompile.py: bad address %r" % raw, file=sys.stderr)
                continue
        end = None
        if end_text:
            try:
                end = int(end_text, 16)
            except ValueError:
                try:
                    end = int(end_text, 0)
                except ValueError:
                    end = None
        entries.append((addr, end))
    addresses = [addr for addr, _ in entries]

    import angr  # noqa: E402  (import after arg check so --help stays cheap)

    print("angr %s loading %s" % (angr.__version__, binary_path), file=sys.stderr)
    main_opts = {"arch": arch} if arch else {}
    project = angr.Project(binary_path, auto_load_libs=False, main_opts=main_opts)

    # CFGFast on multi-megabyte binaries can run for hours; cap it and fall
    # back to per-function recovery (cfg=None) when it does not finish.
    cfg_timeout = float(os.environ.get("ANGR_CFGFAST_TIMEOUT", "240"))
    cfg = None
    try:
        if cfg_timeout > 0:
            _arm(cfg_timeout)
        try:
            cfg = project.analyses.CFGFast(normalize=True)
        finally:
            _disarm()
    except _Deadline:
        print("AngrDecompile.py: CFGFast timed out after %ss; "
              "continuing without a global CFG" % cfg_timeout, file=sys.stderr)
        cfg = None
    except Exception as exc:
        print("AngrDecompile.py: CFGFast failed: %s" % exc, file=sys.stderr)
        cfg = None

    kb = project.kb
    records = []

    def write_rec(rec):
        records.append(rec)
        out_fh.write(json.dumps(rec) + "\n")
        out_fh.flush()

    for index, (addr, func_end) in enumerate(entries):
        rec = {
            "address": "0x%x" % addr,
            "name": "",
            "signature": "",
            "cCode": "",
            "parameters": [],
            "returnType": "",
            "localVariables": [],
            "warnings": [],
        }
        func_timeout = float(os.environ.get("ANGR_FUNC_TIMEOUT", "90"))
        try:
            try:
                if func_timeout > 0:
                    _arm(func_timeout)
                try:
                    if cfg is not None:
                        func = kb.functions.get(addr)
                        if func is None:
                            func = kb.functions.function(addr, create=True)
                        fmodel = cfg.model
                    else:
                        # No global CFG: recover just this function with a
                        # region-limited CFGFast so the Decompiler gets a
                        # normalized graph without paying for the whole
                        # binary.
                        region_end = func_end if func_end and func_end > addr else addr + 0x10000
                        fcfg = project.analyses.CFGFast(
                            regions=[(addr, region_end)],
                            function_starts=[addr], normalize=True)
                        func = fcfg.kb.functions.get(addr)
                        if func is None:
                            func = fcfg.kb.functions.function(addr, create=True)
                        fmodel = fcfg.model
                    if func is None or func.is_simprocedure or func.is_plt:
                        rec["error"] = "function-not-found"
                        write_rec(rec)
                        continue
                    # angr's Decompiler requires a normalized function graph;
                    # functions recovered without CFGFast are not normalized.
                    if not func.normalized:
                        func.normalize()
                    dec = project.analyses.Decompiler(func, cfg=fmodel)
                    text = dec.codegen.text if dec.codegen is not None else ""
                finally:
                    _disarm()
            except _Deadline:
                rec["error"] = "decompile-timeout after %ss" % func_timeout
                rec["warnings"] = [rec["error"]]
                write_rec(rec)
                continue
            if dec.codegen is None:
                rec["error"] = "decompilation-failed"
                rec["warnings"] = [rec["error"]]
                write_rec(rec)
                continue
            rec["cCode"] = text or ""
            if not text.strip():
                rec["warnings"].append("empty-codegen")
            rec["signature"] = signature_of(text)
            rec["name"] = func.name or ("sub_%x" % addr)
            try:
                rec["returnType"] = str(dec.codegen.returnty) if dec.codegen is not None else ""
            except Exception:
                pass
            write_rec(rec)
        except Exception as exc:
            rec["error"] = "exception: %s" % exc
            rec["warnings"] = [rec["error"]]
            write_rec(rec)
        if (index + 1) % 25 == 0:
            print("angr: %d/%d decompiled" % (index + 1, len(addresses)), file=sys.stderr)

    out_fh.close()
    print("angr: wrote %d records to %s" % (len(records), out_path), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
