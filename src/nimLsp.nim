import std/jsconsole
import platform/[vscodeApi, languageClientApi]

import platform/js/[jsNodeFs, jsNodePath, jsNodeCp]
import tables

from std/strformat import fmt
from tools/nimBinTools import getNimbleExecPath, getBinPath
from spec import ExtensionState

proc expand(client: VscodeLanguageClient, doc: VscodeTextDocument = nil): Future[void] {.async.} =
  discard
  # let result = client.sendRequest(
  #   "extension/expandAll".cstring,
  #   {
  #     "position": vscode.window.activeTextEditor.selection.active,
  #     "textDocument": vscode.window.activeTextEditor.selection.active,
  #    }.toJs,
  #   nil)
  # echo "----------"
  # echo (await result).to(cstring)
  # echo "----------"

proc startLanguageServer(tryInstall: bool, state: ExtensionState) =
  let rawPath = getBinPath("nimlangserver")
  if rawPath.isNil or not fs.existsSync(path.resolve(rawPath)):
    console.log("nimlangserver not found on path")
    if tryInstall and not state.installPerformed:
      let command = getNimbleExecPath() & " install nimlangserver --accept"
      vscode.window.showInformationMessage(
        cstring(fmt "Unable to find nimlangserver, trying to install it via '{command}'"))
      state.installPerformed = true
      discard cp.exec(
        command,
        ExecOptions{},
        proc(err: ExecError, stdout: cstring, stderr: cstring): void =
          console.log("Nimble install finished, validating by checking if nimlangserver is present.")
          startLanguageServer(false, state))
    else:
      vscode.window.showInformationMessage("Unable to find/install `nimlangserver`.")
  else:
    let nimlangserver = path.resolve(rawPath);
    console.log(fmt"nimlangserver found: {nimlangserver}".cstring)
    console.log("Starting nimlangserver.")
    let
      serverOptions = ServerOptions{
        run: Executable{command: nimlangserver, transport: "stdio" },
        debug: Executable{command: nimlangserver, transport: "stdio" }
      }
      clientOptions = LanguageClientOptions{
        documentSelector: @[DocumentFilter(scheme: cstring("file"),
                                           language: cstring("nim"))]
      }

    state.client = vscodeLanguageClient.newLanguageClient(
       cstring("nimlangserver"),
       cstring("Nim Language Server"),
       serverOptions,
       clientOptions)
    state.client.start()

    vscode.commands.registerCommand("nim.expand") do (doc: VscodeTextDocument = nil) -> Future[void]:
      expand(state.client, doc)

export startLanguageServer
