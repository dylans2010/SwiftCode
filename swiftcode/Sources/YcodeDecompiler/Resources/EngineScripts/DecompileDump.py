# DecompileDump.py — SwiftCode YcodeDecompiler Ghidra bridge script.
#
# Jython postScript executed inside `analyzeHeadless`. For every function in
# the current program (or only the function whose entry point matches the
# optional address filter) it runs the Ghidra decompiler and writes one JSON
# object per line to the output path given as the first script argument:
#
#   {"address": "0x...", "name": "...", "signature": "...",
#    "cCode": "...", "parameters": [...], "returnType": "...",
#    "localVariables": [...], "warnings": [...]}
#
# Per-function failures are recorded as {"error": "..."} records instead of
# aborting the run. When an address filter is supplied and no function entry
# point matches, a single {"error": "function-not-found"} record is emitted.
#
# Usage (assembled by GhidraDecompiler):
#   analyzeHeadless <projectDir> <projectName> -process [<programName>]
#       -noanalysis -scriptPath <dir> -postScript DecompileDump.py
#       <outputJson> [functionAddressHex]

import json

from ghidra.app.decompiler import DecompInterface
from ghidra.util.task import ConsoleTaskMonitor


def _emit(path, records):
    with open(path, "w") as fh:
        for rec in records:
            fh.write(json.dumps(rec) + "\n")


def run():
    args = getScriptArgs()
    if len(args) < 1:
        print("DecompileDump.py: missing required output path argument")
        return
    out_path = args[0]

    filter_offset = None
    if len(args) > 1 and args[1]:
        try:
            filter_offset = int(args[1], 16)
        except Exception:
            try:
                filter_offset = int(args[1])
            except Exception:
                filter_offset = None

    fm = currentProgram.getFunctionManager()
    ifc = DecompInterface()
    ifc.openProgram(currentProgram)
    monitor = ConsoleTaskMonitor()
    records = []
    matched = False

    try:
        functions = fm.getFunctions(True)
        while functions.hasNext() and not monitor.isCancelled():
            func = functions.next()
            entry = func.getEntryPoint()
            if entry is None:
                continue
            if filter_offset is not None and entry.getOffset() != filter_offset:
                continue
            matched = True
            rec = {
                "address": "0x%x" % entry.getOffset(),
                "name": func.getName(),
                "signature": "",
                "cCode": "",
                "parameters": [],
                "returnType": "",
                "localVariables": [],
                "warnings": [],
            }
            try:
                result = ifc.decompileFunction(func, 60, monitor)
                if result is None or not result.decompileCompleted():
                    msg = "decompilation did not complete"
                    if result is not None:
                        errs = result.getErrorMessages()
                        if errs:
                            msg = "; ".join(str(e) for e in errs)
                    rec["error"] = msg
                    rec["warnings"] = [msg]
                else:
                    df = result.getDecompiledFunction()
                    if df is None:
                        rec["error"] = "no decompiled function produced"
                        rec["warnings"] = [rec["error"]]
                    else:
                        rec["cCode"] = df.getC() or ""
                        rec["signature"] = df.getSignature() or ""
                        try:
                            rec["localVariables"] = [
                                str(v) for v in df.getLocalVariables()
                            ][:128]
                        except Exception:
                            pass
                        try:
                            for e in result.getErrorMessages():
                                rec["warnings"].append(str(e))
                        except Exception:
                            pass
            except Exception as exc:
                rec["error"] = "exception: %s" % exc
                rec["warnings"] = [rec["error"]]
            records.append(rec)
            if filter_offset is not None:
                break
    finally:
        try:
            ifc.dispose()
        except Exception:
            pass

    if filter_offset is not None and not matched:
        records.append({
            "error": "function-not-found",
            "address": "0x%x" % filter_offset,
        })

    _emit(out_path, records)


run()
